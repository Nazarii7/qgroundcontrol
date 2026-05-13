import QtQuick
import QtQuick.Controls

Item {
    id: toggleRoot

    property bool checked: false
    property bool busy: false
    property bool enabled: true

    signal clicked()

    width: 74
    height: 36

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: toggleRoot.busy
               ? Qt.rgba(0.55, 0.55, 0.55, 0.35)
               : (toggleRoot.checked
                  ? Qt.rgba(0.42, 0.08, 0.08, 0.95)
                  : Qt.rgba(0.10, 0.34, 0.14, 0.95))
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        opacity: toggleRoot.busy ? 0.78 : 1.0

        Behavior on color {
            ColorAnimation { duration: 220 }
        }

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }
    }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            width: 28
            height: 28
            radius: 14
            y: 4
            x: toggleRoot.checked ? -30 : 4
            color: "#2e7d32"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)

            Behavior on x {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.InOutCubic
                }
            }

            Label {
                anchors.centerIn: parent
                color: "white"
                font.pixelSize: 9
                font.bold: true
            }
        }

        Rectangle {
            width: 28
            height: 28
            radius: 14
            y: 4
            x: toggleRoot.checked ? 42 : 74
            color: "#b3261e"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)

            Behavior on x {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.InOutCubic
                }
            }

            Label {
                anchors.centerIn: parent
                color: "white"
                font.pixelSize: 9
                font.bold: true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: toggleRoot.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleRoot.clicked()
    }
}