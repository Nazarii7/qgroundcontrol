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
import QGroundControl.FlightDisplay

import "../Shared/Widget" as Shared

Item {
    id: root

    property real margin: 10
    // Keep the horizontal edge independently configurable. By default it
    // remains identical to margin, so existing placements are unchanged.
    property real leftMargin: margin
    property real topOffset: margin
    // Optional startup dock used by Fly View: place the panel immediately
    // above the bottom-left inset (the PiP map), while preserving dragging.
    property bool defaultAboveBottomInset: false
    property real bottomInset: 0
    property real bottomGap: margin
    property real panelWidth: 320
    // Cap the rendered width even when Fly View supplies its previous 320 px.
    property real maximumPanelWidth: 300
    property real maximumPanelHeight: 480
    readonly property real effectivePanelWidth: Math.max(1, Math.min(
        root.panelWidth, root.maximumPanelWidth,
        root.width - root.leftMargin - root.margin))
    readonly property real panelHeightLimit: Math.max(0, Math.min(
        root.maximumPanelHeight,
        root.height - root.margin * 2
        - (root.defaultAboveBottomInset && !root.panelManuallyPositioned
           ? Math.max(0, root.bottomInset) + root.bottomGap : 0)))
    property bool expanded: true

    // All movement state and drag lifecycle are shared with DropControlPanel.
    property alias panelLocked: panelState.locked
    property alias panelX: panelState.panelX
    property alias panelY: panelState.panelY
    readonly property bool panelPositionReady: panelState.ready
    readonly property bool panelDragging: panelState.dragging
    readonly property bool panelManuallyPositioned: panelState.manuallyPositioned
    property real collapsedWidth: 58
    readonly property real collapsedPanelHeight: 52

    WidgetPanelController {
        id: panelState

        enabled: root.visible && root.enabled && root.width > 0 && root.height > 0
        bounds: Qt.rect(root.leftMargin, root.margin,
                        Math.max(0, root.width - root.leftMargin - root.margin),
                        Math.max(0, root.height - root.margin * 2))
        panelSize: Qt.size(root.effectivePanelWidth, root.currentPanelHeight())
        defaultPosition: Qt.point(root.defaultPanelX(), root.defaultPanelY())
        followDefault: root.defaultAboveBottomInset
    }

    readonly property bool hasController: ControllerInputManager.activeControllerName.length > 0
    readonly property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool hasVehicle: controllerStatusModel.hasVehicle
    readonly property bool canEditMappings: controllerStatusModel.canEditMappings
    readonly property bool canEditButtonMappings: controllerStatusModel.canEditButtonMappings

    ControllerInputStatusModel {
        id: controllerStatusModel
        controllerConnected: root.hasController
        controllerName: ControllerInputManager.activeControllerName
        reportedAxisCount: ControllerInputManager.axisCount
        reportedButtonCount: ControllerInputManager.buttonCount
        activeVehicle: root.activeVehicle
        onSeverityChanged: {
            if (severity === "error" && bodyViewport) {
                bodyViewport.contentY = 0
            }
        }
    }

    Shared.WidgetPanelStyle { id: sharedPanelStyle }

    // Common chrome colors; controller-specific indicators remain local.
    readonly property color panelColor: sharedPanelStyle.panelBackground
    readonly property color panelBorderColor: sharedPanelStyle.panelBorder
    readonly property color cardColor: sharedPanelStyle.cardBackground
    readonly property color cardBorderColor: sharedPanelStyle.cardBorder
    readonly property color buttonIdleColor: sharedPanelStyle.buttonIdle
    readonly property color buttonActiveColor: sharedPanelStyle.buttonActive
    readonly property color buttonPressedColor: sharedPanelStyle.buttonPressed
    readonly property color accentColor: sharedPanelStyle.accentColor
    readonly property color activeColor: sharedPanelStyle.successText
    readonly property color warningColor: sharedPanelStyle.warningText
    readonly property color textColor: sharedPanelStyle.textPrimary
    readonly property color secondaryTextColor: sharedPanelStyle.textSecondary
    readonly property color tertiaryTextColor: sharedPanelStyle.textMuted
    readonly property color trackColor: sharedPanelStyle.trackBackground
    readonly property color inactiveButtonColor: sharedPanelStyle.inactiveButton

    readonly property int headerHeight: 42
    readonly property int panelPadding: 10
    readonly property int bodySpacing: 6
    readonly property int axisRowHeight: 26
    readonly property int buttonCellHeight: 24

    property bool cameraControlsExpanded: false
    property bool rawInputsExpanded: false
    property bool rawAxesExpanded: true
    property bool rawButtonsExpanded: false
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

    // Cache display names and search keys only when the existing backend list
    // changes. Typing never requests actions or writes joystick settings.
    readonly property var buttonActionSearchEntries: {
        var actions = ControllerInputManager.availableButtonActions || []
        var entries = []
        for (var i = 0; i < actions.length; ++i) {
            var name = String(actions[i])
            entries.push({ name: name, searchKey: name.toLowerCase() })
        }
        return entries
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
        if (root.defaultAboveBottomInset) {
            return root.leftMargin
        }

        return Math.max(root.margin, root.width - root.effectivePanelWidth - root.margin)
    }

    function defaultPanelY() {
        if (root.defaultAboveBottomInset) {
            return root.height
                    - root.bottomInset
                    - root.bottomGap
                    - root.currentPanelHeight()
        }

        return root.topOffset
    }

    function currentPanelHeight() {
        return root.expanded
                ? (panel.height > 0 ? panel.height : headerHeight + panelPadding * 2)
                : root.collapsedPanelHeight
    }

    // Retain the panel-specific docking policy; share geometry and movement.
    function boundedPanelPosition(x, y) {
        return panelState.boundedPosition(x, y)
    }

    function setPanelPositionLocal(x, y) {
        panelState.setPosition(x, y)
    }

    function initializePanelPosition() {
        panelState.initializePosition()
    }

    function refreshDefaultPanelPosition() {
        panelState.refreshDefaultPosition()
    }

    function keepPanelInBounds() {
        panelState.keepInBounds()
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
            if (root.canEditButtonMappings) {
                Qt.callLater(root.rebuildButtonMappingRows)
            }
        }
    }

    Shared.WidgetPanelSurface {
        id: panel
        objectName: "controllerPanelSurface"

        visible: root.expanded && root.panelPositionReady
        x: root.panelX
        y: root.panelY
        z: 1200

        width: root.effectivePanelWidth
        height: Math.min(root.panelHeightLimit,
                         root.panelPadding * 2 + root.headerHeight
                         + root.bodySpacing + contentColumn.implicitHeight)

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

        onHeightChanged: {
            root.refreshDefaultPanelPosition()
            root.keepPanelInBounds()
        }

        Column {
            id: panelColumn
            x: root.panelPadding
            y: root.panelPadding
            width: parent.width - root.panelPadding * 2
            spacing: root.bodySpacing

            Rectangle {
                id: header
                objectName: "controllerPanelHeader"
                width: parent.width
                height: root.headerHeight
                radius: 10
                color: sharedPanelStyle.headerBackground
                border.width: 1
                border.color: sharedPanelStyle.headerBorder

                Shared.WidgetPanelDragArea {
                    anchors.fill: parent
                    panelController: panelState
                    coordinateItem: root
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
                        color: root.hasController ? root.activeColor : sharedPanelStyle.inactiveIndicator
                    }

                    Shared.WidgetPanelActions {
                        panelController: panelState
                        coordinateItem: root
                        locked: root.panelLocked
                        idleColor: root.buttonIdleColor
                        activeColor: root.buttonActiveColor
                        pressedColor: root.buttonPressedColor
                        borderColor: root.cardBorderColor
                        textColor: root.textColor

                        onLockToggleRequested: root.panelLocked = !root.panelLocked
                        onCollapseRequested: root.expanded = false
                    }

                }
            }

            Flickable {
                id: bodyViewport
                objectName: "controllerBodyViewport"
                width: parent.width
                height: Math.max(0, panel.height - root.panelPadding * 2
                                 - root.headerHeight - root.bodySpacing)
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height && !root.panelDragging
                onContentHeightChanged: returnToBounds()
                onHeightChanged: returnToBounds()

                ScrollBar.vertical: ScrollBar {
                    width: 6
                    policy: bodyViewport.contentHeight > bodyViewport.height + 1
                            ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }

                Column {
                    id: contentColumn
                    visible: root.expanded
                    width: Math.max(0, bodyViewport.width - 8)
                    spacing: root.bodySpacing

                    ControllerInputStatusCard {
                        id: connectionStatus
                        width: parent.width
                        statusModel: controllerStatusModel
                        panelStyle: sharedPanelStyle
                    }

                    Rectangle {
                        objectName: "controllerCameraMappingHeader"
                        visible: root.hasController
                        enabled: root.canEditMappings
                        opacity: enabled ? 1.0 : 0.45
                        width: parent.width
                        height: 30
                        radius: 9
                        color: root.cameraControlsExpanded ? sharedPanelStyle.sectionExpandedBackground : root.cardColor
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
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.cameraControlsExpanded = !root.cameraControlsExpanded
                        }
                    }

                    Column {
                        objectName: "controllerCameraMappingColumn"
                        visible: root.cameraControlsExpanded && root.hasController
                        enabled: root.canEditMappings
                        opacity: enabled ? 1.0 : 0.45
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
                            height: 76
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
                                color: sharedPanelStyle.accentBackground
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
                                objectName: "tiltAssignButton"
                                enabled: root.canEditMappings
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
                                    color: sharedPanelStyle.trackMarker
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
                            height: 76
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
                                color: sharedPanelStyle.accentBackground
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
                                objectName: "zoomAssignButton"
                                enabled: root.canEditMappings
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
                                    color: sharedPanelStyle.trackMarker
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
                        objectName: "controllerButtonMappingHeader"
                        visible: root.hasController
                        enabled: root.canEditMappings
                        opacity: enabled ? 1.0 : 0.45
                        width: parent.width
                        height: 30
                        radius: 9
                        color: root.buttonMappingsExpanded ? sharedPanelStyle.sectionExpandedBackground : root.cardColor
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
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.buttonMappingsExpanded = !root.buttonMappingsExpanded
                        }
                    }

                    Text {
                        objectName: "controllerButtonMappingNotice"
                        visible: root.buttonMappingsExpanded && root.hasController && !root.canEditButtonMappings
                        width: parent.width
                        text: controllerStatusModel.buttonMappingMessage
                        color: controllerStatusModel.severity === "error"
                               ? sharedPanelStyle.dangerText : root.warningColor
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        id: buttonMappingsColumn
                        objectName: "controllerButtonMappingColumn"
                        visible: root.buttonMappingsExpanded && root.hasController
                        enabled: root.canEditButtonMappings
                        opacity: enabled ? 1.0 : 0.45
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
                                height: 42
                                radius: 10
                                color: root.cardColor
                                border.width: 1
                                border.color: root.cardBorderColor

                                Rectangle {
                                    id: buttonSelector
                                    objectName: "controllerButtonSelector"
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 56
                                    height: 28
                                    radius: 7
                                    color: buttonSelectorArea.pressed
                                           ? root.buttonPressedColor
                                           : buttonSelectorArea.containsMouse || buttonSelectorPopup.opened
                                             ? root.buttonActiveColor
                                             : sharedPanelStyle.accentBackground
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
                                    objectName: "controllerActionSelector"
                                    x: buttonSelector.x + buttonSelector.width + 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(60, removeButtonMapping.x - x - 6)
                                    height: 28
                                    radius: 7
                                    color: rowActionSelectorArea.pressed
                                           ? root.buttonPressedColor
                                           : rowActionSelectorArea.containsMouse || rowActionPopup.opened
                                             ? root.buttonActiveColor
                                             : sharedPanelStyle.cardBackground
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
                                           ? sharedPanelStyle.dangerPressedBackground
                                           : removeButtonMappingArea.containsMouse
                                             ? sharedPanelStyle.dangerHoverBackground
                                             : root.buttonIdleColor
                                    border.width: 1
                                    border.color: removeButtonMappingArea.containsMouse || removeButtonMappingArea.pressed
                                                  ? sharedPanelStyle.dangerBorder
                                                  : root.cardBorderColor

                                    Behavior on color {
                                        ColorAnimation { duration: 90 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: removeButtonMappingArea.containsMouse || removeButtonMappingArea.pressed
                                               ? sharedPanelStyle.dangerText
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
                                    objectName: "controllerButtonSelectorPopup"
                                    enabled: root.canEditButtonMappings
                                    onEnabledChanged: { if (!enabled) close() }

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
                                        color: sharedPanelStyle.popupBackground
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
                                                        ? sharedPanelStyle.accentBackground
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
                                    objectName: "controllerActionSelectorPopup"
                                    enabled: root.canEditButtonMappings && root.buttonMappingsExpanded
                                             && root.expanded && root.visible && root.enabled
                                    onEnabledChanged: { if (!enabled) close() }

                                    property var filteredActions: []
                                    property point selectorInOverlay: Qt.point(0, 0)
                                    readonly property real windowWidth: Overlay.overlay ? Overlay.overlay.width : root.width
                                    readonly property real windowHeight: Overlay.overlay ? Overlay.overlay.height : root.height
                                    readonly property real spaceBelow: Math.max(0, windowHeight - 8
                                        - selectorInOverlay.y - rowActionSelector.height - 4)
                                    readonly property real spaceAbove: Math.max(0, selectorInOverlay.y - 12)
                                    readonly property real preferredHeight: Math.min(228,
                                        48 + Math.max(32, root.buttonActionSearchEntries.length * 30))

                                    // Fit above a low row, and keep the search field inside the
                                    // window. The popup height stays stable while filtering.
                                    x: rowActionSelector.x + Math.max(8, Math.min(selectorInOverlay.x,
                                        windowWidth - width - 8)) - selectorInOverlay.x
                                    y: rowActionSelector.y + (spaceBelow >= height || spaceBelow >= spaceAbove
                                        ? rowActionSelector.height + 4 : -height - 4)
                                    width: Math.min(220, Math.max(1, windowWidth - 16))
                                    height: Math.min(preferredHeight, Math.max(spaceAbove, spaceBelow))
                                    padding: 5
                                    modal: false
                                    focus: true
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                    function updateAnchor() {
                                        selectorInOverlay = rowActionSelector.mapToItem(Overlay.overlay, 0, 0)
                                    }

                                    function filterActions() {
                                        var query = rowActionSearch.text.trim().toLowerCase()
                                        var tokens = query.length > 0 ? query.split(/\s+/) : []
                                        var matches = []
                                        var entries = root.buttonActionSearchEntries
                                        for (var i = 0; i < entries.length; ++i) {
                                            var matchesAll = true
                                            for (var t = 0; t < tokens.length; ++t) {
                                                if (entries[i].searchKey.indexOf(tokens[t]) < 0) {
                                                    matchesAll = false
                                                    break
                                                }
                                            }
                                            if (matchesAll) {
                                                matches.push(entries[i].name)
                                            }
                                        }
                                        filteredActions = matches
                                        var selected = query.length === 0
                                                ? matches.indexOf(mappingRow.selectedAction) : -1
                                        rowActionList.currentIndex = matches.length > 0 ? Math.max(0, selected) : -1
                                        rowActionList.positionViewAtIndex(rowActionList.currentIndex, ListView.Contain)
                                    }

                                    function flushSearch() {
                                        if (actionSearchDelay.running) {
                                            actionSearchDelay.stop()
                                            filterActions()
                                        }
                                    }

                                    function moveHighlight(delta) {
                                        flushSearch()
                                        if (filteredActions.length > 0) {
                                            rowActionList.currentIndex = Math.max(0, Math.min(
                                                filteredActions.length - 1, rowActionList.currentIndex + delta))
                                            rowActionList.positionViewAtIndex(rowActionList.currentIndex, ListView.Contain)
                                        }
                                    }

                                    function chooseAction(index) {
                                        if (!visible || !enabled || actionSearchDelay.running
                                                || index < 0 || index >= filteredActions.length) {
                                            return
                                        }
                                        // The result is an original action name, never a filtered
                                        // index into the backend list. Only explicit selection saves.
                                        buttonMappingRows.setProperty(mappingRow.rowIndex, "actionName", filteredActions[index])
                                        root.applyButtonMapping(mappingRow.rowIndex)
                                        close()
                                    }

                                    onAboutToShow: {
                                        actionSearchDelay.stop()
                                        rowActionSearch.clear()
                                        filterActions()
                                        updateAnchor()
                                    }
                                    onOpened: rowActionSearch.forceActiveFocus()
                                    onAboutToHide: actionSearchDelay.stop()
                                    onClosed: {
                                        actionSearchDelay.stop()
                                        rowActionSearch.clear()
                                        filteredActions = []
                                    }

                                    Timer {
                                        id: actionSearchDelay
                                        objectName: "controllerActionSearchDelay"
                                        interval: 150
                                        repeat: false
                                        onTriggered: rowActionPopup.filterActions()
                                    }

                                    Connections {
                                        target: bodyViewport
                                        function onContentYChanged() {
                                            if (rowActionPopup.visible) rowActionPopup.updateAnchor()
                                        }
                                    }
                                    Connections {
                                        target: Overlay.overlay
                                        function onWidthChanged() {
                                            if (rowActionPopup.visible) rowActionPopup.updateAnchor()
                                        }
                                        function onHeightChanged() {
                                            if (rowActionPopup.visible) rowActionPopup.updateAnchor()
                                        }
                                    }

                                    background: Rectangle {
                                        radius: 8
                                        color: sharedPanelStyle.popupBackground
                                        border.width: 1
                                        border.color: root.cardBorderColor
                                    }

                                    contentItem: Item {
                                        TextField {
                                            id: rowActionSearch
                                            objectName: "controllerActionSearchField"
                                            anchors.top: parent.top
                                            width: parent.width
                                            height: 32
                                            placeholderText: qsTr("Search actions...")
                                            color: root.textColor
                                            placeholderTextColor: root.secondaryTextColor
                                            selectionColor: root.accentColor
                                            selectedTextColor: root.trackColor
                                            font.pixelSize: 11
                                            leftPadding: 8
                                            rightPadding: actionSearchClear.visible ? 30 : 8
                                            selectByMouse: true
                                            inputMethodHints: Qt.ImhNoPredictiveText
                                            Accessible.name: qsTr("Search button actions")

                                            background: Rectangle {
                                                radius: 5
                                                color: root.trackColor
                                                border.width: 1
                                                border.color: rowActionSearch.activeFocus ? root.accentColor : root.cardBorderColor
                                            }

                                            onTextChanged: {
                                                if (!rowActionPopup.visible) return
                                                if (text.trim().length === 0) {
                                                    actionSearchDelay.stop()
                                                    rowActionPopup.filterActions()
                                                } else {
                                                    actionSearchDelay.restart()
                                                }
                                            }
                                            Keys.onDownPressed: rowActionPopup.moveHighlight(1)
                                            Keys.onUpPressed: rowActionPopup.moveHighlight(-1)
                                            Keys.onEscapePressed: rowActionPopup.close()
                                            onAccepted: {
                                                rowActionPopup.flushSearch()
                                                rowActionPopup.chooseAction(rowActionList.currentIndex)
                                            }

                                            ToolButton {
                                                id: actionSearchClear
                                                objectName: "controllerActionSearchClear"
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 28
                                                height: 28
                                                visible: rowActionSearch.text.length > 0
                                                focusPolicy: Qt.NoFocus
                                                Accessible.name: qsTr("Clear action search")
                                                contentItem: Text {
                                                    text: "×"
                                                    color: root.secondaryTextColor
                                                    font.pixelSize: 18
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                background: Rectangle {
                                                    radius: 4
                                                    color: actionSearchClear.down ? root.buttonPressedColor
                                                        : actionSearchClear.hovered ? root.buttonActiveColor : "transparent"
                                                }
                                                onClicked: {
                                                    rowActionSearch.clear()
                                                    rowActionSearch.forceActiveFocus()
                                                }
                                            }
                                        }

                                        ListView {
                                            id: rowActionList
                                            objectName: "controllerActionSearchResults"
                                            anchors.top: rowActionSearch.bottom
                                            anchors.topMargin: 6
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            clip: true
                                            boundsBehavior: Flickable.StopAtBounds
                                            model: rowActionPopup.filteredActions
                                            spacing: 2
                                            enabled: !actionSearchDelay.running
                                            opacity: enabled ? 1.0 : 0.5

                                            ScrollBar.vertical: ScrollBar {
                                                policy: rowActionList.contentHeight > rowActionList.height
                                                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                            }

                                            delegate: Rectangle {
                                                id: rowActionOption
                                                objectName: "controllerActionSearchOption" + index
                                                width: rowActionList.width
                                                height: 28
                                                radius: 5
                                                color: rowActionOptionArea.pressed ? root.buttonPressedColor
                                                    : rowActionOptionArea.containsMouse ? root.buttonActiveColor
                                                    : index === rowActionList.currentIndex
                                                      || String(modelData) === mappingRow.selectedAction
                                                      ? sharedPanelStyle.accentBackground : "transparent"

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 9
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 16
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: String(modelData)
                                                    color: root.textColor
                                                    font.pixelSize: 10
                                                    font.bold: String(modelData) === mappingRow.selectedAction
                                                    elide: Text.ElideRight
                                                }
                                                MouseArea {
                                                    id: rowActionOptionArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: rowActionPopup.chooseAction(index)
                                                }
                                            }
                                        }

                                        Text {
                                            objectName: "controllerActionSearchEmpty"
                                            anchors.fill: rowActionList
                                            visible: rowActionList.count === 0 && !actionSearchDelay.running
                                            text: qsTr("No actions found")
                                            color: root.secondaryTextColor
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            wrapMode: Text.WordWrap
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
                        objectName: "controllerRawInputsHeader"
                        visible: root.hasController
                        width: parent.width
                        height: 30
                        radius: 9
                        color: root.rawInputsExpanded ? sharedPanelStyle.sectionExpandedBackground : root.cardColor
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
                        objectName: "controllerRawInputsColumn"
                        visible: root.rawInputsExpanded && root.hasController
                        x: 10
                        width: parent.width - 10
                        spacing: 6

                        Rectangle {
                            width: parent.width
                            height: 26
                            radius: 6
                            color: root.rawAxesExpanded ? sharedPanelStyle.subsectionExpandedBackground : sharedPanelStyle.subsectionBackground
                            border.width: 1
                            border.color: sharedPanelStyle.cardBorder

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
                            objectName: "controllerRawAxisGrid"
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
                                            color: sharedPanelStyle.trackMarker
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
                            color: root.rawButtonsExpanded ? sharedPanelStyle.subsectionExpandedBackground : sharedPanelStyle.subsectionBackground
                            border.width: 1
                            border.color: sharedPanelStyle.cardBorder

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                text: controllerStatusModel.projectProfileActive
                                      ? qsTr("BUTTONS  ·  %1/%2").arg(controllerStatusModel.configuredButtonCount).arg(ControllerInputManager.buttonCount)
                                      : qsTr("BUTTONS")
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

                        Text {
                            objectName: "controllerButtonProfileLabel"
                            visible: root.rawButtonsExpanded && controllerStatusModel.projectProfileActive
                            width: parent.width
                            text: qsTr("%1 preset · outlined = configured").arg(controllerStatusModel.projectControllerProfile.label)
                            color: root.secondaryTextColor
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }

                        Grid {
                            id: buttonGrid
                            objectName: "controllerRawButtonGrid"
                            visible: root.rawButtonsExpanded
                            width: parent.width
                            columns: 8
                            columnSpacing: 5
                            rowSpacing: 5

                            Repeater {
                                model: ControllerInputManager.buttonCount

                                Rectangle {
                                    id: buttonCell
                                    objectName: "controllerRawButton" + index
                                    property bool pressed: ControllerInputManager.buttonPressed(index)
                                    readonly property bool configuredInProfile: controllerStatusModel.isButtonConfigured(index)
                                    readonly property bool profileHighlighted: controllerStatusModel.projectProfileActive && configuredInProfile

                                    width: (buttonGrid.width - buttonGrid.columnSpacing * 7) / 8
                                    height: root.buttonCellHeight
                                    radius: 5
                                    // A real press always wins, including on a button outside the preset.
                                    // The preset affects presentation only, never incoming USB events.
                                    opacity: pressed || configuredInProfile ? 1.0 : 0.28
                                    color: pressed ? root.activeColor : root.inactiveButtonColor
                                    border.width: 1
                                    border.color: pressed ? root.activeColor
                                                         : profileHighlighted ? root.accentColor : root.cardBorderColor
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: controllerStatusModel.buttonDescription(index)
                                                     + (pressed ? qsTr(" - pressed") : "")
                                    ToolTip.visible: buttonHover.containsMouse
                                    ToolTip.delay: 400
                                    ToolTip.text: controllerStatusModel.buttonDescription(index)

                                    MouseArea {
                                        id: buttonHover
                                        anchors.fill: parent
                                        acceptedButtons: Qt.NoButton
                                        hoverEnabled: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: index
                                        color: buttonCell.pressed ? sharedPanelStyle.badgeTextColor : root.textColor
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
    }

    Shared.WidgetCollapsedHandle {
        visible: !root.expanded && root.panelPositionReady
        x: root.panelX + root.effectivePanelWidth - root.collapsedWidth
        y: root.panelY
        z: 1200

        collapsedWidth: root.collapsedWidth
        collapsedPanelHeight: root.collapsedPanelHeight
        panelController: panelState
        coordinateItem: root
        badgeText: controllerStatusModel.severity === "error" || controllerStatusModel.severity === "warning" ? "!" : ""
        badgeColor: connectionStatus.statusColor
        expandToolTip: qsTr("Controller: %1").arg(controllerStatusModel.title)

        onExpandRequested: root.expanded = true
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
        root.refreshDefaultPanelPosition()
        root.keepPanelInBounds()
    }

    onHeightChanged: {
        root.initializePanelPosition()
        root.refreshDefaultPanelPosition()
        root.keepPanelInBounds()
    }

    // Re-read persisted mappings only after the vehicle-dependent backend is
    // available. Losing the link keeps the existing rows visible and disabled.
    onCanEditButtonMappingsChanged: {
        if (root.canEditButtonMappings) {
            Qt.callLater(function() {
                if (root.canEditButtonMappings) {
                    root.rebuildButtonMappingRows()
                }
            })
        }
    }

    // Configuration needs the same live-vehicle prerequisite in both sections.
    // Cancel a pending learn operation so it cannot complete after link loss.
    onCanEditMappingsChanged: {
        if (!root.canEditMappings) {
            if (ControllerInputManager.axisAssignmentActive) {
                ControllerInputManager.cancelAxisAssignment()
            }
            root.cameraControlsExpanded = false
            root.buttonMappingsExpanded = false
            bodyViewport.contentY = 0
        }
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

    onLeftMarginChanged: root.refreshDefaultPanelPosition()
    onBottomInsetChanged: root.refreshDefaultPanelPosition()
    onBottomGapChanged: root.refreshDefaultPanelPosition()
    onDefaultAboveBottomInsetChanged: root.refreshDefaultPanelPosition()
}
