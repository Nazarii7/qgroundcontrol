#include "NavigationSourceController.h"
#include "NavigationMavlink.h"

#include "AudioOutput.h"
#include "LinkInterface.h"
#include "MAVLinkProtocol.h"
#include "JoystickManager.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "Vehicle.h"

#include <chrono>
#include <cmath>
#include <cstring>

namespace {
constexpr qint64 HeartbeatTimeoutMs = 3500;
constexpr qint64 DataTimeoutMs = 3000;
constexpr qint64 SendIntervalMs = 200; // 5 Hz; RC_OVERRIDE_TIME is 3 s on this vehicle.
const char *const ConfigurationNames[] = {
    "VISNAV_CTRL_CH", "GPS_AUTO_SWITCH", "GPS2_TYPE", "GPS_PRIMARY",
    "RC5_MIN", "RC5_MAX", "RC5_OPTION", "FLTMODE_CH", "SYSID_MYGCS"
};
}

qint64 NavigationSourceController::monotonicMs()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch()).count();
}

NavigationSourceController::NavigationSourceController(Vehicle *vehicle)
    : QObject(vehicle), _vehicle(vehicle)
{
    connect(vehicle, &Vehicle::mavlinkMessageReceived,
            this, &NavigationSourceController::_handleMessage);
    // A validated QGC parameter cache can avoid the full PARAM_VALUE stream.
    // Use it only to discover support; all control parameters and the selected
    // source are still requested live before accepting a switch command.
    connect(vehicle->parameterManager(), &ParameterManager::parametersReadyChanged,
            this, [this](bool ready) {
                if (ready && _vehicle->parameterManager()->parameterExists(
                                 ParameterManager::defaultComponentId, "VISNAV_CTRL_CH")) {
                    _identified = true;
                    _lastConfigReadAt = -1;
                    _tick();
                }
            });
    connect(vehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged,
            this, [this](bool lost) {
                if (lost) {
                    _resetSession();
                    emit stateChanged();
                }
            });
    // Enabling a joystick or selecting another vehicle never replays a request.
    connect(vehicle, &Vehicle::joystickEnabledChanged, this, [this](bool) {
        _switch.resetControl();
        _voiceAnnouncementSource = NavigationSwitchState::Unknown;
        _acceptSamplesAfter = monotonicMs();
        _tick();
    });
    connect(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged,
            this, [this](Vehicle *) {
                _switch.resetControl();
                _voiceAnnouncementSource = NavigationSwitchState::Unknown;
                _acceptSamplesAfter = monotonicMs();
                _tick();
            });
    connect(JoystickManager::instance(), &JoystickManager::activeJoystickChanged,
            this, [this](Joystick *) {
                _switch.resetControl();
                _voiceAnnouncementSource = NavigationSwitchState::Unknown;
                _acceptSamplesAfter = monotonicMs();
                _tick();
            });
    _timer.setInterval(100);
    connect(&_timer, &QTimer::timeout, this, &NavigationSourceController::_tick);
    _timer.start();
}

bool NavigationSourceController::_connected() const
{
    return !_vehicle->isOfflineEditingVehicle()
           && !_vehicle->vehicleLinkManager()->communicationLost()
           && _heartbeatAt >= 0 && monotonicMs() - _heartbeatAt <= HeartbeatTimeoutMs;
}

bool NavigationSourceController::controlReady() const
{
    if (!_identified || !_connected()) {
        return false;
    }
    for (const char *name : ConfigurationNames) {
        if (!_parameters.contains(QString::fromLatin1(name))) {
            return false;
        }
    }
    // Deliberately scoped to the configuration proven by the supplied logs.
    return _parameters.value("VISNAV_CTRL_CH") == 5
           && _parameters.value("GPS_AUTO_SWITCH") == 0
           && _parameters.value("GPS2_TYPE") == 14
           && _parameters.value("RC5_MIN") == 988
           && _parameters.value("RC5_MAX") == 2011
           && _parameters.value("RC5_OPTION") == 0
           && _parameters.value("FLTMODE_CH") != 5
           && _parameters.value("SYSID_MYGCS") == MAVLinkProtocol::instance()->getSystemId()
           && _switch.source() != NavigationSwitchState::Unknown;
}

bool NavigationSourceController::_eligible() const
{
    return controlReady() && _vehicle->joystickEnabled()
           && MultiVehicleManager::instance()->activeVehicle() == _vehicle;
}

int NavigationSourceController::activeSource() const
{
    // GPS_PRIMARY describes the selected instance in this fixed-primary setup.
    // It is not a claim that the selected navigation solution is healthy.
    return _connected() && _parameters.contains("GPS_AUTO_SWITCH")
                   && _parameters.value("GPS_AUTO_SWITCH") == 0
               ? _switch.source() : NavigationSwitchState::Unknown;
}

bool NavigationSourceController::confirmationFailed() const
{
    return _switch.confirmationTimedOut(monotonicMs());
}

bool NavigationSourceController::initializing() const
{
    return _eligible() && !_armed
           && (!_switch.hasSample() || _switch.initialSynchronization());
}

bool NavigationSourceController::visnavDataAvailable() const
{
    // Once direct companion telemetry is seen, FC GPS2 re-publication cannot
    // mask its disappearance. GPS2 is a fallback for links that never route GPS_INPUT.
    const qint64 dataAt = _visnavAt >= 0 ? _visnavAt : _gps2At;
    return _connected() && dataAt >= 0 && monotonicMs() - dataAt <= DataTimeoutMs;
}

bool NavigationSourceController::activeDataAvailable() const
{
    const qint64 now = monotonicMs();
    if (activeSource() == 0) {
        return _gpsAt >= 0 && now - _gpsAt <= DataTimeoutMs;
    }
    if (activeSource() == 1) {
        return visnavDataAvailable() && _gps2At >= 0 && now - _gps2At <= DataTimeoutMs;
    }
    return false;
}

double NavigationSourceController::horizontalAccuracy() const
{
    if (!activeDataAvailable()) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    return activeSource() == 0 ? _gpsAccuracy : _gps2Accuracy;
}

int NavigationSourceController::horizontalPositionStatus() const
{
    if (!_connected() || _ekfAt < 0 || monotonicMs() - _ekfAt > DataTimeoutMs) {
        return 0;
    }
    return (_ekfFlags & (EKF_POS_HORIZ_REL | EKF_POS_HORIZ_ABS)) != 0
                   && (_ekfFlags & EKF_UNINITIALIZED) == 0 ? 1 : 2;
}

QString NavigationSourceController::statusText() const
{
    if (!_connected()) {
        return tr("NAV LINK LOST");
    }
    for (const char *name : ConfigurationNames) {
        if (!_parameters.contains(QString::fromLatin1(name))) {
            return tr("READ NAV CONFIG");
        }
    }
    if (!controlReady()) {
        return tr("CHECK NAV CONFIG");
    }
    if (!_vehicle->joystickEnabled()) {
        return tr("ENABLE JOYSTICK");
    }
    if (confirmationFailed()) {
        return tr("NAV NOT CONFIRMED");
    }
    if (pending()) {
        return _switch.requested() == 1 ? tr("WAIT: VISNAV") : tr("WAIT: GPS");
    }
    if (_switch.requested() == NavigationSwitchState::Unknown) {
        if (!_switch.hasSample()) {
            return tr("WAIT FOR SD");
        }
        return _switch.awaitingInitialSync() ? tr("SYNC SD") : tr("MOVE SD TO APPLY");
    }
    return tr("SOURCE CONFIRMED");
}

void NavigationSourceController::_resetSession()
{
    _switch.resetSession();
    _parameters.clear();
    _heartbeatAt = -1;
    _visnavAt = -1;
    _gps2At = -1;
    _gpsAt = -1;
    _ekfAt = -1;
    _gpsAccuracy = std::numeric_limits<double>::quiet_NaN();
    _gps2Accuracy = std::numeric_limits<double>::quiet_NaN();
    _ekfFlags = 0;
    _armed = true;
    _wasConnected = false;
    _lastConfigReadAt = -1;
    _lastPrimaryReadAt = -1;
    _sending = false;
    _lastSentPwm = -1;
    _voiceAnnouncementSource = NavigationSwitchState::Unknown;
    _lastBootMs = 0;
    _acceptSamplesAfter = monotonicMs();
}

void NavigationSourceController::_handleMessage(const mavlink_message_t &message)
{
    if (message.sysid != _vehicle->id()) {
        return;
    }
    const qint64 now = monotonicMs();
    const bool autopilot = message.compid == _vehicle->defaultComponentId();
    if (autopilot && message.msgid == MAVLINK_MSG_ID_HEARTBEAT) {
        if (_heartbeatAt >= 0 && now - _heartbeatAt > HeartbeatTimeoutMs) {
            _resetSession();
        }
        _heartbeatAt = now;
        mavlink_heartbeat_t heartbeat{};
        mavlink_msg_heartbeat_decode(&message, &heartbeat);
        _armed = (heartbeat.base_mode & MAV_MODE_FLAG_SAFETY_ARMED) != 0;
    } else if (autopilot && message.msgid == MAVLINK_MSG_ID_PARAM_VALUE) {
        mavlink_param_value_t value{};
        mavlink_msg_param_value_decode(&message, &value);
        const QString name = QString::fromLatin1(value.param_id, sizeof(value.param_id)).section(QChar(0), 0, 0);
        const double decoded = NavigationMavlink::parameterValue(value);
        if (!std::isfinite(decoded)) {
            return;
        }
        for (const char *wanted : ConfigurationNames) {
            if (name == QLatin1String(wanted)) {
                _parameters.insert(name, static_cast<float>(decoded));
                if (name == QLatin1String("VISNAV_CTRL_CH")) {
                    _identified = true;
                }
                if (name == QLatin1String("GPS_PRIMARY")) {
                    const int source = decoded == 0 ? 0 : decoded == 1 ? 1 : NavigationSwitchState::Unknown;
                    _switch.observeSource(source, now);
                    // Voice feedback belongs to a live SD command, not to
                    // startup discovery or repeated PARAM_VALUE messages.
                    if (_voiceAnnouncementSource == source
                        && _switch.requested() == source && !_switch.pending()) {
                        _announceSource(source);
                        _voiceAnnouncementSource = NavigationSwitchState::Unknown;
                    }
                }
                break;
            }
        }
    } else if (message.msgid == MAVLINK_MSG_ID_GPS_INPUT && message.compid == 192) {
        mavlink_gps_input_t input{};
        mavlink_msg_gps_input_decode(&message, &input);
        if (input.gps_id == 1) {
            _visnavAt = now;
        }
    } else if (autopilot && message.msgid == MAVLINK_MSG_ID_GPS_RAW_INT) {
        mavlink_gps_raw_int_t gps{};
        mavlink_msg_gps_raw_int_decode(&message, &gps);
        _gpsAt = now;
        _gpsAccuracy = gps.h_acc > 0 && gps.h_acc < UINT32_MAX
                           ? gps.h_acc * 0.001 : std::numeric_limits<double>::quiet_NaN();
    } else if (autopilot && message.msgid == MAVLINK_MSG_ID_GPS2_RAW) {
        // Presence of FC-reported GPS2 data, not a visual-navigation quality score.
        mavlink_gps2_raw_t gps{};
        mavlink_msg_gps2_raw_decode(&message, &gps);
        _gps2At = now;
        _gps2Accuracy = gps.h_acc > 0 && gps.h_acc < UINT32_MAX
                            ? gps.h_acc * 0.001 : std::numeric_limits<double>::quiet_NaN();
    } else if (autopilot && message.msgid == MAVLINK_MSG_ID_EKF_STATUS_REPORT) {
        mavlink_ekf_status_report_t ekf{};
        mavlink_msg_ekf_status_report_decode(&message, &ekf);
        _ekfAt = now;
        _ekfFlags = ekf.flags;
    } else if (autopilot && message.msgid == MAVLINK_MSG_ID_RC_CHANNELS) {
        mavlink_rc_channels_t channels{};
        mavlink_msg_rc_channels_decode(&message, &channels);
        if (_lastBootMs > channels.time_boot_ms
            && _lastBootMs - channels.time_boot_ms > 1000
            && _lastBootMs - channels.time_boot_ms < 0x80000000U) {
            _resetSession();
        }
        _lastBootMs = channels.time_boot_ms;
    }
    // STATUSTEXT stays in the existing journal. Its delayed mirrored copies
    // must never overwrite the numeric GPS_PRIMARY confirmation.
    _tick();
}

void NavigationSourceController::sampleSwitch(int button, bool pressed, qint64 sampledAt)
{
    if (sampledAt <= _acceptSamplesAfter) {
        return;
    }
    if (button < 0) {
        _switch.resetControl();
        _voiceAnnouncementSource = NavigationSwitchState::Unknown;
        _acceptSamplesAfter = sampledAt;
        _tick();
        return;
    }
    const int previousRequest = _switch.requested();
    _switch.sample(button, pressed, sampledAt, monotonicMs(), _eligible(), _connected() && !_armed);
    if (_switch.requested() >= 0 && _switch.requested() != previousRequest) {
        _lastPrimaryReadAt = -1;
        // Initial SD synchronization must stay silent. A physical SD edge is
        // announced only after the matching GPS_PRIMARY is received.
        if (!_switch.initialSynchronization()) {
            _voiceAnnouncementSource = _switch.requested();
        }
    }
    _tick();
}

void NavigationSourceController::_tick()
{
    const qint64 now = monotonicMs();
    const bool connected = _connected();
    if (_wasConnected && !connected) {
        _resetSession();
    }
    _wasConnected = connected;
    if (connected && _identified && (_lastConfigReadAt < 0 || now - _lastConfigReadAt >= 2000)) {
        _lastConfigReadAt = now;
        _requestConfiguration();
    }
    const int pwm = _switch.command(now, _eligible());
    if (pwm >= 0) {
        if (!_sending || pwm != _lastSentPwm || now - _lastSentAt >= SendIntervalMs) {
            _sendRc5(static_cast<quint16>(pwm));
            _sending = true;
            _lastSentAt = now;
            _lastSentPwm = pwm;
        }
    } else if (_sending) {
        // Release RC5 ownership only. This does not command GPS or affect sticks.
        if (connected) {
            _sendRc5(0);
        }
        _sending = false;
        _lastSentPwm = -1;
        _voiceAnnouncementSource = NavigationSwitchState::Unknown;
    }
    // One read scheduler, after the RC5 send. Do not issue another read from
    // sampleSwitch: that produced two identical PARAM_REQUEST_READ packets.
    if (connected && _identified && pending()
        && (_lastPrimaryReadAt < 0 || now - _lastPrimaryReadAt >= 1000)) {
        _requestParameter("GPS_PRIMARY");
    }
    const QString presentation = QStringLiteral("%1|%2|%3|%4|%5|%6|%7|%8|%9|%10|%11")
        .arg(_identified).arg(controlReady()).arg(activeSource()).arg(requestedSource())
        .arg(pending()).arg(visnavDataAvailable()).arg(statusText())
        .arg(activeDataAvailable()).arg(horizontalAccuracy()).arg(horizontalPositionStatus()).arg(initializing());
    if (presentation != _presentation) {
        _presentation = presentation;
        emit stateChanged();
    }
}

void NavigationSourceController::_announceSource(int source)
{
    if (source != 0 && source != 1) {
        return;
    }
    const QString vehicle = MultiVehicleManager::instance()->vehicles()->count() > 1
                                ? tr("Vehicle %1 ").arg(_vehicle->id()) : QString();
    const QString sourceName = source == 1 ? tr("VisNav active") : tr("GPS active");
    AudioOutput::instance()->say(QStringLiteral("%1%2").arg(vehicle, sourceName).toLower());
}

void NavigationSourceController::_sendRc5(quint16 pwm)
{
    const SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link || link->linkConfiguration()->isHighLatency()) {
        return;
    }
    const mavlink_message_t message = NavigationMavlink::rc5Override(
        static_cast<uint8_t>(MAVLinkProtocol::instance()->getSystemId()),
        static_cast<uint8_t>(MAVLinkProtocol::getComponentId()), link->mavlinkChannel(),
        static_cast<uint8_t>(_vehicle->id()),
        static_cast<uint8_t>(_vehicle->defaultComponentId()), pwm);
    _vehicle->sendMessageOnLinkThreadSafe(link.get(), message);
}

void NavigationSourceController::_requestParameter(const char *name)
{
    const SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link || link->linkConfiguration()->isHighLatency()) {
        return;
    }
    if (std::strcmp(name, "GPS_PRIMARY") == 0) {
        _lastPrimaryReadAt = monotonicMs();
    }
    const mavlink_message_t message = NavigationMavlink::parameterRead(
        static_cast<uint8_t>(MAVLinkProtocol::instance()->getSystemId()),
        static_cast<uint8_t>(MAVLinkProtocol::getComponentId()), link->mavlinkChannel(),
        static_cast<uint8_t>(_vehicle->id()),
        static_cast<uint8_t>(_vehicle->defaultComponentId()), name);
    _vehicle->sendMessageOnLinkThreadSafe(link.get(), message);
}

void NavigationSourceController::_requestConfiguration()
{
    for (const char *name : ConfigurationNames) {
        if (!_parameters.contains(QString::fromLatin1(name))) {
            _requestParameter(name);
        }
    }
}
