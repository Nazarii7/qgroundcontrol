import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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

    property real panelX: Math.max(0, control.width - panelWidth - margin)
    property real panelY: topOffset

    readonly property bool hasAvailableServos: availableServoCount > 0
    readonly property bool hasDropOrderSection: hasAvailableServos && activeDropCount > 1

    property bool dropModeSectionOpen: true
    property bool dropOrderSectionOpen: true
    property bool availableChannelsSectionOpen: true

    readonly property real settingsSectionHeaderHeight: 28
    readonly property real settingsPopupMaxHeight: 400

    readonly property real availableChannelsContentHeight: availableServoCount > 0
                                                         ? Math.max(settingsRowHeight, availableServoCount * (settingsRowHeight + 6) - 6)
                                                         : 0

    readonly property real availableChannelsMaxHeight: hasDropOrderSection && dropOrderSectionOpen ? 165 : 235

    readonly property real availableChannelsListHeight: availableChannelsSectionOpen
                                                      ? Math.min(availableChannelsMaxHeight, availableChannelsContentHeight)
                                                      : 0

    readonly property real settingsPopupContentHeight: settingsPopupContent.implicitHeight + 20
    readonly property real settingsPopupHeight: settingsOpen
                                               ? Math.min(settingsPopupMaxHeight, settingsPopupContentHeight)
                                               : 0
    readonly property real holdButtonHeight: 44
    readonly property real bodySpacing: 10
    readonly property real bodyHeight: bodyContent.implicitHeight
    readonly property real expandedPanelHeight: 24 + headerHeight + bodySpacing + bodyHeight
    readonly property real collapsedPanelHeight: 52

    signal visibilityToggleRequested(int rowIndex)
    signal settingsOpenChangedFromUi(bool open)
    signal panelExpandedChangedFromUi(bool expanded)
    signal panelPositionChangedFromUi(real x, real y)
    signal holdPressed()
    signal holdReleased()
    signal dropModeChangedFromUi(int mode)
    signal sequenceOrderMoveRequested(int servoNumber, int direction)

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
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

        const delta = wheelDeltaToPixels(event)

        if (delta === 0) {
            event.accepted = true
            return
        }

        const maxContentY = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = clamp(flick.contentY - delta, 0, maxContentY)
        event.accepted = true
    }

    Rectangle {
        id: dropPanel
        visible: control.panelExpanded
        x: control.panelX
        y: control.panelY
        width: control.panelWidth
        height: control.expandedPanelHeight
        radius: 14
        color: Qt.rgba(0.08, 0.10, 0.13, 0.90)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

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

                    property real pressXInRoot: 0
                    property real pressYInRoot: 0
                    property real startPanelX: 0
                    property real startPanelY: 0

                    onPressed: function(mouse) {
                        const p = dragArea.mapToItem(control, mouse.x, mouse.y)
                        pressXInRoot = p.x
                        pressYInRoot = p.y
                        startPanelX = control.panelX
                        startPanelY = control.panelY
                        mouse.accepted = true
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed || control.panelLocked) {
                            return
                        }

                        const p = dragArea.mapToItem(control, mouse.x, mouse.y)
                        const dx = p.x - pressXInRoot
                        const dy = p.y - pressYInRoot

                        const maxX = Math.max(control.margin, control.width - dropPanel.width - control.margin)
                        const maxY = Math.max(control.margin, control.height - dropPanel.height - control.margin)

                        control.panelX = clamp(startPanelX + dx, control.margin, maxX)
                        control.panelY = clamp(startPanelY + dy, control.margin, maxY)

                        mouse.accepted = true
                    }

                    onReleased: function(mouse) {
                        control.panelPositionChangedFromUi(control.panelX, control.panelY)
                        mouse.accepted = true
                    }

                    onCanceled: {
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

                    Rectangle {
                        id: lockButton
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 7
                        color: lockButtonArea.pressed ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Label {
                            anchors.centerIn: parent
                            text: control.panelLocked ? "🔒" : "🔓"
                            color: "white"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: lockButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: control.panelLocked = !control.panelLocked
                        }
                    }

                    Rectangle {
                        id: settingsButton
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 7
                        color: settingsButtonArea.pressed
                               ? Qt.rgba(1, 1, 1, 0.20)
                               : (control.settingsOpen ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                        border.width: 1
                        border.color: control.settingsOpen ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.10)

                        Label {
                            anchors.centerIn: parent
                            text: "\u2699"
                            color: control.settingsOpen ? Qt.rgba(1, 1, 1, 1.0) : Qt.rgba(1, 1, 1, 0.85)
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MouseArea {
                            id: settingsButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: control.settingsOpenChangedFromUi(!control.settingsOpen)
                        }
                    }

                    Rectangle {
                        id: collapseButton
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 7
                        color: collapseButtonArea.pressed ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Label {
                            anchors.centerIn: parent
                            text: "−"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MouseArea {
                            id: collapseButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: control.panelExpandedChangedFromUi(false)
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

                    Column {
                        id: settingsPopupContent

                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        DropModeSelector {
                            id: dropModeSelector

                            width: parent.width
                            visible: control.hasAvailableServos
                            height: visible ? implicitHeight : 0

                            sectionOpen: control.dropModeSectionOpen
                            currentMode: control.dropMode

                            onSectionToggleRequested: {
                                control.dropModeSectionOpen = !control.dropModeSectionOpen
                            }

                            onModeSelected: function(mode) {
                                control.dropModeChangedFromUi(mode)
                            }
                        }

                        DropSequenceEditor {
                            id: dropSequenceEditor

                            width: parent.width
                            visible: control.hasDropOrderSection
                            height: visible ? implicitHeight : 0

                            enabled: !control.holdActive
                            opacity: enabled ? 1.0 : 0.45

                            sectionOpen: control.dropOrderSectionOpen
                            orderedTargets: control.sequenceOrderedTargets

                            onSectionToggleRequested: {
                                control.dropOrderSectionOpen = !control.dropOrderSectionOpen
                            }

                            onMoveRequested: function(servoNumber, direction) {
                                control.sequenceOrderMoveRequested(servoNumber, direction)
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: control.settingsSectionHeaderHeight
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Label {
                                    Layout.fillWidth: true
                                    text: "Available servo channels"
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Item {
                                    visible: control.hasAvailableServos

                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 24

                                    Label {
                                        anchors.centerIn: parent
                                        text: control.availableChannelsSectionOpen ? "−" : "+"
                                        color: "white"
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: availableChannelsGearArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            control.availableChannelsSectionOpen = !control.availableChannelsSectionOpen
                                        }
                                    }
                                }
                            }
                        }

                        Label {
                           visible: control.availableServoCount <= 0
                            width: parent.width
                            text: "No available channels. Connect vehicle and wait for parameters."
                            color: Qt.rgba(1, 1, 1, 0.62)
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }

                        Flickable {
                            id: settingsFlick
                            visible: control.availableServoCount > 0 && control.availableChannelsSectionOpen
                            width: parent.width
                            height: visible ? control.availableChannelsListHeight : 0
                            clip: true
                            contentWidth: width
                            contentHeight: settingsColumn.implicitHeight

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                onWheel: function(event) {
                                    control.scrollFlickable(settingsFlick, event)
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: settingsColumn.implicitHeight > settingsFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            }

                            Column {
                                id: settingsColumn
                                width: settingsFlick.width
                                spacing: 6

                                Repeater {
                                    model: control.dropModel

                                    delegate: Item {
                                        required property int index
                                        required property int servoNumber
                                        required property bool active
                                        required property bool servoAvailable
                                        required property string availabilityText

                                        width: settingsColumn.width
                                        height: servoAvailable ? control.settingsRowHeight : 0
                                        visible: servoAvailable
                                        opacity: servoAvailable ? 1.0 : 0.0

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 7
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.08)

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 10

                                                Column {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 1

                                                    Label {
                                                        text: "SERVO " + servoNumber
                                                        color: "white"
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }

                                                    Label {
                                                        text: "Available"
                                                        color: Qt.rgba(0.55, 1.0, 0.62, 0.80)
                                                        font.pixelSize: 9
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                }

                                                Item {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    Layout.preferredWidth: 18
                                                    Layout.preferredHeight: 18
                                                    CheckBox {
                                                        id: visibleCheck

                                                        anchors.fill: parent
                                                        padding: 0
                                                        spacing: 0

                                                        checked: active && servoAvailable
                                                        enabled: servoAvailable
                                                        opacity: servoAvailable ? 1.0 : 0.35

                                                        indicator: Rectangle {
                                                            width: 16
                                                            height: 16
                                                            anchors.centerIn: parent

                                                            radius: 2
                                                            border.width: 1
                                                            border.color: Qt.rgba(1, 1, 1, 0.35)

                                                            color: visibleCheck.checked
                                                                   ? Qt.rgba(1, 1, 1, 0.95)
                                                                   : Qt.rgba(1, 1, 1, 0.08)

                                                            Rectangle {
                                                                width: 8
                                                                height: 8
                                                                anchors.centerIn: parent

                                                                radius: 1
                                                                visible: visibleCheck.checked
                                                                color: Qt.rgba(0.08, 0.10, 0.13, 1.0)
                                                            }
                                                        }

                                                        contentItem: Item { }

                                                        onClicked: {
                                                            control.visibilityToggleRequested(index)
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
                }

                Rectangle {
                    id: dropStepInfo
                    width: parent.width
                    height: 30
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    visible: control.activeDropCount > 0

                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: control.holdActive && control.currentDropLabel.length > 0
                              ? control.currentDropLabel
                              : control.nextDropLabel
                        color: control.holdActive
                               ? Qt.rgba(1, 1, 1, 0.95)
                               : Qt.rgba(1, 1, 1, 0.72)
                        font.pixelSize: 10
                        font.bold: control.holdActive
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: holdButton
                    width: parent.width
                    height: control.holdButtonHeight
                    radius: 10
                    enabled: control.activeDropCount > 0
                    opacity: enabled ? 1.0 : 0.45
                    color: control.holdActive
                           ? Qt.rgba(0.42, 0.08, 0.08, 0.95)
                           : Qt.rgba(0.10, 0.34, 0.14, 0.95)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)

                    Behavior on color {
                        ColorAnimation { duration: 160 }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: control.holdActive ? "RELEASE TO CLOSE" : "HOLD TO DROP"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    MouseArea {
                        id: holdButtonArea
                        anchors.fill: parent
                        enabled: holdButton.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onPressed: function(mouse) {
                            control.holdPressed()
                            mouse.accepted = true
                        }

                        onReleased: function(mouse) {
                            control.holdReleased()
                            mouse.accepted = true
                        }

                        onCanceled: {
                            control.holdReleased()
                        }
                    }
                }

                Rectangle {
                    id: rowsViewport
                    width: parent.width
                    height: rowsColumn.implicitHeight
                    radius: 9
                    color: "transparent"
                    border.width: 0
                    visible: control.activeDropCount > 0

                    Column {
                        id: rowsColumn
                        width: rowsViewport.width
                        spacing: 0

                        Repeater {
                            model: control.dropModel

                            delegate: Item {
                                required property int index
                                required property int servoNumber
                                required property bool active
                                required property bool isOpen
                                required property bool busy
                                required property bool servoAvailable
                                required property string availabilityText

                                width: rowsViewport.width
                                height: active && servoAvailable ? control.rowAnimatedHeight : 0
                                opacity: active && servoAvailable ? 1.0 : 0.0
                                visible: height > 0 || opacity > 0

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 240
                                        easing.type: Easing.InOutCubic
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 180 }
                                }

                                DropControlRow {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top

                                    rowIndex: index
                                    titleText: control.dropTitleProvider ? control.dropTitleProvider(servoNumber) : ("DROP " + index)
                                    subtitleText: "SERVO " + servoNumber
                                    rowHeight: control.rowHeight
                                    rowAnimatedHeight: control.rowAnimatedHeight
                                    rowActive: active
                                    rowIsOpen: isOpen
                                    rowBusy: busy
                                    rowAvailable: servoAvailable
                                    rowUnavailableText: availabilityText
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (useSavedPanelPosition && savedPanelX >= 0 && savedPanelY >= 0) {
            panelX = savedPanelX
            panelY = savedPanelY
        }
    }

    Rectangle {
        id: collapsedHandle
        visible: !control.panelExpanded
        x: control.panelX + (control.panelWidth - collapsedWidth)
        y: control.panelY
        width: control.collapsedWidth
        height: control.collapsedPanelHeight
        radius: 10
        color: Qt.rgba(0.08, 0.10, 0.13, 0.90)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

        Rectangle {
            anchors.centerIn: parent
            width: 34
            height: 28
            radius: 7
            color: Qt.rgba(0.05, 0.07, 0.10, 0.95)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)

            Label {
                anchors.centerIn: parent
                text: "+"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: control.panelExpandedChangedFromUi(true)
            }
        }
    }
}
