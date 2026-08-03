/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick
import QtQuick.Controls
import QtQuick.Window

import QGroundControl
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.Vehicle
import QGroundControl.Controllers

import "PGRCamera" as PGRCamera

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true

    // True when the whole video view is displayed as the small map PiP.
    // In this mode the video is only a preview, so nested MAIN/SUB PiP
    // controls and no-video status text are hidden.
    property bool compactPipMode: false

    // FlyViewVideo controls whether direct SIYI mouse movement is allowed.
    property bool directSiyiMouseControlEnabled: false

    // Exposed state used to disable the standard QGC full-video gesture layer.
    readonly property bool directSiyiMouseControlActive:
        pgrCameraMouseController.mouseControlActive

    readonly property bool directSiyiMouseContainsMouse:
        pgrCameraMouseController.containsMouse

    signal requestToggleFullScreen()

    Component.onCompleted: {
        console.log("PGR STEP5 QML LOADED: dedicated detached video receiver")
    }

    property double _ar:                QGroundControl.videoManager.gstreamerEnabled
                                            ? QGroundControl.videoManager.videoSize.width / QGroundControl.videoManager.videoSize.height
                                            : QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    // SIYI-compatible screen-fit modes:
    //   0 = Fit Width
    //   1 = Fit Height
    //   2 = Stretch
    // Clamp a legacy saved value 3 to Stretch.
    property int _fitMode: {
        var value = Number(
            QGroundControl
                .settingsManager
                .videoSettings
                .videoFit
                .rawValue
        )

        if (!isFinite(value)) {
            return 0
        }

        return Math.max(0, Math.min(2, value))
    }

    property bool _isMode_FIT_WIDTH:  _fitMode === 0
    property bool _isMode_FIT_HEIGHT: _fitMode === 1
    property bool _isMode_STRETCH:    _fitMode === 2

    // PGR/ZT6 substream UI state. Click the small MAIN/SUB window to swap which stream is primary.
    property bool   _pgrSubPrimary:     false
    property bool   _pgrSubCollapsed:   false
    property bool   _pgrMainCollapsed:  false

    // Internal MAIN/SUB PiP can be moved into a separate native window,
    // matching the standard QGC PiP detach behaviour.
    property bool   _pgrPipDetached:    false
    property bool   _pgrDetachedIsSub:  false

    readonly property bool _pgrSubAvailable: QGroundControl.videoManager.hasPgrZt6Substream
    readonly property bool _pgrSubEnabled:   QGroundControl.videoManager.pgrZt6SubstreamEnabled
    readonly property bool _pgrSubVisible:   _pgrSubAvailable
                                                && _pgrSubEnabled
                                                && !_pgrSubCollapsed
                                                && (!root.compactPipMode
                                                    || root._pgrPipDetached)
    readonly property bool _pgrSubDecoding:  QGroundControl.videoManager.pgrZt6SubstreamDecoding
    readonly property bool _pgrMainVideoActive: QGroundControl.videoManager.decoding

    // Keep the main Fly View video canvas visible while at least one stream
    // that belongs to this window is decoding. This is essential when MAIN is
    // detached and temporarily restarts: SUB remains full-size in Fly View and
    // must not disappear only because MAIN decoding became false.
    readonly property bool _pgrMainCanvasVideoActive:
        _pgrMainVideoActive
        || (_pgrSubDecoding && !_pgrSubDetached)

    readonly property bool _pgrSubUiActive:  _pgrSubAvailable

    // Keep MAIN and SUB PiP dimensions independent. MAIN uses a smaller
    // height so its wider 16:9 frame does not visually dominate the 5:4 SUB PiP.
    readonly property real _pgrMainPipHeight:
        ScreenTools.defaultFontPixelHeight * 8

    readonly property real _pgrSubPipHeight:
        ScreenTools.defaultFontPixelHeight * 12

    readonly property real _pgrMainPipAspect:
        _ar > 0 ? _ar : (16.0 / 9.0)

    readonly property real _pgrSubAspect: _pgrSubAvailable
                                    ? (640.0 / 512.0)
                                    : (QGroundControl.videoManager.thermalAspectRatio > 1.1
                                        ? QGroundControl.videoManager.thermalAspectRatio
                                        : (16.0 / 9.0))

    readonly property real _pgrMainPipWidth:
        _pgrMainPipHeight * _pgrMainPipAspect

    readonly property real _pgrSubPipWidth:
        _pgrSubPipHeight * _pgrSubAspect

    // Explicit derived states keep the layout readable and prevent a detached
    // PiP from accidentally resetting the other stream to its small geometry.
    readonly property bool _pgrMainDetached:
        _pgrPipDetached && !_pgrDetachedIsSub

    readonly property bool _pgrSubDetached:
        _pgrPipDetached && _pgrDetachedIsSub

    readonly property bool _pgrMainPipActive:
        _pgrSubVisible
        && _pgrSubPrimary
        && !_pgrPipDetached
        && !_pgrMainCollapsed

    readonly property bool _pgrSubPrimaryActive:
        _pgrSubVisible && _pgrSubPrimary && !_pgrSubDetached

    readonly property bool _pgrSubPipActive:
        _pgrSubVisible && !_pgrSubPrimary && !_pgrPipDetached

    // White standard QGC PiP icons.
    readonly property color _pgrPipIconColor: "white"
    readonly property color _pgrPipButtonColor: Qt.rgba(0.03, 0.08, 0.12, 0.88)
    readonly property color _pgrPipButtonBorderColor: Qt.rgba(1.0, 1.0, 1.0, 0.70)

    readonly property real _pgrPanelTopMargin: ((mainWindow && mainWindow.header) ? mainWindow.header.height : 0) + (ScreenTools.defaultFontPixelHeight * 0.5)

    function getWidth() {
        return videoBackground.getWidth()
    }
    function getHeight() {
        return videoBackground.getHeight()
    }

    function collapsePgrMainPip() {
        if (!root._pgrMainPipActive) {
            return
        }

        // MAIN is the principal receiver, so collapse affects only its PiP UI.
        // The receiver and RTSP stream remain active.
        root._pgrMainCollapsed = true
        console.log("PGR MAIN PiP collapsed")
    }

    function restorePgrMainPip() {
        root._pgrMainCollapsed = false
        console.log("PGR MAIN PiP restored")
    }

    function collapsePgrSubstream() {
        root._pgrSubPrimary = false
        root._pgrSubCollapsed = true
        QGroundControl.videoManager.setPgrZt6SubstreamEnabled(false)

        console.log("PGR SUB collapsed")
    }

    function restorePgrSubstream() {
        root._pgrSubCollapsed = false
        root._pgrSubPrimary = false
        QGroundControl.videoManager.setPgrZt6SubstreamEnabled(true)

        console.log("PGR SUB restored")
    }

    function detachPgrPip(isSub) {
        if (root._pgrPipDetached) {
            return
        }

        // Keep the opposite original stream full-size in Fly View. The
        // detached Window uses its own permanent QGCVideoBackground and
        // receiver; neither original MAIN nor SUB item changes QQuickWindow.
        root._pgrSubPrimary = !isSub
        root._pgrDetachedIsSub = isSub
        root._pgrPipDetached = true

        var detachedAspect =
            isSub ? root._pgrSubAspect : root._pgrMainPipAspect
        var requestedHeight =
            isSub ? root._pgrSubPipHeight : root._pgrMainPipHeight
        var detachedHeight = Math.max(
            requestedHeight,
            pgrDetachedWindow.minimumHeight,
            pgrDetachedWindow.minimumWidth / detachedAspect
        )

        pgrDetachedWindow.width = detachedHeight * detachedAspect
        pgrDetachedWindow.height = detachedHeight
        pgrDetachedWindow.show()
        pgrDetachedWindow.raise()
        pgrDetachedWindow.requestActivate()

        Qt.callLater(function() {
            QGroundControl.videoManager.startPgrDetachedStream(
                isSub,
                detachedVideo
            )

            console.log(
                "PGR STEP5 detached receiver start requested:",
                isSub ? "SUB" : "MAIN"
            )
        })

        console.log(
            "PGR PIP detached:",
            isSub ? "SUB" : "MAIN"
        )
    }

    function reattachPgrPip() {
        if (!root._pgrPipDetached) {
            pgrDetachedWindow.hide()
            return
        }

        var reattachedStreamIsSub = root._pgrDetachedIsSub

        // Stop only the dedicated detached receiver. The original MAIN/SUB
        // streams have remained active in Fly View for the entire operation.
        QGroundControl.videoManager.stopPgrDetachedStream()

        root._pgrPipDetached = false
        pgrDetachedWindow.hide()

        console.log(
            "PGR PIP reattached:",
            reattachedStreamIsSub ? "SUB" : "MAIN"
        )
    }

    property double _thermalHeightFactor: 0.85 //-- TODO

    Window {
        id: pgrDetachedWindow

        visible: false
        color: "black"
        modality: Qt.NonModal
        flags: Qt.Window

        minimumWidth:  ScreenTools.defaultFontPixelWidth * 30
        minimumHeight: ScreenTools.defaultFontPixelHeight * 10

        title: root._pgrDetachedIsSub
               ? qsTr("SUB Camera")
               : qsTr("MAIN Camera")

        // This video item permanently belongs to the detached QQuickWindow.
        // It is never moved between scene graphs.
        QGCVideoBackground {
            id: detachedVideo
            objectName: "detachedVideo"
            anchors.fill: parent
            visible: pgrDetachedWindow.visible
            z: 1
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            visible:
                pgrDetachedWindow.visible
                && !QGroundControl.videoManager.pgrDetachedStreamDecoding
            z: 10

            QGCLabel {
                anchors.centerIn: parent
                text: root._pgrDetachedIsSub
                      ? qsTr("SUB LOADING...")
                      : qsTr("MAIN LOADING...")
                color: "white"
                font.bold: true
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: detachedStreamLabel.contentWidth
                   + ScreenTools.defaultFontPixelWidth * 1.5
            height: detachedStreamLabel.contentHeight
                    + ScreenTools.defaultFontPixelHeight * 0.4
            color: Qt.rgba(0, 0, 0, 0.65)
            visible: pgrDetachedWindow.visible
            z: 20

            QGCLabel {
                id: detachedStreamLabel
                anchors.centerIn: parent
                text: root._pgrDetachedIsSub ? qsTr("SUB") : qsTr("MAIN")
                color: "white"
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        // Reattach when the reusable native Window becomes hidden.
        onVisibleChanged: {
            if (!visible && root._pgrPipDetached) {
                Qt.callLater(function() {
                    if (root._pgrPipDetached) {
                        root.reattachPgrPip()
                    }
                })
            }
        }
    }

    Image {
        id:             noVideo
        anchors.fill:   parent
        source:         "/res/NoVideoBackground.jpg"
        fillMode:       Image.PreserveAspectCrop
        visible:        !root._pgrMainCanvasVideoActive

        Rectangle {
            id:                 noVideoPanel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:     parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 6
            width:              noVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
            height:             noVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
            radius:             ScreenTools.defaultFontPixelWidth / 2
            color:              Qt.rgba(0, 0, 0, 0.5)
            visible:            !root.compactPipMode

            QGCLabel {
                id:                 noVideoLabel
                text:               QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue ? qsTr("WAITING FOR VIDEO") : qsTr("VIDEO DISABLED")
                font.bold:          true
                color:              "white"
                font.pointSize:     useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
                anchors.centerIn:   parent
            }
        }
    }

    Rectangle {
        id:             videoBackground
        anchors.fill:   parent
        color:          "black"
        visible:        root._pgrMainCanvasVideoActive

        function getWidth() {
            if (_ar > 0.0 && _isMode_FIT_HEIGHT) {
                return root.height * _ar
            }

            // Fit Width and Stretch both use the full available width.
            return root.width
        }

        function getHeight() {
            if (_ar > 0.0 && _isMode_FIT_WIDTH) {
                return root.width / _ar
            }

            // Fit Height and Stretch both use the full available height.
            return root.height
        }

        // Direct SIYI camera movement is placed between the full-size
        // primary stream and the small MAIN/SUB PiP.
        //
        // MAIN primary: MAIN z=10, mouse z=60, small SUB z=70.
        // SUB primary:  SUB  z=40, mouse z=60, small MAIN z=80.
        //
        // Therefore the primary video remains draggable over its entire
        // rendered area, while the small PiP stays above it and keeps its
        // own click/collapse controls.
        PGRCamera.PGRCameraMouseController {
            id: pgrCameraMouseController

            anchors.fill: parent
            z: 60

            controlEnabled:
                root.directSiyiMouseControlEnabled

            onRequestToggleFullScreen: {
                root.requestToggleFullScreen()
            }
        }

        Component {
            id: videoBackgroundComponent
            QGCVideoBackground {
                id:             videoContent
                objectName:     "videoContent"

                Connections {
                    target: QGroundControl.videoManager
                    function onImageFileChanged(filename) {
                        videoContent.grabToImage(function(result) {
                            if (!result.saveToFile(filename)) {
                                console.error('Error capturing video frame');
                            }
                        });
                    }
                }

                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen && !root._pgrSubPrimary
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen && !root._pgrSubPrimary
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen && !root._pgrSubPrimary
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen && !root._pgrSubPrimary
                }
            }
        }

        Item {
            id: mainVideoItem

            // Full-size MAIN layout. The PiP state releases right and bottom,
            // allowing width and height to define the smaller MAIN PiP.
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom

            visible:
                root._pgrMainVideoActive
                && !root._pgrMainDetached
                && !(root._pgrMainCollapsed && root._pgrSubPrimary)
            z: 10

            states: [
                State {
                    name: "mainVideoPip"
                    when: root._pgrMainPipActive

                    AnchorChanges {
                        target: mainVideoItem

                        anchors.right:            undefined
                        anchors.bottom:           undefined
                        anchors.horizontalCenter: undefined
                        anchors.verticalCenter:   undefined
                        anchors.top:              videoBackground.top
                        anchors.left:             videoBackground.left
                    }

                    PropertyChanges {
                        target: mainVideoItem

                        width:              root._pgrMainPipWidth
                        height:             root._pgrMainPipHeight
                        anchors.topMargin:  root._pgrPanelTopMargin
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 12
                        z:                  80
                    }
                }


            ]

            Loader {
                id: mainVideoLoader

                // Apply Video Screen Fit to the actual MAIN renderer.
                //
                // Full-size MAIN:
                //   Fit Width  -> full width, proportional height
                //   Fit Height -> full height, proportional width
                //   Stretch    -> full width and full height
                //
                // Small MAIN PiP:
                //   keep filling the fixed PiP frame exactly as before.
                anchors.centerIn: parent

                width:
                    root._pgrMainPipActive
                        ? parent.width
                        : videoBackground.getWidth()

                height:
                    root._pgrMainPipActive
                        ? parent.height
                        : videoBackground.getHeight()

                visible: root._pgrMainVideoActive
                sourceComponent: videoBackgroundComponent

                property bool videoDisabled:
                    QGroundControl.settingsManager.videoSettings.videoSource.rawValue
                    === QGroundControl.settingsManager.videoSettings.disabledVideoSource
            }

            // MAIN label stays inside the actual video/PiP frame.
            Rectangle {
                anchors.right: parent.right
                anchors.top:   parent.top

                width:  mainSmallLabel.contentWidth
                        + ScreenTools.defaultFontPixelWidth * 1.5
                height: mainSmallLabel.contentHeight
                        + ScreenTools.defaultFontPixelHeight * 0.4
                radius: ScreenTools.defaultFontPixelWidth * 0.25
                color:  Qt.rgba(0, 0, 0, 0.65)

                visible: root._pgrMainPipActive

                z: 100

                QGCLabel {
                    id: mainSmallLabel

                    anchors.centerIn: parent
                    text: qsTr("MAIN")
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            // Click the small MAIN PiP to switch back to MAIN primary.
            MouseArea {
                id: mainPipMouseArea

                anchors.fill: parent
                enabled: root._pgrMainPipActive
                visible: enabled

                acceptedButtons: Qt.LeftButton
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: 50

                onClicked: {
                    root._pgrSubPrimary = false
                    console.log(
                        "PGR MAIN PIP clicked, subPrimary:",
                        root._pgrSubPrimary
                    )
                }
            }

            // Standard QGC PiP-to-window control. The SVG includes its own
            // styling, so no extra Rectangle, border or recoloring is applied.
            Image {
                id: mainPipDetachButton

                source: "/qmlimages/PiP.svg"
                mipmap: true
                fillMode: Image.PreserveAspectFit

                anchors.left: parent.left
                anchors.top:  parent.top

                width:  ScreenTools.defaultFontPixelHeight * 2.5
                height: ScreenTools.defaultFontPixelHeight * 2.5
                sourceSize.height: height

                visible:
                    mainPipMouseArea.enabled
                    && !root.compactPipMode
                    && !ScreenTools.isMobile
                    && (mainPipMouseArea.containsMouse
                        || mainPipDetachMouseArea.containsMouse
                        || mainPipCollapseMouseArea.containsMouse)

                z: 140

                MouseArea {
                    id: mainPipDetachMouseArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    propagateComposedEvents: false
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouse) => {
                        mouse.accepted = true
                        root.detachPgrPip(false)
                    }
                }
            }

            // MAIN now has the same standard QGC collapse control as the
            // regular map/video PiP.
            Image {
                id: mainPipCollapseButton

                source: "/qmlimages/pipHide.svg"
                mipmap: true
                fillMode: Image.PreserveAspectFit

                anchors.left:   parent.left
                anchors.bottom: parent.bottom

                width:  ScreenTools.defaultFontPixelHeight * 2.5
                height: ScreenTools.defaultFontPixelHeight * 2.5
                sourceSize.height: height

                visible:
                    mainPipMouseArea.enabled
                    && !root.compactPipMode
                    && (ScreenTools.isMobile
                        || mainPipMouseArea.containsMouse
                        || mainPipDetachMouseArea.containsMouse
                        || mainPipCollapseMouseArea.containsMouse)

                z: 140

                MouseArea {
                    id: mainPipCollapseMouseArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    propagateComposedEvents: false
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouse) => {
                        mouse.accepted = true
                        root.collapsePgrMainPip()
                    }
                }
            }

        }

        // Restore the collapsed MAIN PiP. This follows the standard QGC
        // PipView show-button styling.
        Rectangle {
            id: pgrMainCollapsedButton

            anchors.top:        parent.top
            anchors.topMargin:  root._pgrPanelTopMargin
            anchors.left:       parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 12

            width:  ScreenTools.defaultFontPixelHeight * 2
            height: ScreenTools.defaultFontPixelHeight * 2
            radius: ScreenTools.defaultFontPixelHeight / 3
            color:  Qt.rgba(0, 0, 0, 0.75)

            visible:
                root._pgrMainCollapsed
                && root._pgrSubPrimary
                && root._pgrSubVisible
                && !root.compactPipMode
                && !root._pgrPipDetached

            z: 90

            Image {
                anchors.centerIn: parent

                width:  parent.width * 0.75
                height: parent.height * 0.75
                sourceSize.height: height

                source: "/res/buttonRight.svg"
                mipmap: true
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                cursorShape: Qt.PointingHandCursor

                onClicked: root.restorePgrMainPip()
            }
        }

        //-- Thermal/Substream Image
        Item {
            id:                 thermalItem
            clip:               true

            property bool pgrSubstreamMode: root._pgrSubAvailable

            width:              root._pgrSubPipWidth
            height:             root._pgrSubPipHeight
            anchors.top:        parent.top
            anchors.topMargin:  root._pgrPanelTopMargin
            anchors.left:       parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 12
            visible:            !root._pgrSubDetached
                                && (root._pgrSubVisible
                                    || (!pgrSubstreamMode && QGroundControl.videoManager.hasThermal
                                        && (!_camera || _camera.thermalMode !== MavlinkCameraControl.THERMAL_OFF)))
            z:                  70

            states: [
                State {
                    name: "subPrimary"
                    when: root._pgrSubPrimaryActive

                    AnchorChanges {
                        target: thermalItem

                        anchors.top:              undefined
                        anchors.left:             undefined
                        anchors.horizontalCenter: videoBackground.horizontalCenter
                        anchors.verticalCenter:   videoBackground.verticalCenter
                    }

                    PropertyChanges {
                        target: thermalItem

                        width:              videoBackground.width
                        height:             videoBackground.height
                        anchors.topMargin:  0
                        anchors.leftMargin: 0
                        z:                  40
                    }
                }


            ]

            function pipOrNot() {
                // Layout is controlled by states. Keep this function for existing camera thermal mode callbacks.
            }

            Connections {
                target:                 _camera
                function onThermalModeChanged() {
                    thermalItem.pipOrNot()
                }
            }

            QGCVideoBackground {
                id:         thermalVideo
                objectName: "thermalVideo"

                // Keep the PiP/state container untouched. Apply screen fit
                // only to the actual SUB renderer when SUB is primary.
                anchors.centerIn: parent

                width: {
                    if (!root._pgrSubPrimaryActive) {
                        return parent.width
                    }

                    if (root._pgrSubAspect > 0.0
                            && root._isMode_FIT_HEIGHT) {
                        return parent.height * root._pgrSubAspect
                    }

                    // Fit Width and Stretch.
                    return parent.width
                }

                height: {
                    if (!root._pgrSubPrimaryActive) {
                        return parent.height
                    }

                    if (root._pgrSubAspect > 0.0
                            && root._isMode_FIT_WIDTH) {
                        return parent.width / root._pgrSubAspect
                    }

                    // Fit Height and Stretch.
                    return parent.height
                }

                z: 1

                opacity:
                    thermalItem.pgrSubstreamMode || !_camera
                        ? 1.0
                        : (_camera.thermalMode
                           === MavlinkCameraControl.THERMAL_BLEND
                           ? _camera.thermalOpacity / 100
                           : 1.0)

                // Grid follows the rendered SUB image, not thermalItem.
                Rectangle {
                    color:  Qt.rgba(1, 1, 1, 0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.33

                    visible:
                        root._showGrid
                        && !QGroundControl.videoManager.fullScreen
                        && root._pgrSubPrimaryActive
                }

                Rectangle {
                    color:  Qt.rgba(1, 1, 1, 0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.66

                    visible:
                        root._showGrid
                        && !QGroundControl.videoManager.fullScreen
                        && root._pgrSubPrimaryActive
                }

                Rectangle {
                    color:  Qt.rgba(1, 1, 1, 0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.33

                    visible:
                        root._showGrid
                        && !QGroundControl.videoManager.fullScreen
                        && root._pgrSubPrimaryActive
                }

                Rectangle {
                    color:  Qt.rgba(1, 1, 1, 0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.66

                    visible:
                        root._showGrid
                        && !QGroundControl.videoManager.fullScreen
                        && root._pgrSubPrimaryActive
                }
            }

            // Click on SUB toggles MAIN/SUB positions.
            MouseArea {
                id:             subPipMouseArea

                anchors.fill:   parent
                // The full-size SUB stream must not cover the SIYI
                // camera-drag MouseArea. When SUB is primary, switching
                // back is handled by the small MAIN PiP MouseArea.
                enabled:        thermalItem.pgrSubstreamMode
                                && root._pgrSubPipActive
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z:              50
                onClicked: {
                    root._pgrSubPrimary = !root._pgrSubPrimary
                    console.log("PGR SUB clicked, subPrimary:", root._pgrSubPrimary)
                }
            }

            // Rectangle {
            //     anchors.fill:   parent
            //     color:          "transparent"
            //     border.width:   thermalItem.pgrSubstreamMode ? 1 : 0
            //     border.color:   Qt.rgba(1, 1, 1, 0.65)
            //     visible:        thermalItem.pgrSubstreamMode
            //     z:              80
            // }

            Rectangle {
                anchors.right: parent.right
                anchors.top:   parent.top

                width:   substreamLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 1.5
                height:  substreamLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.4
                radius:  ScreenTools.defaultFontPixelWidth * 0.25
                color:   Qt.rgba(0, 0, 0, 0.65)
                visible:
                    (thermalItem.pgrSubstreamMode
                     && root._pgrSubPipActive)
                    || root._pgrSubDetached
                z: 100

                QGCLabel {
                    id:               substreamLabel
                    anchors.centerIn: parent
                    text:             qsTr("SUB")
                    color:            "white"
                    font.bold:        true
                    font.pointSize:   ScreenTools.smallFontPointSize
                }
            }

            // Standard QGC PiP-to-window control.
            Image {
                id: subPipDetachButton

                source: "/qmlimages/PiP.svg"
                mipmap: true
                fillMode: Image.PreserveAspectFit

                anchors.left: parent.left
                anchors.top:  parent.top

                width:  ScreenTools.defaultFontPixelHeight * 2.5
                height: ScreenTools.defaultFontPixelHeight * 2.5
                sourceSize.height: height

                visible:
                    subPipMouseArea.enabled
                    && !root.compactPipMode
                    && !ScreenTools.isMobile
                    && (subPipMouseArea.containsMouse
                        || subPipDetachMouseArea.containsMouse
                        || subPipCollapseMouseArea.containsMouse)

                z: 145

                MouseArea {
                    id: subPipDetachMouseArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    propagateComposedEvents: false
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouse) => {
                        mouse.accepted = true
                        root.detachPgrPip(true)
                    }
                }
            }

            // Standard QGC collapse control. The complete background and
            // chevrons come from pipHide.svg.
            Image {
                id: subPipCollapseButton

                source: "/qmlimages/pipHide.svg"
                mipmap: true
                fillMode: Image.PreserveAspectFit

                anchors.left:   parent.left
                anchors.bottom: parent.bottom

                width:  ScreenTools.defaultFontPixelHeight * 2.5
                height: ScreenTools.defaultFontPixelHeight * 2.5
                sourceSize.height: height

                visible:
                    subPipMouseArea.enabled
                    && !root.compactPipMode
                    && (ScreenTools.isMobile
                        || subPipMouseArea.containsMouse
                        || subPipDetachMouseArea.containsMouse
                        || subPipCollapseMouseArea.containsMouse)

                z: 145

                MouseArea {
                    id: subPipCollapseMouseArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    propagateComposedEvents: false
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouse) => {
                        mouse.accepted = true
                        root.collapsePgrSubstream()
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width:            substreamLoadingLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 2
                height:           substreamLoadingLabel.contentHeight + ScreenTools.defaultFontPixelHeight
                radius:           ScreenTools.defaultFontPixelWidth / 2
                color:            Qt.rgba(0, 0, 0, 0.72)
                visible:          thermalItem.pgrSubstreamMode
                                  && root._pgrSubVisible
                                  && !root._pgrSubDecoding
                z:                120

                QGCLabel {
                    id:                 substreamLoadingLabel
                    anchors.centerIn:   parent
                    text:               qsTr("SUB LOADING...")
                    color:              "white"
                    font.bold:          true
                    font.pointSize:     ScreenTools.smallFontPointSize
                }
            }
        }

        // Collapsed SUB uses the same restore icon as the standard QGC PiP.
        Rectangle {
            id: pgrSubCollapsedButton

            width:  ScreenTools.defaultFontPixelHeight * 2
            height: ScreenTools.defaultFontPixelHeight * 2

            anchors.top:        parent.top
            anchors.topMargin:  root._pgrPanelTopMargin
            anchors.left:       parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 12

            radius: ScreenTools.defaultFontPixelHeight / 3
            color:  Qt.rgba(0, 0, 0, 0.75)

            visible: root._pgrSubAvailable
                     && root._pgrSubCollapsed
                     && !root.compactPipMode
                     && !root._pgrPipDetached
            z: 90

            Image {
                anchors.centerIn: parent

                width:  parent.width * 0.75
                height: parent.height * 0.75
                sourceSize.height: height

                source: "/res/buttonRight.svg"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                cursorShape: Qt.PointingHandCursor

                onClicked: root.restorePgrSubstream()
            }
        }

        //-- Zoom
        PinchArea {
            id:             pinchZoom
            // PinchArea spans the entire video and otherwise consumes
            // the left-button press before PGRCameraMouseController.
            enabled:        _hasZoom
                            && !root._pgrSubPrimary
                            && !root.directSiyiMouseControlActive
            anchors.fill:   parent
            onPinchStarted: pinchZoom.zoom = 0
            onPinchUpdated: {
                if(_hasZoom) {
                    var z = 0
                    if(pinch.scale < 1) {
                        z = Math.round(pinch.scale * -10)
                    } else {
                        z = Math.round(pinch.scale)
                    }
                    if(pinchZoom.zoom != z) {
                        _camera.stepZoom(z)
                    }
                }
            }
            property int zoom: 0
        }
    }
}
