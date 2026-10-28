#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariantMap>

class DropWidgetSettings : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString activeServos READ activeServos WRITE setActiveServos NOTIFY activeServosChanged FINAL)
    Q_PROPERTY(double panelX READ panelX WRITE setPanelX NOTIFY panelXChanged FINAL)
    Q_PROPERTY(double panelY READ panelY WRITE setPanelY NOTIFY panelYChanged FINAL)
    Q_PROPERTY(bool panelExpanded READ panelExpanded WRITE setPanelExpanded NOTIFY panelExpandedChanged FINAL)
    Q_PROPERTY(int dropMode READ dropMode WRITE setDropMode NOTIFY dropModeChanged FINAL)
    Q_PROPERTY(int controlBehavior READ controlBehavior WRITE setControlBehavior NOTIFY controlBehaviorChanged FINAL)
    Q_PROPERTY(QString servoOrder READ servoOrder WRITE setServoOrder NOTIFY servoOrderChanged FINAL)
    Q_PROPERTY(QString servoPwmPositions READ servoPwmPositions WRITE setServoPwmPositions NOTIFY servoPwmPositionsChanged FINAL)
    Q_PROPERTY(bool cameraControlsVisible READ cameraControlsVisible WRITE setCameraControlsVisible NOTIFY cameraControlsVisibleChanged FINAL)
    Q_PROPERTY(bool cameraControlsLocked READ cameraControlsLocked WRITE setCameraControlsLocked NOTIFY cameraControlsLockedChanged FINAL)
    Q_PROPERTY(double cameraControlsX READ cameraControlsX NOTIFY cameraControlsXChanged FINAL)
    Q_PROPERTY(double cameraControlsY READ cameraControlsY NOTIFY cameraControlsYChanged FINAL)
    Q_PROPERTY(bool photoVideoVisible READ photoVideoVisible WRITE setPhotoVideoVisible NOTIFY photoVideoVisibleChanged FINAL)
    Q_PROPERTY(bool photoVideoLocked READ photoVideoLocked WRITE setPhotoVideoLocked NOTIFY photoVideoLockedChanged FINAL)
    Q_PROPERTY(double photoVideoX READ photoVideoX NOTIFY photoVideoXChanged FINAL)
    Q_PROPERTY(double photoVideoY READ photoVideoY NOTIFY photoVideoYChanged FINAL)
    Q_PROPERTY(bool dropWidgetVisible READ dropWidgetVisible WRITE setDropWidgetVisible NOTIFY dropWidgetVisibleChanged FINAL)
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
    explicit DropWidgetSettings(QObject* parent = nullptr);

    static DropWidgetSettings* instance();
    static void registerQmlSingleton();

    QString activeServos() const;
    void setActiveServos(const QString& value);

    double panelX() const;
    void setPanelX(double value);

    double panelY() const;
    void setPanelY(double value);

    Q_INVOKABLE void setPanelPosition(double x, double y);

    bool panelExpanded() const;
    void setPanelExpanded(bool value);

    int dropMode() const;
    void setDropMode(int value);

    int controlBehavior() const;
    void setControlBehavior(int value);

    QString servoOrder() const;
    void setServoOrder(const QString& value);

    QString servoPwmPositions() const;
    void setServoPwmPositions(const QString& value);

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

    bool dropWidgetVisible() const;
    void setDropWidgetVisible(bool value);

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

    Q_INVOKABLE QVariantMap servoFunctionAvailability(QObject* parameterManagerObject, int servoNumber) const;

   signals:
    void activeServosChanged();
    void panelXChanged();
    void panelYChanged();
    void panelExpandedChanged();

    void dropModeChanged();
    void controlBehaviorChanged();
    void servoOrderChanged();
    void servoPwmPositionsChanged();
    void cameraControlsVisibleChanged();
    void cameraControlsLockedChanged();
    void cameraControlsXChanged();
    void cameraControlsYChanged();
    void photoVideoVisibleChanged();
    void photoVideoLockedChanged();
    void photoVideoXChanged();
    void photoVideoYChanged();
    void dropWidgetVisibleChanged();
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

   private:
    QSettings _settings;
};
