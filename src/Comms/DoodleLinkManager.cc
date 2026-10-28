/****************************************************************************
 *
 * DoodleLinkManager.cc
 * Read-only Doodle Labs operating-frequency and per-antenna RSSI provider for QML.
 *
 ****************************************************************************/

#include "DoodleLinkManager.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonParseError>
#include <QtCore/QLoggingCategory>
#include <QtCore/QRegularExpression>
#include <QtCore/QtGlobal>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QSslError>
#include <QtQml/qqml.h>

Q_LOGGING_CATEGORY(DoodleLinkManagerLog, "qgc.comms.doodlelink")

namespace {
constexpr auto kDoodleEndpoint = "https://10.223.30.250/ubus";
constexpr auto kDoodleHost = "10.223.30.250";
constexpr auto kDoodleUser = "root";
constexpr auto kDoodlePassword = "";
constexpr auto kWirelessDevice = "wlan0";
constexpr auto kAnonymousSession = "00000000000000000000000000000000";
constexpr int kPollIntervalMs = 1000;
constexpr int kRequestTimeoutMs = 3000;
constexpr int kFailuresBeforeInvalid = 3;
}

DoodleLinkManager::DoodleLinkManager(QObject *parent)
    : QObject(parent)
{
    _pollTimer.setInterval(kPollIntervalMs);
    _pollTimer.setSingleShot(false);

    (void) connect(&_pollTimer, &QTimer::timeout, this, &DoodleLinkManager::_poll);
}

DoodleLinkManager *DoodleLinkManager::instance()
{
    static DoodleLinkManager *s_instance =
        new DoodleLinkManager(QCoreApplication::instance());

    return s_instance;
}

void DoodleLinkManager::registerQmlSingleton()
{
    qmlRegisterSingletonInstance(
        "QGroundControl.DoodleLink",
        1,
        0,
        "DoodleLinkManager",
        DoodleLinkManager::instance());
}

void DoodleLinkManager::init()
{
    if (_initialized) {
        return;
    }

    _initialized = true;
    _pollTimer.start();

            // Do not wait for the first timer tick before requesting live data.
    QTimer::singleShot(0, this, &DoodleLinkManager::_poll);
}

void DoodleLinkManager::_poll()
{
    if (_requestInFlight) {
        return;
    }

    if (_session.isEmpty()) {
        _login();
    } else {
        _requestChannelInfo();
    }
}

void DoodleLinkManager::_login()
{
    if (_requestInFlight) {
        return;
    }

    const QJsonObject credentials {
                                  {QStringLiteral("username"), QString::fromLatin1(kDoodleUser)},
                                  {QStringLiteral("password"), QString::fromLatin1(kDoodlePassword)},
                                  };

    const QJsonArray params {
        QString::fromLatin1(kAnonymousSession),
        QStringLiteral("session"),
        QStringLiteral("login"),
        credentials,
    };

    const QJsonObject requestObject {
                                    {QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                                    {QStringLiteral("id"), 1},
                                    {QStringLiteral("method"), QStringLiteral("call")},
                                    {QStringLiteral("params"), params},
                                    };

    QNetworkRequest request(QUrl(QString::fromLatin1(kDoodleEndpoint)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(kRequestTimeoutMs);

    _requestInFlight = true;
    QNetworkReply *const reply = _networkAccessManager.post(
        request,
        QJsonDocument(requestObject).toJson(QJsonDocument::Compact));

    _configureReply(reply);

    (void) connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        _requestInFlight = false;

        if (reply->error() != QNetworkReply::NoError) {
            const QString errorText = QStringLiteral("Doodle login failed: %1").arg(reply->errorString());
            reply->deleteLater();
            _handleFailure(errorText, true);
            return;
        }

        const QByteArray payload = reply->readAll();
        reply->deleteLater();

        QJsonObject resultObject;
        QString errorText;
        if (!_parseRpcResult(payload, resultObject, errorText)) {
            _handleFailure(QStringLiteral("Doodle login RPC failed: %1").arg(errorText), true);
            return;
        }

        const QString session = resultObject.value(QStringLiteral("ubus_rpc_session")).toString();
        if (session.isEmpty()) {
            _handleFailure(QStringLiteral("Doodle login response has no ubus_rpc_session"), true);
            return;
        }

        _session = session;
        _lastLoggedError.clear();

                // Fetch channel/frequency first, then the per-antenna RSSI sample.
        QTimer::singleShot(0, this, &DoodleLinkManager::_requestChannelInfo);
    });
}

void DoodleLinkManager::_requestChannelInfo()
{
    if (_requestInFlight || _session.isEmpty()) {
        return;
    }
    const QJsonObject execArguments {
        {QStringLiteral("command"), QStringLiteral("iw")},
        {QStringLiteral("params"), QJsonArray {
                                       QString::fromLatin1(kWirelessDevice),
                                       QStringLiteral("info"),
                                   }},
    };

    const QJsonArray params {
        _session,
        QStringLiteral("file"),
        QStringLiteral("exec"),
        execArguments,
    };

    const QJsonObject requestObject {
                                    {QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                                    {QStringLiteral("id"), 2},
                                    {QStringLiteral("method"), QStringLiteral("call")},
                                    {QStringLiteral("params"), params},
                                    };

    QNetworkRequest request(QUrl(QString::fromLatin1(kDoodleEndpoint)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(kRequestTimeoutMs);

    _requestInFlight = true;
    QNetworkReply *const reply = _networkAccessManager.post(
        request,
        QJsonDocument(requestObject).toJson(QJsonDocument::Compact));

    _configureReply(reply);

    (void) connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        _requestInFlight = false;

                // Frequency and RSSI are independent values. Even if file/exec or its
                // output is unavailable, continue the existing assoclist request.
        const auto requestAssocList = [this]() {
            if (!_session.isEmpty()) {
                _requestAssocList();
            }
        };

        if (reply->error() != QNetworkReply::NoError) {
            const QString errorText = QStringLiteral("Doodle channel info failed: %1").arg(reply->errorString());
            reply->deleteLater();
            _handleFrequencyFailure(errorText);
            requestAssocList();
            return;
        }

        const QByteArray payload = reply->readAll();
        reply->deleteLater();

        QJsonObject resultObject;
        QString errorText;
        if (!_parseRpcResult(payload, resultObject, errorText)) {
            // Let the following assoclist call retain the existing stale-session
            // recovery behavior without coupling frequency validity to RSSI.
            _handleFrequencyFailure(QStringLiteral("Doodle channel info RPC failed: %1").arg(errorText));
            requestAssocList();
            return;
        }

        int frequencyMHz = -1;
        if (!_parseFrequencyMHz(resultObject, frequencyMHz, errorText)) {
            _handleFrequencyFailure(QStringLiteral("Doodle frequency unavailable: %1").arg(errorText));
            requestAssocList();
            return;
        }

        _setFrequencyMHz(frequencyMHz);
        requestAssocList();
    });
}

void DoodleLinkManager::_requestAssocList()
{
    if (_requestInFlight || _session.isEmpty()) {
        return;
    }

    const QJsonObject assocArguments {
                                     {QStringLiteral("device"), QString::fromLatin1(kWirelessDevice)},
                                     };

    const QJsonArray params {
        _session,
        QStringLiteral("iwinfo"),
        QStringLiteral("assoclist"),
        assocArguments,
    };

    const QJsonObject requestObject {
                                    {QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                                    {QStringLiteral("id"), 3},
                                    {QStringLiteral("method"), QStringLiteral("call")},
                                    {QStringLiteral("params"), params},
                                    };

    QNetworkRequest request(QUrl(QString::fromLatin1(kDoodleEndpoint)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(kRequestTimeoutMs);

    _requestInFlight = true;
    QNetworkReply *const reply = _networkAccessManager.post(
        request,
        QJsonDocument(requestObject).toJson(QJsonDocument::Compact));

    _configureReply(reply);

    (void) connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        _requestInFlight = false;

        if (reply->error() != QNetworkReply::NoError) {
            const QString errorText = QStringLiteral("Doodle assoclist failed: %1").arg(reply->errorString());
            reply->deleteLater();
            _handleFailure(errorText);
            return;
        }

        const QByteArray payload = reply->readAll();
        reply->deleteLater();

        QJsonObject resultObject;
        QString errorText;
        if (!_parseRpcResult(payload, resultObject, errorText)) {
            // A stale/expired UBUS session is recovered by logging in again on
            // the next polling cycle. This does not affect any other QGC link.
            _handleFailure(QStringLiteral("Doodle assoclist RPC failed: %1").arg(errorText), true);
            return;
        }

        QVariantList antennaRssi;
        if (!_parseAntennaRssi(resultObject, antennaRssi, errorText)) {
            _handleFailure(QStringLiteral("Doodle antenna RSSI unavailable: %1").arg(errorText));
            return;
        }

        _setAntennaRssi(antennaRssi);
    });
}

void DoodleLinkManager::_configureReply(QNetworkReply *reply)
{
    if (!reply) {
        return;
    }

            // The lab Doodle endpoint uses its own/self-signed HTTPS certificate.
            // Ignore SSL validation errors only for this exact private Doodle host and
            // only inside this dedicated manager. No global QGC SSL behavior changes.
    (void) connect(reply, &QNetworkReply::sslErrors, this,
                  [reply](const QList<QSslError> &errors) {
                      const QUrl url = reply->url();
                      if (url.scheme() == QStringLiteral("https")
                          && url.host() == QString::fromLatin1(kDoodleHost)) {
                          reply->ignoreSslErrors(errors);
                      }
                  });
}

bool DoodleLinkManager::_parseRpcResult(
    const QByteArray &payload,
    QJsonObject &resultObject,
    QString &errorText) const
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(payload, &parseError);

    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        errorText = parseError.error != QJsonParseError::NoError
                        ? parseError.errorString()
                        : QStringLiteral("response is not a JSON object");
        return false;
    }

    const QJsonArray result = document.object().value(QStringLiteral("result")).toArray();
    if (result.size() < 2) {
        errorText = QStringLiteral("missing JSON-RPC result array");
        return false;
    }

    const int status = result.at(0).toInt(-1);
    if (status != 0) {
        errorText = QStringLiteral("UBUS status %1").arg(status);
        return false;
    }

    if (!result.at(1).isObject()) {
        errorText = QStringLiteral("JSON-RPC result payload is not an object");
        return false;
    }

    resultObject = result.at(1).toObject();
    return true;
}

bool DoodleLinkManager::_parseFrequencyMHz(
    const QJsonObject &resultObject,
    int &frequencyMHz,
    QString &errorText) const
{
    const QJsonValue codeValue = resultObject.value(QStringLiteral("code"));
    if (!codeValue.isDouble()) {
        errorText = QStringLiteral("file/exec response has no numeric exit code");
        return false;
    }

    const int exitCode = codeValue.toInt(-1);
    if (exitCode != 0) {
        const QString stderrText = resultObject.value(QStringLiteral("stderr")).toString().trimmed();
        errorText = stderrText.isEmpty()
                        ? QStringLiteral("iw exited with code %1").arg(exitCode)
                        : QStringLiteral("iw exited with code %1: %2").arg(exitCode).arg(stderrText);
        return false;
    }

    const QString output = resultObject.value(QStringLiteral("stdout")).toString();
    if (output.isEmpty()) {
        errorText = QStringLiteral("iw returned empty stdout");
        return false;
    }

            // Typical line: channel 149 (5745 MHz), width: 20 MHz, center1: 5745 MHz
            // Anchor to the channel field so bandwidth/center-frequency numbers cannot
            // be mistaken for the active operating frequency.
    static const QRegularExpression frequencyPattern(
        QStringLiteral(R"(\bchannel\s+\d+\s+\(\s*(\d+(?:\.\d+)?)\s*MHz\s*\))"),
        QRegularExpression::CaseInsensitiveOption);

    const QRegularExpressionMatch match = frequencyPattern.match(output);
    if (!match.hasMatch()) {
        errorText = QStringLiteral("channel frequency is missing from iw output");
        return false;
    }

    bool conversionOk = false;
    const double parsedMHz = match.captured(1).toDouble(&conversionOk);
    if (!conversionOk || !qIsFinite(parsedMHz)) {
        errorText = QStringLiteral("channel frequency is not numeric");
        return false;
    }

    const int roundedMHz = qRound(parsedMHz);
    if (roundedMHz < 100 || roundedMHz > 100000) {
        errorText = QStringLiteral("channel frequency is outside the supported range: %1 MHz").arg(parsedMHz);
        return false;
    }

    frequencyMHz = roundedMHz;
    return true;
}

bool DoodleLinkManager::_parseAntennaRssi(
    const QJsonObject &resultObject,
    QVariantList &antennaRssi,
    QString &errorText) const
{
    const QJsonArray stations = resultObject.value(QStringLiteral("results")).toArray();

    if (stations.isEmpty()) {
        errorText = QStringLiteral("no associated station on wlan0");
        return false;
    }

            // Do not silently display a random peer when a mesh has multiple associated
            // stations. The current LS2 lab topology has exactly one remote Doodle peer.
    if (stations.size() != 1) {
        errorText = QStringLiteral("expected one associated station, got %1").arg(stations.size());
        return false;
    }

    const QJsonObject station = stations.first().toObject();
    const QJsonArray signalAnt = station.value(QStringLiteral("signal_ant")).toArray();

    if (signalAnt.isEmpty()) {
        errorText = QStringLiteral("signal_ant is missing or empty");
        return false;
    }

    QVariantList values;
    values.reserve(signalAnt.size());

    for (const QJsonValue &value : signalAnt) {
        if (!value.isDouble()) {
            errorText = QStringLiteral("signal_ant contains a non-numeric value");
            return false;
        }

        const int rssi = qRound(value.toDouble());
        if (rssi < -200 || rssi > 0) {
            errorText = QStringLiteral("signal_ant contains an invalid RSSI value: %1").arg(rssi);
            return false;
        }

        values.append(rssi);
    }

    antennaRssi = values;
    return true;
}

void DoodleLinkManager::_setFrequencyMHz(int frequencyMHz)
{
    _consecutiveFrequencyFailures = 0;
    _lastLoggedFrequencyError.clear();

    if (_frequencyMHz != frequencyMHz) {
        _frequencyMHz = frequencyMHz;
        emit frequencyMHzChanged();
    }
}

void DoodleLinkManager::_setAntennaRssi(const QVariantList &antennaRssi)
{
    _consecutiveFailures = 0;
    _lastLoggedError.clear();

    if (_antennaRssi != antennaRssi) {
        _antennaRssi = antennaRssi;
        emit antennaRssiChanged();
    }

    if (!_valid) {
        _valid = true;
        emit validChanged();
    }
}

void DoodleLinkManager::_handleFrequencyFailure(const QString &reason, bool logWarning)
{
    ++_consecutiveFrequencyFailures;

    if (logWarning && _lastLoggedFrequencyError != reason) {
        _lastLoggedFrequencyError = reason;
        qCWarning(DoodleLinkManagerLog) << reason;
    }

            // Keep the last good value through two short failures, matching RSSI.
    if (_consecutiveFrequencyFailures >= kFailuresBeforeInvalid && _frequencyMHz >= 0) {
        _frequencyMHz = -1;
        emit frequencyMHzChanged();
    }
}

void DoodleLinkManager::_handleFailure(const QString &reason, bool clearSession)
{
    if (clearSession) {
        _session.clear();
        _handleFrequencyFailure(reason, false);
    }

    ++_consecutiveFailures;

    if (_lastLoggedError != reason) {
        _lastLoggedError = reason;
        qCWarning(DoodleLinkManagerLog) << reason;
    }

            // Keep the last good sample through short one/two-cycle network glitches,
            // then clearly invalidate it instead of leaving stale RSSI on screen.
    if (_consecutiveFailures >= kFailuresBeforeInvalid) {
        _setUnavailable();
    }
}

void DoodleLinkManager::_setUnavailable()
{
    if (!_antennaRssi.isEmpty()) {
        _antennaRssi.clear();
        emit antennaRssiChanged();
    }

    if (_valid) {
        _valid = false;
        emit validChanged();
    }
}
