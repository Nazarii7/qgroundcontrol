#include "DropWidgetJoystickBridge.h"

#include <QCoreApplication>
#include <QMetaObject>
#include <QtQml/qqml.h>

DropWidgetJoystickBridge::DropWidgetJoystickBridge(QObject* parent)
    : QObject(parent)
{
}

DropWidgetJoystickBridge* DropWidgetJoystickBridge::instance()
{
    static DropWidgetJoystickBridge* s_instance =
        new DropWidgetJoystickBridge(QCoreApplication::instance());

    return s_instance;
}

void DropWidgetJoystickBridge::registerQmlSingleton()
{
    qmlRegisterSingletonInstance(
        "QGroundControl.FlightDisplay",
        1,
        0,
        "DropWidgetJoystickBridge",
        DropWidgetJoystickBridge::instance());
}

void DropWidgetJoystickBridge::triggerDropHoldPressed()
{
    QMetaObject::invokeMethod(
        this,
        [this]() {
            emit dropHoldPressed();
        },
        Qt::QueuedConnection);
}

void DropWidgetJoystickBridge::triggerDropHoldReleased()
{
    QMetaObject::invokeMethod(
        this,
        [this]() {
            emit dropHoldReleased();
        },
        Qt::QueuedConnection);
}