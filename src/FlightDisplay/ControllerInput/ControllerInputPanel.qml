/****************************************************************************
 *
 * ControllerInputPanel.qml
 * Styled to match the Drop Widget visual language and with collapsible
 * Camera Controls / Button Mapping / Raw Inputs sections.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.JoystickManager 1.0

Item {
    id: root

    property real margin: 10
    property real topOffset: margin
    property real panelWidth: 320
    property bool expanded: true

    // Movement behavior mirrors DropControlPanel.
    property bool panelLocked: true
    property real panelX: -1
    property real panelY: -1
    property bool panelPositionReady: false
    property bool panelDragging: false

    property real dragStartPointerX: 0
    property real dragStartPointerY: 0
    property real dragStartPanelX: 0
    property real dragStartPanelY: 0

    readonly property bool hasController: ControllerInputManager.activeControllerName.length > 0
    readonly property bool hasVehicle: QGroundControl.multiVehicleManager.activeVehicle !== null
                                       && QGroundControl.multiVehicleManager.activeVehicle !== undefined

    // Drop-widget-like styling
    readonly property color panelColor: Qt.rgba(0.10, 0.11, 0.15, 0.93)
    readonly property color panelBorderColor: Qt.rgba(1, 1, 1, 0.10)
    readonly property color cardColor: Qt.rgba(1, 1, 1, 0.06)
    readonly property color cardBorderColor: Qt.rgba(1, 1, 1, 0.10)
    readonly property color buttonIdleColor: Qt.rgba(1, 1, 1, 0.06)
    readonly property color buttonActiveColor: Qt.rgba(1, 1, 1, 0.12)
    readonly property color buttonPressedColor: Qt.rgba(0.66, 0.61, 1.0, 0.28)
    readonly property color accentColor: "#A89BFF"
    readonly property color activeColor: "#55D88B"
    readonly property color warningColor: "#F7C948"
    readonly property color textColor: "white"
    readonly property color secondaryTextColor: Qt.rgba(1, 1, 1, 0.62)
    readonly property color tertiaryTextColor: Qt.rgba(1, 1, 1, 0.45)
    readonly property color trackColor: Qt.rgba(0, 0, 0, 0.35)
    readonly property color inactiveButtonColor: "#343442"

    readonly property int headerHeight: 46
    readonly property int panelPadding: 12
    readonly property int bodySpacing: 10
    readonly property int axisRowHeight: 30
    readonly property int buttonCellHeight: 27

    property bool cameraControlsExpanded: false
    property bool rawInputsExpanded: false
    property bool rawAxesExpanded: true
    property bool rawButtonsExpanded: true
    property bool buttonMappingsExpanded: false

    property int tiltRawValue: 0
    property int zoomRawValue: 0
    property int zoomDirection: 0

    property int selectedButtonIndex: 0
    property int selectedButtonActionIndex: 0

    // UI-only list of button/action rows. Actual mappings are still stored
    // through ControllerInputManager / the standard QGC joystick backend.
    ListModel {
        id: buttonMappingRows
    }

    readonly property int tiltAxis: ControllerInputManager.cameraTiltAxis
    readonly property int zoomAxis: ControllerInputManager.cameraZoomAxis

    readonly property int tiltPercent: axisPercent(tiltRawValue)
    readonly property int zoomPercent: axisPercent(zoomRawValue)

    readonly property int tiltDeadzonePercent: 5
    readonly property int zoomStartPercent: 20
    readonly property int zoomStopPercent: 10

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function normalizedAxisValue(rawValue) {
        if (rawValue < 0) {
            return clamp(rawValue / 32768.0, -1.0, 1.0)
        }
        return clamp(rawValue / 32767.0, -1.0, 1.0)
    }

    function axisPercent(rawValue) {
        return Math.round(normalizedAxisValue(rawValue) * 100)
    }

    function signedTrackPosition(percent) {
        return (clamp(percent, -100, 100) + 100) / 200
    }

    function tiltStatus(percent) {
        if (Math.abs(percent) <= root.tiltDeadzonePercent) {
            return qsTr("STOP")
        }

        return percent > 0
                ? qsTr("UP %1%").arg(Math.abs(percent))
                : qsTr("DOWN %1%").arg(Math.abs(percent))
    }

    function updateZoomDirection(percent) {
        var nextDirection = root.zoomDirection

        if (root.zoomDirection === 0) {
            if (percent >= root.zoomStartPercent) {
                nextDirection = 1
            } else if (percent <= -root.zoomStartPercent) {
                nextDirection = -1
            }
        } else if (root.zoomDirection > 0) {
            if (percent <= -root.zoomStartPercent) {
                nextDirection = -1
            } else if (percent <= root.zoomStopPercent) {
                nextDirection = 0
            }
        } else {
            if (percent >= root.zoomStartPercent) {
                nextDirection = 1
            } else if (percent >= -root.zoomStopPercent) {
                nextDirection = 0
            }
        }

        root.zoomDirection = nextDirection
    }

    function zoomStatus() {
        if (root.zoomDirection > 0) {
            return qsTr("ZOOM IN")
        }
        if (root.zoomDirection < 0) {
            return qsTr("ZOOM OUT")
        }
        return qsTr("STOP")
    }

    function axisLabel(index) {
        return index >= 0 ? "A" + index : qsTr("NONE")
    }

    function assignmentTargetLabel() {
        if (!ControllerInputManager.axisAssignmentActive) {
            return ""
        }
        return ControllerInputManager.axisAssignmentTarget === "tilt"
                ? qsTr("TILT")
                : qsTr("ZOOM")
    }

    function selectedButtonCurrentAction() {
        if (!root.hasController
                || root.selectedButtonIndex < 0
                || root.selectedButtonIndex >= ControllerInputManager.buttonCount) {
            return qsTr("No Action")
        }
        return ControllerInputManager.buttonAction(root.selectedButtonIndex)
    }

    function selectedButtonActionName() {
        var actions = ControllerInputManager.availableButtonActions
        if (!actions || actions.length === 0) {
            return qsTr("No Action")
        }

        var index = root.clamp(root.selectedButtonActionIndex, 0, actions.length - 1)
        return actions[index]
    }

    function syncSelectedButtonAction() {
        var actions = ControllerInputManager.availableButtonActions
        if (!actions || actions.length === 0) {
            root.selectedButtonActionIndex = 0
            return
        }

        var currentAction = root.selectedButtonCurrentAction()
        for (var i = 0; i < actions.length; ++i) {
            if (actions[i] === currentAction) {
                root.selectedButtonActionIndex = i
                return
            }
        }

        root.selectedButtonActionIndex = 0
    }

    function cycleSelectedButton(delta) {
        var count = ControllerInputManager.buttonCount
        if (count <= 0) {
            root.selectedButtonIndex = 0
            return
        }

        root.selectedButtonIndex = (root.selectedButtonIndex + delta + count) % count
        root.syncSelectedButtonAction()
    }

    function cycleSelectedButtonAction(delta) {
        var actions = ControllerInputManager.availableButtonActions
        if (!actions || actions.length === 0) {
            root.selectedButtonActionIndex = 0
            return
        }

        root.selectedButtonActionIndex = (root.selectedButtonActionIndex + delta + actions.length) % actions.length
    }

    function buttonActionForIndex(buttonIndex) {
        if (!root.hasController
                || buttonIndex < 0
                || buttonIndex >= ControllerInputManager.buttonCount) {
            return qsTr("No Action")
        }

        var actionName = String(ControllerInputManager.buttonAction(buttonIndex))
        return actionName.length > 0 ? actionName : qsTr("No Action")
    }

    function isNoButtonAction(actionName) {
        var value = String(actionName)
        return value.length === 0 || value === "No Action" || value === qsTr("No Action")
    }

    function buttonUsedByOtherRow(buttonIndex, rowIndex) {
        for (var i = 0; i < buttonMappingRows.count; ++i) {
            if (i !== rowIndex && buttonMappingRows.get(i).buttonIndex === buttonIndex) {
                return true
            }
        }
        return false
    }

    function nextUnusedButtonIndex() {
        for (var buttonIndex = 0; buttonIndex < ControllerInputManager.buttonCount; ++buttonIndex) {
            var used = false
            for (var rowIndex = 0; rowIndex < buttonMappingRows.count; ++rowIndex) {
                if (buttonMappingRows.get(rowIndex).buttonIndex === buttonIndex) {
                    used = true
                    break
                }
            }

            if (!used) {
                return buttonIndex
            }
        }

        return -1
    }

    function addButtonMappingRow() {
        var buttonIndex = root.nextUnusedButtonIndex()
        if (buttonIndex < 0) {
            return
        }

        buttonMappingRows.append({
            "buttonIndex": buttonIndex,
            "actionName": root.buttonActionForIndex(buttonIndex),
            "assignedButtonIndex": -1
        })
        root.keepPanelInBounds()
    }

    function ensureButtonMappingRows() {
        if (buttonMappingRows.count === 0 && root.hasController && ControllerInputManager.buttonCount > 0) {
            root.addButtonMappingRow()
        }
    }

    function rebuildButtonMappingRows() {
        buttonMappingRows.clear()

        if (!root.hasController || ControllerInputManager.buttonCount <= 0) {
            return
        }

        // Restore rows for mappings already persisted by the standard
        // joystick backend. This keeps the UI useful after QGC restart.
        for (var buttonIndex = 0; buttonIndex < ControllerInputManager.buttonCount; ++buttonIndex) {
            var actionName = root.buttonActionForIndex(buttonIndex)
            if (!root.isNoButtonAction(actionName)) {
                buttonMappingRows.append({
                    "buttonIndex": buttonIndex,
                    "actionName": actionName,
                    "assignedButtonIndex": buttonIndex
                })
            }
        }

        root.ensureButtonMappingRows()
    }

    function applyButtonMapping(rowIndex) {
        if (rowIndex < 0 || rowIndex >= buttonMappingRows.count) {
            return
        }

        var row = buttonMappingRows.get(rowIndex)
        var buttonIndex = row.buttonIndex
        var actionName = String(row.actionName)
        var previousButtonIndex = row.assignedButtonIndex

        if (buttonIndex < 0 || buttonIndex >= ControllerInputManager.buttonCount) {
            return
        }

        // If this row was previously assigned to a different button, move
        // the mapping instead of silently leaving the old assignment behind.
        if (previousButtonIndex >= 0 && previousButtonIndex !== buttonIndex) {
            ControllerInputManager.clearButtonAction(previousButtonIndex)
        }

        if (root.isNoButtonAction(actionName)) {
            ControllerInputManager.clearButtonAction(buttonIndex)
        } else {
            ControllerInputManager.setButtonAction(buttonIndex, actionName)
        }

        buttonMappingRows.setProperty(rowIndex, "assignedButtonIndex", buttonIndex)
    }

    function removeButtonMappingRow(rowIndex) {
        if (rowIndex < 0 || rowIndex >= buttonMappingRows.count) {
            return
        }

        var row = buttonMappingRows.get(rowIndex)
        var assignedButtonIndex = row.assignedButtonIndex

        // Removing a configured row also removes its persisted joystick action.
        if (assignedButtonIndex >= 0 && assignedButtonIndex < ControllerInputManager.buttonCount) {
            ControllerInputManager.clearButtonAction(assignedButtonIndex)
        }

        buttonMappingRows.remove(rowIndex)
        root.keepPanelInBounds()
    }

    function defaultPanelX() {
        return Math.max(root.margin, root.width - root.panelWidth - root.margin)
    }

    function defaultPanelY() {
        return root.topOffset
    }

    function currentPanelHeight() {
        return panel.height > 0 ? panel.height : headerHeight + panelPadding * 2
    }

    function boundedPanelPosition(x, y) {
        var maxX = Math.max(root.margin, root.width - root.panelWidth - root.margin)
        var maxY = Math.max(root.margin, root.height - root.currentPanelHeight() - root.margin)

        return {
            "x": root.clamp(x, root.margin, maxX),
            "y": root.clamp(y, root.margin, maxY)
        }
    }

    function setPanelPositionLocal(x, y) {
        if (root.width <= 0 || root.height <= 0) {
            return
        }

        var bounded = root.boundedPanelPosition(x, y)
        root.panelX = bounded.x
        root.panelY = bounded.y
        root.panelPositionReady = true
    }

    function initializePanelPosition() {
        if (root.width <= 0 || root.height <= 0) {
            return
        }

        if (!root.panelPositionReady) {
            root.setPanelPositionLocal(root.defaultPanelX(), root.defaultPanelY())
        }
    }

    function keepPanelInBounds() {
        if (!root.panelPositionReady || root.panelDragging || root.width <= 0 || root.height <= 0) {
            return
        }

        var bounded = root.boundedPanelPosition(root.panelX, root.panelY)
        root.panelX = bounded.x
        root.panelY = bounded.y
    }

    Connections {
        target: ControllerInputManager

        function onAxisValueChanged(changedIndex, value) {
            if (changedIndex === root.tiltAxis) {
                root.tiltRawValue = value
            }
            if (changedIndex === root.zoomAxis) {
                root.zoomRawValue = value
                root.updateZoomDirection(root.axisPercent(value))
            }
        }

        function onCameraAxisMappingsChanged() {
            root.tiltRawValue = ControllerInputManager.axisValue(root.tiltAxis)
            root.zoomRawValue = ControllerInputManager.axisValue(root.zoomAxis)
            root.zoomDirection = 0
            root.updateZoomDirection(root.zoomPercent)
        }

        function onActiveControllerChanged() {
            root.tiltRawValue = ControllerInputManager.axisValue(root.tiltAxis)
            root.zoomRawValue = ControllerInputManager.axisValue(root.zoomAxis)
            root.zoomDirection = 0
            root.updateZoomDirection(root.zoomPercent)
            root.selectedButtonIndex = 0
            root.syncSelectedButtonAction()
            root.rebuildButtonMappingRows()
        }

        function onButtonMappingsChanged() {
            root.syncSelectedButtonAction()
        }

        function onAvailableButtonActionsChanged() {
            root.syncSelectedButtonAction()
        }
    }

    Rectangle {
        id: panel

        visible: root.panelPositionReady
        x: root.panelX
        y: root.panelY
        z: 1200

        width: root.panelWidth
        height: panelColumn.implicitHeight + root.panelPadding * 2

        radius: 14
        color: root.panelColor
        border.width: 1
        border.color: root.panelDragging ? root.accentColor : root.panelBorderColor
        clip: true

        layer.enabled: root.panelDragging
        layer.smooth: false

        Behavior on height {
            NumberAnimation { duration: 120 }
        }

        onHeightChanged: root.keepPanelInBounds()

        Column {
            id: panelColumn
            x: root.panelPadding
            y: root.panelPadding
            width: parent.width - root.panelPadding * 2
            spacing: root.bodySpacing

            Rectangle {
                id: header
                width: parent.width
                height: root.headerHeight
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: !root.panelLocked
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: !root.panelLocked ? Qt.SizeAllCursor : Qt.ArrowCursor
                    preventStealing: true

                    function pointerInRoot(mouse) {
                        return mapToItem(root, mouse.x, mouse.y)
                    }

                    function applyPanelPosition(pointerPoint) {
                        var nextX = root.dragStartPanelX + pointerPoint.x - root.dragStartPointerX
                        var nextY = root.dragStartPanelY + pointerPoint.y - root.dragStartPointerY
                        var bounded = root.boundedPanelPosition(nextX, nextY)
                        root.panelX = bounded.x
                        root.panelY = bounded.y
                        root.panelPositionReady = true
                    }

                    onPressed: function(mouse) {
                        var pointerPoint = pointerInRoot(mouse)
                        root.panelDragging = true
                        root.dragStartPointerX = pointerPoint.x
                        root.dragStartPointerY = pointerPoint.y
                        root.dragStartPanelX = root.panelX
                        root.dragStartPanelY = root.panelY
                        mouse.accepted = true
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed || !root.panelDragging) {
                            return
                        }
                        applyPanelPosition(pointerInRoot(mouse))
                        mouse.accepted = true
                    }

                    onReleased: function(mouse) {
                        if (root.panelDragging) {
                            applyPanelPosition(pointerInRoot(mouse))
                        }
                        root.panelDragging = false
                        root.keepPanelInBounds()
                        mouse.accepted = true
                    }

                    onCanceled: {
                        root.panelDragging = false
                        root.keepPanelInBounds()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Label {
                            width: parent.width
                            text: qsTr("Controller")
                            color: root.textColor
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Label {
                            width: parent.width
                            text: root.hasController ? ControllerInputManager.activeControllerName : qsTr("No active controller")
                            color: root.secondaryTextColor
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        radius: 5
                        color: root.hasController ? root.activeColor : Qt.rgba(1, 1, 1, 0.25)
                    }

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 7
                        color: panelLocked ? root.buttonIdleColor : root.buttonActiveColor
                        border.width: 1
                        border.color: root.cardBorderColor

                        Text {
                            anchors.centerIn: parent
                            text: root.panelLocked ? "🔒" : "🔓"
                            color: root.textColor
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.panelLocked = !root.panelLocked
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 7
                        color: root.buttonIdleColor
                        border.width: 1
                        border.color: root.cardBorderColor

                        Text {
                            anchors.centerIn: parent
                            text: root.expanded ? "−" : "+"
                            color: root.textColor
                            font.pixelSize: 18
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expanded = !root.expanded
                        }
                    }
                }
            }

            Column {
                id: contentColumn
                visible: root.expanded
                width: parent.width
                spacing: root.bodySpacing

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 10
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: root.hasController ? root.activeColor : Qt.rgba(1, 1, 1, 0.25)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.hasController ? ControllerInputManager.activeControllerName : qsTr("No active controller")
                            color: root.hasController ? root.textColor : root.secondaryTextColor
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: root.hasController
                                  ? qsTr("%1 AX  ·  %2 BTN").arg(ControllerInputManager.axisCount).arg(ControllerInputManager.buttonCount)
                                  : ""
                            color: root.secondaryTextColor
                            font.pixelSize: 9
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    visible: root.hasController && root.hasVehicle
                    width: parent.width
                    height: 34
                    radius: 9
                    color: root.cameraControlsExpanded ? Qt.rgba(1, 1, 1, 0.08) : root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Camera Mapping")
                        color: root.textColor
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.cameraControlsExpanded ? "−" : "+"
                        color: root.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cameraControlsExpanded = !root.cameraControlsExpanded
                    }
                }

                Column {
                    visible: root.cameraControlsExpanded && root.hasController && root.hasVehicle
                    width: parent.width
                    spacing: 8

                    Text {
                        visible: ControllerInputManager.axisAssignmentActive
                        width: parent.width
                        text: qsTr("Move the desired axis for %1...").arg(root.assignmentTargetLabel())
                        color: root.accentColor
                        font.pixelSize: 9
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: parent.width
                        height: 88
                        radius: 10
                        color: root.cardColor
                        border.width: 1
                        border.color: ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "tilt"
                                      ? root.accentColor
                                      : root.cardBorderColor

                        Rectangle {
                            id: tiltBadge
                            x: 10
                            y: 10
                            width: 42
                            height: 24
                            radius: 6
                            color: Qt.rgba(0.66, 0.61, 1.0, 0.12)
                            border.width: 1
                            border.color: root.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: root.axisLabel(root.tiltAxis)
                                color: root.textColor
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            x: tiltBadge.x + tiltBadge.width + 10
                            anchors.verticalCenter: tiltBadge.verticalCenter
                            text: qsTr("TILT")
                            color: root.textColor
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            anchors.right: tiltAssignButton.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: tiltBadge.verticalCenter
                            text: root.tiltStatus(root.tiltPercent)
                            color: Math.abs(root.tiltPercent) <= root.tiltDeadzonePercent ? root.secondaryTextColor : root.activeColor
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Rectangle {
                            id: tiltAssignButton
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: tiltBadge.verticalCenter
                            width: 82
                            height: 26
                            radius: 7
                            color: ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "tilt"
                                   ? root.buttonPressedColor
                                   : root.buttonIdleColor
                            border.width: 1
                            border.color: root.cardBorderColor

                            Text {
                                anchors.centerIn: parent
                                text: ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "tilt"
                                      ? qsTr("CANCEL")
                                      : qsTr("ASSIGN")
                                color: root.textColor
                                font.pixelSize: 9
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "tilt") {
                                        ControllerInputManager.cancelAxisAssignment()
                                    } else {
                                        ControllerInputManager.beginAxisAssignment("tilt")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: tiltTrack
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16
                            height: 6
                            radius: 3
                            color: root.trackColor

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: 14
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }

                            Rectangle {
                                readonly property real centerX: parent.width / 2
                                readonly property real valueX: root.signedTrackPosition(root.tiltPercent) * parent.width
                                x: Math.min(centerX, valueX)
                                y: 1
                                width: Math.max(1, Math.abs(valueX - centerX))
                                height: parent.height - 2
                                radius: 2
                                color: root.accentColor
                                visible: Math.abs(root.tiltPercent) > root.tiltDeadzonePercent
                            }

                            Rectangle {
                                width: 8
                                height: 16
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(tiltTrack.width - width,
                                                        root.signedTrackPosition(root.tiltPercent) * (tiltTrack.width - width)))
                                color: root.accentColor
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 88
                        radius: 10
                        color: root.cardColor
                        border.width: 1
                        border.color: ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "zoom"
                                      ? root.accentColor
                                      : root.cardBorderColor

                        Rectangle {
                            id: zoomBadge
                            x: 10
                            y: 10
                            width: 42
                            height: 24
                            radius: 6
                            color: Qt.rgba(0.66, 0.61, 1.0, 0.12)
                            border.width: 1
                            border.color: root.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: root.axisLabel(root.zoomAxis)
                                color: root.textColor
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            x: zoomBadge.x + zoomBadge.width + 10
                            anchors.verticalCenter: zoomBadge.verticalCenter
                            text: qsTr("ZOOM")
                            color: root.textColor
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            anchors.right: zoomAssignButton.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: zoomBadge.verticalCenter
                            text: root.zoomStatus()
                            color: root.zoomDirection === 0 ? root.secondaryTextColor : root.activeColor
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Rectangle {
                            id: zoomAssignButton
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: zoomBadge.verticalCenter
                            width: 82
                            height: 26
                            radius: 7
                            color: ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "zoom"
                                   ? root.buttonPressedColor
                                   : root.buttonIdleColor
                            border.width: 1
                            border.color: root.cardBorderColor

                            Text {
                                anchors.centerIn: parent
                                text: ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "zoom"
                                      ? qsTr("CANCEL")
                                      : qsTr("ASSIGN")
                                color: root.textColor
                                font.pixelSize: 9
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (ControllerInputManager.axisAssignmentActive && ControllerInputManager.axisAssignmentTarget === "zoom") {
                                        ControllerInputManager.cancelAxisAssignment()
                                    } else {
                                        ControllerInputManager.beginAxisAssignment("zoom")
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.bottom: zoomTrack.top
                            anchors.bottomMargin: 4
                            text: root.zoomPercent + "%"
                            color: root.secondaryTextColor
                            font.pixelSize: 8
                        }

                        Rectangle {
                            id: zoomTrack
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16
                            height: 6
                            radius: 3
                            color: root.trackColor

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: 14
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }

                            Rectangle {
                                readonly property real centerX: parent.width / 2
                                readonly property real valueX: root.signedTrackPosition(root.zoomPercent) * parent.width
                                x: Math.min(centerX, valueX)
                                y: 1
                                width: Math.max(1, Math.abs(valueX - centerX))
                                height: parent.height - 2
                                radius: 2
                                color: root.accentColor
                                visible: root.zoomDirection !== 0
                            }

                            Rectangle {
                                width: 8
                                height: 16
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(zoomTrack.width - width,
                                                        root.signedTrackPosition(root.zoomPercent) * (zoomTrack.width - width)))
                                color: root.accentColor
                            }
                        }
                    }

                }

                Rectangle {
                    id: buttonMappingsHeader
                    visible: root.hasController && root.hasVehicle
                    width: parent.width
                    height: 34
                    radius: 9
                    color: root.buttonMappingsExpanded ? Qt.rgba(1, 1, 1, 0.08) : root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Button Mapping")
                        color: root.textColor
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.buttonMappingsExpanded ? "−" : "+"
                        color: root.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.buttonMappingsExpanded = !root.buttonMappingsExpanded
                    }
                }

                Column {
                    id: buttonMappingsColumn
                    visible: root.buttonMappingsExpanded && root.hasController && root.hasVehicle
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: buttonMappingRows

                        delegate: Rectangle {
                            id: mappingRow

                            property int rowIndex: index
                            property int selectedButton: buttonIndex
                            property string selectedAction: String(actionName)
                            property int assignedButton: assignedButtonIndex

                            width: buttonMappingsColumn.width
                            height: 48
                            radius: 10
                            color: root.cardColor
                            border.width: 1
                            border.color: root.cardBorderColor

                            Rectangle {
                                id: buttonSelector
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 56
                                height: 28
                                radius: 7
                                color: buttonSelectorArea.pressed
                                       ? root.buttonPressedColor
                                       : buttonSelectorArea.containsMouse || buttonSelectorPopup.opened
                                         ? root.buttonActiveColor
                                         : Qt.rgba(0.66, 0.61, 1.0, 0.12)
                                border.width: 1
                                border.color: buttonSelectorArea.containsMouse || buttonSelectorArea.pressed || buttonSelectorPopup.opened
                                              ? root.accentColor
                                              : root.accentColor

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 9
                                    anchors.right: buttonSelectorChevron.left
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "B" + mappingRow.selectedButton
                                    color: root.textColor
                                    font.pixelSize: 10
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    id: buttonSelectorChevron
                                    anchors.right: parent.right
                                    anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: buttonSelectorPopup.opened ? "▴" : "▾"
                                    color: root.secondaryTextColor
                                    font.pixelSize: 9
                                }

                                MouseArea {
                                    id: buttonSelectorArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (rowActionPopup.opened) {
                                            rowActionPopup.close()
                                        }

                                        if (buttonSelectorPopup.opened) {
                                            buttonSelectorPopup.close()
                                        } else {
                                            buttonSelectorPopup.open()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: rowActionSelector
                                x: buttonSelector.x + buttonSelector.width + 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 170
                                height: 28
                                radius: 7
                                color: rowActionSelectorArea.pressed
                                       ? root.buttonPressedColor
                                       : rowActionSelectorArea.containsMouse || rowActionPopup.opened
                                         ? root.buttonActiveColor
                                         : Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: rowActionSelectorArea.containsMouse || rowActionSelectorArea.pressed || rowActionPopup.opened
                                              ? root.accentColor
                                              : root.cardBorderColor

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: rowActionChevron.left
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: mappingRow.selectedAction
                                    color: root.textColor
                                    font.pixelSize: 9
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: rowActionChevron
                                    anchors.right: parent.right
                                    anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: rowActionPopup.opened ? "▴" : "▾"
                                    color: root.secondaryTextColor
                                    font.pixelSize: 9
                                }

                                MouseArea {
                                    id: rowActionSelectorArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (buttonSelectorPopup.opened) {
                                            buttonSelectorPopup.close()
                                        }

                                        if (rowActionPopup.opened) {
                                            rowActionPopup.close()
                                        } else {
                                            rowActionPopup.open()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: removeButtonMapping
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 28
                                radius: 7
                                color: removeButtonMappingArea.pressed
                                       ? Qt.rgba(1.0, 0.32, 0.32, 0.30)
                                       : removeButtonMappingArea.containsMouse
                                         ? Qt.rgba(1.0, 0.32, 0.32, 0.18)
                                         : root.buttonIdleColor
                                border.width: 1
                                border.color: removeButtonMappingArea.containsMouse || removeButtonMappingArea.pressed
                                              ? "#FF6B6B"
                                              : root.cardBorderColor

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: removeButtonMappingArea.containsMouse || removeButtonMappingArea.pressed
                                           ? "#FF8A8A"
                                           : root.secondaryTextColor
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                MouseArea {
                                    id: removeButtonMappingArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        buttonSelectorPopup.close()
                                        rowActionPopup.close()
                                        root.removeButtonMappingRow(mappingRow.rowIndex)
                                    }
                                }
                            }

                            Popup {
                                id: buttonSelectorPopup

                                // Popup coordinates are local to the mapping row. Keeping
                                // them local places the list directly under its selector.
                                x: buttonSelector.x
                                y: buttonSelector.y + buttonSelector.height + 4
                                width: 116
                                height: Math.min(184, buttonSelectorList.contentHeight + 10)
                                padding: 5
                                modal: false
                                focus: true
                                // The selector lives inside the popup parent (mappingRow), so
                                // pressing the selector again must not auto-close before our
                                // toggle handler runs. Clicks outside the row still close it.
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                background: Rectangle {
                                    radius: 8
                                    color: Qt.rgba(0.12, 0.13, 0.17, 0.98)
                                    border.width: 1
                                    border.color: root.cardBorderColor
                                }

                                contentItem: ListView {
                                    id: buttonSelectorList
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: ControllerInputManager.buttonCount
                                    spacing: 2

                                    ScrollBar.vertical: ScrollBar {
                                        policy: buttonSelectorList.contentHeight > buttonSelectorList.height
                                                ? ScrollBar.AlwaysOn
                                                : ScrollBar.AlwaysOff
                                    }

                                    delegate: Rectangle {
                                        id: buttonOption

                                        readonly property bool usedByOtherRow: root.buttonUsedByOtherRow(index, mappingRow.rowIndex)

                                        width: buttonSelectorList.width
                                        height: 28
                                        radius: 5
                                        opacity: usedByOtherRow ? 0.38 : 1.0
                                        color: buttonOptionArea.pressed && !usedByOtherRow
                                               ? root.buttonPressedColor
                                               : buttonOptionArea.containsMouse && !usedByOtherRow
                                                 ? root.buttonActiveColor
                                                 : (index === mappingRow.selectedButton
                                                    ? Qt.rgba(0.66, 0.61, 1.0, 0.14)
                                                    : "transparent")

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 9
                                            anchors.right: parent.right
                                            anchors.rightMargin: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: qsTr("Button %1").arg(index)
                                            color: root.textColor
                                            font.pixelSize: 9
                                            font.bold: index === mappingRow.selectedButton
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: buttonOptionArea
                                            anchors.fill: parent
                                            enabled: !buttonOption.usedByOtherRow
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                            onClicked: {
                                                buttonMappingRows.setProperty(mappingRow.rowIndex, "buttonIndex", index)
                                                root.applyButtonMapping(mappingRow.rowIndex)
                                                buttonSelectorPopup.close()
                                            }
                                        }
                                    }
                                }
                            }

                            Popup {
                                id: rowActionPopup

                                // Keep the list directly below the action selector.
                                x: rowActionSelector.x
                                y: rowActionSelector.y + rowActionSelector.height + 4
                                width: 184
                                height: Math.min(184, rowActionList.contentHeight + 10)
                                padding: 5
                                modal: false
                                focus: true
                                // The selector lives inside the popup parent (mappingRow), so
                                // pressing the selector again must not auto-close before our
                                // toggle handler runs. Clicks outside the row still close it.
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                background: Rectangle {
                                    radius: 8
                                    color: Qt.rgba(0.12, 0.13, 0.17, 0.98)
                                    border.width: 1
                                    border.color: root.cardBorderColor
                                }

                                contentItem: ListView {
                                    id: rowActionList
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: ControllerInputManager.availableButtonActions
                                    spacing: 2

                                    ScrollBar.vertical: ScrollBar {
                                        policy: rowActionList.contentHeight > rowActionList.height
                                                ? ScrollBar.AlwaysOn
                                                : ScrollBar.AlwaysOff
                                    }

                                    delegate: Rectangle {
                                        id: rowActionOption
                                        width: rowActionList.width
                                        height: 28
                                        radius: 5
                                        color: rowActionOptionArea.pressed
                                               ? root.buttonPressedColor
                                               : rowActionOptionArea.containsMouse
                                                 ? root.buttonActiveColor
                                                 : (String(modelData) === mappingRow.selectedAction
                                                    ? Qt.rgba(0.66, 0.61, 1.0, 0.14)
                                                    : "transparent")

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 9
                                            anchors.right: parent.right
                                            anchors.rightMargin: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: String(modelData)
                                            color: root.textColor
                                            font.pixelSize: 9
                                            font.bold: String(modelData) === mappingRow.selectedAction
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: rowActionOptionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                buttonMappingRows.setProperty(mappingRow.rowIndex, "actionName", String(modelData))
                                                root.applyButtonMapping(mappingRow.rowIndex)
                                                rowActionPopup.close()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 8
                        color: addButtonMappingArea.pressed
                               ? root.buttonPressedColor
                               : addButtonMappingArea.containsMouse
                                 ? root.buttonActiveColor
                                 : root.buttonIdleColor
                        border.width: 1
                        border.color: addButtonMappingArea.containsMouse || addButtonMappingArea.pressed
                                      ? root.accentColor
                                      : root.cardBorderColor
                        opacity: buttonMappingRows.count < ControllerInputManager.buttonCount ? 1.0 : 0.45

                        Behavior on color {
                            ColorAnimation { duration: 90 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: buttonMappingRows.count < ControllerInputManager.buttonCount
                                  ? qsTr("+  ADD BUTTON MAPPING")
                                  : qsTr("ALL BUTTONS ADDED")
                            color: root.secondaryTextColor
                            font.pixelSize: 9
                            font.bold: true
                        }

                        MouseArea {
                            id: addButtonMappingArea
                            anchors.fill: parent
                            enabled: buttonMappingRows.count < ControllerInputManager.buttonCount
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.addButtonMappingRow()
                        }
                    }
                }

                Rectangle {
                    id: rawInputsHeader
                    visible: root.hasController && root.hasVehicle
                    width: parent.width
                    height: 34
                    radius: 9
                    color: root.rawInputsExpanded ? Qt.rgba(1, 1, 1, 0.08) : root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Raw Inputs")
                        color: root.textColor
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Text {
                        anchors.right: rawToggleText.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hasController
                              ? qsTr("%1 AX  ·  %2 BTN").arg(ControllerInputManager.axisCount).arg(ControllerInputManager.buttonCount)
                              : ""
                        color: root.secondaryTextColor
                        font.pixelSize: 8
                    }

                    Text {
                        id: rawToggleText
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.rawInputsExpanded ? "−" : "+"
                        color: root.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rawInputsExpanded = !root.rawInputsExpanded
                    }
                }

                Column {
                    id: rawInputsColumn
                    visible: root.rawInputsExpanded && root.hasController && root.hasVehicle
                    x: 10
                    width: parent.width - 10
                    spacing: 6

                    Rectangle {
                        width: parent.width
                        height: 26
                        radius: 6
                        color: root.rawAxesExpanded ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.025)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.07)

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("AXES")
                            color: root.secondaryTextColor
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.rawAxesExpanded ? "−" : "+"
                            color: root.textColor
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.rawAxesExpanded = !root.rawAxesExpanded
                        }
                    }

                    Grid {
                        id: axisGrid
                        visible: root.rawAxesExpanded
                        width: parent.width
                        columns: 2
                        columnSpacing: 7
                        rowSpacing: 5

                        Repeater {
                            model: ControllerInputManager.axisCount

                            Rectangle {
                                id: axisRow
                                property int currentValue: ControllerInputManager.axisValue(index)
                                readonly property real normalizedSignedValue: root.normalizedAxisValue(currentValue)
                                readonly property real normalizedTrackValue: (normalizedSignedValue + 1.0) / 2.0

                                width: (axisGrid.width - axisGrid.columnSpacing) / 2
                                height: root.axisRowHeight
                                radius: 6
                                color: root.cardColor
                                border.width: 1
                                border.color: (index === root.tiltAxis || index === root.zoomAxis)
                                              ? root.accentColor
                                              : root.cardBorderColor

                                Text {
                                    id: axisLabelText
                                    anchors.left: parent.left
                                    anchors.leftMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    text: "A" + index
                                    color: (index === root.tiltAxis || index === root.zoomAxis) ? root.accentColor : root.textColor
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                Rectangle {
                                    id: axisTrack
                                    anchors.left: axisLabelText.right
                                    anchors.leftMargin: 4
                                    anchors.right: axisValueText.left
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: root.trackColor

                                    Rectangle {
                                        width: 1
                                        height: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Qt.rgba(1, 1, 1, 0.30)
                                    }

                                    Rectangle {
                                        width: 3
                                        height: 11
                                        radius: 1
                                        x: Math.max(0, Math.min(axisTrack.width - width,
                                                                axisRow.normalizedTrackValue * (axisTrack.width - width)))
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.accentColor
                                    }
                                }

                                Text {
                                    id: axisValueText
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40
                                    horizontalAlignment: Text.AlignRight
                                    text: root.axisPercent(axisRow.currentValue) + "%"
                                    color: root.secondaryTextColor
                                    font.pixelSize: 9
                                }

                                Connections {
                                    target: ControllerInputManager

                                    function onAxisValueChanged(changedIndex, value) {
                                        if (changedIndex === index) {
                                            axisRow.currentValue = value
                                        }
                                    }

                                    function onActiveControllerChanged() {
                                        axisRow.currentValue = ControllerInputManager.axisValue(index)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 26
                        radius: 6
                        color: root.rawButtonsExpanded ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.025)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.07)

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("BUTTONS")
                            color: root.secondaryTextColor
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.rawButtonsExpanded ? "−" : "+"
                            color: root.textColor
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.rawButtonsExpanded = !root.rawButtonsExpanded
                        }
                    }

                    Grid {
                        id: buttonGrid
                        visible: root.rawButtonsExpanded
                        width: parent.width
                        columns: 8
                        columnSpacing: 5
                        rowSpacing: 5

                        Repeater {
                            model: ControllerInputManager.buttonCount

                            Rectangle {
                                id: buttonCell
                                property bool pressed: ControllerInputManager.buttonPressed(index)

                                width: (buttonGrid.width - buttonGrid.columnSpacing * 7) / 8
                                height: root.buttonCellHeight
                                radius: 5
                                color: pressed ? root.activeColor : root.inactiveButtonColor
                                border.width: 1
                                border.color: pressed ? root.activeColor : root.cardBorderColor

                                Text {
                                    anchors.centerIn: parent
                                    text: index
                                    color: buttonCell.pressed ? "#111118" : root.textColor
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                Connections {
                                    target: ControllerInputManager

                                    function onButtonStateChanged(changedIndex, isPressed) {
                                        if (changedIndex === index) {
                                            buttonCell.pressed = isPressed
                                        }
                                    }

                                    function onActiveControllerChanged() {
                                        buttonCell.pressed = ControllerInputManager.buttonPressed(index)
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }

    Component.onCompleted: {
        root.initializePanelPosition()
        root.tiltRawValue = ControllerInputManager.axisValue(root.tiltAxis)
        root.zoomRawValue = ControllerInputManager.axisValue(root.zoomAxis)
        root.zoomDirection = 0
        root.updateZoomDirection(root.zoomPercent)
        root.selectedButtonIndex = 0
        root.syncSelectedButtonAction()
        root.rebuildButtonMappingRows()
    }

    onWidthChanged: {
        root.initializePanelPosition()
        root.keepPanelInBounds()
    }

    onHeightChanged: {
        root.initializePanelPosition()
        root.keepPanelInBounds()
    }

    onExpandedChanged: root.keepPanelInBounds()
    onCameraControlsExpandedChanged: root.keepPanelInBounds()
    onButtonMappingsExpandedChanged: root.keepPanelInBounds()
    onRawInputsExpandedChanged: root.keepPanelInBounds()
    onRawAxesExpandedChanged: root.keepPanelInBounds()
    onRawButtonsExpandedChanged: root.keepPanelInBounds()

    onTopOffsetChanged: {
        if (!root.panelPositionReady) {
            root.initializePanelPosition()
        }
    }
}
