#include "DropWidgetSettings.h"

#include "Fact.h"
#include "ParameterManager.h"

#include <QCoreApplication>
#include <QtQml/qqml.h>

namespace {
static constexpr const char* kActiveServosKey  = "DropWidget/ActiveServos";
static constexpr const char* kPanelXKey        = "DropWidget/PanelX";
static constexpr const char* kPanelYKey        = "DropWidget/PanelY";
static constexpr const char* kPanelExpandedKey = "DropWidget/PanelExpanded";
static constexpr const char* kDropModeKey      = "DropWidget/DropMode";
static constexpr const char* kControlBehaviorKey = "DropWidget/ControlBehavior";
static constexpr const char* kServoOrderKey    = "DropWidget/ServoOrder";
static constexpr const char* kServoPwmPositionsKey = "DropWidget/ServoPwmPositions";
static constexpr const char* kCameraControlsVisibleKey = "FlyViewWidgets/CameraControlsVisible";
static constexpr const char* kCameraControlsLockedKey = "FlyViewWidgets/CameraControlsLocked";
static constexpr const char* kCameraControlsXKey = "FlyViewWidgets/CameraControlsX";
static constexpr const char* kCameraControlsYKey = "FlyViewWidgets/CameraControlsY";
static constexpr const char* kPhotoVideoVisibleKey = "FlyViewWidgets/PhotoVideoVisible";
static constexpr const char* kPhotoVideoLockedKey = "FlyViewWidgets/PhotoVideoLocked";
static constexpr const char* kPhotoVideoXKey = "FlyViewWidgets/PhotoVideoX";
static constexpr const char* kPhotoVideoYKey = "FlyViewWidgets/PhotoVideoY";
static constexpr const char* kDropWidgetVisibleKey = "FlyViewWidgets/DropWidgetVisible";
static constexpr const char* kControllerInputVisibleKey = "FlyViewWidgets/ControllerInputVisible";
static constexpr const char* kCameraLogsVisibleKey = "FlyViewWidgets/CameraLogsVisible";
static constexpr const char* kLinkOsdVisibleKey = "FlyViewHUD/LinkVisible";
static constexpr const char* kGpsOsdVisibleKey = "FlyViewHUD/GpsVisible";
static constexpr const char* kBatteryOsdVisibleKey = "FlyViewHUD/BatteryVisible";
static constexpr const char* kAltitudeOsdVisibleKey = "FlyViewHUD/AltitudeVisible";
static constexpr const char* kHorizonOsdVisibleKey = "FlyViewHUD/HorizonVisible";
static constexpr const char* kCompassOsdVisibleKey = "FlyViewHUD/CompassVisible";
static constexpr const char* kHomeOsdVisibleKey = "FlyViewHUD/HomeVisible";
static constexpr const char* kHudTransparentBackgroundKey = "FlyViewHUD/TransparentBackground";

static QString servoFunctionParamName(int servoNumber)
{
    return QStringLiteral("SERVO%1_FUNCTION").arg(servoNumber);
}

static bool isServoFunctionAllowed(int functionValue)
{
    return functionValue == 0 ||
           functionValue == 1 ||
           functionValue == 22 ||
           functionValue == 23 ||
           (functionValue >= 51 && functionValue <= 66);
}

static QString servoFunctionLabel(int functionValue)
{
    switch (functionValue) {
        case 0:
            return QStringLiteral("Disabled");
        case 1:
            return QStringLiteral("RCPassThru");
        case 22:
            return QStringLiteral("SprayerPump");
        case 23:
            return QStringLiteral("SprayerSpinner");
        case 33:
            return QStringLiteral("Motor 1");
        case 34:
            return QStringLiteral("Motor 2");
        case 35:
            return QStringLiteral("Motor 3");
        case 36:
            return QStringLiteral("Motor 4");
        case 37:
            return QStringLiteral("Motor 5");
        case 38:
            return QStringLiteral("Motor 6");
        case 39:
            return QStringLiteral("Motor 7");
        case 40:
            return QStringLiteral("Motor 8");
        default:
            if (functionValue >= 51 && functionValue <= 66) {
                return QStringLiteral("RCIN%1").arg(functionValue - 50);
            }

            return QStringLiteral("Function %1").arg(functionValue);
    }
}

static QVariantMap makeAvailabilityResult(
    int servoNumber,
    const QString& paramName,
    int functionValue,
    bool available,
    const QString& text)
{
    QVariantMap result;
    result.insert(QStringLiteral("servoNumber"), servoNumber);
    result.insert(QStringLiteral("paramName"), paramName);
    result.insert(QStringLiteral("functionValue"), functionValue);
    result.insert(QStringLiteral("available"), available);
    result.insert(QStringLiteral("text"), text);
    return result;
}
}

DropWidgetSettings::DropWidgetSettings(QObject* parent)
    : QObject(parent)
{
}

DropWidgetSettings* DropWidgetSettings::instance()
{
    static DropWidgetSettings* s_instance =
        new DropWidgetSettings(QCoreApplication::instance());
    return s_instance;
}

void DropWidgetSettings::registerQmlSingleton()
{
    qmlRegisterSingletonInstance(
        "QGroundControl.FlightDisplay",
        1, 0,
        "DropWidgetSettings",
        DropWidgetSettings::instance());
}

QString DropWidgetSettings::activeServos() const
{
    return _settings.value(kActiveServosKey, QString()).toString();
}

void DropWidgetSettings::setActiveServos(const QString& value)
{
    if (activeServos() == value) {
        return;
    }

    _settings.setValue(kActiveServosKey, value);
    _settings.sync();
    emit activeServosChanged();
}

double DropWidgetSettings::panelX() const
{
    return _settings.value(kPanelXKey, -1.0).toDouble();
}

void DropWidgetSettings::setPanelX(double value)
{
    if (panelX() == value) {
        return;
    }

    _settings.setValue(kPanelXKey, value);
    _settings.sync();
    emit panelXChanged();
}

double DropWidgetSettings::panelY() const
{
    return _settings.value(kPanelYKey, -1.0).toDouble();
}

void DropWidgetSettings::setPanelY(double value)
{
    if (panelY() == value) {
        return;
    }

    _settings.setValue(kPanelYKey, value);
    _settings.sync();
    emit panelYChanged();
}

void DropWidgetSettings::setPanelPosition(double x, double y)
{
    const bool xChanged = panelX() != x;
    const bool yChanged = panelY() != y;

    if (!xChanged && !yChanged) {
        return;
    }

    if (xChanged) {
        _settings.setValue(kPanelXKey, x);
    }

    if (yChanged) {
        _settings.setValue(kPanelYKey, y);
    }

    _settings.sync();

    if (xChanged) {
        emit panelXChanged();
    }

    if (yChanged) {
        emit panelYChanged();
    }
}

bool DropWidgetSettings::panelExpanded() const
{
    return _settings.value(kPanelExpandedKey, true).toBool();
}

void DropWidgetSettings::setPanelExpanded(bool value)
{
    if (panelExpanded() == value) {
        return;
    }

    _settings.setValue(kPanelExpandedKey, value);
    _settings.sync();
    emit panelExpandedChanged();
}

int DropWidgetSettings::dropMode() const
{
    return _settings.value(kDropModeKey, 0).toInt();
}

void DropWidgetSettings::setDropMode(int value)
{
    if (dropMode() == value) {
        return;
    }

    _settings.setValue(kDropModeKey, value);
    _settings.sync();
    emit dropModeChanged();
}

int DropWidgetSettings::controlBehavior() const
{
    // Value 0 is the legacy Standard behavior. Keeping it as the default
    // guarantees that existing installations continue to work unchanged.
    return _settings.value(kControlBehaviorKey, 0).toInt();
}

void DropWidgetSettings::setControlBehavior(int value)
{
    // 0 = Standard, 1 = Step & Hold, 2 = Synchronized Pair.
    // Invalid values are normalized to Standard instead of being persisted.
    if (value < 0 || value > 2) {
        value = 0;
    }

    if (controlBehavior() == value) {
        return;
    }

    _settings.setValue(kControlBehaviorKey, value);
    _settings.sync();
    emit controlBehaviorChanged();
}

QString DropWidgetSettings::servoOrder() const
{
    return _settings.value(kServoOrderKey, QString()).toString();
}

void DropWidgetSettings::setServoOrder(const QString& value)
{
    if (servoOrder() == value) {
        return;
    }

    _settings.setValue(kServoOrderKey, value);
    _settings.sync();
    emit servoOrderChanged();
}

QString DropWidgetSettings::servoPwmPositions() const
{
    return _settings.value(kServoPwmPositionsKey, QString()).toString();
}

void DropWidgetSettings::setServoPwmPositions(const QString& value)
{
    if (servoPwmPositions() == value) {
        return;
    }

    _settings.setValue(kServoPwmPositionsKey, value);
    _settings.sync();
    emit servoPwmPositionsChanged();
}

bool DropWidgetSettings::cameraControlsVisible() const
{
    return _settings.value(kCameraControlsVisibleKey, true).toBool();
}

void DropWidgetSettings::setCameraControlsVisible(bool value)
{
    if (cameraControlsVisible() == value) {
        return;
    }

    _settings.setValue(kCameraControlsVisibleKey, value);
    _settings.sync();
    emit cameraControlsVisibleChanged();
}

bool DropWidgetSettings::cameraControlsLocked() const
{
    return _settings.value(kCameraControlsLockedKey, true).toBool();
}

void DropWidgetSettings::setCameraControlsLocked(bool value)
{
    if (cameraControlsLocked() == value) {
        return;
    }

    _settings.setValue(kCameraControlsLockedKey, value);
    _settings.sync();
    emit cameraControlsLockedChanged();
}

double DropWidgetSettings::cameraControlsX() const
{
    return _settings.value(kCameraControlsXKey, -1.0).toDouble();
}

double DropWidgetSettings::cameraControlsY() const
{
    return _settings.value(kCameraControlsYKey, -1.0).toDouble();
}

void DropWidgetSettings::setCameraControlsPosition(double x, double y)
{
    const bool xChanged = cameraControlsX() != x;
    const bool yChanged = cameraControlsY() != y;

    if (!xChanged && !yChanged) {
        return;
    }

    if (xChanged) {
        _settings.setValue(kCameraControlsXKey, x);
    }

    if (yChanged) {
        _settings.setValue(kCameraControlsYKey, y);
    }

    _settings.sync();

    if (xChanged) {
        emit cameraControlsXChanged();
    }

    if (yChanged) {
        emit cameraControlsYChanged();
    }
}

bool DropWidgetSettings::photoVideoVisible() const
{
    return _settings.value(kPhotoVideoVisibleKey, true).toBool();
}

void DropWidgetSettings::setPhotoVideoVisible(bool value)
{
    if (photoVideoVisible() == value) {
        return;
    }

    _settings.setValue(kPhotoVideoVisibleKey, value);
    _settings.sync();
    emit photoVideoVisibleChanged();
}

bool DropWidgetSettings::photoVideoLocked() const
{
    return _settings.value(kPhotoVideoLockedKey, true).toBool();
}

void DropWidgetSettings::setPhotoVideoLocked(bool value)
{
    if (photoVideoLocked() == value) {
        return;
    }

    _settings.setValue(kPhotoVideoLockedKey, value);
    _settings.sync();
    emit photoVideoLockedChanged();
}

double DropWidgetSettings::photoVideoX() const
{
    return _settings.value(kPhotoVideoXKey, -1.0).toDouble();
}

double DropWidgetSettings::photoVideoY() const
{
    return _settings.value(kPhotoVideoYKey, -1.0).toDouble();
}

void DropWidgetSettings::setPhotoVideoPosition(double x, double y)
{
    const bool xChanged = photoVideoX() != x;
    const bool yChanged = photoVideoY() != y;

    if (!xChanged && !yChanged) {
        return;
    }

    if (xChanged) {
        _settings.setValue(kPhotoVideoXKey, x);
    }

    if (yChanged) {
        _settings.setValue(kPhotoVideoYKey, y);
    }

    _settings.sync();

    if (xChanged) {
        emit photoVideoXChanged();
    }

    if (yChanged) {
        emit photoVideoYChanged();
    }
}

bool DropWidgetSettings::dropWidgetVisible() const
{
    return _settings.value(kDropWidgetVisibleKey, true).toBool();
}

void DropWidgetSettings::setDropWidgetVisible(bool value)
{
    if (dropWidgetVisible() == value) {
        return;
    }

    _settings.setValue(kDropWidgetVisibleKey, value);
    _settings.sync();
    emit dropWidgetVisibleChanged();
}

bool DropWidgetSettings::controllerInputVisible() const
{
    return _settings.value(kControllerInputVisibleKey, true).toBool();
}

void DropWidgetSettings::setControllerInputVisible(bool value)
{
    if (controllerInputVisible() == value) {
        return;
    }

    _settings.setValue(kControllerInputVisibleKey, value);
    _settings.sync();
    emit controllerInputVisibleChanged();
}

bool DropWidgetSettings::cameraLogsVisible() const
{
    return _settings.value(kCameraLogsVisibleKey, true).toBool();
}

void DropWidgetSettings::setCameraLogsVisible(bool value)
{
    if (cameraLogsVisible() == value) {
        return;
    }

    _settings.setValue(kCameraLogsVisibleKey, value);
    _settings.sync();
    emit cameraLogsVisibleChanged();
}

bool DropWidgetSettings::linkOsdVisible() const
{
    return _settings.value(kLinkOsdVisibleKey, true).toBool();
}

void DropWidgetSettings::setLinkOsdVisible(bool value)
{
    if (linkOsdVisible() == value) {
        return;
    }

    _settings.setValue(kLinkOsdVisibleKey, value);
    _settings.sync();
    emit linkOsdVisibleChanged();
}

bool DropWidgetSettings::gpsOsdVisible() const
{
    return _settings.value(kGpsOsdVisibleKey, true).toBool();
}

void DropWidgetSettings::setGpsOsdVisible(bool value)
{
    if (gpsOsdVisible() == value) {
        return;
    }

    _settings.setValue(kGpsOsdVisibleKey, value);
    _settings.sync();
    emit gpsOsdVisibleChanged();
}

bool DropWidgetSettings::batteryOsdVisible() const
{
    return _settings.value(kBatteryOsdVisibleKey, true).toBool();
}

void DropWidgetSettings::setBatteryOsdVisible(bool value)
{
    if (batteryOsdVisible() == value) {
        return;
    }

    _settings.setValue(kBatteryOsdVisibleKey, value);
    _settings.sync();
    emit batteryOsdVisibleChanged();
}

bool DropWidgetSettings::altitudeOsdVisible() const
{
    return _settings.value(kAltitudeOsdVisibleKey, true).toBool();
}

void DropWidgetSettings::setAltitudeOsdVisible(bool value)
{
    if (altitudeOsdVisible() == value) {
        return;
    }

    _settings.setValue(kAltitudeOsdVisibleKey, value);
    _settings.sync();
    emit altitudeOsdVisibleChanged();
}

bool DropWidgetSettings::horizonOsdVisible() const
{
    return _settings.value(kHorizonOsdVisibleKey, true).toBool();
}

void DropWidgetSettings::setHorizonOsdVisible(bool value)
{
    if (horizonOsdVisible() == value) {
        return;
    }

    _settings.setValue(kHorizonOsdVisibleKey, value);
    _settings.sync();
    emit horizonOsdVisibleChanged();
}

bool DropWidgetSettings::compassOsdVisible() const
{
    return _settings.value(kCompassOsdVisibleKey, true).toBool();
}

void DropWidgetSettings::setCompassOsdVisible(bool value)
{
    if (compassOsdVisible() == value) {
        return;
    }

    _settings.setValue(kCompassOsdVisibleKey, value);
    _settings.sync();
    emit compassOsdVisibleChanged();
}

bool DropWidgetSettings::homeOsdVisible() const
{
    return _settings.value(kHomeOsdVisibleKey, true).toBool();
}

void DropWidgetSettings::setHomeOsdVisible(bool value)
{
    if (homeOsdVisible() == value) {
        return;
    }

    _settings.setValue(kHomeOsdVisibleKey, value);
    _settings.sync();
    emit homeOsdVisibleChanged();
}

bool DropWidgetSettings::hudTransparentBackground() const
{
    return _settings.value(kHudTransparentBackgroundKey, false).toBool();
}

void DropWidgetSettings::setHudTransparentBackground(bool value)
{
    if (hudTransparentBackground() == value) {
        return;
    }

    _settings.setValue(kHudTransparentBackgroundKey, value);
    _settings.sync();
    emit hudTransparentBackgroundChanged();
}

QVariantMap DropWidgetSettings::servoFunctionAvailability(QObject* parameterManagerObject, int servoNumber) const
{
    const QString paramName = servoFunctionParamName(servoNumber);

    if (!parameterManagerObject) {
        return makeAvailabilityResult(
            servoNumber,
            paramName,
            -1,
            false,
            QStringLiteral("No active vehicle"));
    }

    auto* parameterManager = qobject_cast<ParameterManager*>(parameterManagerObject);
    if (!parameterManager) {
        return makeAvailabilityResult(
            servoNumber,
            paramName,
            -1,
            false,
            QStringLiteral("Parameter manager unavailable"));
    }

    if (!parameterManager->parametersReady()) {
        return makeAvailabilityResult(
            servoNumber,
            paramName,
            -1,
            false,
            QStringLiteral("Waiting for parameters"));
    }

    if (!parameterManager->parameterExists(-1, paramName)) {
        return makeAvailabilityResult(
            servoNumber,
            paramName,
            -1,
            false,
            QStringLiteral("%1 unavailable").arg(paramName));
    }

    Fact* fact = parameterManager->getParameter(-1, paramName);

    if (!fact) {
        return makeAvailabilityResult(
            servoNumber,
            paramName,
            -1,
            false,
            QStringLiteral("%1 unavailable").arg(paramName));
    }

    bool ok = false;
    const int functionValue = fact->rawValue().toInt(&ok);

    if (!ok) {
        return makeAvailabilityResult(
            servoNumber,
            paramName,
            -1,
            false,
            QStringLiteral("%1 has invalid value").arg(paramName));
    }

    const bool available = isServoFunctionAllowed(functionValue);
    const QString label = servoFunctionLabel(functionValue);

    const QString text = available
                             ? QStringLiteral("Available: %1=%2 (%3)").arg(paramName).arg(functionValue).arg(label)
                             : QStringLiteral("Blocked: %1=%2 (%3)").arg(paramName).arg(functionValue).arg(label);

    return makeAvailabilityResult(
        servoNumber,
        paramName,
        functionValue,
        available,
        text);
}
