#pragma once

#include <QObject>

class DropWidgetJoystickBridge : public QObject
{
    Q_OBJECT

   public:
    explicit DropWidgetJoystickBridge(QObject* parent = nullptr);

    static DropWidgetJoystickBridge* instance();
    static void registerQmlSingleton();

    void triggerDropHoldPressed();
    void triggerDropHoldReleased();

   signals:
    void dropHoldPressed();
    void dropHoldReleased();
};