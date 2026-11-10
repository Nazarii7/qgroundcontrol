import QtQuick

Grid {
    id: actions

    property int orientation: Qt.Horizontal
    property var panelController: null
    property Item coordinateItem: null
    property bool locked: panelController ? Boolean(panelController.locked) : true
    property bool settingsVisible: false
    property bool settingsOpen: false
    property bool settingsEnabled: true
    property bool lockEnabled: true
    property bool collapseEnabled: true
    property real buttonWidth: style.buttonWidth
    property real buttonHeight: style.buttonHeight
    property color idleColor: style.buttonIdle
    property color activeColor: style.buttonActive
    property color pressedColor: style.buttonPressed
    property color borderColor: style.buttonBorder
    property color textColor: style.textPrimary

    signal lockToggleRequested()
    signal settingsToggleRequested()
    signal collapseRequested()

    WidgetPanelStyle { id: style }

    columns: orientation === Qt.Vertical ? 1 : (settingsVisible ? 3 : 2)
    spacing: style.buttonSpacing

    // Keep settings before the adjacent lock and collapse buttons in both axes.
    WidgetIconButton {
        objectName: "widgetSettingsButton"
        visible: actions.settingsVisible
        enabledState: actions.settingsEnabled
        width: actions.buttonWidth
        height: actions.buttonHeight
        text: "\u2699"
        textSize: 16
        toolTip: qsTr("Widget settings")
        active: actions.settingsOpen
        idleColor: actions.idleColor
        activeColor: actions.activeColor
        pressedColor: actions.pressedColor
        borderColor: actions.borderColor
        textColor: actions.textColor
        onClicked: actions.settingsToggleRequested()
    }

    WidgetIconButton {
        objectName: "widgetLockButton"
        enabledState: actions.lockEnabled
        width: actions.buttonWidth
        height: actions.buttonHeight
        lockIndicator: true
        locked: actions.locked
        active: !actions.locked
        dragController: actions.panelController
        coordinateItem: actions.coordinateItem
        toolTip: actions.locked ? qsTr("Unlock widget position")
                               : qsTr("Drag to move; click to lock")
        idleColor: actions.idleColor
        activeColor: actions.activeColor
        pressedColor: actions.pressedColor
        borderColor: actions.borderColor
        textColor: actions.textColor
        onClicked: actions.lockToggleRequested()
    }

    WidgetIconButton {
        objectName: "widgetCollapseButton"
        enabledState: actions.collapseEnabled
        width: actions.buttonWidth
        height: actions.buttonHeight
        text: "\u2212"
        textSize: 16
        toolTip: qsTr("Collapse widget")
        idleColor: actions.idleColor
        activeColor: actions.activeColor
        pressedColor: actions.pressedColor
        borderColor: actions.borderColor
        textColor: actions.textColor
        onClicked: actions.collapseRequested()
    }
}
