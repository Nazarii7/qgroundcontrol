/****************************************************************************
 *
 * Payload, video and Fly View widget settings opened from FlyViewToolBar.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.FlightDisplay
import QGroundControl.ScreenTools

Popup {
    id: root

    property Item anchorItem: null
    property var widgetSettings: null
    // Sections always start collapsed whenever the Settings popup is opened.
    property bool widgetsSectionExpanded: false
    property bool hudItemsSectionExpanded: false

    // FlyViewToolBar may pass this object explicitly. The fallback keeps the
    // menu functional when the toolbar does not expose FlightDisplay types.
    readonly property var _resolvedWidgetSettings:
        widgetSettings ? widgetSettings : DropWidgetSettings

    readonly property real _margins:
        Math.max(8, ScreenTools.defaultFontPixelHeight * 0.5)

    readonly property real _smallMargins:
        Math.max(4, ScreenTools.defaultFontPixelWidth * 0.5)

    readonly property var _videoSettings:
        QGroundControl.settingsManager.videoSettings

    readonly property var _videoFitFact:
        _videoSettings ? _videoSettings.videoFit : null

    parent: mainWindow.contentItem

    modal: true
    dim: true
    focus: true
    padding: 0
    z: 10000

    closePolicy:
        Popup.CloseOnEscape
        | Popup.CloseOnPressOutside

    width: Math.max(
        ScreenTools.defaultFontPixelWidth * 36,
        350
    )

    height: settingsContent.implicitHeight

    function updatePosition() {
        if (!parent) {
            return
        }

        var safeMargin = root._margins
        var desiredX = parent.width - width - safeMargin
        var desiredY = ScreenTools.toolbarHeight + safeMargin

        if (anchorItem) {
            var anchorPosition = anchorItem.mapToItem(
                parent,
                0,
                anchorItem.height
            )

            desiredX = anchorPosition.x + anchorItem.width - width
            desiredY = anchorPosition.y + root._smallMargins
        }

        x = Math.max(
            safeMargin,
            Math.min(parent.width - width - safeMargin, desiredX)
        )

        y = Math.max(
            ScreenTools.toolbarHeight + root._smallMargins,
            Math.min(parent.height - height - safeMargin, desiredY)
        )
    }

    onAboutToShow: {
        widgetsSectionExpanded = false
        hudItemsSectionExpanded = false
        updatePosition()
    }
    onOpened: updatePosition()

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.28)
    }

    background: Rectangle {
        color: pgrStyle.panelBackground
        radius: pgrStyle.panelRadius

        border.width: 1
        border.color: pgrStyle.panelBorder
    }

    QtObject {
        id: pgrStyle

        readonly property color panelBackground:
            Qt.rgba(0.08, 0.10, 0.13, 0.97)

        readonly property color panelBorder:
            Qt.rgba(1, 1, 1, 0.16)

        readonly property color buttonIdle:
            Qt.rgba(1, 1, 1, 0.08)

        readonly property color buttonHover:
            Qt.rgba(1, 1, 1, 0.14)

        readonly property color buttonActive:
            Qt.rgba(1, 1, 1, 0.22)

        readonly property color buttonPressed:
            Qt.rgba(1, 1, 1, 0.18)

        readonly property color buttonBorder:
            Qt.rgba(1, 1, 1, 0.10)

        readonly property color textPrimary: "white"
        readonly property color textSecondary:
            Qt.rgba(1, 1, 1, 0.62)

        readonly property int panelRadius: 12
        readonly property int buttonRadius: 7
        readonly property int titleFontSize: 12
        readonly property int buttonFontSize: 10
    }

    component SettingsSwitch: RowLayout {
        id: switchRow

        property string title: ""
        property bool checked: false
        property bool available: true

        signal toggleRequested()

        Layout.fillWidth: true
        spacing: root._margins
        opacity: available ? 1.0 : 0.45

        QGCLabel {
            Layout.fillWidth: true

            text: switchRow.title
            color: pgrStyle.textPrimary
            font.pixelSize: pgrStyle.buttonFontSize
        }

        Rectangle {
            Layout.preferredWidth: Math.max(
                42,
                ScreenTools.defaultFontPixelWidth * 5
            )

            Layout.preferredHeight: Math.max(
                22,
                ScreenTools.defaultFontPixelHeight * 1.25
            )

            radius: height / 2

            color:
                switchRow.checked
                    ? Qt.rgba(0.00, 0.80, 0.35, 0.95)
                    : pgrStyle.buttonIdle

            border.width: 1
            border.color: pgrStyle.buttonBorder

            Rectangle {
                width: parent.height - 6
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter

                x:
                    switchRow.checked
                        ? parent.width - width - 3
                        : 3

                color: pgrStyle.textPrimary

                Behavior on x {
                    NumberAnimation {
                        duration: 110
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: switchRow.available
                hoverEnabled: true
                cursorShape:
                    enabled
                        ? Qt.PointingHandCursor
                        : Qt.ArrowCursor

                onClicked: switchRow.toggleRequested()
            }
        }
    }

    contentItem: ColumnLayout {
        id: settingsContent

        width: root.width
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(
                44,
                ScreenTools.defaultFontPixelHeight * 2.5
            )

            color: Qt.rgba(1, 1, 1, 0.055)
            topLeftRadius: pgrStyle.panelRadius
            topRightRadius: pgrStyle.panelRadius

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root._margins * 1.4
                anchors.rightMargin: root._margins
                spacing: root._smallMargins

                QGCLabel {
                    Layout.fillWidth: true

                    text: qsTr("Settings")
                    color: pgrStyle.textPrimary
                    font.pixelSize: Math.max(
                        pgrStyle.titleFontSize,
                        ScreenTools.defaultFontPixelHeight
                    )

                    font.bold: true
                }

                Rectangle {
                    Layout.preferredWidth: Math.max(
                        64,
                        ScreenTools.defaultFontPixelWidth * 8
                    )

                    Layout.preferredHeight: Math.max(
                        31,
                        ScreenTools.defaultFontPixelHeight * 1.75
                    )

                    radius: pgrStyle.buttonRadius

                    color:
                        closeMouseArea.pressed
                            ? pgrStyle.buttonPressed
                            : closeMouseArea.containsMouse
                              ? pgrStyle.buttonHover
                              : pgrStyle.buttonIdle

                    border.width: 1
                    border.color: pgrStyle.buttonBorder

                    QGCLabel {
                        anchors.centerIn: parent

                        text: qsTr("Close")
                        color: pgrStyle.textPrimary
                        font.pixelSize: pgrStyle.buttonFontSize
                    }

                    MouseArea {
                        id: closeMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: root._margins * 1.4
            spacing: Math.max(
                10,
                ScreenTools.defaultFontPixelHeight * 0.65
            )

            SettingsSwitch {
                title: qsTr("Video Grid Lines")
                available:
                    root._videoSettings
                    && root._videoSettings.gridLines

                checked:
                    available
                    && Boolean(root._videoSettings.gridLines.rawValue)

                onToggleRequested: {
                    root._videoSettings.gridLines.rawValue =
                        checked ? 0 : 1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root._margins

                QGCLabel {
                    Layout.fillWidth: true

                    text: qsTr("Video Screen Fit")
                    color: pgrStyle.textPrimary
                    font.pixelSize: pgrStyle.buttonFontSize
                }

                ComboBox {
                    id: videoFitCombo

                    Layout.preferredWidth: Math.max(
                        112,
                        ScreenTools.defaultFontPixelWidth * 13
                    )

                    Layout.preferredHeight: Math.max(
                        32,
                        ScreenTools.defaultFontPixelHeight * 1.8
                    )

                    model: [
                        qsTr("Fit Width"),
                        qsTr("Fit Height"),
                        qsTr("Stretch")
                    ]

                    currentIndex: {
                        var fact = root._videoFitFact

                        if (!fact) {
                            return 0
                        }

                        var value = Number(fact.rawValue)

                        if (!isFinite(value)) {
                            return 0
                        }

                        return Math.max(0, Math.min(2, value))
                    }

                    onActivated: (index) => {
                        if (root._videoFitFact) {
                            root._videoFitFact.rawValue = index
                        }
                    }

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: videoFitCombo.indicator.width + 10

                        text: videoFitCombo.displayText
                        color: pgrStyle.textPrimary
                        font.pixelSize: pgrStyle.buttonFontSize
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    indicator: Canvas {
                        x: videoFitCombo.width - width - 9
                        y: Math.round(
                            (videoFitCombo.height - height) / 2
                        )

                        width: 10
                        height: 6

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.beginPath()
                            ctx.moveTo(0, 0)
                            ctx.lineTo(width, 0)
                            ctx.lineTo(width / 2, height)
                            ctx.closePath()
                            ctx.fillStyle = pgrStyle.textPrimary
                            ctx.fill()
                        }
                    }

                    background: Rectangle {
                        radius: pgrStyle.buttonRadius

                        color:
                            videoFitCombo.pressed
                                ? pgrStyle.buttonPressed
                                : pgrStyle.buttonIdle

                        border.width: 1
                        border.color:
                            videoFitCombo.activeFocus
                                ? Qt.rgba(1, 1, 1, 0.36)
                                : pgrStyle.buttonBorder
                    }

                    delegate: ItemDelegate {
                        width: videoFitCombo.width
                        height: Math.max(
                            32,
                            ScreenTools.defaultFontPixelHeight * 1.8
                        )

                        highlighted:
                            videoFitCombo.highlightedIndex === index

                        contentItem: Text {
                            leftPadding: 8
                            text: modelData
                            color: pgrStyle.textPrimary
                            font.pixelSize: pgrStyle.buttonFontSize
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: pgrStyle.buttonRadius
                            color:
                                parent.highlighted
                                    ? pgrStyle.buttonActive
                                    : "transparent"
                        }
                    }

                    popup: Popup {
                        y: videoFitCombo.height + 4
                        width: videoFitCombo.width
                        padding: 4

                        implicitHeight: Math.min(
                            contentItem.implicitHeight
                            + topPadding
                            + bottomPadding,
                            220
                        )

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model:
                                videoFitCombo.popup.visible
                                    ? videoFitCombo.delegateModel
                                    : null

                            currentIndex:
                                videoFitCombo.highlightedIndex
                        }

                        background: Rectangle {
                            color: Qt.rgba(0.08, 0.10, 0.13, 0.98)
                            radius: pgrStyle.buttonRadius
                            border.width: 1
                            border.color: pgrStyle.panelBorder
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: pgrStyle.panelBorder
                opacity: 0.7
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root._smallMargins

                QGCLabel {
                    Layout.fillWidth: true

                    text: qsTr("Widgets")
                    color: pgrStyle.textPrimary
                    font.pixelSize: pgrStyle.buttonFontSize
                    font.bold: true
                }

                Rectangle {
                    Layout.preferredWidth: Math.max(
                        28,
                        ScreenTools.defaultFontPixelHeight * 1.65
                    )

                    Layout.preferredHeight: Layout.preferredWidth
                    radius: pgrStyle.buttonRadius

                    color:
                        widgetsToggleMouseArea.pressed
                            ? pgrStyle.buttonPressed
                            : widgetsToggleMouseArea.containsMouse
                              ? pgrStyle.buttonHover
                              : pgrStyle.buttonIdle

                    border.width: 1
                    border.color: pgrStyle.buttonBorder

                    QGCLabel {
                        anchors.centerIn: parent

                        text: root.widgetsSectionExpanded ? "−" : "+"
                        color: pgrStyle.textPrimary
                        font.pixelSize: Math.max(
                            pgrStyle.buttonFontSize,
                            ScreenTools.defaultFontPixelHeight
                        )

                        font.bold: true
                    }

                    MouseArea {
                        id: widgetsToggleMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.widgetsSectionExpanded =
                                !root.widgetsSectionExpanded

                            Qt.callLater(root.updatePosition)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root._smallMargins
                visible: root.widgetsSectionExpanded

                SettingsSwitch {
                    title: qsTr("Photo & Video")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.photoVideoVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.photoVideoVisible =
                            !Boolean(
                                root._resolvedWidgetSettings
                                    .photoVideoVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Camera Controls")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.cameraControlsVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.cameraControlsVisible =
                            !Boolean(
                                root._resolvedWidgetSettings
                                    .cameraControlsVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Drop Widget")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.dropWidgetVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.dropWidgetVisible =
                            !Boolean(
                                root._resolvedWidgetSettings
                                    .dropWidgetVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Controller Input")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.controllerInputVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.controllerInputVisible =
                            !Boolean(
                                root._resolvedWidgetSettings
                                    .controllerInputVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Camera Logs")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.cameraLogsVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.cameraLogsVisible =
                            !Boolean(
                                root._resolvedWidgetSettings
                                    .cameraLogsVisible
                            )
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: pgrStyle.panelBorder
                opacity: 0.7
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root._smallMargins

                QGCLabel {
                    Layout.fillWidth: true

                    text: qsTr("HUD Items")
                    color: pgrStyle.textPrimary
                    font.pixelSize: pgrStyle.buttonFontSize
                    font.bold: true
                }

                Rectangle {
                    Layout.preferredWidth: Math.max(
                        28,
                        ScreenTools.defaultFontPixelHeight * 1.65
                    )

                    Layout.preferredHeight: Layout.preferredWidth
                    radius: pgrStyle.buttonRadius

                    color:
                        hudItemsToggleMouseArea.pressed
                            ? pgrStyle.buttonPressed
                            : hudItemsToggleMouseArea.containsMouse
                              ? pgrStyle.buttonHover
                              : pgrStyle.buttonIdle

                    border.width: 1
                    border.color: pgrStyle.buttonBorder

                    QGCLabel {
                        anchors.centerIn: parent

                        text: root.hudItemsSectionExpanded ? "−" : "+"
                        color: pgrStyle.textPrimary
                        font.pixelSize: Math.max(
                            pgrStyle.buttonFontSize,
                            ScreenTools.defaultFontPixelHeight
                        )

                        font.bold: true
                    }

                    MouseArea {
                        id: hudItemsToggleMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.hudItemsSectionExpanded =
                                !root.hudItemsSectionExpanded

                            Qt.callLater(root.updatePosition)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root._smallMargins
                visible: root.hudItemsSectionExpanded

                SettingsSwitch {
                    title: qsTr("Transparent Background")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings
                                .hudTransparentBackground
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings
                            .hudTransparentBackground =
                                !Boolean(
                                    root._resolvedWidgetSettings
                                        .hudTransparentBackground
                                )
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: pgrStyle.panelBorder
                    opacity: 0.45
                }

                SettingsSwitch {
                    title: qsTr("Link")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.linkOsdVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.linkOsdVisible =
                            !Boolean(
                                root._resolvedWidgetSettings.linkOsdVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("GPS")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.gpsOsdVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.gpsOsdVisible =
                            !Boolean(
                                root._resolvedWidgetSettings.gpsOsdVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Battery")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.batteryOsdVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.batteryOsdVisible =
                            !Boolean(
                                root._resolvedWidgetSettings.batteryOsdVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Altitude")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.altitudeOsdVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.altitudeOsdVisible =
                            !Boolean(
                                root._resolvedWidgetSettings.altitudeOsdVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Horizon")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.horizonOsdVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.horizonOsdVisible =
                            !Boolean(
                                root._resolvedWidgetSettings.horizonOsdVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Compass")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.compassOsdVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.compassOsdVisible =
                            !Boolean(
                                root._resolvedWidgetSettings.compassOsdVisible
                            )
                    }
                }

                SettingsSwitch {
                    title: qsTr("Home")
                    available: Boolean(root._resolvedWidgetSettings)
                    checked:
                        available
                        && Boolean(
                            root._resolvedWidgetSettings.homeOsdVisible
                        )

                    onToggleRequested: {
                        root._resolvedWidgetSettings.homeOsdVisible =
                            !Boolean(
                                root._resolvedWidgetSettings.homeOsdVisible
                            )
                    }
                }
            }
        }
    }
}
