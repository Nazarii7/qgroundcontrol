import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    property bool panelLocked: true
    property bool holdActive: false

    property int dropMode: 0
    property int dropModeAll: 0
    property int dropModeGroups: 1
    property int dropModeIndividual: 2

    property string currentDropLabel: ""
    property string nextDropLabel: "Next: All selected"
    property var sequenceOrderedTargets: []

    property bool useSavedPanelPosition: false
    property real savedPanelX: -1
    property real savedPanelY: -1

    property real panelX: -1
    property real panelY: -1

    property bool panelPositionReady: false
    property bool panelPositionChangedByUser: false

    readonly property bool hasValidSavedPanelPosition: useSavedPanelPosition && savedPanelX >= 0 && savedPanelY >= 0

    property bool panelDragging: false
    property real dragStartPointerX: 0
    property real dragStartPointerY: 0
    property real dragStartPanelX: 0
    property real dragStartPanelY: 0

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

    function boundedPanelPosition(x, y) {
        var maxX = Math.max(
                    control.margin,
                    control.width - control.panelWidth - control.margin
                    )

        var maxY = Math.max(
                    control.margin,
                    control.height - control.currentPanelHeight() - control.margin
                    )

        return {
            "x": control.clamp(x, control.margin, maxX),
            "y": control.clamp(y, control.margin, maxY)
        }
    }

    function setPanelPositionLocal(x, y) {
        if (control.width <= 0 || control.height <= 0) {
            return
        }

        var bounded = control.boundedPanelPosition(x, y)

        control.panelX = bounded.x
        control.panelY = bounded.y
        control.panelPositionReady = true
    }

    function initializePanelPosition() {
        if (control.width <= 0 || control.height <= 0) {
            return
        }

        if (control.hasValidSavedPanelPosition && !control.panelPositionChangedByUser) {
            control.setPanelPositionLocal(control.savedPanelX, control.savedPanelY)
            return
        }

        if (!control.panelPositionReady) {
            control.setPanelPositionLocal(control.defaultPanelX(), control.defaultPanelY())
        }
    }

    function keepPanelInBounds() {
        if (!control.panelPositionReady || control.panelDragging || control.width <= 0 || control.height <= 0) {
            return
        }

        var bounded = control.boundedPanelPosition(control.panelX, control.panelY)

        if (bounded.x === control.panelX && bounded.y === control.panelY) {
            return
        }

        control.panelX = bounded.x
        control.panelY = bounded.y
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

        if (sectionName === "dropMode") {
            shouldOpen = !control.dropModeSectionOpen
        } else if (sectionName === "dropOrder") {
            shouldOpen = !control.dropOrderSectionOpen
        } else if (sectionName === "pwm") {
            shouldOpen = !control.pwmSectionOpen
        } else if (sectionName === "availableChannels") {
            shouldOpen = !control.availableChannelsSectionOpen
        }

        control.dropModeSectionOpen = false
        control.dropOrderSectionOpen = false
        control.pwmSectionOpen = false
        control.availableChannelsSectionOpen = false

        if (!shouldOpen) {
            return
        }

        if (sectionName === "dropMode") {
            control.dropModeSectionOpen = true
        } else if (sectionName === "dropOrder") {
            control.dropOrderSectionOpen = true
        } else if (sectionName === "pwm") {
            control.pwmSectionOpen = true
        } else if (sectionName === "availableChannels") {
            control.availableChannelsSectionOpen = true
        }
    }

    Rectangle {
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
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: !control.panelLocked
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: !control.panelLocked ? Qt.SizeAllCursor : Qt.ArrowCursor
                    preventStealing: true

                    function pointerInControl(mouse) {
                        return mapToItem(control, mouse.x, mouse.y)
                    }

                    function applyPanelPosition(pointerPoint) {
                        var nextX = control.dragStartPanelX + pointerPoint.x - control.dragStartPointerX
                        var nextY = control.dragStartPanelY + pointerPoint.y - control.dragStartPointerY

                        var bounded = control.boundedPanelPosition(nextX, nextY)

                        control.panelX = bounded.x
                        control.panelY = bounded.y
                        control.panelPositionReady = true
                    }

                    onPressed: function(mouse) {
                        var pointerPoint = pointerInControl(mouse)

                        control.panelDragging = true
                        control.dragStartPointerX = pointerPoint.x
                        control.dragStartPointerY = pointerPoint.y
                        control.dragStartPanelX = control.panelX
                        control.dragStartPanelY = control.panelY

                        mouse.accepted = true
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed || !control.panelDragging) {
                            return
                        }

                        applyPanelPosition(pointerInControl(mouse))
                        mouse.accepted = true
                    }

                    onReleased: function(mouse) {
                        if (control.panelDragging) {
                            applyPanelPosition(pointerInControl(mouse))
                        }

                        control.panelDragging = false
                        control.panelPositionChangedByUser = true
                        control.panelPositionChangedFromUi(control.panelX, control.panelY)

                        mouse.accepted = true
                    }

                    onCanceled: {
                        control.panelDragging = false
                        control.panelPositionChangedByUser = true
                        control.panelPositionChangedFromUi(control.panelX, control.panelY)
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
                            text: "Drops"
                            color: "white"
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Label {
                            text: control.activeDropCount > 0
                                  ? (control.activeDropCount + " selected")
                                  : "No selected channels"
                            color: Qt.rgba(1, 1, 1, 0.62)
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    DropIconButton {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28

                        text: control.panelLocked ? "🔒" : "🔓"
                        textSize: 14

                        idleColor: style.buttonIdle
                        activeColor: style.buttonActive
                        pressedColor: style.buttonPressed
                        borderColor: style.buttonBorder
                        textColor: style.textPrimary

                        onClicked: {
                            control.panelLocked = !control.panelLocked
                        }
                    }

                    DropIconButton {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28

                        text: "\u2699"
                        textSize: 16
                        active: control.settingsOpen

                        idleColor: style.buttonIdle
                        activeColor: style.buttonActive
                        pressedColor: style.buttonPressed
                        borderColor: control.settingsOpen ? Qt.rgba(1, 1, 1, 0.28) : style.buttonBorder
                        textColor: control.settingsOpen ? style.textPrimary : Qt.rgba(1, 1, 1, 0.85)

                        onClicked: {
                            control.settingsOpenChangedFromUi(!control.settingsOpen)
                        }
                    }

                    DropIconButton {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28

                        text: "−"
                        textSize: 16

                        idleColor: style.buttonIdle
                        activeColor: style.buttonActive
                        pressedColor: style.buttonPressed
                        borderColor: style.buttonBorder
                        textColor: style.textPrimary

                        onClicked: {
                            control.panelExpandedChangedFromUi(false)
                        }
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
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
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

                            DropModeSelector {
                                width: parent.width
                                visible: control.availableServoCount > 0
                                currentMode: control.dropMode
                                sectionOpen: control.dropModeSectionOpen

                                onModeSelected: function(mode) {
                                    control.dropModeChangedFromUi(mode)
                                }

                                onSectionToggleRequested: {
                                    control.toggleSettingsSection("dropMode")
                                }
                            }

                            DropSequenceEditor {
                                width: parent.width
                                visible: control.activeDropCount > 1
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
                    canDrop: control.activeDropCount > 0

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

    DropCollapsedHandle {
        visible: !control.panelExpanded && control.panelPositionReady

        x: control.panelX + (control.panelWidth - control.collapsedWidth)
        y: control.panelY

        collapsedWidth: control.collapsedWidth
        collapsedPanelHeight: control.collapsedPanelHeight

        onExpandRequested: {
            control.panelExpandedChangedFromUi(true)
        }
    }
}
