import QtQuick

Rectangle {
    id: button

    property bool holdActive: false
    property bool canDrop: false
    property int buttonHeight: 44

    signal holdPressed()
    signal holdReleased()

    width: parent ? parent.width : 320
    height: buttonHeight
    radius: 10

    enabled: canDrop
    opacity: enabled ? 1.0 : 0.45

    color: holdActive
           ? Qt.rgba(0.42, 0.08, 0.08, 0.95)
           : Qt.rgba(0.10, 0.34, 0.14, 0.95)

    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    Text {
        anchors.centerIn: parent

        text: button.holdActive ? "RELEASE TO CLOSE" : "HOLD TO DROP"
        color: "white"
        font.pixelSize: 14
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        anchors.fill: parent
        enabled: button.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: function(mouse) {
            button.holdPressed()
            mouse.accepted = true
        }

        onReleased: function(mouse) {
            button.holdReleased()
            mouse.accepted = true
        }

        onCanceled: {
            button.holdReleased()
        }
    }
}