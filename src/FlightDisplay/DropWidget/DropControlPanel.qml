import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.FlightDisplay
import "../Shared/Widget" as Shared

import "controls"
import "style"
import "ui"

Item {
    id: control

    property var dropModel
    property var paletteObject
    property var dropTitleProvider

    property real panelWidth: 320
    property real collapsedWidth: 58
    property real margin: 12
    property real topOffset: 12

    property real headerHeight: 46
    property real rowHeight: 54
    property real rowAnimatedHeight: 58
    property real settingsRowHeight: 30

    property int activeDropCount: 0
    property int availableServoCount: 0
    property bool settingsOpen: false
    property bool panelExpanded: true
    property alias panelLocked: panelState.locked
    property bool holdActive: false

    property int dropMode: 0
    property int dropModeAll: 0
    property int dropModeGroups: 1
    property int dropModeIndividual: 2

    property int controlBehavior: 0
    property int controlBehaviorStandard: 0
    property int controlBehaviorStepAndHold: 1
    property int controlBehaviorSynchronizedPair: 2
    property bool dropModeEditingEnabled: true
    property bool canDrop: activeDropCount > 0
    property bool showPhysicalPositionWhenIdle: false
    property string configurationMessage: ""
    property string holdButtonIdleText: "HOLD TO DROP"
    property string holdButtonActiveText: "RELEASE TO CLOSE"

    property string currentDropLabel: ""
    property string nextDropLabel: "Next: All selected"
    property var sequenceOrderedTargets: []

    property bool useSavedPanelPosition: false
    property real savedPanelX: -1
    property real savedPanelY: -1

    property alias panelX: panelState.panelX
    property alias panelY: panelState.panelY
    readonly property bool panelPositionReady: panelState.ready
    readonly property bool panelPositionChangedByUser: panelState.manuallyPositioned
    readonly property bool panelDragging: panelState.dragging

    readonly property bool hasValidSavedPanelPosition: useSavedPanelPosition && savedPanelX >= 0 && savedPanelY >= 0

    WidgetPanelController {
        id: panelState

        enabled: control.visible && control.enabled && control.width > 0 && control.height > 0
        bounds: Qt.rect(control.margin, control.margin,
                        Math.max(0, control.width - control.margin * 2),
                        Math.max(0, control.height - control.margin * 2))
        panelSize: Qt.size(control.panelWidth, control.currentPanelHeight())
        defaultPosition: Qt.point(control.defaultPanelX(), control.defaultPanelY())
        savedPosition: Qt.point(control.savedPanelX, control.savedPanelY)
        useSavedPosition: control.hasValidSavedPanelPosition

        onPositionCommitted: function(x, y) {
            control.panelPositionChangedFromUi(x, y)
        }
    }

    property bool controlBehaviorSectionOpen: false
    property bool dropModeSectionOpen: false
    property bool dropOrderSectionOpen: false
    property bool pwmSectionOpen: false
    property bool availableChannelsSectionOpen: false

    readonly property real holdButtonHeight: 44
    readonly property real bodySpacing: 10
    readonly property real bodyHeight: bodyContent.implicitHeight
    readonly property real settingsPopupHeight: settingsOpen ? Math.min(Math.max(settingsColumn.implicitHeight + 20, 168), Math.max(220, control.height - 180)) : 0
    readonly property real expandedPanelHeight: Math.min(24 + headerHeight + bodySpacing + bodyHeight, Math.max(200, control.height - margin * 2))
    readonly property real collapsedPanelHeight: 52

    signal visibilityToggleRequested(int rowIndex)
    signal settingsOpenChangedFromUi(bool open)
    signal panelExpandedChangedFromUi(bool expanded)
    signal panelPositionChangedFromUi(real x, real y)
    signal holdPressed()
    signal holdReleased()

    signal controlBehaviorChangedFromUi(int behavior)
    signal dropModeChangedFromUi(int mode)
    signal sequenceOrderMoveRequested(int servoNumber, int direction)

    signal servoClosedPwmChanged(int rowIndex, int pwmValue)
    signal servoOpenPositionPwmChanged(int rowIndex, int positionIndex, int pwmValue)
    signal servoOpenPositionAddRequested(int rowIndex)
    signal servoOpenPositionRemoveRequested(int rowIndex, int positionIndex)
    signal servoPwmResetRequested(int rowIndex)

    DropStyle {
        id: style
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function currentPanelHeight() {
        return control.panelExpanded
               ? control.expandedPanelHeight
               : control.collapsedPanelHeight
    }

    function defaultPanelX() {
        return Math.max(control.margin, control.width - control.panelWidth - control.margin)
    }

    function defaultPanelY() {
        return control.topOffset
    }

    // Compatibility entry points delegate to the shared presentation controller.
    function boundedPanelPosition(x, y) {
        return panelState.boundedPosition(x, y)
    }

    function setPanelPositionLocal(x, y) {
        panelState.setPosition(x, y)
    }

    function initializePanelPosition() {
        panelState.initializePosition()
    }

    function keepPanelInBounds() {
        panelState.keepInBounds()
    }

    function wheelDeltaToPixels(event) {
        if (event.pixelDelta && event.pixelDelta.y !== 0) {
            return event.pixelDelta.y
        }

        if (event.angleDelta && event.angleDelta.y !== 0) {
            return event.angleDelta.y / 120 * 40
        }

        return 0
    }

    function scrollFlickable(flick, event) {
        if (!flick || flick.contentHeight <= flick.height) {
            event.accepted = true
            return
        }

        var delta = wheelDeltaToPixels(event)

        if (delta === 0) {
            event.accepted = true
            return
        }

        var maxContentY = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = clamp(flick.contentY - delta, 0, maxContentY)
        event.accepted = true
    }

    function toggleSettingsSection(sectionName) {
        var shouldOpen = false

        if (sectionName === "controlBehavior") {
            shouldOpen = !control.controlBehaviorSectionOpen
        } else if (sectionName === "dropMode") {
            shouldOpen = !control.dropModeSectionOpen
        } else if (sectionName === "dropOrder") {
            shouldOpen = !control.dropOrderSectionOpen
        } else if (sectionName === "pwm") {
            shouldOpen = !control.pwmSectionOpen
        } else if (sectionName === "availableChannels") {
            shouldOpen = !control.availableChannelsSectionOpen
        }

        control.controlBehaviorSectionOpen = false
        control.dropModeSectionOpen = false
        control.dropOrderSectionOpen = false
        control.pwmSectionOpen = false
        control.availableChannelsSectionOpen = false

        if (!shouldOpen) {
            return
        }

        if (sectionName === "controlBehavior") {
            control.controlBehaviorSectionOpen = true
        } else if (sectionName === "dropMode") {
            control.dropModeSectionOpen = true
        } else if (sectionName === "dropOrder") {
            control.dropOrderSectionOpen = true
        } else if (sectionName === "pwm") {
            control.pwmSectionOpen = true
        } else if (sectionName === "availableChannels") {
            control.availableChannelsSectionOpen = true
        }
    }

    Shared.WidgetPanelSurface {
        id: dropPanel
        visible: control.panelExpanded && control.panelPositionReady
        x: control.panelX
        y: control.panelY
        width: control.panelWidth
        height: control.expandedPanelHeight
        radius: style.panelRadius
        color: style.panelBackground
        border.width: 1
        border.color: style.panelBorder
        clip: true

        layer.enabled: control.panelDragging
        layer.smooth: false

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: control.bodySpacing

            Rectangle {
                id: header
                width: parent.width
                height: control.headerHeight
                radius: 10
                color: style.headerBackground
                border.width: 1
                border.color: style.cardBorder

                Shared.WidgetPanelDragArea {
                    anchors.fill: parent
                    panelController: panelState
                    coordinateItem: control
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
                            text: "Drops"
                            color: style.textPrimary
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Label {
                            text: control.activeDropCount > 0
                                  ? (control.activeDropCount + " selected")
                                  : "No selected channels"
                            color: style.textSecondary
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Shared.WidgetPanelActions {
                        panelController: panelState
                        coordinateItem: control
                        locked: control.panelLocked
                        settingsVisible: true
                        settingsOpen: control.settingsOpen

                        onLockToggleRequested: control.panelLocked = !control.panelLocked
                        onSettingsToggleRequested: control.settingsOpenChangedFromUi(!control.settingsOpen)
                        onCollapseRequested: control.panelExpandedChangedFromUi(false)
                    }

                }
            }

            Column {
                id: bodyContent
                width: parent.width
                spacing: control.bodySpacing

                Rectangle {
                    id: settingsPopup
                    width: parent.width
                    height: control.settingsPopupHeight
                    radius: 9
                    color: style.cardBackground
                    border.width: 1
                    border.color: style.cardBorder
                    opacity: control.settingsOpen ? 1.0 : 0.0
                    clip: true
                    visible: height > 0 || opacity > 0
                    enabled: !control.panelDragging

                    Flickable {
                        id: settingsFlick
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: width
                        contentHeight: settingsColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                            onWheel: function(event) {
                                control.scrollFlickable(settingsFlick, event)
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                        }

                        Column {
                            id: settingsColumn
                            width: settingsFlick.width
                            spacing: 8

                            Column {
                                width: parent.width
                                spacing: 6
                                visible: control.availableServoCount > 0

                                RowLayout {
                                    width: parent.width
                                    height: 28
                                    spacing: 8

                                    Label {
                                        Layout.fillWidth: true
                                        text: "Control behavior"
                                        color: style.textPrimary
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Item {
                                        Layout.preferredWidth: 20
                                        Layout.preferredHeight: 24

                                        Label {
                                            anchors.centerIn: parent
                                            text: control.controlBehaviorSectionOpen ? "−" : "+"
                                            color: style.textPrimary
                                            font.pixelSize: 18
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                control.toggleSettingsSection("controlBehavior")
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    visible: control.controlBehaviorSectionOpen
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { label: "Standard", value: control.controlBehaviorStandard },
                                            { label: "Step & Hold", value: control.controlBehaviorStepAndHold },
                                            { label: "Synchronized Pair", value: control.controlBehaviorSynchronizedPair }
                                        ]

                                        delegate: Rectangle {
                                            width: parent.width
                                            height: 30
                                            radius: 8
                                            color: control.controlBehavior === modelData.value
                                                   ? style.successBackground
                                                   : style.buttonIdle
                                            border.width: 1
                                            border.color: control.controlBehavior === modelData.value
                                                          ? style.successBorder
                                                          : style.buttonBorder
                                            opacity: control.holdActive ? 0.45 : 1.0

                                            Label {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: style.textPrimary
                                                font.pixelSize: 10
                                                font.bold: control.controlBehavior === modelData.value
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !control.holdActive
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    control.controlBehaviorChangedFromUi(modelData.value)
                                                }
                                            }
                                        }
                                    }

                                    Label {
                                        width: parent.width
                                        text: control.configurationMessage
                                        color: control.canDrop
                                               ? style.successText
                                               : style.warningText
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            DropModeSelector {
                                width: parent.width
                                visible: control.availableServoCount > 0
                                currentMode: control.dropMode
                                sectionOpen: control.dropModeSectionOpen
                                enabled: control.dropModeEditingEnabled
                                opacity: enabled ? 1.0 : 0.45

                                onModeSelected: function(mode) {
                                    control.dropModeChangedFromUi(mode)
                                }

                                onSectionToggleRequested: {
                                    control.toggleSettingsSection("dropMode")
                                }
                            }

                            DropSequenceEditor {
                                width: parent.width
                                visible: control.activeDropCount > 1 && control.dropModeEditingEnabled
                                orderedTargets: control.sequenceOrderedTargets
                                sectionOpen: control.dropOrderSectionOpen

                                onMoveRequested: function(servoNumber, direction) {
                                    control.sequenceOrderMoveRequested(servoNumber, direction)
                                }

                                onSectionToggleRequested: {
                                    control.toggleSettingsSection("dropOrder")
                                }
                            }

                            DropPwmPositionEditor {
                                width: parent.width
                                visible: control.activeDropCount > 0
                                dropModel: control.dropModel
                                dropTitleProvider: control.dropTitleProvider
                                sectionOpen: control.pwmSectionOpen
                                editingLocked: control.holdActive

                                onSectionToggleRequested: {
                                    control.toggleSettingsSection("pwm")
                                }

                                onClosedPwmChanged: function(rowIndex, pwmValue) {
                                    control.servoClosedPwmChanged(rowIndex, pwmValue)
                                }

                                onOpenPositionPwmChanged: function(rowIndex, positionIndex, pwmValue) {
                                    control.servoOpenPositionPwmChanged(rowIndex, positionIndex, pwmValue)
                                }

                                onOpenPositionAddRequested: function(rowIndex) {
                                    control.servoOpenPositionAddRequested(rowIndex)
                                }

                                onOpenPositionRemoveRequested: function(rowIndex, positionIndex) {
                                    control.servoOpenPositionRemoveRequested(rowIndex, positionIndex)
                                }

                                onPwmResetRequested: function(rowIndex) {
                                    control.servoPwmResetRequested(rowIndex)
                                }
                            }

                            DropAvailableServoList {
                                width: parent.width

                                dropModel: control.dropModel
                                availableServoCount: control.availableServoCount
                                settingsRowHeight: control.settingsRowHeight
                                sectionOpen: control.availableChannelsSectionOpen

                                onSectionToggleRequested: {
                                    control.toggleSettingsSection("availableChannels")
                                }

                                onVisibilityToggleRequested: function(rowIndex) {
                                    control.visibilityToggleRequested(rowIndex)
                                }
                            }
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: control.activeDropCount > 0 && control.controlBehavior !== control.controlBehaviorStandard
                    text: control.configurationMessage
                    color: control.canDrop
                           ? style.successText
                           : style.warningText
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }

                DropCurrentNextLabel {
                    width: parent.width

                    activeDropCount: control.activeDropCount
                    holdActive: control.holdActive
                    currentDropLabel: control.currentDropLabel
                    nextDropLabel: control.nextDropLabel
                }

                DropHoldButton {
                    width: parent.width

                    buttonHeight: control.holdButtonHeight
                    holdActive: control.holdActive
                    canDrop: control.canDrop
                    idleText: control.holdButtonIdleText
                    activeText: control.holdButtonActiveText

                    onHoldPressed: {
                        control.holdPressed()
                    }

                    onHoldReleased: {
                        control.holdReleased()
                    }
                }

                DropActiveRowsList {
                    width: parent.width

                    dropModel: control.dropModel
                    dropTitleProvider: control.dropTitleProvider
                    orderedTargets: control.sequenceOrderedTargets

                    activeDropCount: control.activeDropCount
                    rowHeight: control.rowHeight
                    rowAnimatedHeight: control.rowAnimatedHeight
                    showPhysicalPositionWhenIdle: control.showPhysicalPositionWhenIdle
                }
            }
        }
    }

    Component.onCompleted: {
        control.initializePanelPosition()
    }

    onWidthChanged: {
        control.initializePanelPosition()
        control.keepPanelInBounds()
    }

    onHeightChanged: {
        control.initializePanelPosition()
        control.keepPanelInBounds()
    }

    onExpandedPanelHeightChanged: {
        control.keepPanelInBounds()
    }

    onPanelExpandedChanged: {
        control.initializePanelPosition()
        control.keepPanelInBounds()
    }

    onUseSavedPanelPositionChanged: {
        control.initializePanelPosition()
        control.keepPanelInBounds()
    }

    onSavedPanelXChanged: {
        control.initializePanelPosition()
        control.keepPanelInBounds()
    }

    onSavedPanelYChanged: {
        control.initializePanelPosition()
        control.keepPanelInBounds()
    }

    Shared.WidgetCollapsedHandle {
        visible: !control.panelExpanded && control.panelPositionReady

        x: control.panelX + (control.panelWidth - control.collapsedWidth)
        y: control.panelY

        collapsedWidth: control.collapsedWidth
        collapsedPanelHeight: control.collapsedPanelHeight
        panelController: panelState
        coordinateItem: control

        onExpandRequested: {
            control.panelExpandedChangedFromUi(true)
        }
    }
}
