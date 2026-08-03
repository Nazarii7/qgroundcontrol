#include <QTimer>
#include <QtEndian>
#include <QDateTime>
#include <QTcpSocket>
#include <QTimerEvent>
#include <QUrl>
#include <QMutexLocker>

#include "SiYiCrcApi.h"
#include "SiYiTcpClient.h"



SiYiTcpClient::SiYiTcpClient(const QString ip, quint16 port, QObject *parent)
    : QThread(parent)
    , ip_(ip)
    , port_(port)
{
    sequence_ = quint16(QDateTime::currentMSecsSinceEpoch());
    // 自动重连
    connect(this, &SiYiTcpClient::finished, this, [=]() { start(); });
}

SiYiTcpClient::~SiYiTcpClient()
{
    if (isRunning()) {
        exit();
        wait();
    }
}

void SiYiTcpClient::sendMessage(const QByteArray &msg)
{
    if (isRunning()) {
        txMessageVectorMutex_.lock();
        txMessageVector_.append(msg);
        txMessageVectorMutex_.unlock();
    }
}

void SiYiTcpClient::analyzeIp(QString ip)
{
    ip = ip.trimmed();

    const QStringList parts = ip.split('.');
    if (parts.size() != 4) {
        qWarning() << "SIYI_INVALID_CONTROL_IP:" << ip;
        return;
    }

    for (const QString &part : parts) {
        bool ok = false;
        const int octet = part.toInt(&ok);

        if (!ok || octet < 0 || octet > 255) {
            qWarning() << "SIYI_INVALID_CONTROL_IP:" << ip;
            return;
        }
    }

    qInfo() << "SIYI_CONTROL_IP_RESOLVED:"
            << "old:" << ip_
            << "new:" << ip;

    resetIp(ip);
}


quint16 SiYiTcpClient::sequence()
{
    quint16 seq = sequence_;
    sequence_ += 1;
    return seq;
}

void SiYiTcpClient::run()
{
    QTcpSocket *tcpClient = new QTcpSocket();
    QTimer *txTimer = new QTimer();
    QTimer *rxTimer = new QTimer();
    QTimer *heartbeatTimer = new QTimer();
    const QString info = QString("[%1:%2]:").arg(ip_, QString::number(port_));

    tcpState_ = QStringLiteral("CONNECTING");
    emit tcpStateChanged();

    lastTcpError_ = QStringLiteral("None");
    emit lastTcpErrorChanged();

    qInfo() << "SIYI_TCP_CONNECT"
            << "ip:" << ip_
            << "port:" << port_;

    connect(tcpClient, &QTcpSocket::connected, tcpClient, [this, tcpClient, heartbeatTimer, txTimer, info]() {
        qInfo() << "SIYI_TCP_CONNECTED"
                << "ip:" << ip_
                << "port:" << port_;

        heartbeatTimer->start();
        txTimer->start();

        isConnected_ = true;
        tcpState_ = QStringLiteral("CONNECTED");
        lastTcpError_ = QStringLiteral("None");

        emit connected();
        emit isConnectedChanged();
        emit tcpStateChanged();
        emit lastTcpErrorChanged();
    });
    connect(tcpClient, &QTcpSocket::disconnected, tcpClient, [this, tcpClient, heartbeatTimer, info]() {
        const QString socketError = tcpClient->errorString();

        qInfo() << "SIYI_TCP_DISCONNECTED"
                << "ip:" << ip_
                << "port:" << port_
                << "reason:" << socketError;

        isConnected_ = false;
        tcpState_ = QStringLiteral("DISCONNECTED");

        if (!socketError.isEmpty()
            && socketError != QStringLiteral("Unknown error")) {
            lastTcpError_ = socketError;
            emit lastTcpErrorChanged();
        }

        {
            QMutexLocker locker(&txMessageVectorMutex_);
            txMessageVector_.clear();
        }

        emit disconnected();
        emit isConnectedChanged();
        emit tcpStateChanged();

        heartbeatTimer->stop();
        exit();
    });
    connect(
        tcpClient,
        &QTcpSocket::errorOccurred,
        tcpClient,
        [this, tcpClient, heartbeatTimer, info](QAbstractSocket::SocketError socketError) {
            Q_UNUSED(socketError)

            const QString errorText = tcpClient->errorString();

            qWarning() << "SIYI_TCP_ERROR"
                       << "ip:" << ip_
                       << "port:" << port_
                       << "error:" << errorText;

            isConnected_ = false;
            tcpState_ = QStringLiteral("ERROR");
            lastTcpError_ = errorText.isEmpty()
                                ? QStringLiteral("Unknown TCP error")
                                : errorText;

            emit isConnectedChanged();
            emit tcpStateChanged();
            emit lastTcpErrorChanged();
            emit disconnected();

            heartbeatTimer->stop();
            exit();
        });

    // 定时发送
    txTimer->setInterval(10);
    txTimer->setSingleShot(true);

    connect(
        txTimer,
        &QTimer::timeout,
        txTimer,
        [this, txTimer, tcpClient, info]()
        {
            this->txMessageVectorMutex_.lock();

            const QByteArray msg =
                this->txMessageVector_.isEmpty()
                    ? QByteArray()
                    : this->txMessageVector_.takeFirst();

            this->txMessageVectorMutex_.unlock();

            if (!msg.isEmpty()) {
                if (tcpClient->state() == QTcpSocket::ConnectedState) {
                    const qint64 written = tcpClient->write(msg);

                    if (written >= 0) {
                        qInfo() << "SIYI_TX_PACKET"
                                << info
                                << "written:" << written
                                << "size:" << msg.size()
                                << "packet:" << msg.toHex(' ');

                        tcpClient->flush();
                    } else {
                        qWarning() << "SIYI_TX_FAILED"
                                   << info
                                   << "error:" << tcpClient->errorString();
                    }
                } else {
                    qWarning() << "SIYI_TX_NOT_CONNECTED"
                               << info
                               << "state:" << tcpClient->state()
                               << "error:" << tcpClient->errorString();

                    exit();
                }
            }

            txTimer->start();
        }
        );

    // 定时处理接收数据
    rxTimer->setInterval(1);
    rxTimer->setSingleShot(true);
    connect(rxTimer, &QTimer::timeout, rxTimer, [=](){
        this->rxBytesMutex_.lock();

        QByteArray bytes = tcpClient->readAll();
        this->rxBytes_.append(bytes);

        analyzeMessage();

        this->rxBytesMutex_.unlock();

        rxTimer->start();
    });

    // 心跳
    heartbeatTimer->setInterval(1500);
    heartbeatTimer->setSingleShot(true);
    connect(heartbeatTimer, &QTimer::timeout, heartbeatTimer, [=](){
        // 心跳超时后退出线程
        this->timeoutCountMutex.lock();
        int count = this->timeoutCount;
        this->timeoutCountMutex.unlock();

        if (count > 3) {
            this->timeoutCountMutex.lock();
            this->timeoutCount = 0;
            this->timeoutCountMutex.unlock();

            qWarning() << "Heartbeat timeout, the client will be restart soon!";
            this->exit();
        }

        this->timeoutCountMutex.lock();
        this->timeoutCount += 1;
        this->timeoutCountMutex.unlock();

        QByteArray msg = heartbeatMessage();
        sendMessage(msg);
        heartbeatTimer->start();
    });

    tcpState_ = QStringLiteral("CONNECTING");
    emit tcpStateChanged();

    qInfo() << "SIYI_TCP_CONNECT_TO_HOST"
            << "ip:" << ip_
            << "port:" << port_;

    tcpClient->connectToHost(ip_, port_);

    //txTimer->start();
    rxTimer->start();
    exec();
    txTimer->deleteLater();
    tcpClient->deleteLater();
}

quint32 SiYiTcpClient::checkSum32(const QByteArray &bytes)
{
    return SiYiCrcApi::calculateCrc32(bytes);
}

void SiYiTcpClient::resetIp(const QString &ip)
{
    if (ip_ == ip) {
        qInfo() << "SIYI_CONTROL_IP_UNCHANGED:" << ip;
        return;
    }

    qInfo() << "SIYI_CONTROL_IP_CHANGE:"
            << "from:" << ip_
            << "to:" << ip;

    ip_ = ip;

    if (isRunning()) {
        exit();
        wait();
    } else {
        start();
    }

    emit ipChanged();
}
