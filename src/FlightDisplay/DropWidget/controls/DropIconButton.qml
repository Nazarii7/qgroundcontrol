import QtQuick

Rectangle {
    id: button

    property string text: ""
    property bool active: false
    property bool enabledState: true

    property color idleColor: Qt.rgba(1, 1, 1, 0.08)
    property color activeColor: Qt.rgba(1, 1, 1, 0.22)
    property color pressedColor: Qt.rgba(1, 1, 1, 0.18)
    property color borderColor: Qt.rgba(1, 1, 1, 0.10)
    property color textColor: "white"

    property int textSize: 14

    signal clicked()

    width: 34
    height: 28
    radius: 7

    enabled: enabledState
    opacity: enabled ? 1.0 : 0.45

    color: mouseArea.pressed
           ? pressedColor
           : active
             ? activeColor
             : idleColor

    border.width: 1
    border.color: borderColor

    Text {
        anchors.centerIn: parent
        text: button.text
        color: button.textColor
        font.pixelSize: button.textSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: button.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            button.clicked()
        }
    }
}