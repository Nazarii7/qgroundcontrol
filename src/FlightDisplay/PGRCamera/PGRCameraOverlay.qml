import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.ScreenTools
import SiYi.Object 1.0

import "controls" as PGRControls
import "style" as PGRStyle

Item {
    id: root
    anchors.fill: parent
    // Camera controls are interactive and must stay above every OSD item.
    z: 10000

    // No full-screen MouseArea here.
    // Only small buttons are interactive, so the main video/gimbal/tracking area remains safe.
    visible: true

    property bool expanded: true

    readonly property bool controlsVisible:
        DropWidgetSettings.cameraControlsVisible

    readonly property bool logsVisible:
        DropWidgetSettings.cameraLogsVisible

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
        DropWidgetSettings.cameraControlsLocked

    property real controlPanelX: -1
    property real controlPanelY: -1
    property bool controlPanelPositionReady: false
    property bool controlPanelDragging: false
    property real dragStartPointerX: 0
    property real dragStartPointerY: 0
    property real dragStartPanelX: 0
    property real dragStartPanelY: 0

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
        return Qt.point(
            Math.max(0, Math.min(root.width - panel.width, x)),
            Math.max(0, Math.min(root.height - panel.height, y))
        )
    }

    function initializeControlPanelPosition() {
        if (root.width <= 0 || root.height <= 0) {
            return
        }

        var savedX = Number(DropWidgetSettings.cameraControlsX)
        var savedY = Number(DropWidgetSettings.cameraControlsY)
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

        controlPanelX = position.x
        controlPanelY = position.y
        controlPanelPositionReady = true

        // Persist the corrected coordinates once. This prevents the obsolete
        // overlapping position from being restored on the next application
        // start while leaving every valid user-moved position untouched.
        if (useDefaultPosition && savedX >= 0 && savedY >= 0) {
            DropWidgetSettings.setCameraControlsPosition(
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

    function applyControlPanelPosition(pointerPoint) {
        var position = boundedControlPanelPosition(
            dragStartPanelX + pointerPoint.x - dragStartPointerX,
            dragStartPanelY + pointerPoint.y - dragStartPointerY
        )

        controlPanelX = position.x
        controlPanelY = position.y
    }

    function keepControlPanelInBounds(savePosition) {
        if (!controlPanelPositionReady
                || root.width <= 0
                || root.height <= 0) {
            return
        }

        var position = boundedControlPanelPosition(
            controlPanelX,
            controlPanelY
        )

        controlPanelX = position.x
        controlPanelY = position.y

        if (savePosition) {
            DropWidgetSettings.setCameraControlsPosition(
                controlPanelX,
                controlPanelY
            )
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

    Rectangle {
        id: panel

        // Keep the complete movable panel, including its drag/lock controls,
        // above the remaining children of this overlay.
        z: 100

        visible:
            root.controlsVisible
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

            // A single centered lock is also the drag handle. A short click
            // toggles the lock; dragging is available only while unlocked.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                Rectangle {
                    id: cameraLockButton

                    anchors.centerIn: parent

                    width: 22
                    height: 22
                    radius: 6
                    scale:
                        cameraLockMouseArea.pressed
                        && !cameraLockMouseArea.dragMoved
                            ? 0.92
                            : 1.0

                    color:
                        cameraLockMouseArea.pressed
                            ? style.buttonPressed
                            : cameraLockMouseArea.containsMouse
                              ? style.buttonActive
                              : root.panelLocked
                                ? Qt.rgba(1, 1, 1, 0.08)
                                : style.buttonActive
                    border.width: 1
                    border.color:
                        root.panelLocked
                            ? Qt.rgba(1, 1, 1, 0.18)
                            : style.buttonBorder

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 90 }
                    }

                    QGCColoredImage {
                        anchors.centerIn: parent
                        width: 12
                        height: width
                        sourceSize.width: width
                        source:
                            root.panelLocked
                                ? "qrc:/InstrumentValueIcons/lock-closed.svg"
                                : "qrc:/InstrumentValueIcons/lock-open.svg"
                        color: style.textPrimary
                        mipmap: true
                    }

                    MouseArea {
                        id: cameraLockMouseArea

                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape:
                            root.panelLocked
                                ? Qt.PointingHandCursor
                                : Qt.SizeAllCursor

                        property bool dragMoved: false
                        readonly property real dragThreshold: 4

                        function pointerInRoot(mouse) {
                            return mapToItem(root, mouse.x, mouse.y)
                        }

                        onPressed: function(mouse) {
                            dragMoved = false
                            root.controlPanelDragging = false

                            if (!root.panelLocked) {
                                var pointerPoint = pointerInRoot(mouse)
                                root.controlPanelDragging = true
                                root.dragStartPointerX = pointerPoint.x
                                root.dragStartPointerY = pointerPoint.y
                                root.dragStartPanelX = root.controlPanelX
                                root.dragStartPanelY = root.controlPanelY
                            }

                            mouse.accepted = true
                        }

                        onPositionChanged: function(mouse) {
                            if (!pressed
                                    || root.panelLocked
                                    || !root.controlPanelDragging) {
                                return
                            }

                            var pointerPoint = pointerInRoot(mouse)
                            var deltaX =
                                pointerPoint.x - root.dragStartPointerX
                            var deltaY =
                                pointerPoint.y - root.dragStartPointerY

                            if (!dragMoved
                                    && Math.abs(deltaX) < dragThreshold
                                    && Math.abs(deltaY) < dragThreshold) {
                                return
                            }

                            dragMoved = true
                            root.applyControlPanelPosition(pointerPoint)
                            mouse.accepted = true
                        }

                        onReleased: function(mouse) {
                            if (root.controlPanelDragging && dragMoved) {
                                root.applyControlPanelPosition(
                                    pointerInRoot(mouse)
                                )
                                root.keepControlPanelInBounds(true)
                            } else {
                                DropWidgetSettings.cameraControlsLocked =
                                    !root.panelLocked
                            }

                            root.controlPanelDragging = false
                            mouse.accepted = true
                        }

                        onCanceled: {
                            if (root.controlPanelDragging && dragMoved) {
                                root.keepControlPanelInBounds(true)
                            }

                            root.controlPanelDragging = false
                            dragMoved = false
                        }
                    }
                }
            }

            PGRControls.PGRCameraButton {
                Layout.fillWidth: true
                Layout.preferredHeight: root.cameraHeaderHeight

                // Horizontal compact header, matching the requested layout.
                text: "CAM"
                textSize: 9
                active: root.expanded && root.hasCamera

                idleColor: style.buttonIdle
                activeColor: style.buttonActive
                pressedColor: style.buttonPressed
                borderColor: style.buttonBorder
                textColor: style.textPrimary

                onClicked: {
                    root.expanded = !root.expanded
                }
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

    Rectangle {
        id: debugStatusPanel

        visible:
            root.logsVisible
            && root.debugStatusVisible

        anchors.right: parent.right
        anchors.rightMargin: root.panelMargin

        y: Math.round((parent.height - height) / 2)

        width: debugStatusText.implicitWidth + 16
        height: debugStatusText.implicitHeight + 10
        radius: 6

        color: Qt.rgba(0, 0, 0, 0.70)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.20)

        Text {
            id: debugStatusText

            anchors.centerIn: parent

            color: "white"
            font.pixelSize: 10
            lineHeight: 1.1

            text:
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
