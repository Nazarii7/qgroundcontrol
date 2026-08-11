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
    Q_PROPERTY(bool dropWidgetVisible READ dropWidgetVisible WRITE setDropWidgetVisible NOTIFY dropWidgetVisibleChanged FINAL)
    Q_PROPERTY(bool cameraLogsVisible READ cameraLogsVisible WRITE setCameraLogsVisible NOTIFY cameraLogsVisibleChanged FINAL)

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

    bool dropWidgetVisible() const;
    void setDropWidgetVisible(bool value);

    bool cameraLogsVisible() const;
    void setCameraLogsVisible(bool value);

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
    void dropWidgetVisibleChanged();
    void cameraLogsVisibleChanged();

   private:
    QSettings _settings;
};