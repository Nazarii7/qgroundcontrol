import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id: list

    property var dropModel

    property int availableServoCount: 0
    property real settingsRowHeight: 30
    property bool sectionOpen: true

    signal sectionToggleRequested()
    signal visibilityToggleRequested(int rowIndex)

    width: parent ? parent.width : 320
    spacing: 8
    visible: true

    RowLayout {
        width: parent.width
        height: 28
        spacing: 8
        visible: list.availableServoCount > 0

        Label {
            Layout.fillWidth: true
            text: "Available servo channels"
            color: "white"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }

        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 24

            Label {
                anchors.centerIn: parent
                text: list.sectionOpen ? "−" : "+"
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    list.sectionToggleRequested()
                }
            }
        }
    }

    Label {
        visible: list.availableServoCount <= 0
        width: parent.width
        text: "No available channels. Connect vehicle and wait for parameters."
        color: Qt.rgba(1, 1, 1, 0.62)
        font.pixelSize: 10
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        visible: list.sectionOpen && list.availableServoCount > 0
        spacing: 6

        Repeater {
            model: list.dropModel

            delegate: DropAvailableServoRow {
                width: parent.width
                settingsRowHeight: list.settingsRowHeight

                onVisibilityToggleRequested: function(rowIndex) {
                    list.visibilityToggleRequested(rowIndex)
                }
            }
        }
    }
}