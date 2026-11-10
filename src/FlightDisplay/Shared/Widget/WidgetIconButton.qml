import QtQuick
import QtQuick.Controls

Rectangle {
    id: button

    property string text: ""
    property string toolTip: ""
    property bool active: false
    property bool enabledState: true
    property bool lockIndicator: false
    property bool locked: true
    property color idleColor: style.buttonIdle
    property color activeColor: style.buttonActive
    property color pressedColor: style.buttonPressed
    property color borderColor: style.buttonBorder
    property color textColor: style.textPrimary
    property color lockColor: style.lockColor
    property int textSize: 14
    property var dragController: null
    property Item coordinateItem: null
    property real dragThreshold: style.dragThreshold
    readonly property bool acceptsDrag: dragController !== null && coordinateItem !== null
    readonly property bool hovered: tapArea.containsMouse || moveArea.containsMouse
    readonly property bool pressed: tapArea.pressed || moveArea.pressed

    signal clicked()

    WidgetPanelStyle { id: style }

    implicitWidth: style.buttonWidth
    implicitHeight: style.buttonHeight
    width: implicitWidth
    height: implicitHeight
    radius: style.buttonRadius
    enabled: enabledState
    opacity: enabled ? 1.0 : 0.45
    activeFocusOnTab: true
    color: pressed ? pressedColor : active ? activeColor : idleColor
    border.width: 1
    border.color: activeFocus ? style.focusBorder : borderColor

    Accessible.role: Accessible.Button
    Accessible.name: toolTip.length > 0 ? toolTip : text
    Accessible.onPressAction: { if (button.enabled) button.clicked() }

    // Keep toolTip as the accessible button name and compatibility API.
    // Hover hints are intentionally not displayed for shared widget controls.

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
        }
    }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat && button.enabled) button.clicked()
            event.accepted = true
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !button.lockIndicator
        text: button.text
        color: button.textColor
        font.pixelSize: button.textSize
        font.bold: true
    }

    // Native QML geometry keeps both states sharp without fonts or assets.
    Item {
        anchors.centerIn: parent
        visible: button.lockIndicator
        width: 24
        height: 24
        scale: Math.max(0, Math.min(1, (button.width - 8) / width,
                                      (button.height - 4) / height))

        // The unlocked shackle shifts right and leaves a clear gap above the body.
        Item {
            x: button.locked ? 6 : 9
            y: 1
            width: 12
            height: 11

            // Clip a rounded outline to obtain a clean semicircular arch.
            Item {
                width: parent.width
                height: 6
                clip: true
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "transparent"
                    border.width: 2
                    border.color: button.lockColor
                    antialiasing: true
                }
            }
            Rectangle {
                x: 0
                y: 6
                width: 2
                height: button.locked ? 5 : 1
                color: button.lockColor
            }
            Rectangle {
                x: 10
                y: 6
                width: 2
                height: 5
                color: button.lockColor
            }
        }

        Rectangle {
            x: 3
            y: 10
            width: 18
            height: 13
            radius: 3
            color: button.lockColor
            antialiasing: true

            // Round keyhole head with a short stem, identical in both states.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3
                width: 4
                height: 4
                radius: 2
                color: style.keyholeColor
                antialiasing: true
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 5
                width: 2
                height: 4
                radius: 1
                color: style.keyholeColor
                antialiasing: true
            }
        }
    }

    MouseArea {
        id: tapArea
        anchors.fill: parent
        enabled: button.enabled && !button.acceptsDrag
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    WidgetPanelDragArea {
        id: moveArea
        anchors.fill: parent
        visible: button.acceptsDrag
        panelController: button.dragController
        coordinateItem: button.coordinateItem
        clickableWhenLocked: true
        dragThreshold: button.dragThreshold
        onTapRequested: button.clicked()
    }
}
