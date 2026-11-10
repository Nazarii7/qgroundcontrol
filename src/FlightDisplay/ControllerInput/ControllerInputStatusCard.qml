import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "controllerInputStatusCard"

    required property var statusModel
    required property var panelStyle
    property bool detailsExpanded: false

    readonly property string severity: statusModel.severity
    readonly property color statusColor: {
        switch (severity) {
        case "error": return panelStyle.dangerText
        case "warning": return panelStyle.warningText
        case "success": return panelStyle.successText
        default: return panelStyle.inactiveIndicator
        }
    }

    implicitHeight: content.implicitHeight + 16
    height: implicitHeight
    radius: panelStyle.cardRadius
    color: panelStyle.cardBackground
    border.width: 1
    border.color: panelStyle.cardBorder

    // Keep the reason visible when a new loss occurs after details were folded.
    onSeverityChanged: {
        if (severity === "error") {
            detailsExpanded = true
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        width: 3
        radius: 1.5
        color: root.statusColor
    }

    ColumnLayout {
        id: content
        x: 16
        y: 8
        width: Math.max(0, parent.width - 24)
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                objectName: "controllerStatusTitle"
                Layout.fillWidth: true
                text: root.statusModel.title
                color: root.severity === "neutral" ? root.panelStyle.textSecondary : root.statusColor
                font.pixelSize: 11
                font.bold: true
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }

            ToolButton {
                objectName: "controllerStatusDetailsButton"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                text: root.detailsExpanded ? "−" : "+"
                Accessible.name: root.detailsExpanded ? qsTr("Hide connection details") : qsTr("Show connection details")
                onClicked: root.detailsExpanded = !root.detailsExpanded

                contentItem: Text {
                    text: parent.text
                    color: root.panelStyle.textPrimary
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.down ? root.panelStyle.buttonPressed
                                       : parent.hovered ? root.panelStyle.buttonActive
                                                        : root.panelStyle.buttonIdle
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: root.panelStyle.focusBorder
                }
            }
        }

        Text {
            objectName: "controllerStatusMessage"
            visible: root.detailsExpanded
            Layout.fillWidth: true
            text: root.statusModel.message
            color: root.panelStyle.textSecondary
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }
}
