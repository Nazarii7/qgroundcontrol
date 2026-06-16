import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: editor

    property var orderedTargets: []
    property bool sectionOpen: true

    signal moveRequested(int servoNumber, int direction)
    signal sectionToggleRequested()

    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 6

        RowLayout {
            width: parent.width
            height: 28
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: "Drop order"
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
                    text: editor.sectionOpen ? "−" : "+"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: sectionGearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        editor.sectionToggleRequested()
                    }
                }
            }
        }

        Column {
            width: parent.width
            visible: editor.sectionOpen
            spacing: 6

            Label {
                width: parent.width
                visible: editor.orderedTargets.length <= 1
                text: "Select at least two servos to change order."
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: editor.orderedTargets

                delegate: Rectangle {
                    width: parent.width
                    height: 30
                    radius: 7
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        Label {
                            Layout.fillWidth: true
                            text: (index + 1) + ". SERVO " + modelData.servoNumber
                            color: "white"
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 22
                            radius: 5
                            color: index > 0 ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            opacity: index > 0 ? 1.0 : 0.35

                            Label {
                                anchors.centerIn: parent
                                text: "↑"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: index > 0
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    editor.moveRequested(modelData.servoNumber, -1)
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 22
                            radius: 5
                            color: index < editor.orderedTargets.length - 1 ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            opacity: index < editor.orderedTargets.length - 1 ? 1.0 : 0.35

                            Label {
                                anchors.centerIn: parent
                                text: "↓"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: index < editor.orderedTargets.length - 1
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    editor.moveRequested(modelData.servoNumber, 1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}