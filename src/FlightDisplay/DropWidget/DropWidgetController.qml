import QtQuick

import QGroundControl
import QGroundControl.FlightDisplay

Item {
    id: controller

    visible: false

    property var activeVehicle

    property alias dropModel: dropModel

    property bool settingsOpen: false
    property bool panelExpanded: true
    property bool holdActive: false

    property int activeDropCount: 0
    property int availableServoCount: 0

    property real panelX: -1
    property real panelY: -1

    readonly property bool hasSavedPanelPosition: panelX >= 0 && panelY >= 0

    readonly property int _mavCmdDoSetServo: 183
    readonly property int _autopilotComponentId: 1
    readonly property int _servoCommandTimeoutMs: 2000

    property var _servoCommandQueue: []
    property bool _servoCommandInProgress: false

    onActiveVehicleChanged: {
        resetHoldState()
        clearServoCommandQueue()
        refreshServoAvailability()
        loadActiveServos()
        pruneUnavailableActiveServos()
        syncModelCounters()
    }

    Component.onCompleted: {
        loadPanelState()
        refreshServoAvailability()
        loadActiveServos()
        pruneUnavailableActiveServos()
        syncModelCounters()
    }

    function dropTitleForServo(servoNumber) {
        if (servoNumber >= 5) {
            return "DROP " + (servoNumber - 4)
        }

        return "SERVO " + servoNumber
    }

    function loadPanelState() {
        panelExpanded = DropWidgetSettings.panelExpanded
        panelX = DropWidgetSettings.panelX
        panelY = DropWidgetSettings.panelY
    }

    function setSettingsOpen(open) {
        settingsOpen = open
    }

    function setPanelExpanded(expanded) {
        panelExpanded = expanded
        DropWidgetSettings.panelExpanded = expanded
    }

    function setPanelPosition(x, y) {
        panelX = x
        panelY = y

        if (panelX >= 0) {
            DropWidgetSettings.panelX = panelX
        }

        if (panelY >= 0) {
            DropWidgetSettings.panelY = panelY
        }
    }

    function refreshServoAvailability() {
        var parameterManager = (activeVehicle && activeVehicle.parameterManager)
                               ? activeVehicle.parameterManager
                               : null

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)
            var info = DropWidgetSettings.servoFunctionAvailability(parameterManager, row.servoNumber)

            dropModel.setProperty(i, "functionParamName", info.paramName)
            dropModel.setProperty(i, "functionValue", info.functionValue)
            dropModel.setProperty(i, "servoAvailable", info.available)
            dropModel.setProperty(i, "availabilityText", info.text)
        }

        pruneUnavailableActiveServos()
        syncModelCounters()
    }

    function hasResolvedServoAvailability() {
        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)

            if (row.functionValue !== -1) {
                return true
            }
        }

        return false
    }

    function pruneUnavailableActiveServos() {
        var changed = false

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)

            if (row.active && !row.servoAvailable) {
                dropModel.setProperty(i, "active", false)
                dropModel.setProperty(i, "isOpen", false)
                dropModel.setProperty(i, "busy", false)
                changed = true
            }
        }

        syncModelCounters()

        if (changed && hasResolvedServoAvailability()) {
            saveActiveServos()
        }
    }

    function saveActiveServos() {
        var activeList = []

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)

            if (row.active && row.servoAvailable) {
                activeList.push(row.servoNumber)
            }
        }

        console.log("DROP_WIDGET_SAVE_ACTIVE_SERVOS", activeList.join(","))
        DropWidgetSettings.activeServos = activeList.join(",")
    }

    function loadActiveServos() {
        var raw = DropWidgetSettings.activeServos
        var selected = {}

        console.log("DROP_WIDGET_LOAD_ACTIVE_SERVOS", raw)

        if (raw && raw.length > 0) {
            var parts = raw.split(",")

            for (var i = 0; i < parts.length; i++) {
                var n = parseInt(parts[i])

                if (!isNaN(n)) {
                    selected[n] = true
                }
            }
        }

        for (var j = 0; j < dropModel.count; j++) {
            var row = dropModel.get(j)
            var shouldBeActive = !!selected[row.servoNumber] && row.servoAvailable

            dropModel.setProperty(j, "active", shouldBeActive)

            if (!shouldBeActive) {
                dropModel.setProperty(j, "isOpen", false)
                dropModel.setProperty(j, "busy", false)
            }
        }

        syncModelCounters()

        if (hasResolvedServoAvailability()) {
            saveActiveServos()
        }
    }

    function syncModelCounters() {
        var activeTotal = 0
        var availableTotal = 0

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)

            if (row.servoAvailable) {
                availableTotal++
            }

            if (row.active && row.servoAvailable) {
                activeTotal++
            }
        }

        activeDropCount = activeTotal
        availableServoCount = availableTotal
    }

    function toggleServoVisibility(rowIndex) {
        if (rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        var row = dropModel.get(rowIndex)

        if (!row.servoAvailable) {
            console.warn("DROP_WIDGET: servo channel is unavailable",
                         "servo:", row.servoNumber,
                         "reason:", row.availabilityText)
            return
        }

        dropModel.setProperty(rowIndex, "active", !row.active)
        dropModel.setProperty(rowIndex, "isOpen", false)
        dropModel.setProperty(rowIndex, "busy", false)

        syncModelCounters()
        saveActiveServos()
    }

    function setDropBusy(rowIndex, busy) {
        if (rowIndex >= 0 && rowIndex < dropModel.count) {
            dropModel.setProperty(rowIndex, "busy", busy)
        }
    }

    function setDropOpen(rowIndex, isOpen) {
        if (rowIndex >= 0 && rowIndex < dropModel.count) {
            dropModel.setProperty(rowIndex, "isOpen", isOpen)
        }
    }

    function resetHoldState() {
        holdActive = false

        for (var i = 0; i < dropModel.count; i++) {
            dropModel.setProperty(i, "isOpen", false)
            dropModel.setProperty(i, "busy", false)
        }
    }

    function clearServoCommandQueue() {
        _servoCommandQueue = []
        _servoCommandInProgress = false
        servoCommandTimeoutTimer.stop()
    }

    function queueServoCommand(servoNumber, pwmValue) {
        if (!activeVehicle) {
            console.warn("DROP_WIDGET: no active vehicle")
            return false
        }

        var nextQueue = _servoCommandQueue.slice()
        nextQueue.push({
            "servoNumber": servoNumber,
            "pwmValue": pwmValue
        })

        _servoCommandQueue = nextQueue
        processServoCommandQueue()

        return true
    }

    function processServoCommandQueue() {
        if (!activeVehicle || _servoCommandInProgress || _servoCommandQueue.length <= 0) {
            return
        }

        var nextQueue = _servoCommandQueue.slice()
        var commandRequest = nextQueue.shift()

        _servoCommandQueue = nextQueue
        _servoCommandInProgress = true

        console.log("DROP_WIDGET_SEND",
                    "servo:", commandRequest.servoNumber,
                    "pwm:", commandRequest.pwmValue)

        activeVehicle.sendCommand(
            _autopilotComponentId,
            _mavCmdDoSetServo,
            true,
            commandRequest.servoNumber,
            commandRequest.pwmValue,
            0,
            0,
            0,
            0,
            0
        )

        servoCommandTimeoutTimer.restart()
    }

    function sendSelectedServosState(openState, markBusy) {
        if (!activeVehicle) {
            console.warn("DROP_WIDGET_HOLD: no active vehicle")
            return false
        }

        var sent = false

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)

            if (!row.active || !row.servoAvailable) {
                continue
            }

            var targetPwm = openState ? row.openPwm : row.closedPwm

            if (markBusy) {
                setDropBusy(i, true)
            }

            setDropOpen(i, openState)

            if (queueServoCommand(row.servoNumber, targetPwm)) {
                sent = true
            }

            if (markBusy) {
                setDropBusy(i, false)
            }
        }

        return sent
    }

    function holdDropPressed() {
        if (activeDropCount <= 0) {
            console.warn("DROP_WIDGET_HOLD: no selected servo channels")
            return
        }

        if (holdActive) {
            return
        }

        console.log("DROP_WIDGET_HOLD_OPEN")
        holdActive = true

        sendSelectedServosState(true, true)
        holdOpenRepeatTimer.restart()
    }

    function holdDropReleased() {
        if (!holdActive) {
            return
        }

        console.log("DROP_WIDGET_HOLD_CLOSE")
        holdActive = false

        holdOpenRepeatTimer.stop()
        sendSelectedServosState(false, true)
    }

    Timer {
        id: servoAvailabilityTimer
        interval: 1500
        repeat: true
        running: true

        onTriggered: {
            refreshServoAvailability()
        }
    }

    Timer {
        id: servoCommandTimeoutTimer
        interval: _servoCommandTimeoutMs
        repeat: false

        onTriggered: {
            console.warn("DROP_WIDGET_ACK TIMEOUT: command response was not received")
            _servoCommandInProgress = false
            processServoCommandQueue()
        }
    }

    Timer {
        id: holdOpenRepeatTimer
        interval: 5000
        repeat: true
        running: false

        onTriggered: {
            if (!holdActive) {
                stop()
                return
            }

            if (_servoCommandInProgress || _servoCommandQueue.length > 0) {
                console.log("DROP_WIDGET_HOLD_REPEAT_SKIP queue busy")
                return
            }

            console.log("DROP_WIDGET_HOLD_REPEAT_OPEN")
            sendSelectedServosState(true, true)
        }
    }

    ListModel {
        id: dropModel

        ListElement { servoNumber: 1;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO1_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO1_FUNCTION" }
        ListElement { servoNumber: 2;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO2_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO2_FUNCTION" }
        ListElement { servoNumber: 3;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO3_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO3_FUNCTION" }
        ListElement { servoNumber: 4;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO4_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO4_FUNCTION" }
        ListElement { servoNumber: 5;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO5_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO5_FUNCTION" }
        ListElement { servoNumber: 6;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO6_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO6_FUNCTION" }
        ListElement { servoNumber: 7;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO7_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO7_FUNCTION" }
        ListElement { servoNumber: 8;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO8_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO8_FUNCTION" }
        ListElement { servoNumber: 9;  closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO9_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO9_FUNCTION" }
        ListElement { servoNumber: 10; closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO10_FUNCTION"; functionValue: -1; availabilityText: "Waiting for SERVO10_FUNCTION" }
        ListElement { servoNumber: 11; closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO11_FUNCTION"; functionValue: -1; availabilityText: "Waiting for SERVO11_FUNCTION" }
        ListElement { servoNumber: 12; closedPwm: 1000; openPwm: 2000; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO12_FUNCTION"; functionValue: -1; availabilityText: "Waiting for SERVO12_FUNCTION" }
    }

    Connections {
        target: activeVehicle

        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            if (command !== _mavCmdDoSetServo) {
                return
            }

            if (ackResult === 0) {
                console.log("DROP_WIDGET_ACK OK",
                            "vehicleId:", vehicleId,
                            "targetComponent:", targetComponent,
                            "command:", command)
            } else {
                console.warn("DROP_WIDGET_ACK FAIL",
                             "vehicleId:", vehicleId,
                             "targetComponent:", targetComponent,
                             "command:", command,
                             "ack:", ackResult,
                             "failure:", failureCode)
            }

            _servoCommandInProgress = false
            servoCommandTimeoutTimer.stop()
            processServoCommandQueue()
        }
    }

    Connections {
        target: activeVehicle && activeVehicle.parameterManager ? activeVehicle.parameterManager : null

        function onParametersReadyChanged() {
            refreshServoAvailability()
            loadActiveServos()
            pruneUnavailableActiveServos()
            syncModelCounters()
        }
    }
}