#pragma once

#include "Joystick.h"

#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QVector>

class ControllerInputManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString activeControllerName READ activeControllerName NOTIFY activeControllerChanged)
    Q_PROPERTY(int axisCount READ axisCount NOTIFY activeControllerChanged)
    Q_PROPERTY(int buttonCount READ buttonCount NOTIFY activeControllerChanged)

    Q_PROPERTY(int cameraTiltAxis READ cameraTiltAxis NOTIFY cameraAxisMappingsChanged)
    Q_PROPERTY(int cameraZoomAxis READ cameraZoomAxis NOTIFY cameraAxisMappingsChanged)
    Q_PROPERTY(bool axisAssignmentActive READ axisAssignmentActive NOTIFY axisAssignmentChanged)
    Q_PROPERTY(QString axisAssignmentTarget READ axisAssignmentTarget NOTIFY axisAssignmentChanged)

    Q_PROPERTY(QStringList availableButtonActions READ availableButtonActions NOTIFY availableButtonActionsChanged)

   public:
    explicit ControllerInputManager(QObject *parent = nullptr);

    static ControllerInputManager *instance();
    static void registerQmlSingleton();

            /// Connects this observer to JoystickManager.
            /// Safe to call more than once.
    void init();

    QString activeControllerName() const;
    int axisCount() const { return _axisValues.size(); }
    int buttonCount() const { return _buttonStates.size(); }

    int cameraTiltAxis() const { return _cameraTiltAxis; }
    int cameraZoomAxis() const { return _cameraZoomAxis; }
    bool axisAssignmentActive() const { return _axisAssignmentActive; }
    QString axisAssignmentTarget() const { return _axisAssignmentTarget; }

    QStringList availableButtonActions() const;

    Q_INVOKABLE int axisValue(int index) const;
    Q_INVOKABLE bool buttonPressed(int index) const;

    Q_INVOKABLE void setCameraTiltAxis(int index);
    Q_INVOKABLE void setCameraZoomAxis(int index);
    Q_INVOKABLE void beginAxisAssignment(const QString &target);
    Q_INVOKABLE void cancelAxisAssignment();
    Q_INVOKABLE void resetCameraAxisMappings();

    Q_INVOKABLE QString buttonAction(int index) const;
    Q_INVOKABLE void setButtonAction(int index, const QString &action);
    Q_INVOKABLE void clearButtonAction(int index);

   signals:
    void activeControllerChanged();
    void axisValueChanged(int index, int value);
    void buttonStateChanged(int index, bool pressed);

    void cameraAxisMappingsChanged();
    void axisAssignmentChanged();
    void buttonMappingsChanged();
    void availableButtonActionsChanged();

            // Semantic camera inputs. The physical axis mapping is configurable per
            // controller; SIYI-specific deadzones/hysteresis stay outside this class.
    void cameraTiltInputChanged(int percent);
    void cameraZoomInputChanged(int percent);

   private:
    void _setActiveJoystick(Joystick *joystick);
    void _resetState();

    void _loadCameraAxisMappings();
    void _saveCameraAxisMappings() const;
    void _applyCameraAxisMapping(const QString &target, int index);
    bool _processAxisAssignment(int index, int rawValue, bool axisWasSeen);
    void _finishAxisAssignment();

    void _processMappedCameraAxis(int index, int rawValue);
    void _stopMappedCameraInputs();

    bool _validAxisIndex(int index) const;
    static int _axisPercentFromRaw(int rawValue);

    bool _initialized = false;
    QPointer<Joystick> _activeJoystick;
    QVector<int> _axisValues;
    QVector<bool> _axisSeen;
    QVector<bool> _buttonStates;

    int _cameraTiltAxis = -1;
    int _cameraZoomAxis = -1;

    bool _axisAssignmentActive = false;
    QString _axisAssignmentTarget;
    QVector<int> _axisAssignmentBaseline;
    QVector<bool> _axisAssignmentBaselineValid;

    int _lastCameraTiltPercent = 0;
    int _lastCameraZoomPercent = 0;

    static constexpr int kDefaultCameraTiltAxis = 4;
    static constexpr int kDefaultCameraZoomAxis = 5;
    static constexpr int kAxisAssignmentDelta = 10000;

    static constexpr const char *kSettingsGroup = "ControllerInputMappings";
    static constexpr const char *kTiltAxisSettingsKey = "CameraTiltAxis";
    static constexpr const char *kZoomAxisSettingsKey = "CameraZoomAxis";
};