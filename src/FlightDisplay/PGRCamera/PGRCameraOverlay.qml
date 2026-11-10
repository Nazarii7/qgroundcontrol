import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.ScreenTools
import SiYi.Object 1.0

import "controls" as PGRControls
import "style" as PGRStyle
import "../Shared/Widget" as Shared
import "." as LocalCamera

Item {
    id: root
    anchors.fill: parent
    // Camera controls are interactive and must stay above every OSD item.
    z: mainWindow.widgetPanelZ

    // No full-screen MouseArea here.
    // Only small buttons are interactive, so the main video/gimbal/tracking area remains safe.
    visible: true

    property bool expanded: true

    readonly property bool controlsVisible:
        WidgetPanelSettings.cameraControlsVisible

    readonly property bool logsVisible:
        WidgetPanelSettings.cameraLogsVisible

    // Development mode:
    // true  - buttons remain visible but disabled when camera capability is false.
    // false - unsupported buttons are hidden, closer to final SIYI behavior.
    property bool showUnavailableControls: false

    property var siyi: SiYi
    property var camera: siyi.camera

    readonly property bool hasCamera: camera !== null && camera !== undefined

    readonly property string tcpDebugState:
        root.hasCamera && root.camera.tcpState
            ? String(root.camera.tcpState)
            : "NO OBJECT"

    readonly property string tcpDebugError:
        root.hasCamera && root.camera.lastTcpError
            ? String(root.camera.lastTcpError)
            : "-"

    readonly property string rawVideoUrl:
        String(QGroundControl.settingsManager.videoSettings.rtspUrl.rawValue || "").trim()

    readonly property string videoUrl:
        normalizeRtspUrl(rawVideoUrl)

    readonly property bool rtspUrlWasNormalized:
        rawVideoUrl !== "" && rawVideoUrl !== videoUrl

    property string lastAnalyzedVideoUrl: ""
    property bool debugStatusVisible: true

    readonly property string parsedCameraIp: parseIpFromVideoUrl(videoUrl)

    readonly property bool hasVideoUrl: videoUrl !== ""
                                      && videoUrl !== undefined
                                      && videoUrl !== null

    readonly property bool isRtspVideoUrl: hasVideoUrl
                                        && videoUrl.toLowerCase().indexOf("rtsp://") === 0

    readonly property bool canZoom: hasCamera && camera.enableZoom
    readonly property bool canFocus: hasCamera && camera.enableFocus
    readonly property bool canResetPosition:
        hasCamera
        && camera.isConnected
        && camera.enableControl

    readonly property int panelMargin: 12
    readonly property int buttonWidth: 42
    readonly property int buttonHeight: 28
    readonly property int headerButtonWidth: 52
    readonly property int cameraHeaderHeight: 34

    // Match the outer Takeoff / Return ToolStrip width exactly.
    readonly property real cameraOuterPanelWidth:
        ScreenTools.defaultFontPixelWidth * 8

    // Keep CAM, Z+/Z-, RST and F+/F- visibly narrower than the panel.
    readonly property real cameraInnerButtonWidth:
        ScreenTools.defaultFontPixelWidth * 6

    // FlyViewWidgetLayer originally centered cameraPanelX using 4 px of
    // horizontal padding on each side. Preserve that center while changing
    // the outer panel to the exact ToolStrip width.
    readonly property real placementReferencePadding: 4

    // Supplied by FlyViewVideo. cameraPanelY is already the intended top
    // coordinate below Takeoff/Return; cameraPanelWidth is the reference
    // width used to keep both controls horizontally aligned.
    property real cameraPanelX: panelMargin
    property real cameraPanelY: panelMargin
    property real cameraPanelWidth: headerButtonWidth

    readonly property real cameraPanelBottomGap:
        Math.max(6, ScreenTools.defaultFontPixelHeight * 0.35)

    readonly property bool panelLocked:
        WidgetPanelSettings.cameraControlsLocked

    property alias controlPanelX: cameraPanelState.panelX
    property alias controlPanelY: cameraPanelState.panelY
    readonly property bool controlPanelPositionReady: cameraPanelState.ready
    readonly property bool controlPanelDragging: cameraPanelState.dragging
    readonly property real collapsedPanelWidth: 58
    readonly property real collapsedPanelHeight: 52

    WidgetPanelController {
        id: cameraPanelState
        enabled: root.visible && root.enabled && root.controlsVisible && root.width > 0 && root.height > 0
        locked: root.panelLocked
        onEnabledChanged: { if (enabled) Qt.callLater(root.initializeControlPanelPosition) }
        bounds: Qt.rect(0, 0, root.width, root.height)
        panelSize: Qt.size(panel.width, root.expanded ? panel.height : root.collapsedPanelHeight)
        defaultPosition: Qt.point(root.defaultControlPanelX(), root.defaultControlPanelY())
        savedPosition: Qt.point(Number(WidgetPanelSettings.cameraControlsX),
                                Number(WidgetPanelSettings.cameraControlsY))
        useSavedPosition: !root.savedPositionOverlapsToolStrip(
            Number(WidgetPanelSettings.cameraControlsX),
            Number(WidgetPanelSettings.cameraControlsY))

        onPositionCommitted: function(x, y) {
            WidgetPanelSettings.setCameraControlsPosition(x, y)
        }
    }

    function defaultControlPanelX() {
        return Math.max(
            0,
            root.cameraPanelX
                + (
                    root.cameraPanelWidth
                    + root.placementReferencePadding * 2
                    - panel.width
                ) / 2
        )
    }

    function defaultControlPanelY() {
        return Math.max(
            0,
            root.cameraPanelY
                + root.cameraPanelBottomGap
        )
    }

    function savedPositionOverlapsToolStrip(savedX, savedY) {
        if (savedX < 0 || savedY < 0) {
            return false
        }

        var toolStripLeft = root.cameraPanelX
        var toolStripRight =
            root.cameraPanelX
            + root.cameraPanelWidth
            + root.placementReferencePadding * 2
        var horizontallyOverlaps =
            savedX < toolStripRight
            && savedX + panel.width > toolStripLeft

        return horizontallyOverlaps
                && savedY < root.defaultControlPanelY()
    }

    function boundedControlPanelPosition(x, y) {
        return cameraPanelState.boundedPosition(x, y)
    }

    function initializeControlPanelPosition() {
        if (!cameraPanelState.enabled || root.width <= 0 || root.height <= 0) {
            return
        }

        var savedX = Number(WidgetPanelSettings.cameraControlsX)
        var savedY = Number(WidgetPanelSettings.cameraControlsY)
        // Migrate only the old invalid position which covered Return. Any
        // valid user-moved position remains untouched.
        var useDefaultPosition =
            savedX < 0
            || savedY < 0
            || savedPositionOverlapsToolStrip(savedX, savedY)
        var position = boundedControlPanelPosition(
            useDefaultPosition ? defaultControlPanelX() : savedX,
            useDefaultPosition ? defaultControlPanelY() : savedY
        )

        cameraPanelState.setPosition(position.x, position.y)

        // Persist the corrected coordinates once. This prevents the obsolete
        // overlapping position from being restored on the next application
        // start while leaving every valid user-moved position untouched.
        if (useDefaultPosition && savedX >= 0 && savedY >= 0) {
            WidgetPanelSettings.setCameraControlsPosition(
                controlPanelX,
                controlPanelY
            )
        }
    }

    function reconcileControlPanelPosition() {
        if (!root.controlPanelPositionReady) {
            Qt.callLater(root.initializeControlPanelPosition)
            return
        }

        if (!root.savedPositionOverlapsToolStrip(
                    root.controlPanelX,
                    root.controlPanelY)) {
            return
        }

        root.controlPanelX = root.defaultControlPanelX()
        root.controlPanelY = root.defaultControlPanelY()
        root.keepControlPanelInBounds(true)
    }

    function keepControlPanelInBounds(savePosition) {
        if (!cameraPanelState.ready || !cameraPanelState.enabled) return
        cameraPanelState.keepInBounds()
        if (savePosition) {
            WidgetPanelSettings.setCameraControlsPosition(controlPanelX, controlPanelY)
        }
    }

    onWidthChanged: {
        if (controlPanelPositionReady) {
            keepControlPanelInBounds(false)
        } else {
            Qt.callLater(root.initializeControlPanelPosition)
        }
    }

    onHeightChanged: {
        if (controlPanelPositionReady) {
            keepControlPanelInBounds(false)
        } else {
            Qt.callLater(root.initializeControlPanelPosition)
        }
    }

    onCameraPanelXChanged: {
        Qt.callLater(root.reconcileControlPanelPosition)
    }

    onCameraPanelYChanged: {
        Qt.callLater(root.reconcileControlPanelPosition)
    }

    onCameraPanelWidthChanged: {
        Qt.callLater(root.reconcileControlPanelPosition)
    }

    function shouldShowControl(capability) {
        return root.expanded && (root.showUnavailableControls || capability)
    }

    function stopZoom() {
        if (root.hasCamera && root.canZoom) {
            root.camera.zoom(0)
        }
    }

    function zoomIn() {
        if (root.hasCamera && root.canZoom) {
            root.camera.zoom(1)
        } else {
            console.log("PGR camera: zoom in unavailable")
        }
    }

    function zoomOut() {
        if (root.hasCamera && root.canZoom) {
            root.camera.zoom(-1)
        } else {
            console.log("PGR camera: zoom out unavailable")
        }
    }

    function stopFocus() {
        if (root.hasCamera && root.canFocus) {
            root.camera.focus(0)
        }
    }

    onControlsVisibleChanged: {
        if (!root.controlsVisible) {
            root.stopZoom()
            root.stopFocus()
        }
    }


    function focusFar() {
        if (root.hasCamera && root.canFocus) {
            root.camera.focus(1)
        } else {
            console.log("PGR camera: focus far unavailable")
        }
    }

    function focusNear() {
        if (root.hasCamera && root.canFocus) {
            root.camera.focus(-1)
        } else {
            console.log("PGR camera: focus near unavailable")
        }
    }

    function resetCameraPosition() {
        if (!root.canResetPosition) {
            console.log("PGR camera: reset position unavailable")
            return
        }

        console.log(
            "PGR camera: reset position requested",
            "connected:", root.camera.isConnected,
            "control:", root.camera.enableControl
        )

        var result = root.camera.resetPostion()

        console.log(
            "PGR camera: resetPostion returned:",
            result
        )
    }

    function parseIpFromVideoUrl(url) {
        if (url === undefined || url === null) {
            return ""
        }

        var value = String(url).trim()

        if (value === "") {
            return ""
        }

        var match = value.match(
            /(?:rtsp:\/\/)?(?:[^@\/\s]+@)?(\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?(?:\/[^\s]*)?/i
        )

        if (!match || match.length < 2) {
            console.warn(
                "SiYi failed to parse camera IP:",
                JSON.stringify(value)
            )
            return ""
        }

        var ip = match[1]
        var octets = ip.split(".")

        if (octets.length !== 4) {
            return ""
        }

        for (var i = 0; i < octets.length; i++) {
            var octet = Number(octets[i])

            if (!Number.isInteger(octet)
                    || octet < 0
                    || octet > 255) {
                console.warn("SiYi invalid IPv4:", ip)
                return ""
            }
        }

        return ip
    }

    function updateCameraIpFromVideoUrl(reason) {
        if (!root.hasCamera) {
            console.log("PGR SiYi IP analyze skipped: no camera object, reason:", reason)
            return
        }

        if (!root.isRtspVideoUrl) {
            console.log("PGR SiYi IP analyze skipped: video URL is not RTSP:", root.videoUrl, "reason:", reason)
            return
        }

        if (root.parsedCameraIp === "") {
            console.log("PGR SiYi IP analyze skipped: invalid RTSP URL:", root.videoUrl, "reason:", reason)
            return
        }

        if (root.lastAnalyzedVideoUrl === root.videoUrl) {
            return
        }

        root.lastAnalyzedVideoUrl = root.videoUrl

        console.log("PGR SiYi analyzeIp:", root.videoUrl, "parsed IP:", root.parsedCameraIp, "reason:", reason)
        root.camera.analyzeIp(root.parsedCameraIp)
    }

    function normalizeRtspUrl(url) {
        var value = String(url || "").trim()

        if (value === "") {
            return ""
        }

        // Fix common typo:
        // rtsp:/10.223.0.10:8554/main.264
        // -> rtsp://10.223.0.10:8554/main.264
        if (value.toLowerCase().indexOf("rtsp:/") === 0
                && value.toLowerCase().indexOf("rtsp://") !== 0) {
            return "rtsp://" + value.substring(6)
        }

        return value
    }

    Timer {
        id: analyzeIpStartupTimer

        interval: 800
        repeat: false
        running: false

        onTriggered: {
            root.updateCameraIpFromVideoUrl("startup timer")
        }
    }

    onVideoUrlChanged: {
        root.lastAnalyzedVideoUrl = ""
        analyzeIpStartupTimer.restart()
    }

    onCameraChanged: {
        root.lastAnalyzedVideoUrl = ""
        analyzeIpStartupTimer.restart()
    }

    Component.onCompleted: {
        console.log("PGR SiYi object:", siyi)
        console.log("PGR SiYi camera:", camera)
        console.log("PGR SiYi enableZoom:", camera ? camera.enableZoom : "no camera")
        console.log("PGR SiYi enableFocus:", camera ? camera.enableFocus : "no camera")
        console.log("PGR SiYi videoUrl:", root.videoUrl)
        console.log("PGR SiYi parsed IP:", root.parsedCameraIp)

        analyzeIpStartupTimer.start()
        Qt.callLater(root.initializeControlPanelPosition)
    }

    PGRStyle.PGRCameraStyle {
        id: style
    }

    // Visual-only host: preserve the source coordinate system and visibility.
    Item {
        objectName: "cameraControlsWidgetStack"
        parent: mainWindow.widgetPanelOverlay
        width: root.width
        height: root.height
        z: mainWindow.widgetPanelZ
        visible: root.visible
        enabled: root.enabled
        opacity: mainWindow.widgetPanelOpacity(root)
        transform: Matrix4x4 {
            matrix: mainWindow.widgetPanelTransform(root)
        }

        Shared.WidgetPanelSurface {
            id: panel

            // Keep the complete movable panel, including its drag/lock controls,
            // above the remaining children of this overlay.
            z: 100

            visible:
                root.controlsVisible
                && root.expanded
                && root.controlPanelPositionReady
            enabled: root.controlsVisible

            x: root.controlPanelX
            y: root.controlPanelY

            width: ScreenTools.defaultFontPixelWidth * 8
            height: controlsColumn.implicitHeight + 16
            radius: 10
            color: style.panelBackground
            border.width: 1
            border.color: style.panelBorder

            onHeightChanged: root.keepControlPanelInBounds(false)

            ColumnLayout {
                id: controlsColumn

                anchors.fill: parent

                anchors.leftMargin:
                    Math.max(
                        0,
                        (parent.width - root.cameraInnerButtonWidth) / 2
                    )

                anchors.rightMargin:
                    Math.max(
                        0,
                        (parent.width - root.cameraInnerButtonWidth) / 2
                    )

                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "CAM"
                    color: style.textPrimary
                    font.pixelSize: 10
                    font.bold: true
                }

                Shared.WidgetPanelActions {
                    Layout.alignment: Qt.AlignHCenter
                    orientation: Qt.Vertical
                    panelController: cameraPanelState
                    coordinateItem: root
                    locked: root.panelLocked

                    onLockToggleRequested: WidgetPanelSettings.cameraControlsLocked = !root.panelLocked
                    onCollapseRequested: root.expanded = false
                }


                PGRControls.PGRCameraButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.buttonHeight
                    visible: root.shouldShowControl(root.canZoom)
                    enabledState: root.canZoom

                    text: "Z+"
                    textSize: 11

                    idleColor: style.buttonIdle
                    activeColor: style.buttonActive
                    pressedColor: style.buttonPressed
                    borderColor: style.buttonBorder
                    textColor: style.textPrimary

                    onPressed: root.zoomIn()
                    onReleased: root.stopZoom()
                    onCanceled: root.stopZoom()
                }

                PGRControls.PGRCameraButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.buttonHeight
                    visible: root.shouldShowControl(root.canZoom)
                    enabledState: root.canZoom

                    text: "Z-"
                    textSize: 11

                    idleColor: style.buttonIdle
                    activeColor: style.buttonActive
                    pressedColor: style.buttonPressed
                    borderColor: style.buttonBorder
                    textColor: style.textPrimary

                    onPressed: root.zoomOut()
                    onReleased: root.stopZoom()
                    onCanceled: root.stopZoom()
                }

                PGRControls.PGRCameraButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.buttonHeight

                    visible: root.expanded
                             && (root.showUnavailableControls
                                 || root.canResetPosition)

                    enabledState: root.canResetPosition

                    text: "RST"
                    textSize: 9

                    idleColor: style.buttonIdle
                    activeColor: style.buttonActive
                    pressedColor: style.buttonPressed
                    borderColor: style.buttonBorder
                    textColor: style.textPrimary

                    onPressed: root.resetCameraPosition()
                }

                PGRControls.PGRCameraButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.buttonHeight
                    visible: root.shouldShowControl(root.canFocus)
                    enabledState: root.canFocus

                    text: "F+"
                    textSize: 11

                    idleColor: style.buttonIdle
                    activeColor: style.buttonActive
                    pressedColor: style.buttonPressed
                    borderColor: style.buttonBorder
                    textColor: style.textPrimary

                    onPressed: root.focusFar()
                    onReleased: root.stopFocus()
                    onCanceled: root.stopFocus()
                }

                PGRControls.PGRCameraButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.buttonHeight
                    visible: root.shouldShowControl(root.canFocus)
                    enabledState: root.canFocus

                    text: "F-"
                    textSize: 11

                    idleColor: style.buttonIdle
                    activeColor: style.buttonActive
                    pressedColor: style.buttonPressed
                    borderColor: style.buttonBorder
                    textColor: style.textPrimary

                    onPressed: root.focusNear()
                    onReleased: root.stopFocus()
                    onCanceled: root.stopFocus()
                }

            }
        }

        Shared.WidgetCollapsedHandle {
            visible: root.controlsVisible && !root.expanded && root.controlPanelPositionReady
            z: 100
            x: root.controlPanelX + Math.max(0, (panel.width - width) / 2)
            y: root.controlPanelY
            panelController: cameraPanelState
            coordinateItem: root
            collapsedWidth: root.collapsedPanelWidth
            collapsedPanelHeight: root.collapsedPanelHeight
            onExpandRequested: root.expanded = true
        }
    }

    // Visual-only host: preserve the source coordinate system and visibility.
    Item {
        objectName: "cameraLogsWidgetStack"
        parent: mainWindow.widgetPanelOverlay
        width: root.width
        height: root.height
        z: mainWindow.widgetPanelZ
        visible: root.visible
        enabled: root.enabled
        opacity: mainWindow.widgetPanelOpacity(root)
        transform: Matrix4x4 {
            matrix: mainWindow.widgetPanelTransform(root)
        }

        LocalCamera.PGRCameraLogPanel {
            anchors.fill: parent
            visible: root.logsVisible && root.debugStatusVisible
            panelMargin: root.panelMargin
            logText:
                "SIYI BACKEND\n"
                + "RAW URL: " + (root.rawVideoUrl !== "" ? root.rawVideoUrl : "-") + "\n"
                + "URL: " + (root.videoUrl !== "" ? root.videoUrl : "-") + "\n"
                + "URL FIX: " + (root.rtspUrlWasNormalized ? "YES" : "NO") + "\n"
                + "IP: " + (root.parsedCameraIp !== "" ? root.parsedCameraIp : "-") + "\n"
                + "OBJ: " + (root.hasCamera ? "OK" : "NO") + "\n"
                + "TCP: " + root.tcpDebugState + "\n"
                + "ERROR: " + root.tcpDebugError + "\n"
                + "ZOOM: " + root.canZoom + "\n"
                + "FOCUS: " + root.canFocus
        }
    }

}
