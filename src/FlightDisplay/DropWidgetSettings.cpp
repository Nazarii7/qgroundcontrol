#include "DropWidgetSettings.h"

#include <QCoreApplication>
#include <QtQml/qqml.h>

namespace {
static constexpr const char* kActiveServosKey  = "DropWidget/ActiveServos";
static constexpr const char* kPanelXKey        = "DropWidget/PanelX";
static constexpr const char* kPanelYKey        = "DropWidget/PanelY";
static constexpr const char* kPanelExpandedKey = "DropWidget/PanelExpanded";
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
    return _settings.value(kActiveServosKey, QStringLiteral("5,6")).toString();
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