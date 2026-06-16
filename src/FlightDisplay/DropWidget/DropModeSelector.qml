import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: selector

    property int currentMode: 0
    property bool sectionOpen: true

    readonly property int modeAll: 0
    readonly property int modeGroups: 1
    readonly property int modeIndividual: 2

    signal modeSelected(int mode)
    signal sectionToggleRequested()

    implicitHeight: content.implicitHeight

    function buttonColor(mode) {
        return selector.currentMode === mode
                ? Qt.rgba(0.20, 0.55, 0.24, 0.95)
                : Qt.rgba(1, 1, 1, 0.08)
    }

    function buttonBorderColor(mode) {
        return selector.currentMode === mode
                ? Qt.rgba(0.70, 1.0, 0.72, 0.90)
                : Qt.rgba(1, 1, 1, 0.16)
    }

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
                text: "Drop mode"
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
                    text: selector.sectionOpen ? "−" : "+"
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
                        selector.sectionToggleRequested()
                    }
                }
            }
        }

        RowLayout {
            width: parent.width
            visible: selector.sectionOpen
            height: visible ? 30 : 0
            spacing: 6

            Repeater {
                model: [
                    { label: "All", mode: selector.modeAll },
                    { label: "Groups", mode: selector.modeGroups },
                    { label: "Single", mode: selector.modeIndividual }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 8
                    color: selector.buttonColor(modelData.mode)
                    border.width: 1
                    border.color: selector.buttonBorderColor(modelData.mode)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: "white"
                        font.pixelSize: 11
                        font.bold: selector.currentMode === modelData.mode
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            selector.modeSelected(modelData.mode)
                        }
                    }
                }
            }
        }
    }
}