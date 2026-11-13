#pragma once

#include "NavigationSwitchState.h"
#include "QGCMAVLink.h"

#include <QtCore/QMap>
#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QString>

#include <limits>

class Vehicle;

// One controller per Vehicle. All mutable state and MAVLink sends stay on the
// Vehicle thread; joystick samples arrive through a queued connection.
class NavigationSourceController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool identified READ identified NOTIFY stateChanged)
    Q_PROPERTY(bool controlReady READ controlReady NOTIFY stateChanged)
    Q_PROPERTY(int activeSource READ activeSource NOTIFY stateChanged)
    Q_PROPERTY(int requestedSource READ requestedSource NOTIFY stateChanged)
    Q_PROPERTY(bool pending READ pending NOTIFY stateChanged)
    Q_PROPERTY(bool initializing READ initializing NOTIFY stateChanged)
    Q_PROPERTY(bool confirmationFailed READ confirmationFailed NOTIFY stateChanged)
    Q_PROPERTY(bool visnavDataAvailable READ visnavDataAvailable NOTIFY stateChanged)
    Q_PROPERTY(bool activeDataAvailable READ activeDataAvailable NOTIFY stateChanged)
    Q_PROPERTY(double horizontalAccuracy READ horizontalAccuracy NOTIFY stateChanged)
    Q_PROPERTY(int horizontalPositionStatus READ horizontalPositionStatus NOTIFY stateChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY stateChanged)

public:
    explicit NavigationSourceController(Vehicle *vehicle);

    bool identified() const { return _identified; }
    bool controlReady() const;
    int activeSource() const;
    int requestedSource() const { return _switch.requested(); }
    bool pending() const { return _switch.pending(); }
    bool initializing() const;
    bool confirmationFailed() const;
    bool visnavDataAvailable() const;
    bool activeDataAvailable() const;
    double horizontalAccuracy() const;
    // 0: unknown/stale, 1: EKF reports horizontal position, 2: unavailable.
    int horizontalPositionStatus() const;
    QString statusText() const;

    static qint64 monotonicMs();

public slots:
    void sampleSwitch(int button, bool pressed, qint64 sampledAt);

signals:
    void stateChanged();

private:
    void _handleMessage(const mavlink_message_t &message);
    void _tick();
    void _announceSource(int source);
    void _resetSession();
    bool _connected() const;
    bool _eligible() const;
    void _sendRc5(quint16 pwm);
    void _requestParameter(const char *name);
    void _requestConfiguration();

    Vehicle *const _vehicle;
    QTimer _timer;
    NavigationSwitchState _switch;
    QMap<QString, float> _parameters;
    bool _identified = false;
    bool _wasConnected = false;
    bool _sending = false;
    qint64 _heartbeatAt = -1;
    qint64 _visnavAt = -1;
    qint64 _gps2At = -1;
    qint64 _gpsAt = -1;
    qint64 _ekfAt = -1;
    double _gpsAccuracy = std::numeric_limits<double>::quiet_NaN();
    double _gps2Accuracy = std::numeric_limits<double>::quiet_NaN();
    quint16 _ekfFlags = 0;
    bool _armed = true; // No automatic initialization before a live heartbeat.
    qint64 _lastConfigReadAt = -1;
    qint64 _lastPrimaryReadAt = -1;
    qint64 _lastSentAt = -1;
    qint64 _acceptSamplesAfter = 0;
    quint32 _lastBootMs = 0;
    int _lastSentPwm = -1;
    int _voiceAnnouncementSource = NavigationSwitchState::Unknown;
    QString _presentation;
};
