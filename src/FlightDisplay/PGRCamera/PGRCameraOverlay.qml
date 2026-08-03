import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FlightDisplay
import QGroundControl.ScreenTools
import SiYi.Object 1.0

import "controls" as PGRControls
import "style" as PGRStyle

Item {
    id: root
    anchors.fill: parent
    z: 1000

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

    // Mirror the original SIYI QGC approach: bind a local QML property
    // directly to SiYiCamera::zoomMultiple.
    readonly property int zoomMultipleValue:
        root.hasCamera
            ? Number(root.camera.zoomMultiple)
            : 0

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

    // Supplied from the actual Fly View ToolStrip geometry.
    // cameraPanelWidth is the inner Takeoff/Return action-button width.
    property real cameraPanelX: panelMargin
    property real cameraPanelY: panelMargin
    property real cameraPanelWidth: headerButtonWidth

    function shouldShowControl(capability) {
        return root.expanded && (root.showUnavailableControls || capability)
    }

    function showZoomMultiple(rawZoomMultiple, reason) {
        if (!root.controlsVisible) {
            return
        }

        var value = Number(rawZoomMultiple)

        if (isNaN(value) || value <= 0) {
            console.log(
                "PGR camera: invalid zoom multiple:",
                rawZoomMultiple,
                "reason:", reason
            )
            return
        }

        zoomMultipleText.text = (value / 10).toFixed(1)
        zoomMultiplePopup.visible = true
        zoomMultiplePopupTimer.restart()

        console.log(
            "PGR camera: zoom multiple:",
            zoomMultipleText.text,
            "raw:", value,
            "reason:", reason
        )
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
            zoomMultiplePopupTimer.stop()
            zoomMultiplePopup.visible = false
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

    // This follows the original SIYI pattern: a local bound QML property
    // reacts when SiYiCamera::zoomMultiple changes.
    onZoomMultipleValueChanged: {
        root.showZoomMultiple(
            root.zoomMultipleValue,
            "QML property binding"
        )
    }

    Component.onCompleted: {
        console.log("PGR SiYi object:", siyi)
        console.log("PGR SiYi camera:", camera)
        console.log("PGR SiYi enableZoom:", camera ? camera.enableZoom : "no camera")
        console.log("PGR SiYi enableFocus:", camera ? camera.enableFocus : "no camera")
        console.log("PGR SiYi videoUrl:", root.videoUrl)
        console.log("PGR SiYi parsed IP:", root.parsedCameraIp)

        analyzeIpStartupTimer.start()
    }

    PGRStyle.PGRCameraStyle {
        id: style
    }

    // SIYI zoom-multiple notification.
    // The camera reports zoomMultiple in tenths: 10 -> 1.0, 11 -> 1.1, etc.
    Rectangle {
        id: zoomMultiplePopup

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6

        z: 100
        visible: false

        width: Math.max(52, zoomMultipleText.implicitWidth + 20)
        height: zoomMultipleText.implicitHeight + 12
        radius: style.buttonRadius

        color: style.panelBackground
        border.width: 1
        border.color: style.panelBorder

        Text {
            id: zoomMultipleText

            anchors.centerIn: parent

            text: "1.0"
            color: style.textPrimary
            font.pixelSize: 24
            font.bold: true
        }

        Timer {
            id: zoomMultiplePopupTimer

            interval: 5000
            repeat: false
            running: false

            onTriggered: {
                zoomMultiplePopup.visible = false
            }
        }

        Connections {
            target: root.hasCamera ? root.camera : null
            ignoreUnknownSignals: true

            function onIsConnectedChanged() {
                if (!root.camera.isConnected) {
                    zoomMultiplePopupTimer.stop()
                    zoomMultiplePopup.visible = false
                }
            }
        }
    }

    Rectangle {
        id: panel

        visible: root.controlsVisible
        enabled: root.controlsVisible

        x:
            Math.max(
                0,
                root.cameraPanelX
                    + (
                        root.cameraPanelWidth
                        + root.placementReferencePadding * 2
                        - width
                    ) / 2
            )

        y: Math.max(0, root.cameraPanelY)

        width: ScreenTools.defaultFontPixelWidth * 8
        height: controlsColumn.implicitHeight + 16
        radius: 10
        color: style.panelBackground
        border.width: 1
        border.color: style.panelBorder

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