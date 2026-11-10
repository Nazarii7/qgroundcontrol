#include "widgetpanelsettings.h"

namespace {
static constexpr const char* kCameraControlsVisibleKey = "FlyViewWidgets/CameraControlsVisible";
static constexpr const char* kCameraControlsLockedKey = "FlyViewWidgets/CameraControlsLocked";
static constexpr const char* kCameraControlsXKey = "FlyViewWidgets/CameraControlsX";
static constexpr const char* kCameraControlsYKey = "FlyViewWidgets/CameraControlsY";
static constexpr const char* kPhotoVideoVisibleKey = "FlyViewWidgets/PhotoVideoVisible";
static constexpr const char* kPhotoVideoLockedKey = "FlyViewWidgets/PhotoVideoLocked";
static constexpr const char* kPhotoVideoXKey = "FlyViewWidgets/PhotoVideoX";
static constexpr const char* kPhotoVideoYKey = "FlyViewWidgets/PhotoVideoY";
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
}

WidgetPanelSettings::WidgetPanelSettings(QObject* parent)
    : QObject(parent)
{
}

bool WidgetPanelSettings::cameraControlsVisible() const
{
    return _settings.value(kCameraControlsVisibleKey, true).toBool();
}

void WidgetPanelSettings::setCameraControlsVisible(bool value)
{
    if (cameraControlsVisible() == value) {
        return;
    }

    _settings.setValue(kCameraControlsVisibleKey, value);
    _settings.sync();
    emit cameraControlsVisibleChanged();
}

bool WidgetPanelSettings::cameraControlsLocked() const
{
    return _settings.value(kCameraControlsLockedKey, true).toBool();
}

void WidgetPanelSettings::setCameraControlsLocked(bool value)
{
    if (cameraControlsLocked() == value) {
        return;
    }

    _settings.setValue(kCameraControlsLockedKey, value);
    _settings.sync();
    emit cameraControlsLockedChanged();
}

double WidgetPanelSettings::cameraControlsX() const
{
    return _settings.value(kCameraControlsXKey, -1.0).toDouble();
}

double WidgetPanelSettings::cameraControlsY() const
{
    return _settings.value(kCameraControlsYKey, -1.0).toDouble();
}

void WidgetPanelSettings::setCameraControlsPosition(double x, double y)
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

bool WidgetPanelSettings::photoVideoVisible() const
{
    return _settings.value(kPhotoVideoVisibleKey, true).toBool();
}

void WidgetPanelSettings::setPhotoVideoVisible(bool value)
{
    if (photoVideoVisible() == value) {
        return;
    }

    _settings.setValue(kPhotoVideoVisibleKey, value);
    _settings.sync();
    emit photoVideoVisibleChanged();
}

bool WidgetPanelSettings::photoVideoLocked() const
{
    return _settings.value(kPhotoVideoLockedKey, true).toBool();
}

void WidgetPanelSettings::setPhotoVideoLocked(bool value)
{
    if (photoVideoLocked() == value) {
        return;
    }

    _settings.setValue(kPhotoVideoLockedKey, value);
    _settings.sync();
    emit photoVideoLockedChanged();
}

double WidgetPanelSettings::photoVideoX() const
{
    return _settings.value(kPhotoVideoXKey, -1.0).toDouble();
}

double WidgetPanelSettings::photoVideoY() const
{
    return _settings.value(kPhotoVideoYKey, -1.0).toDouble();
}

void WidgetPanelSettings::setPhotoVideoPosition(double x, double y)
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

bool WidgetPanelSettings::controllerInputVisible() const
{
    return _settings.value(kControllerInputVisibleKey, true).toBool();
}

void WidgetPanelSettings::setControllerInputVisible(bool value)
{
    if (controllerInputVisible() == value) {
        return;
    }

    _settings.setValue(kControllerInputVisibleKey, value);
    _settings.sync();
    emit controllerInputVisibleChanged();
}

bool WidgetPanelSettings::cameraLogsVisible() const
{
    return _settings.value(kCameraLogsVisibleKey, true).toBool();
}

void WidgetPanelSettings::setCameraLogsVisible(bool value)
{
    if (cameraLogsVisible() == value) {
        return;
    }

    _settings.setValue(kCameraLogsVisibleKey, value);
    _settings.sync();
    emit cameraLogsVisibleChanged();
}

bool WidgetPanelSettings::linkOsdVisible() const
{
    return _settings.value(kLinkOsdVisibleKey, true).toBool();
}

void WidgetPanelSettings::setLinkOsdVisible(bool value)
{
    if (linkOsdVisible() == value) {
        return;
    }

    _settings.setValue(kLinkOsdVisibleKey, value);
    _settings.sync();
    emit linkOsdVisibleChanged();
}

bool WidgetPanelSettings::gpsOsdVisible() const
{
    return _settings.value(kGpsOsdVisibleKey, true).toBool();
}

void WidgetPanelSettings::setGpsOsdVisible(bool value)
{
    if (gpsOsdVisible() == value) {
        return;
    }

    _settings.setValue(kGpsOsdVisibleKey, value);
    _settings.sync();
    emit gpsOsdVisibleChanged();
}

bool WidgetPanelSettings::batteryOsdVisible() const
{
    return _settings.value(kBatteryOsdVisibleKey, true).toBool();
}

void WidgetPanelSettings::setBatteryOsdVisible(bool value)
{
    if (batteryOsdVisible() == value) {
        return;
    }

    _settings.setValue(kBatteryOsdVisibleKey, value);
    _settings.sync();
    emit batteryOsdVisibleChanged();
}

bool WidgetPanelSettings::altitudeOsdVisible() const
{
    return _settings.value(kAltitudeOsdVisibleKey, true).toBool();
}

void WidgetPanelSettings::setAltitudeOsdVisible(bool value)
{
    if (altitudeOsdVisible() == value) {
        return;
    }

    _settings.setValue(kAltitudeOsdVisibleKey, value);
    _settings.sync();
    emit altitudeOsdVisibleChanged();
}

bool WidgetPanelSettings::horizonOsdVisible() const
{
    return _settings.value(kHorizonOsdVisibleKey, true).toBool();
}

void WidgetPanelSettings::setHorizonOsdVisible(bool value)
{
    if (horizonOsdVisible() == value) {
        return;
    }

    _settings.setValue(kHorizonOsdVisibleKey, value);
    _settings.sync();
    emit horizonOsdVisibleChanged();
}

bool WidgetPanelSettings::compassOsdVisible() const
{
    return _settings.value(kCompassOsdVisibleKey, true).toBool();
}

void WidgetPanelSettings::setCompassOsdVisible(bool value)
{
    if (compassOsdVisible() == value) {
        return;
    }

    _settings.setValue(kCompassOsdVisibleKey, value);
    _settings.sync();
    emit compassOsdVisibleChanged();
}

bool WidgetPanelSettings::homeOsdVisible() const
{
    return _settings.value(kHomeOsdVisibleKey, true).toBool();
}

void WidgetPanelSettings::setHomeOsdVisible(bool value)
{
    if (homeOsdVisible() == value) {
        return;
    }

    _settings.setValue(kHomeOsdVisibleKey, value);
    _settings.sync();
    emit homeOsdVisibleChanged();
}

bool WidgetPanelSettings::hudTransparentBackground() const
{
    return _settings.value(kHudTransparentBackgroundKey, false).toBool();
}

void WidgetPanelSettings::setHudTransparentBackground(bool value)
{
    if (hudTransparentBackground() == value) {
        return;
    }

    _settings.setValue(kHudTransparentBackgroundKey, value);
    _settings.sync();
    emit hudTransparentBackgroundChanged();
}
