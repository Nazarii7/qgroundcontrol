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
static constexpr const char* kServoOrderKey    = "DropWidget/ServoOrder";
static constexpr const char* kServoPwmPositionsKey = "DropWidget/ServoPwmPositions";

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