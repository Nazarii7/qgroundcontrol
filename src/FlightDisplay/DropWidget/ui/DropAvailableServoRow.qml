import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: rowRoot

    required property int index
    required property int servoNumber
    required property bool active
    required property bool servoAvailable
    required property string availabilityText

    property real settingsRowHeight: 30

    signal visibilityToggleRequested(int rowIndex)

    width: parent ? parent.width : 320
    height: servoAvailable ? settingsRowHeight : 0
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
                    text: "SERVO " + rowRoot.servoNumber
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }

                Label {
                    text: rowRoot.availabilityText
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

                    anchors.centerIn: parent
                    checked: rowRoot.active
                    enabled: true
                    opacity: 1.0

                    indicator: Rectangle {
                        implicitWidth: 14
                        implicitHeight: 14
                        anchors.centerIn: parent
                        radius: 2
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                        color: visibleCheck.checked
                               ? Qt.rgba(1, 1, 1, 0.95)
                               : Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            anchors.centerIn: parent
                            width: 7
                            height: 7
                            radius: 1
                            visible: visibleCheck.checked
                            color: Qt.rgba(0.08, 0.10, 0.13, 1.0)
                        }
                    }

                    contentItem: Item { }

                    onClicked: {
                        rowRoot.visibilityToggleRequested(rowRoot.index)
                    }
                }
            }
        }
    }
}