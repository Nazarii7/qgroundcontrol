/****************************************************************************
 *
 * DoodleLinkManager.h
 * Read-only Doodle Labs operating-frequency and per-antenna RSSI provider for QML.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QJsonObject>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtCore/QVariant>
#include <QtNetwork/QNetworkAccessManager>

class QNetworkReply;

class DoodleLinkManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList antennaRssi READ antennaRssi NOTIFY antennaRssiChanged)
    Q_PROPERTY(int frequencyMHz READ frequencyMHz NOTIFY frequencyMHzChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY validChanged)

   public:
    explicit DoodleLinkManager(QObject *parent = nullptr);

    static DoodleLinkManager *instance();
    static void registerQmlSingleton();

            /// Starts read-only polling of the Doodle UBUS endpoint.
            /// Safe to call more than once.
    void init();

    QVariantList antennaRssi() const { return _antennaRssi; }
    int frequencyMHz() const { return _frequencyMHz; }
    bool valid() const { return _valid; }

   signals:
    void antennaRssiChanged();
    void frequencyMHzChanged();
    void validChanged();

   private:
    void _poll();
    void _login();
    void _requestChannelInfo();
    void _requestAssocList();
    void _configureReply(QNetworkReply *reply);

    bool _parseRpcResult(const QByteArray &payload, QJsonObject &resultObject, QString &errorText) const;
    bool _parseFrequencyMHz(const QJsonObject &resultObject, int &frequencyMHz, QString &errorText) const;
    bool _parseAntennaRssi(const QJsonObject &resultObject, QVariantList &antennaRssi, QString &errorText) const;

    void _setFrequencyMHz(int frequencyMHz);
    void _setAntennaRssi(const QVariantList &antennaRssi);
    void _handleFrequencyFailure(const QString &reason, bool logWarning = true);
    void _handleFailure(const QString &reason, bool clearSession = false);
    void _setUnavailable();

    QNetworkAccessManager _networkAccessManager;
    QTimer _pollTimer;

    QString _session;
    QVariantList _antennaRssi;
    int _frequencyMHz = -1;
    QString _lastLoggedError;
    QString _lastLoggedFrequencyError;

    bool _initialized = false;
    bool _requestInFlight = false;
    bool _valid = false;
    int _consecutiveFailures = 0;
    int _consecutiveFrequencyFailures = 0;
};
