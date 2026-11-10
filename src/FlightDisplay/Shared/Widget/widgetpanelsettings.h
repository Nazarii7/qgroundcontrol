#pragma once

#include <QObject>
#include <QSettings>

// Persistent settings for non-Drop Fly View widgets. The legacy
// DropWidgetSettings singleton inherits this API during the QML migration.
class WidgetPanelSettings : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool cameraControlsVisible READ cameraControlsVisible WRITE setCameraControlsVisible NOTIFY cameraControlsVisibleChanged FINAL)
    Q_PROPERTY(bool cameraControlsLocked READ cameraControlsLocked WRITE setCameraControlsLocked NOTIFY cameraControlsLockedChanged FINAL)
    Q_PROPERTY(double cameraControlsX READ cameraControlsX NOTIFY cameraControlsXChanged FINAL)
    Q_PROPERTY(double cameraControlsY READ cameraControlsY NOTIFY cameraControlsYChanged FINAL)
    Q_PROPERTY(bool photoVideoVisible READ photoVideoVisible WRITE setPhotoVideoVisible NOTIFY photoVideoVisibleChanged FINAL)
    Q_PROPERTY(bool photoVideoLocked READ photoVideoLocked WRITE setPhotoVideoLocked NOTIFY photoVideoLockedChanged FINAL)
    Q_PROPERTY(double photoVideoX READ photoVideoX NOTIFY photoVideoXChanged FINAL)
    Q_PROPERTY(double photoVideoY READ photoVideoY NOTIFY photoVideoYChanged FINAL)
    Q_PROPERTY(bool controllerInputVisible READ controllerInputVisible WRITE setControllerInputVisible NOTIFY controllerInputVisibleChanged FINAL)
    Q_PROPERTY(bool cameraLogsVisible READ cameraLogsVisible WRITE setCameraLogsVisible NOTIFY cameraLogsVisibleChanged FINAL)
    Q_PROPERTY(bool linkOsdVisible READ linkOsdVisible WRITE setLinkOsdVisible NOTIFY linkOsdVisibleChanged FINAL)
    Q_PROPERTY(bool gpsOsdVisible READ gpsOsdVisible WRITE setGpsOsdVisible NOTIFY gpsOsdVisibleChanged FINAL)
    Q_PROPERTY(bool batteryOsdVisible READ batteryOsdVisible WRITE setBatteryOsdVisible NOTIFY batteryOsdVisibleChanged FINAL)
    Q_PROPERTY(bool altitudeOsdVisible READ altitudeOsdVisible WRITE setAltitudeOsdVisible NOTIFY altitudeOsdVisibleChanged FINAL)
    Q_PROPERTY(bool horizonOsdVisible READ horizonOsdVisible WRITE setHorizonOsdVisible NOTIFY horizonOsdVisibleChanged FINAL)
    Q_PROPERTY(bool compassOsdVisible READ compassOsdVisible WRITE setCompassOsdVisible NOTIFY compassOsdVisibleChanged FINAL)
    Q_PROPERTY(bool homeOsdVisible READ homeOsdVisible WRITE setHomeOsdVisible NOTIFY homeOsdVisibleChanged FINAL)
    Q_PROPERTY(bool hudTransparentBackground READ hudTransparentBackground WRITE setHudTransparentBackground NOTIFY hudTransparentBackgroundChanged FINAL)

   public:
    explicit WidgetPanelSettings(QObject* parent = nullptr);

    bool cameraControlsVisible() const;
    void setCameraControlsVisible(bool value);
    bool cameraControlsLocked() const;
    void setCameraControlsLocked(bool value);
    double cameraControlsX() const;
    double cameraControlsY() const;
    Q_INVOKABLE void setCameraControlsPosition(double x, double y);
    bool photoVideoVisible() const;
    void setPhotoVideoVisible(bool value);
    bool photoVideoLocked() const;
    void setPhotoVideoLocked(bool value);
    double photoVideoX() const;
    double photoVideoY() const;
    Q_INVOKABLE void setPhotoVideoPosition(double x, double y);
    bool controllerInputVisible() const;
    void setControllerInputVisible(bool value);
    bool cameraLogsVisible() const;
    void setCameraLogsVisible(bool value);
    bool linkOsdVisible() const;
    void setLinkOsdVisible(bool value);
    bool gpsOsdVisible() const;
    void setGpsOsdVisible(bool value);
    bool batteryOsdVisible() const;
    void setBatteryOsdVisible(bool value);
    bool altitudeOsdVisible() const;
    void setAltitudeOsdVisible(bool value);
    bool horizonOsdVisible() const;
    void setHorizonOsdVisible(bool value);
    bool compassOsdVisible() const;
    void setCompassOsdVisible(bool value);
    bool homeOsdVisible() const;
    void setHomeOsdVisible(bool value);
    bool hudTransparentBackground() const;
    void setHudTransparentBackground(bool value);

   signals:
    void cameraControlsVisibleChanged();
    void cameraControlsLockedChanged();
    void cameraControlsXChanged();
    void cameraControlsYChanged();
    void photoVideoVisibleChanged();
    void photoVideoLockedChanged();
    void photoVideoXChanged();
    void photoVideoYChanged();
    void controllerInputVisibleChanged();
    void cameraLogsVisibleChanged();
    void linkOsdVisibleChanged();
    void gpsOsdVisibleChanged();
    void batteryOsdVisibleChanged();
    void altitudeOsdVisibleChanged();
    void horizonOsdVisibleChanged();
    void compassOsdVisibleChanged();
    void homeOsdVisibleChanged();
    void hudTransparentBackgroundChanged();

   protected:
    // One QSettings instance is shared with the Drop-specific derived class.
    QSettings _settings;
};
