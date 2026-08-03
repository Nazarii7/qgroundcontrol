#include <QCoreApplication>
#include <QQmlEngine>
#include <QJSEngine>

#include "SiYi.h"
#include "SiYiTcpClient.h"

SiYi *SiYi::instance_ = Q_NULLPTR;
SiYi::SiYi(QObject *parent)
    : QObject{parent}
{
    camera_ = new SiYiCamera(this);
    transmitter_ = new SiYiTransmitter(this);
    connect(transmitter_, &SiYiTcpClient::connected, this, [this]() {
        isTransmitterConnected_ = true;

        if (!camera_->isRunning()) {
            camera_->start();
        }
    });

    connect(transmitter_, &SiYiTcpClient::disconnected, this, [this]() {
        isTransmitterConnected_ = false;
    });

#if 0
    connect(transmitter_, &SiYiCamera::ipChanged, this, [=](){
        if (transmitter_->isRunning()) {
            transmitter_->exit();
            transmitter_->wait();
        }

        transmitter_->start();
    });
#endif
#ifdef Q_OS_ANDROID
    isAndroid_ = true;
#else
    isAndroid_ = false;
#endif

    transmitter_->start();
#if 1   // ä¸º1æ—¶ï¼Œäº‘å°æŽ§åˆ¶æ— éœ€å…ˆè¿žæŽ¥
    camera_->start();
#endif
}

SiYi *SiYi::instance()
{
    if (!instance_) {
        instance_ = new SiYi(qApp);
    }

    Q_ASSERT_X(instance_, __FUNCTION__,
               "Can not allocate memory for SiYi instance!");
    return instance_;
}

SiYiCamera *SiYi::cameraInstance()
{
    return camera_;
}

SiYiTransmitter *SiYi::transmitterInstance()
{
    return transmitter_;
}

void SiYi::registerQmlSingleton()
{
    qmlRegisterSingletonType<SiYi>("SiYi.Object", 1, 0, "SiYi",
        [](QQmlEngine *engine, QJSEngine *) -> QObject * {
            SiYi *singleton = SiYi::instance();
            QQmlEngine::setObjectOwnership(singleton, QQmlEngine::CppOwnership);
            Q_UNUSED(engine)
            return singleton;
        });

    qmlRegisterUncreatableType<SiYiCamera>(
        "SiYi.Object", 1, 0, "SiYiCamera",
        "SiYiCamera is available through SiYi.camera");

    qmlRegisterUncreatableType<SiYiTransmitter>(
        "SiYi.Object", 1, 0, "SiYiTransmitter",
        "SiYiTransmitter is available through SiYi.transmitter");
}
