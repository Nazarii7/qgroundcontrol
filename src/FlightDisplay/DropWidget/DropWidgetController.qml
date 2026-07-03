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

    readonly property int dropModeAll: 0
    readonly property int dropModeGroups: 1
    readonly property int dropModeIndividual: 2

    property int dropMode: dropModeAll
    property string currentDropLabel: ""
    property string nextDropLabel: "Next: All selected"
    property var sequenceOrderedTargets: []
    property var _currentHoldTargets: []

    property int activeDropCount: 0
    property int availableServoCount: 0

    property real panelX: -1
    property real panelY: -1

    readonly property bool hasSavedPanelPosition: panelX >= 0 && panelY >= 0

    readonly property int _mavCmdDoSetServo: 183
    readonly property int _autopilotComponentId: 1
    readonly property int _servoCommandTimeoutMs: 2000
    readonly property int _commandRepeatIntervalMs: 5000
    readonly property int _maxCommandRepeatCount: 3

    readonly property int _minPwm: 800
    readonly property int _maxPwm: 2200
    readonly property int _defaultClosedPwm: 1000
    readonly property int _defaultOpenPwm: 2000

    property int _openRepeatCount: 0
    property int _closedRepeatCount: 0

    property var _servoCommandQueue: []
    property bool _servoCommandInProgress: false

    onActiveVehicleChanged: {
        resetHoldState()
        closedRepeatTimer.stop()
        clearServoCommandQueue()
        loadDropMode()
        loadServoPwmPositions()
        refreshServoAvailability()
        loadActiveServos()
        loadServoOrder()
        pruneUnavailableActiveServos()
        syncModelCounters()
        restartClosedRepeatTimer()
    }

    Component.onCompleted: {
        loadPanelState()
        loadDropMode()
        loadServoPwmPositions()
        refreshServoAvailability()
        loadActiveServos()
        loadServoOrder()
        pruneUnavailableActiveServos()
        syncModelCounters()
        restartClosedRepeatTimer()
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

    function clampPwm(value, fallbackValue) {
        var parsed = parseInt(value)

        if (isNaN(parsed)) {
            parsed = fallbackValue
        }

        if (parsed < _minPwm) {
            return _minPwm
        }

        if (parsed > _maxPwm) {
            return _maxPwm
        }

        return parsed
    }

    function parseOpenPositions(raw, fallbackPwm) {
        var positions = []

        if (raw && raw.length > 0) {
            try {
                var parsed = JSON.parse(raw)

                if (parsed && parsed.length !== undefined) {
                    for (var i = 0; i < parsed.length; i++) {
                        positions.push(clampPwm(parsed[i], fallbackPwm))
                    }
                }
            } catch (e) {
                console.warn("DROP_WIDGET_PWM: invalid row positions json", raw, e)
            }
        }

        if (positions.length <= 0) {
            positions.push(clampPwm(fallbackPwm, _defaultOpenPwm))
        }

        return positions
    }

    function positionsToJson(positions) {
        var sanitized = []

        for (var i = 0; positions && i < positions.length; i++) {
            sanitized.push(clampPwm(positions[i], _defaultOpenPwm))
        }

        if (sanitized.length <= 0) {
            sanitized.push(_defaultOpenPwm)
        }

        return JSON.stringify(sanitized)
    }

    function pwmTargetForRow(row) {
        var positions = parseOpenPositions(row.openPositionsJson, row.openPwm)
        var index = row.currentPositionIndex

        if (index < 0) {
            index = 0
        }

        return positions[index % positions.length]
    }

    function pwmLabelForRow(row) {
        var positions = parseOpenPositions(row.openPositionsJson, row.openPwm)
        var index = row.currentPositionIndex

        if (index < 0) {
            index = 0
        }

        return "P" + ((index % positions.length) + 1)
    }

    function syncRowPwmPreview(rowIndex) {
        if (rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        var row = dropModel.get(rowIndex)
        var nextPwm = pwmTargetForRow(row)
        var nextLabel = pwmLabelForRow(row)

        dropModel.setProperty(rowIndex, "nextOpenPwm", nextPwm)
        dropModel.setProperty(rowIndex, "nextPositionLabel", nextLabel)

        if (!row.isOpen) {
            dropModel.setProperty(rowIndex, "currentPwm", row.closedPwm)
            dropModel.setProperty(rowIndex, "currentPositionLabel", "Closed")
        }
    }

    function syncAllPwmPreviews() {
        for (var i = 0; i < dropModel.count; i++) {
            syncRowPwmPreview(i)
        }
    }

    function loadServoPwmPositions() {
        var raw = DropWidgetSettings.servoPwmPositions
        var config = {}

        if (raw && raw.length > 0) {
            try {
                config = JSON.parse(raw)
            } catch (e) {
                console.warn("DROP_WIDGET_PWM_LOAD_INVALID", raw, e)
                config = {}
            }
        }

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)
            var key = String(row.servoNumber)
            var rowConfig = config[key] || {}

            var closedPwm = clampPwm(rowConfig.closed, row.closedPwm || _defaultClosedPwm)
            var positions = parseOpenPositions(JSON.stringify(rowConfig.positions || []), row.openPwm || _defaultOpenPwm)
            var positionsJson = positionsToJson(positions)
            var currentIndex = row.currentPositionIndex

            if (currentIndex < 0) {
                currentIndex = 0
            }

            if (currentIndex >= positions.length) {
                currentIndex = 0
            }

            dropModel.setProperty(i, "closedPwm", closedPwm)
            dropModel.setProperty(i, "openPwm", positions[0])
            dropModel.setProperty(i, "openPositionsJson", positionsJson)
            dropModel.setProperty(i, "currentPositionIndex", currentIndex)
            dropModel.setProperty(i, "currentPwm", row.isOpen ? positions[currentIndex] : closedPwm)
            dropModel.setProperty(i, "currentPositionLabel", row.isOpen ? ("P" + (currentIndex + 1)) : "Closed")
            syncRowPwmPreview(i)
        }

        syncModelCounters()
    }

    function saveServoPwmPositions() {
        var config = {}

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)
            config[String(row.servoNumber)] = {
                "closed": clampPwm(row.closedPwm, _defaultClosedPwm),
                "positions": parseOpenPositions(row.openPositionsJson, row.openPwm)
            }
        }

        var raw = JSON.stringify(config)
        DropWidgetSettings.servoPwmPositions = raw

        console.log("DROP_WIDGET_PWM_SAVE", raw)
    }

    function setServoClosedPwm(rowIndex, pwmValue) {
        if (holdActive || rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        var closedPwm = clampPwm(pwmValue, _defaultClosedPwm)

        dropModel.setProperty(rowIndex, "closedPwm", closedPwm)
        dropModel.setProperty(rowIndex, "isOpen", false)
        dropModel.setProperty(rowIndex, "currentPwm", closedPwm)
        dropModel.setProperty(rowIndex, "currentPositionLabel", "Closed")

        syncRowPwmPreview(rowIndex)
        saveServoPwmPositions()
        syncModelCounters()
    }

    function setServoOpenPositionPwm(rowIndex, positionIndex, pwmValue) {
        if (holdActive || rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        var row = dropModel.get(rowIndex)
        var positions = parseOpenPositions(row.openPositionsJson, row.openPwm)

        if (positionIndex < 0 || positionIndex >= positions.length) {
            return
        }

        positions[positionIndex] = clampPwm(pwmValue, row.openPwm)

        dropModel.setProperty(rowIndex, "openPositionsJson", positionsToJson(positions))
        dropModel.setProperty(rowIndex, "openPwm", positions[0])

        if (row.currentPositionIndex >= positions.length) {
            dropModel.setProperty(rowIndex, "currentPositionIndex", 0)
        }

        syncRowPwmPreview(rowIndex)
        saveServoPwmPositions()
        syncModelCounters()
    }

    function addServoOpenPosition(rowIndex) {
        if (holdActive || rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        var row = dropModel.get(rowIndex)
        var positions = parseOpenPositions(row.openPositionsJson, row.openPwm)
        var lastValue = positions.length > 0 ? positions[positions.length - 1] : _defaultOpenPwm

        positions.push(lastValue)

        dropModel.setProperty(rowIndex, "openPositionsJson", positionsToJson(positions))
        dropModel.setProperty(rowIndex, "openPwm", positions[0])

        syncRowPwmPreview(rowIndex)
        saveServoPwmPositions()
        syncModelCounters()
    }

    function removeServoOpenPosition(rowIndex, positionIndex) {
        if (holdActive || rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        var row = dropModel.get(rowIndex)
        var positions = parseOpenPositions(row.openPositionsJson, row.openPwm)

        if (positions.length <= 1 || positionIndex < 0 || positionIndex >= positions.length) {
            return
        }

        positions.splice(positionIndex, 1)

        var nextIndex = row.currentPositionIndex
        if (nextIndex >= positions.length) {
            nextIndex = 0
        }

        dropModel.setProperty(rowIndex, "openPositionsJson", positionsToJson(positions))
        dropModel.setProperty(rowIndex, "openPwm", positions[0])
        dropModel.setProperty(rowIndex, "currentPositionIndex", nextIndex)

        syncRowPwmPreview(rowIndex)
        saveServoPwmPositions()
        syncModelCounters()
    }

    function resetServoPwmPositions(rowIndex) {
        if (holdActive || rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        dropModel.setProperty(rowIndex, "closedPwm", _defaultClosedPwm)
        dropModel.setProperty(rowIndex, "openPwm", _defaultOpenPwm)
        dropModel.setProperty(rowIndex, "openPositionsJson", positionsToJson([ _defaultOpenPwm ]))
        dropModel.setProperty(rowIndex, "currentPositionIndex", 0)
        dropModel.setProperty(rowIndex, "isOpen", false)
        dropModel.setProperty(rowIndex, "currentPwm", _defaultClosedPwm)
        dropModel.setProperty(rowIndex, "currentPositionLabel", "Closed")

        syncRowPwmPreview(rowIndex)
        saveServoPwmPositions()
        syncModelCounters()
    }

    function advancePwmPositionsForTargets(targets) {
        var advanced = {}

        for (var i = 0; targets && i < targets.length; i++) {
            var target = targets[i]
            var key = String(target.rowIndex)

            if (advanced[key]) {
                continue
            }

            if (target.rowIndex < 0 || target.rowIndex >= dropModel.count) {
                continue
            }

            var row = dropModel.get(target.rowIndex)
            var positions = parseOpenPositions(row.openPositionsJson, row.openPwm)
            var nextIndex = (row.currentPositionIndex + 1) % positions.length

            dropModel.setProperty(target.rowIndex, "currentPositionIndex", nextIndex)
            syncRowPwmPreview(target.rowIndex)

            advanced[key] = true
        }

        saveServoPwmPositions()
        syncModelCounters()
    }

    function parseServoOrder(raw) {
        var result = []

        if (!raw || raw.length <= 0) {
            return result
        }

        var parts = raw.split(",")

        for (var i = 0; i < parts.length; i++) {
            var servoNumber = parseInt(parts[i])

            if (!isNaN(servoNumber)) {
                result.push(servoNumber)
            }
        }

        return result
    }

    function servoOrderToString(order) {
        if (!order || order.length <= 0) {
            return ""
        }

        var result = []

        for (var i = 0; i < order.length; i++) {
            result.push(order[i])
        }

        return result.join(",")
    }

    function loadDropMode() {
        var savedMode = DropWidgetSettings.dropMode

        if (savedMode !== dropModeAll &&
            savedMode !== dropModeGroups &&
            savedMode !== dropModeIndividual) {
            savedMode = dropModeAll
        }

        dropMode = savedMode
        dropSequenceController.setDropMode(savedMode)

        currentDropLabel = dropSequenceController.currentActionLabel
        nextDropLabel = dropSequenceController.nextActionLabel

        console.log("DROP_WIDGET_LOAD_MODE", savedMode)
    }

    function loadServoOrder() {
        if (!hasResolvedServoAvailability()) {
            return
        }

        var raw = DropWidgetSettings.servoOrder
        var order = parseServoOrder(raw)

        console.log("DROP_WIDGET_LOAD_SERVO_ORDER", raw)

        dropSequenceController.setServoOrder(order)

        sequenceOrderedTargets = dropSequenceController.orderedTargetsPreview
        currentDropLabel = dropSequenceController.currentActionLabel
        nextDropLabel = dropSequenceController.nextActionLabel
    }

    function saveServoOrder() {
        if (!hasResolvedServoAvailability()) {
            return
        }

        var targets = dropSequenceController.selectedTargets()
        var order = []

        for (var i = 0; i < targets.length; i++) {
            order.push(targets[i].servoNumber)
        }

        var raw = servoOrderToString(order)

        console.log("DROP_WIDGET_SAVE_SERVO_ORDER", raw)

        DropWidgetSettings.servoOrder = raw
    }

    function setSettingsOpen(open) {
        settingsOpen = open
    }

    function setDropMode(mode) {
        if (mode !== dropModeAll &&
            mode !== dropModeGroups &&
            mode !== dropModeIndividual) {
            return
        }

        dropMode = mode
        dropSequenceController.setDropMode(mode)

        currentDropLabel = dropSequenceController.currentActionLabel
        nextDropLabel = dropSequenceController.nextActionLabel

        DropWidgetSettings.dropMode = mode

        console.log("DROP_WIDGET_MODE_CHANGED", mode)
    }

    function moveServoInSequence(servoNumber, direction) {
        if (holdActive) {
            console.warn("DROP_WIDGET_SEQUENCE: cannot change order while hold is active")
            return
        }

        dropSequenceController.moveServoInOrder(servoNumber, direction)

        sequenceOrderedTargets = dropSequenceController.orderedTargetsPreview
        currentDropLabel = dropSequenceController.currentActionLabel
        nextDropLabel = dropSequenceController.nextActionLabel

        saveServoOrder()

        console.log("DROP_WIDGET_SEQUENCE_MOVE", servoNumber, direction)
    }

    function setPanelExpanded(expanded) {
        panelExpanded = expanded
        DropWidgetSettings.panelExpanded = expanded
    }

    function setPanelPosition(x, y) {
        panelX = x
        panelY = y

        if (DropWidgetSettings.setPanelPosition) {
            DropWidgetSettings.setPanelPosition(x, y)
            return
        }

        DropWidgetSettings.panelX = x
        DropWidgetSettings.panelY = y
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
                dropModel.setProperty(i, "currentPwm", row.closedPwm)
                dropModel.setProperty(i, "currentPositionLabel", "Closed")
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
                dropModel.setProperty(j, "currentPwm", row.closedPwm)
                dropModel.setProperty(j, "currentPositionLabel", "Closed")
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

        syncAllPwmPreviews()

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

        dropSequenceController.updateSequenceInfo()
        sequenceOrderedTargets = dropSequenceController.orderedTargetsPreview
        currentDropLabel = dropSequenceController.currentActionLabel
        nextDropLabel = dropSequenceController.nextActionLabel
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
        dropModel.setProperty(rowIndex, "currentPwm", row.closedPwm)
        dropModel.setProperty(rowIndex, "currentPositionLabel", "Closed")

        syncModelCounters()
        saveActiveServos()

        dropSequenceController.resetSequence()
        sequenceOrderedTargets = dropSequenceController.orderedTargetsPreview
        currentDropLabel = dropSequenceController.currentActionLabel
        nextDropLabel = dropSequenceController.nextActionLabel

        saveServoOrder()
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

    function setDropCurrentPwm(rowIndex, pwmValue, positionLabel) {
        if (rowIndex >= 0 && rowIndex < dropModel.count) {
            dropModel.setProperty(rowIndex, "currentPwm", pwmValue)
            dropModel.setProperty(rowIndex, "currentPositionLabel", positionLabel)
        }
    }

    function resetHoldState() {
        holdActive = false
        _openRepeatCount = 0
        _closedRepeatCount = 0
        holdOpenRepeatTimer.stop()
        closedRepeatTimer.stop()

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)
            dropModel.setProperty(i, "isOpen", false)
            dropModel.setProperty(i, "busy", false)
            dropModel.setProperty(i, "currentPwm", row.closedPwm)
            dropModel.setProperty(i, "currentPositionLabel", "Closed")
        }
    }

    function clearServoCommandQueue() {
        _servoCommandQueue = []
        _servoCommandInProgress = false
        servoCommandTimeoutTimer.stop()
    }

    function clearPendingServoCommands() {
        _servoCommandQueue = []
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

    function sendSelectedServosClosed(markBusy) {
        if (!activeVehicle) {
            console.warn("DROP_WIDGET_CLOSE: no active vehicle")
            return false
        }

        var sent = false

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)

            if (!row.active || !row.servoAvailable) {
                continue
            }

            var targetPwm = row.closedPwm

            if (markBusy) {
                setDropBusy(i, true)
            }

            setDropOpen(i, false)
            setDropCurrentPwm(i, targetPwm, "Closed")

            if (queueServoCommand(row.servoNumber, targetPwm)) {
                sent = true
            }

            if (markBusy) {
                setDropBusy(i, false)
            }
        }

        return sent
    }

    function sendServoTargetsOpen(targets, markBusy) {
        if (!activeVehicle) {
            console.warn("DROP_WIDGET_TARGETS: no active vehicle")
            return false
        }

        if (!targets || targets.length <= 0) {
            console.warn("DROP_WIDGET_TARGETS: no targets")
            return false
        }

        var sent = false

        for (var i = 0; i < targets.length; i++) {
            var target = targets[i]
            var targetPwm = target.openPwm
            var targetLabel = target.positionLabel || "OPEN"

            if (markBusy) {
                setDropBusy(target.rowIndex, true)
            }

            setDropOpen(target.rowIndex, true)
            setDropCurrentPwm(target.rowIndex, targetPwm, targetLabel)

            if (queueServoCommand(target.servoNumber, targetPwm)) {
                sent = true
            }

            if (markBusy) {
                setDropBusy(target.rowIndex, false)
            }
        }

        return sent
    }

    function shouldMaintainClosedState() {
        return !!activeVehicle && !holdActive && activeDropCount > 0
    }

    function restartClosedRepeatTimer() {
        _closedRepeatCount = 0

        if (shouldMaintainClosedState()) {
            closedRepeatTimer.restart()
        } else {
            closedRepeatTimer.stop()
        }
    }

    function holdDropPressed() {
        if (activeDropCount <= 0) {
            console.warn("DROP_WIDGET_HOLD: no selected servo channels")
            return
        }

        if (holdActive) {
            return
        }

        var targets = dropSequenceController.currentTargets()

        if (!targets || targets.length <= 0) {
            console.warn("DROP_WIDGET_HOLD: no targets for current drop mode")
            return
        }

        console.log("DROP_WIDGET_HOLD_OPEN", dropSequenceController.currentActionLabel)
        holdActive = true

        _currentHoldTargets = targets
        currentDropLabel = dropSequenceController.currentActionLabel
        nextDropLabel = dropSequenceController.nextActionLabel

        _openRepeatCount = 0
        _closedRepeatCount = 0

        closedRepeatTimer.stop()
        clearPendingServoCommands()

        sendServoTargetsOpen(_currentHoldTargets, true)
        holdOpenRepeatTimer.restart()
    }

    function holdDropReleased() {
        if (!holdActive) {
            return
        }

        console.log("DROP_WIDGET_HOLD_CLOSE")
        holdActive = false

        holdOpenRepeatTimer.stop()
        _openRepeatCount = 0

        clearPendingServoCommands()

        sendSelectedServosClosed(true)
        advancePwmPositionsForTargets(_currentHoldTargets)

        _currentHoldTargets = []
        currentDropLabel = ""

        dropSequenceController.advanceSequence()
        nextDropLabel = dropSequenceController.nextActionLabel

        restartClosedRepeatTimer()
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
        interval: _commandRepeatIntervalMs
        repeat: true
        running: false

        onTriggered: {
            if (!holdActive) {
                _openRepeatCount = 0
                stop()
                return
            }

            if (_openRepeatCount >= _maxCommandRepeatCount) {
                console.log("DROP_WIDGET_HOLD_REPEAT_DONE")
                stop()
                return
            }

            if (_servoCommandInProgress || _servoCommandQueue.length > 0) {
                console.log("DROP_WIDGET_HOLD_REPEAT_SKIP queue busy")
                return
            }

            _openRepeatCount++
            console.log("DROP_WIDGET_HOLD_REPEAT_OPEN", _openRepeatCount, "of", _maxCommandRepeatCount)
            sendServoTargetsOpen(_currentHoldTargets, true)

            if (_openRepeatCount >= _maxCommandRepeatCount) {
                stop()
            }
        }
    }

    Timer {
        id: closedRepeatTimer
        interval: _commandRepeatIntervalMs
        repeat: true
        running: false

        onTriggered: {
            if (!shouldMaintainClosedState()) {
                _closedRepeatCount = 0
                stop()
                return
            }

            if (_closedRepeatCount >= _maxCommandRepeatCount) {
                console.log("DROP_WIDGET_CLOSED_REPEAT_DONE")
                stop()
                return
            }

            if (_servoCommandInProgress || _servoCommandQueue.length > 0) {
                console.log("DROP_WIDGET_CLOSED_REPEAT_SKIP queue busy")
                return
            }

            _closedRepeatCount++
            console.log("DROP_WIDGET_CLOSED_REPEAT", _closedRepeatCount, "of", _maxCommandRepeatCount)
            sendSelectedServosClosed(false)

            if (_closedRepeatCount >= _maxCommandRepeatCount) {
                stop()
            }
        }
    }

    ListModel {
        id: dropModel

        ListElement { servoNumber: 1;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO1_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO1_FUNCTION" }
        ListElement { servoNumber: 2;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO2_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO2_FUNCTION" }
        ListElement { servoNumber: 3;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO3_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO3_FUNCTION" }
        ListElement { servoNumber: 4;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO4_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO4_FUNCTION" }
        ListElement { servoNumber: 5;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO5_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO5_FUNCTION" }
        ListElement { servoNumber: 6;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO6_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO6_FUNCTION" }
        ListElement { servoNumber: 7;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO7_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO7_FUNCTION" }
        ListElement { servoNumber: 8;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO8_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO8_FUNCTION" }
        ListElement { servoNumber: 9;  closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO9_FUNCTION";  functionValue: -1; availabilityText: "Waiting for SERVO9_FUNCTION" }
        ListElement { servoNumber: 10; closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO10_FUNCTION"; functionValue: -1; availabilityText: "Waiting for SERVO10_FUNCTION" }
        ListElement { servoNumber: 11; closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO11_FUNCTION"; functionValue: -1; availabilityText: "Waiting for SERVO11_FUNCTION" }
        ListElement { servoNumber: 12; closedPwm: 1000; openPwm: 2000; openPositionsJson: "[2000]"; currentPositionIndex: 0; currentPwm: 1000; currentPositionLabel: "Closed"; nextOpenPwm: 2000; nextPositionLabel: "P1"; isOpen: false; busy: false; active: false; servoAvailable: false; functionParamName: "SERVO12_FUNCTION"; functionValue: -1; availabilityText: "Waiting for SERVO12_FUNCTION" }
    }

    DropSequenceController {
        id: dropSequenceController

        dropModel: dropModel
        dropMode: controller.dropMode

        onNextActionLabelChanged: {
            controller.nextDropLabel = nextActionLabel
        }

        onCurrentActionLabelChanged: {
            controller.currentDropLabel = currentActionLabel
        }

        onOrderedTargetsPreviewChanged: {
            controller.sequenceOrderedTargets = orderedTargetsPreview
        }

        onSequenceChanged: {
            controller.sequenceOrderedTargets = orderedTargetsPreview
            controller.nextDropLabel = nextActionLabel

            if (controller.holdActive) {
                controller.currentDropLabel = currentActionLabel
            }
        }
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
            loadServoOrder()
            restartClosedRepeatTimer()
        }
    }

    Connections {
          target: DropWidgetJoystickBridge

          function onDropHoldPressed() {
              controller.holdDropPressed()
          }

          function onDropHoldReleased() {
              controller.holdDropReleased()
          }
      }
}
