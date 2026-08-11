import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: rowRoot

    property int rowIndex: -1
    property string titleText: ""
    property string subtitleText: ""

    property bool rowActive: true
    property bool rowIsOpen: false
    property bool rowBusy: false

    readonly property bool rowPhysicallyOpen:
        rowIsOpen && rowCurrentPositionLabel !== "Closed"

    property int rowCurrentPwm: 1000
    property string rowCurrentPositionLabel: "Closed"
    property int rowNextOpenPwm: 2000
    property string rowNextPositionLabel: "P1"
    property bool showPhysicalPositionWhenIdle: false

    property real rowHeight: 54
    property real rowAnimatedHeight: 58

    property bool rowAvailable: true
    property string rowUnavailableText: ""

    width: 320
    height: rowHeight

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: rowRoot.rowHeight
        radius: 9
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        opacity: rowRoot.rowAvailable ? 1.0 : 0.55

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 10

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Label {
                    text: rowRoot.titleText
                    color: rowRoot.rowAvailable ? "white" : Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }

                Label {
                    text: rowRoot.subtitleText + " · Next " + rowRoot.rowNextPositionLabel + " " + rowRoot.rowNextOpenPwm
                    color: rowRoot.rowAvailable
                           ? Qt.rgba(1, 1, 1, 0.65)
                           : Qt.rgba(1.0, 0.55, 0.55, 0.85)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                Layout.preferredWidth: 88
                Layout.preferredHeight: 32
                radius: 16
                color: rowRoot.rowPhysicallyOpen
                       ? Qt.rgba(0.42, 0.08, 0.08, 0.95)
                       : Qt.rgba(0.10, 0.34, 0.14, 0.95)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                Behavior on color {
                    ColorAnimation { duration: 160 }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                       text: rowRoot.rowPhysicallyOpen ? "OPEN" : "CLOSED"
                        color: "white"
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(rowRoot.rowCurrentPwm)
                        color: Qt.rgba(1, 1, 1, 0.82)
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }
        }
    }
}
