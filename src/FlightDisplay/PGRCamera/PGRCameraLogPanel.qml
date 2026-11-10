import QtQuick
import QtQuick.Controls
import QGroundControl.FlightDisplay
import "../Shared/Widget" as Shared

// Camera-specific presentation only. The camera owner supplies the log text.
Item {
    id: root
    anchors.fill: parent

    property string title: qsTr("Camera logs")
    property string logText: ""
    property bool expanded: true
    property bool transparentBackground: false
    property real panelMargin: 12
    property real preferredWidth: 200
    property int logFontSize: 10
    property alias panelLocked: panelState.locked
    readonly property real panelX: panelState.panelX
    readonly property real panelY: panelState.panelY
    readonly property bool panelDragging: panelState.dragging
    readonly property bool panelPositionReady: panelState.ready

    readonly property real availableWidth: Math.max(0, width - panelMargin * 2)
    readonly property real availableHeight: Math.max(0, height - panelMargin * 2)
    readonly property real panelWidth: Math.min(Math.max(100, preferredWidth), availableWidth)
    readonly property real panelHeight: Math.min(availableHeight,
        Math.ceil(style.headerHeight + style.panelPadding * 3 + logLabel.implicitHeight))

    Shared.WidgetPanelStyle { id: style }

    WidgetPanelController {
        id: panelState
        enabled: root.visible && root.enabled && root.availableWidth > 0 && root.availableHeight > 0
        bounds: Qt.rect(root.panelMargin, root.panelMargin, root.availableWidth, root.availableHeight)
        panelSize: Qt.size(root.panelWidth,
                           root.expanded ? root.panelHeight : style.collapsedHeight)
        defaultPosition: Qt.point(Math.max(root.panelMargin, root.width - root.panelWidth - root.panelMargin),
                                  Math.max(root.panelMargin, (root.height - root.panelHeight) / 2))
        followDefault: true
    }

    Shared.WidgetPanelSurface {
        id: surface
        objectName: "cameraLogSurface"
        visible: root.expanded && panelState.ready
        x: panelState.panelX
        y: panelState.panelY
        width: root.panelWidth
        height: root.panelHeight
        transparentBackground: root.transparentBackground
        panelStyle: style
        clip: true

        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: style.panelPadding
            height: style.headerHeight

            Shared.WidgetPanelDragArea {
                anchors.fill: parent
                panelController: panelState
                coordinateItem: root
            }
            Text {
                id: titleLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(implicitWidth,
                    header.width - actions.width - style.buttonSpacing))
                text: root.title
                color: style.textPrimary
                font.pixelSize: style.titleFontSize
                font.bold: true
                // Fit the title before eliding so both controls remain visible.
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Math.min(style.titleFontSize, 12)
                elide: Text.ElideRight
            }
            Shared.WidgetPanelActions {
                id: actions
                anchors.left: titleLabel.right
                anchors.leftMargin: titleLabel.width > 0 ? style.buttonSpacing : 0
                anchors.verticalCenter: parent.verticalCenter
                panelController: panelState
                coordinateItem: root
                onLockToggleRequested: root.panelLocked = !root.panelLocked
                onCollapseRequested: root.expanded = false
            }
        }

        Flickable {
            id: logView
            objectName: "cameraLogViewport"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.margins: style.panelPadding
            contentWidth: width
            contentHeight: logLabel.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Text {
                id: logLabel
                width: logView.width
                text: root.logText
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: style.textPrimary
                font.pixelSize: root.logFontSize
                lineHeight: 1.1
                style: root.transparentBackground ? Text.Outline : Text.Normal
                styleColor: style.textShadowColor
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }

    Shared.WidgetCollapsedHandle {
        objectName: "cameraLogCollapsedHandle"
        visible: !root.expanded && panelState.ready
        x: panelState.panelX + Math.max(0, root.panelWidth - width)
        y: panelState.panelY
        panelController: panelState
        coordinateItem: root
        transparentBackground: root.transparentBackground
        expandToolTip: qsTr("Expand camera logs")
        onExpandRequested: root.expanded = true
    }
}
