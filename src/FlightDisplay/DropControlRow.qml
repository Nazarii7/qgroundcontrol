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

    property real rowHeight: 54
    property real rowAnimatedHeight: 58

    signal toggleRequested(int rowIndex)

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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 10

            Column {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Label {
                    text: rowRoot.titleText
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                }

                Label {
                    text: rowRoot.subtitleText
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: 11
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ServoToggle {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                checked: rowRoot.rowIsOpen
                busy: rowRoot.rowBusy
                enabled: !rowRoot.rowBusy

                onClicked: rowRoot.toggleRequested(rowRoot.rowIndex)
            }
        }
    }
}