#include "ControllerInputManager.h"

#include "JoystickManager.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QSettings>
#include <QtCore/QtGlobal>
#include <QtQml/qqml.h>

ControllerInputManager::ControllerInputManager(QObject *parent)
    : QObject(parent)
{
}

ControllerInputManager *ControllerInputManager::instance()
{
    static ControllerInputManager *s_instance =
        new ControllerInputManager(QCoreApplication::instance());

    return s_instance;
}

void ControllerInputManager::registerQmlSingleton()
{
    qmlRegisterSingletonInstance(
        "QGroundControl.JoystickManager",
        1,
        0,
        "ControllerInputManager",
        ControllerInputManager::instance());
}

void ControllerInputManager::init()
{
    if (_initialized) {
        return;
    }

    _initialized = true;

    JoystickManager *const joystickManager = JoystickManager::instance();

    (void) connect(
        joystickManager,
        &JoystickManager::activeJoystickChanged,
        this,
        [this](Joystick *joystick) {
            _setActiveJoystick(joystick);
        });

    _setActiveJoystick(joystickManager->activeJoystick());
}

QString ControllerInputManager::activeControllerName() const
{
    return _activeJoystick ? _activeJoystick->name() : QString();
}

QStringList ControllerInputManager::availableButtonActions() const
{
    return _activeJoystick ? _activeJoystick->assignableActionTitles() : QStringList();
}

int ControllerInputManager::axisValue(int index) const
{
    if (index < 0 || index >= _axisValues.size()) {
        return 0;
    }

    return _axisValues.at(index);
}

bool ControllerInputManager::buttonPressed(int index) const
{
    if (index < 0 || index >= _buttonStates.size()) {
        return false;
    }

    return _buttonStates.at(index);
}

void ControllerInputManager::setCameraTiltAxis(int index)
{
    if (!_validAxisIndex(index)) {
        return;
    }

    cancelAxisAssignment();
    _applyCameraAxisMapping(QStringLiteral("tilt"), index);
}

void ControllerInputManager::setCameraZoomAxis(int index)
{
    if (!_validAxisIndex(index)) {
        return;
    }

    cancelAxisAssignment();
    _applyCameraAxisMapping(QStringLiteral("zoom"), index);
}

void ControllerInputManager::beginAxisAssignment(const QString &target)
{
    if (!_activeJoystick || axisCount() <= 0) {
        return;
    }

    const QString normalizedTarget = target.trimmed().toLower();
    if (normalizedTarget != QStringLiteral("tilt")
        && normalizedTarget != QStringLiteral("zoom")) {
        return;
    }

            // Entering assignment mode must never leave an old camera motion command active.
    _stopMappedCameraInputs();

    _axisAssignmentActive = true;
    _axisAssignmentTarget = normalizedTarget;
    _axisAssignmentBaseline = _axisValues;
    _axisAssignmentBaselineValid = _axisSeen;

    emit axisAssignmentChanged();
}

void ControllerInputManager::cancelAxisAssignment()
{
    if (!_axisAssignmentActive) {
        return;
    }

    _finishAxisAssignment();
}

void ControllerInputManager::resetCameraAxisMappings()
{
    if (!_activeJoystick) {
        return;
    }

    cancelAxisAssignment();
    _stopMappedCameraInputs();

    const int defaultTilt = _validAxisIndex(kDefaultCameraTiltAxis)
                                ? kDefaultCameraTiltAxis
                                : -1;
    int defaultZoom = _validAxisIndex(kDefaultCameraZoomAxis)
                          ? kDefaultCameraZoomAxis
                          : -1;

    if (defaultZoom == defaultTilt) {
        defaultZoom = -1;
    }

    if (_cameraTiltAxis == defaultTilt && _cameraZoomAxis == defaultZoom) {
        return;
    }

    _cameraTiltAxis = defaultTilt;
    _cameraZoomAxis = defaultZoom;
    _saveCameraAxisMappings();

    _lastCameraTiltPercent = 0;
    _lastCameraZoomPercent = 0;

    emit cameraAxisMappingsChanged();
}

QString ControllerInputManager::buttonAction(int index) const
{
    if (!_activeJoystick || index < 0 || index >= buttonCount()) {
        return QString();
    }

    return _activeJoystick->getButtonAction(index);
}

void ControllerInputManager::setButtonAction(int index, const QString &action)
{
    if (!_activeJoystick || index < 0 || index >= buttonCount()) {
        return;
    }

    const QStringList actions = availableButtonActions();
    if (!action.isEmpty() && !actions.contains(action)) {
        return;
    }

    _activeJoystick->setButtonAction(index, action);
}

void ControllerInputManager::clearButtonAction(int index)
{
    if (!_activeJoystick || index < 0 || index >= buttonCount()) {
        return;
    }

    _activeJoystick->setButtonAction(index, QString());
}

void ControllerInputManager::_setActiveJoystick(Joystick *joystick)
{
    if (_activeJoystick == joystick) {
        return;
    }

    cancelAxisAssignment();

            // If the current controller was driving camera motion, explicitly return
            // both semantic camera inputs to neutral before detaching it.
    _stopMappedCameraInputs();

    if (_activeJoystick) {
        // Disconnect only signals from the old joystick to this observer.
        // Existing QGC/Vehicle/Drop Widget connections are not affected.
        (void) disconnect(_activeJoystick.data(), nullptr, this, nullptr);
    }

    _activeJoystick = joystick;
    _resetState();

    if (_activeJoystick) {
        _axisValues.fill(0, _activeJoystick->axisCount());
        _axisSeen.fill(false, _activeJoystick->axisCount());
        _buttonStates.fill(false, _activeJoystick->totalButtonCount());

        _loadCameraAxisMappings();

                // Joystick emits these signals from its polling thread. Force queued
                // delivery so all ControllerInputManager state stays on the app thread.
        const QPointer<Joystick> sourceJoystick = _activeJoystick;

        (void) connect(
            _activeJoystick.data(),
            &Joystick::axisInputChanged,
            this,
            [this, sourceJoystick](int index, int value) {
                if (!sourceJoystick || sourceJoystick != _activeJoystick) {
                    return;
                }

                if (index < 0 || index >= _axisValues.size()) {
                    return;
                }

                const bool axisWasSeen = _axisSeen[index];
                const bool valueChanged = _axisValues[index] != value;

                _axisValues[index] = value;
                _axisSeen[index] = true;

                if (!valueChanged) {
                    return;
                }

                const bool assignmentCaptured =
                    _processAxisAssignment(index, value, axisWasSeen);

                        // While an axis assignment is active, camera semantic commands are
                        // intentionally suppressed. This prevents the control being moved for
                        // detection from simultaneously driving the camera.
                if (!_axisAssignmentActive && !assignmentCaptured) {
                    _processMappedCameraAxis(index, value);
                }

                emit axisValueChanged(index, value);
            },
            Qt::QueuedConnection);

        (void) connect(
            _activeJoystick.data(),
            &Joystick::buttonInputChanged,
            this,
            [this, sourceJoystick](int index, bool pressed) {
                if (!sourceJoystick || sourceJoystick != _activeJoystick) {
                    return;
                }

                if (index < 0 || index >= _buttonStates.size()) {
                    return;
                }

                if (_buttonStates[index] == pressed) {
                    return;
                }

                _buttonStates[index] = pressed;
                emit buttonStateChanged(index, pressed);
            },
            Qt::QueuedConnection);

        (void) connect(
            _activeJoystick.data(),
            &Joystick::buttonActionsChanged,
            this,
            &ControllerInputManager::buttonMappingsChanged);

        (void) connect(
            _activeJoystick.data(),
            &Joystick::assignableActionsChanged,
            this,
            &ControllerInputManager::availableButtonActionsChanged);
    } else {
        _cameraTiltAxis = -1;
        _cameraZoomAxis = -1;
    }

    emit activeControllerChanged();
    emit cameraAxisMappingsChanged();
    emit buttonMappingsChanged();
    emit availableButtonActionsChanged();
}

void ControllerInputManager::_resetState()
{
    _axisValues.clear();
    _axisSeen.clear();
    _buttonStates.clear();

    _axisAssignmentBaseline.clear();
    _axisAssignmentBaselineValid.clear();
    _axisAssignmentActive = false;
    _axisAssignmentTarget.clear();

    _lastCameraTiltPercent = 0;
    _lastCameraZoomPercent = 0;
}

void ControllerInputManager::_loadCameraAxisMappings()
{
    if (!_activeJoystick) {
        _cameraTiltAxis = -1;
        _cameraZoomAxis = -1;
        return;
    }

    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kSettingsGroup));
    settings.beginGroup(_activeJoystick->name());

    int tiltAxis = settings.value(
                               QString::fromLatin1(kTiltAxisSettingsKey),
                               kDefaultCameraTiltAxis).toInt();

    int zoomAxis = settings.value(
                               QString::fromLatin1(kZoomAxisSettingsKey),
                               kDefaultCameraZoomAxis).toInt();

    settings.endGroup();
    settings.endGroup();

    if (!_validAxisIndex(tiltAxis)) {
        tiltAxis = _validAxisIndex(kDefaultCameraTiltAxis)
        ? kDefaultCameraTiltAxis
        : -1;
    }

    if (!_validAxisIndex(zoomAxis)) {
        zoomAxis = _validAxisIndex(kDefaultCameraZoomAxis)
        ? kDefaultCameraZoomAxis
        : -1;
    }

    if (zoomAxis == tiltAxis) {
        zoomAxis = -1;
    }

    _cameraTiltAxis = tiltAxis;
    _cameraZoomAxis = zoomAxis;
}

void ControllerInputManager::_saveCameraAxisMappings() const
{
    if (!_activeJoystick) {
        return;
    }

    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kSettingsGroup));
    settings.beginGroup(_activeJoystick->name());

    settings.setValue(QString::fromLatin1(kTiltAxisSettingsKey), _cameraTiltAxis);
    settings.setValue(QString::fromLatin1(kZoomAxisSettingsKey), _cameraZoomAxis);

    settings.endGroup();
    settings.endGroup();
}

void ControllerInputManager::_applyCameraAxisMapping(const QString &target, int index)
{
    if (!_validAxisIndex(index)) {
        return;
    }

    const bool isTilt = target == QStringLiteral("tilt");
    const bool isZoom = target == QStringLiteral("zoom");
    if (!isTilt && !isZoom) {
        return;
    }

    if ((isTilt && _cameraTiltAxis == index)
        || (isZoom && _cameraZoomAxis == index)) {
        return;
    }

    _stopMappedCameraInputs();

            // Keep Tilt and Zoom one-to-one. If the selected axis is already assigned to
            // the other camera function, swap the previous axis instead of creating a
            // duplicate mapping.
    if (isTilt) {
        const int oldTiltAxis = _cameraTiltAxis;
        if (_cameraZoomAxis == index) {
            _cameraZoomAxis = oldTiltAxis;
        }
        _cameraTiltAxis = index;
    } else {
        const int oldZoomAxis = _cameraZoomAxis;
        if (_cameraTiltAxis == index) {
            _cameraTiltAxis = oldZoomAxis;
        }
        _cameraZoomAxis = index;
    }

    if (_cameraTiltAxis == _cameraZoomAxis) {
        if (isTilt) {
            _cameraZoomAxis = -1;
        } else {
            _cameraTiltAxis = -1;
        }
    }

    _lastCameraTiltPercent = 0;
    _lastCameraZoomPercent = 0;

    _saveCameraAxisMappings();
    emit cameraAxisMappingsChanged();
}

bool ControllerInputManager::_processAxisAssignment(int index, int rawValue, bool axisWasSeen)
{
    if (!_axisAssignmentActive
        || index < 0
        || index >= _axisAssignmentBaseline.size()) {
        return false;
    }

            // If this axis had never emitted a live sample before assignment started,
            // use its first sample as the baseline instead of accidentally treating a
            // non-centered stationary control as user intent.
    if (!axisWasSeen || !_axisAssignmentBaselineValid[index]) {
        _axisAssignmentBaseline[index] = rawValue;
        _axisAssignmentBaselineValid[index] = true;
        return false;
    }

    const qint64 delta =
        qAbs(static_cast<qint64>(rawValue)
             - static_cast<qint64>(_axisAssignmentBaseline[index]));

    if (delta < kAxisAssignmentDelta) {
        return false;
    }

    const QString target = _axisAssignmentTarget;
    _applyCameraAxisMapping(target, index);
    _finishAxisAssignment();
    return true;
}

void ControllerInputManager::_finishAxisAssignment()
{
    if (!_axisAssignmentActive) {
        return;
    }

    _axisAssignmentActive = false;
    _axisAssignmentTarget.clear();
    _axisAssignmentBaseline.clear();
    _axisAssignmentBaselineValid.clear();

    emit axisAssignmentChanged();
}

void ControllerInputManager::_processMappedCameraAxis(int index, int rawValue)
{
    const int percent = _axisPercentFromRaw(rawValue);

    if (index == _cameraTiltAxis) {
        if (_lastCameraTiltPercent == percent) {
            return;
        }

        _lastCameraTiltPercent = percent;
        emit cameraTiltInputChanged(percent);
        return;
    }

    if (index == _cameraZoomAxis) {
        if (_lastCameraZoomPercent == percent) {
            return;
        }

        _lastCameraZoomPercent = percent;
        emit cameraZoomInputChanged(percent);
    }
}

void ControllerInputManager::_stopMappedCameraInputs()
{
    if (_lastCameraTiltPercent != 0) {
        _lastCameraTiltPercent = 0;
        emit cameraTiltInputChanged(0);
    }

    if (_lastCameraZoomPercent != 0) {
        _lastCameraZoomPercent = 0;
        emit cameraZoomInputChanged(0);
    }
}

bool ControllerInputManager::_validAxisIndex(int index) const
{
    return index >= 0 && index < axisCount();
}

int ControllerInputManager::_axisPercentFromRaw(int rawValue)
{
    // SDL joystick axes are signed 16-bit values:
    // -32768 on the negative edge and +32767 on the positive edge.
    const int denominator = rawValue < 0 ? 32768 : 32767;

    const int percent = (rawValue * 100) / denominator;
    return qBound(-100, percent, 100);
}