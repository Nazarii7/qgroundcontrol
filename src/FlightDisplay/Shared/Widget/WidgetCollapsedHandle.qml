import QtQuick

WidgetPanelSurface {
    id: handle

    property real collapsedWidth: effectiveStyle.collapsedWidth
    property real collapsedPanelHeight: effectiveStyle.collapsedHeight
    property var panelController: null
    property Item coordinateItem: null
    property string expandToolTip: qsTr("Expand widget")
    property string badgeText: ""
    property color badgeColor: effectiveStyle.lockColor

    signal expandRequested()

    width: collapsedWidth
    height: collapsedPanelHeight
    radius: effectiveStyle.cardRadius

    WidgetPanelDragArea {
        anchors.fill: parent
        panelController: handle.panelController
        coordinateItem: handle.coordinateItem
        dragThreshold: handle.effectiveStyle.dragThreshold
    }

    WidgetIconButton {
        objectName: "widgetExpandButton"
        anchors.centerIn: parent
        text: "+"
        textSize: 16
        toolTip: handle.expandToolTip
        onClicked: handle.expandRequested()
    }

    Rectangle {
        visible: handle.badgeText.length > 0 && handle.badgeText !== "0"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 2
        width: Math.max(16, badgeLabel.implicitWidth + 6)
        height: 16
        radius: height / 2
        color: handle.badgeColor
        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: handle.badgeText
            color: handle.effectiveStyle.badgeTextColor
            font.pixelSize: 10
            font.bold: true
        }
    }
}
