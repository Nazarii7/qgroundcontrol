import QtQuick

import "../controls"

Rectangle {
    id: handle

    property real collapsedWidth: 58
    property real collapsedPanelHeight: 52

    signal expandRequested()

    width: collapsedWidth
    height: collapsedPanelHeight
    radius: 10
    color: Qt.rgba(0.08, 0.10, 0.13, 0.90)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)

    DropIconButton {
        anchors.centerIn: parent

        text: "+"
        textSize: 16

        idleColor: Qt.rgba(0.05, 0.07, 0.10, 0.95)
        activeColor: Qt.rgba(0.05, 0.07, 0.10, 0.95)
        pressedColor: Qt.rgba(1, 1, 1, 0.12)
        borderColor: Qt.rgba(1, 1, 1, 0.18)

        onClicked: {
            handle.expandRequested()
        }
    }
}