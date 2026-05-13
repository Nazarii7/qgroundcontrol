/****************************************************************************
 *
 * FlyViewCustomLayer.qml
 * Compact and stable Drop Control widget
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.FlightDisplay


Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets: _toolInsets
    property var mapControl

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    readonly property int _mavCmdDoSetServo: 183
    readonly property int _autopilotComponentId: 1

    readonly property real _m: ScreenTools.defaultFontPixelHeight * 0.6
    readonly property real _panelWidth: 220
    readonly property real _headerHeight: 46
    readonly property real _rowHeight: 54
    readonly property real _rowAnimatedHeight: 58
    readonly property real _settingsRowHeight: 30
    readonly property real _topOffset: parentToolInsets ? parentToolInsets.topEdgeRightInset + _m : _m

    property int _pendingRowIndex: -1
    property bool _pendingPreviousState: false
    property bool _settingsOpen: false
    property bool _panelExpanded: true
    property int _activeDropCount: 0
    property real _panelX: -1
    property real _panelY: -1

    function dropTitleForServo(servoNumber) {
        return "DROP " + (servoNumber - 4)
    }

    function saveActiveServos() {
        var activeList = []
        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)
            if (row.active) {
                activeList.push(row.servoNumber)
            }
        }
        DropWidgetSettings.activeServos = activeList.join(",")
    }

    function loadActiveServos() {
        var raw = DropWidgetSettings.activeServos
        var selected = {}

        if (raw && raw.length > 0) {
            var parts = raw.split(",")
            for (var i = 0; i < parts.length; i++) {
                var n = parseInt(parts[i])
                if (!isNaN(n)) {
                    selected[n] = true
                }
            }
        } else {
            selected[5] = true
            selected[6] = true
        }

        for (var j = 0; j < dropModel.count; j++) {
            var servo = dropModel.get(j).servoNumber
            dropModel.setProperty(j, "active", !!selected[servo])
        }
    }

    function loadPanelState() {
        _panelExpanded = DropWidgetSettings.panelExpanded

        var savedX = DropWidgetSettings.panelX
        var savedY = DropWidgetSettings.panelY

        _panelX = savedX
        _panelY = savedY
    }

    function savePanelState() {
        DropWidgetSettings.panelExpanded = _panelExpanded

        if (_panelX >= 0) {
            DropWidgetSettings.panelX = _panelX
        }

        if (_panelY >= 0) {
            DropWidgetSettings.panelY = _panelY
        }
    }

    function syncActiveCount() {
        var total = 0
        for (var i = 0; i < dropModel.count; i++) {
            if (dropModel.get(i).active) {
                total++
            }
        }
        _activeDropCount = total
    }

    function toggleServoVisibility(rowIndex) {
        if (rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        var row = dropModel.get(rowIndex)
        dropModel.setProperty(rowIndex, "active", !row.active)
        syncActiveCount()
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

    function sendServoCommand(servoNumber, pwmValue) {
        if (!_activeVehicle) {
            console.warn("DROP_WIDGET: no active vehicle")
            return false
        }

        console.log("DROP_WIDGET_SEND",
                    "servo:", servoNumber,
                    "pwm:", pwmValue)

        _activeVehicle.sendCommand(
            _autopilotComponentId,
            _mavCmdDoSetServo,
            true,
            servoNumber,
            pwmValue,
            0,
            0,
            0,
            0,
            0
        )

        return true
    }

    function toggleDrop(rowIndex) {
        if (rowIndex < 0 || rowIndex >= dropModel.count) {
            return
        }

        if (_pendingRowIndex !== -1) {
            console.warn("DROP_WIDGET_TOGGLE: command already in flight")
            return
        }

        var row = dropModel.get(rowIndex)

        if (!row.active) {
            return
        }

        if (!_activeVehicle) {
            console.warn("DROP_WIDGET_TOGGLE: no active vehicle")
            return
        }

        var previousState = row.isOpen
        var nextState = !row.isOpen
        var targetPwm = nextState ? row.openPwm : row.closedPwm

        _pendingRowIndex = rowIndex
        _pendingPreviousState = previousState

        setDropOpen(rowIndex, nextState)
        setDropBusy(rowIndex, true)

        var ok = sendServoCommand(row.servoNumber, targetPwm)
        if (!ok) {
            setDropOpen(rowIndex, previousState)
            setDropBusy(rowIndex, false)
            _pendingRowIndex = -1
            _pendingPreviousState = false
        }
    }

    Component.onCompleted: {
        loadActiveServos()
        syncActiveCount()
        loadPanelState()
        saveActiveServos()
        savePanelState()
    }

    QGCToolInsets {
        id: _toolInsets

        leftEdgeTopInset:       parentToolInsets ? parentToolInsets.leftEdgeTopInset : 0
        leftEdgeCenterInset:    parentToolInsets ? parentToolInsets.leftEdgeCenterInset : 0
        leftEdgeBottomInset:    parentToolInsets ? parentToolInsets.leftEdgeBottomInset : 0

        rightEdgeTopInset:      _panelWidth + _m * 2
        rightEdgeCenterInset:   parentToolInsets ? parentToolInsets.rightEdgeCenterInset : 0
        rightEdgeBottomInset:   parentToolInsets ? parentToolInsets.rightEdgeBottomInset : 0

        topEdgeLeftInset:       parentToolInsets ? parentToolInsets.topEdgeLeftInset : 0
        topEdgeCenterInset:     parentToolInsets ? parentToolInsets.topEdgeCenterInset : 0
        topEdgeRightInset:      parentToolInsets ? parentToolInsets.topEdgeRightInset : 0

        bottomEdgeLeftInset:    parentToolInsets ? parentToolInsets.bottomEdgeLeftInset : 0
        bottomEdgeCenterInset:  parentToolInsets ? parentToolInsets.bottomEdgeCenterInset : 0
        bottomEdgeRightInset:   parentToolInsets ? parentToolInsets.bottomEdgeRightInset : 0
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

    ListModel {
        id: dropModel

        ListElement {
            servoNumber: 5
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: true
        }

        ListElement {
            servoNumber: 6
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: true
        }

        ListElement {
            servoNumber: 7
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: false
        }

        ListElement {
            servoNumber: 8
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: false
        }

        ListElement {
            servoNumber: 9
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: false
        }

        ListElement {
            servoNumber: 10
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: false
        }

        ListElement {
            servoNumber: 11
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: false
        }

        ListElement {
            servoNumber: 12
            closedPwm: 1000
            openPwm: 2000
            isOpen: false
            busy: false
            active: false
        }
    }

    Connections {
        target: _activeVehicle

        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            if (command !== _mavCmdDoSetServo) {
                return
            }

            if (_pendingRowIndex < 0 || _pendingRowIndex >= dropModel.count) {
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

                setDropOpen(_pendingRowIndex, _pendingPreviousState)
            }

            setDropBusy(_pendingRowIndex, false)
            _pendingRowIndex = -1
            _pendingPreviousState = false
        }
    }

    DropControlPanel {
        id: dropControlPanel
        anchors.fill: parent

        panelWidth: _panelWidth
        margin: _m
        topOffset: _topOffset
        headerHeight: _headerHeight
        rowHeight: _rowHeight
        rowAnimatedHeight: _rowAnimatedHeight
        settingsRowHeight: _settingsRowHeight
        savedPanelX: _panelX
        savedPanelY: _panelY
        useSavedPanelPosition: _panelX >= 0 && _panelY >= 0

        activeDropCount: _activeDropCount
        settingsOpen: _settingsOpen
        panelExpanded: _panelExpanded

        dropModel: dropModel
        paletteObject: qgcPal
        dropTitleProvider: _root.dropTitleForServo

        onSettingsOpenChangedFromUi: function(open) {
            _settingsOpen = open
        }

        onPanelPositionChangedFromUi: function(x, y) {
            _panelX = x
            _panelY = y
            savePanelState()
        }

        onPanelExpandedChangedFromUi: function(expanded) {
               _panelExpanded = expanded
               savePanelState()
           }


        onToggleRequested: function(rowIndex) {
            _root.toggleDrop(rowIndex)
        }

        onVisibilityToggleRequested: function(rowIndex) {
            _root.toggleServoVisibility(rowIndex)
        }
    }
}