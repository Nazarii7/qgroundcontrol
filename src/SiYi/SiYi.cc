#include <QCoreApplication>
#include <QQmlEngine>
#include <QJSEngine>

#include "SiYi.h"
#include "SiYiTcpClient.h"
#include "ControllerInputManager.h"

SiYi *SiYi::instance_ = Q_NULLPTR;

SiYi::SiYi(QObject *parent)
    : QObject{parent}
{
    camera_ = new SiYiCamera(this);
    transmitter_ = new SiYiTransmitter(this);

    connect(transmitter_, &SiYiTcpClient::connected, this, [this]() {
        isTransmitterConnected_ = true;

        if (!camera_->isRunning()) {
            camera_->start();
        }
    });

    connect(transmitter_, &SiYiTcpClient::disconnected, this, [this]() {
        isTransmitterConnected_ = false;
    });

            // Keep USB-controller mapping isolated from Joystick and from the camera
            // protocol implementation:
            //
            // GX12 S1 -> Axis 4 -> camera tilt input (-100..+100)
            // GX12 S2 -> Axis 5 -> camera zoom input (-100..+100)
            //
            // ControllerInputManager emits on the application thread, which is also
            // where the existing QML camera calls originate.
    ControllerInputManager *const controllerInput =
        ControllerInputManager::instance();

    connect(
        controllerInput,
        &ControllerInputManager::cameraTiltInputChanged,
        this,
        &SiYi::handleControllerTiltInput);

    connect(
        controllerInput,
        &ControllerInputManager::cameraZoomInputChanged,
        this,
        &SiYi::handleControllerZoomInput);

            // A disconnected camera must never retain a logical "moving/zooming" state.
            // We intentionally do not auto-resume on reconnect; the operator must move
            // S1/S2 again, which is the safer behavior.
    connect(camera_, &SiYiTcpClient::disconnected, this, [this]() {
        resetControllerCameraState();
    });

#if 0
    connect(transmitter_, &SiYiCamera::ipChanged, this, [=](){
        if (transmitter_->isRunning()) {
            transmitter_->exit();
            transmitter_->wait();
        }

        transmitter_->start();
    });
#endif

#ifdef Q_OS_ANDROID
    isAndroid_ = true;
#else
    isAndroid_ = false;
#endif

    transmitter_->start();

#if 1   // ä¸º1æ—¶ï¼Œäº‘å°æŽ§åˆ¶æ— éœ€å…ˆè¿žæŽ¥
    camera_->start();
#endif
}

void SiYi::handleControllerTiltInput(int percent)
{
    // Do not enqueue camera-control packets unless the TCP camera connection
    // is actually up and the detected model reports gimbal control support.
    if (!camera_->property("isConnected").toBool()
        || !camera_->property("enableControl").toBool()) {
        controllerTiltPitch_ = 0;
        return;
    }

    percent = qBound(-100, percent, 100);

            // S1 is analog. A small center deadzone prevents camera creep caused by
            // tiny HID noise around zero.
    const int pitch =
        (percent >= -kControllerTiltDeadzonePercent
         && percent <= kControllerTiltDeadzonePercent)
            ? 0
            : percent;

    if (pitch == controllerTiltPitch_) {
        return;
    }

    controllerTiltPitch_ = pitch;

            // Positive S1 (clockwise/right) maps to positive SIYI pitch.
            // If the desired physical direction is reversed later, only this sign
            // needs to change: camera_->turn(0, -controllerTiltPitch_).
    camera_->turn(0, controllerTiltPitch_);
}

void SiYi::handleControllerZoomInput(int percent)
{
    // Zoom is capability-gated per detected camera model (ZT6/ZR10/A8, etc.).
    if (!camera_->property("isConnected").toBool()
        || !camera_->property("enableZoom").toBool()) {
        controllerZoomDirection_ = 0;
        return;
    }

    percent = qBound(-100, percent, 100);

    int nextDirection = controllerZoomDirection_;

            // Hysteresis:
            //   neutral -> start at +/-20%
            //   active  -> stop again inside +/-10%
            //
            // This prevents repeated zoom/stop chatter around the center.
    if (controllerZoomDirection_ == 0) {
        if (percent >= kControllerZoomStartPercent) {
            nextDirection = 1;
        } else if (percent <= -kControllerZoomStartPercent) {
            nextDirection = -1;
        }
    } else if (controllerZoomDirection_ > 0) {
        if (percent <= -kControllerZoomStartPercent) {
            nextDirection = -1;
        } else if (percent <= kControllerZoomStopPercent) {
            nextDirection = 0;
        }
    } else {
        if (percent >= kControllerZoomStartPercent) {
            nextDirection = 1;
        } else if (percent >= -kControllerZoomStopPercent) {
            nextDirection = 0;
        }
    }

    if (nextDirection == controllerZoomDirection_) {
        return;
    }

    controllerZoomDirection_ = nextDirection;

            // Existing SIYI API semantics:
            //   +1 = zoom in
            //    0 = stop
            //   -1 = zoom out
    camera_->zoom(controllerZoomDirection_);
}

void SiYi::resetControllerCameraState()
{
    // The TCP disconnect itself stops command delivery. Reset only local state
    // so reconnect never resumes motion automatically.
    controllerTiltPitch_ = 0;
    controllerZoomDirection_ = 0;
}

SiYi *SiYi::instance()
{
    if (!instance_) {
        instance_ = new SiYi(qApp);
    }

    Q_ASSERT_X(instance_, __FUNCTION__,
               "Can not allocate memory for SiYi instance!");
    return instance_;
}

SiYiCamera *SiYi::cameraInstance()
{
    return camera_;
}

SiYiTransmitter *SiYi::transmitterInstance()
{
    return transmitter_;
}

void SiYi::registerQmlSingleton()
{
    qmlRegisterSingletonType<SiYi>("SiYi.Object", 1, 0, "SiYi",
                                   [](QQmlEngine *engine, QJSEngine *) -> QObject * {
                                       SiYi *singleton = SiYi::instance();
                                       QQmlEngine::setObjectOwnership(singleton, QQmlEngine::CppOwnership);
                                       Q_UNUSED(engine)
                                       return singleton;
                                   });

    qmlRegisterUncreatableType<SiYiCamera>(
        "SiYi.Object", 1, 0, "SiYiCamera",
        "SiYiCamera is available through SiYi.camera");

    qmlRegisterUncreatableType<SiYiTransmitter>(
        "SiYi.Object", 1, 0, "SiYiTransmitter",
        "SiYiTransmitter is available through SiYi.transmitter");
}