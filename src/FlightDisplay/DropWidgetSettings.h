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

    bool panelExpanded() const;
    void setPanelExpanded(bool value);

    Q_INVOKABLE QVariantMap servoFunctionAvailability(QObject* parameterManagerObject, int servoNumber) const;

   signals:
    void activeServosChanged();
    void panelXChanged();
    void panelYChanged();
    void panelExpandedChanged();

   private:
    QSettings _settings;
};