/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtPositioning
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.ScreenTools
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.Vehicle
import QGroundControl.Controllers
import QGroundControl.FactSystem
import QGroundControl.FactControls

import SiYi.Object 1.0
import "../../FlightDisplay/Shared/Widget" as Shared

Shared.WidgetPanelSurface {
    id: root

    implicitWidth:  Math.max(ScreenTools.defaultFontPixelWidth * 17, 138)
    implicitHeight: expanded ? mainLayout.implicitHeight + (_margins * 2) : 52
    width:          implicitWidth
    height:         implicitHeight

    color:        expanded ? pgrStyle.panelBackground : "transparent"
    radius:       pgrStyle.panelRadius
    border.width: expanded ? 1 : 0
    surfaceInputEnabled: expanded
    border.color: pgrStyle.panelBorder

    // The widget must remain present over both map and video, even when
    // neither a vehicle nor a camera is currently connected.
    visible: true

    // Supplied by the FlightDisplay layer. Keeping this as a generic object
    // keeps the settings and popup ownership in the FlightDisplay layer.
    property var widgetSettings: null

    // The top-right Fly View layer hosts this control inside a non-modal
    // Popup so it can move freely across the complete flight view.
    property var movementHost: null
    property Item movementBounds: null
    property real movementTopInset: 0

    readonly property bool panelLocked:
        widgetSettings ? Boolean(widgetSettings.photoVideoLocked) : true

    property bool expanded: true
    readonly property bool _panelDragging: photoPanelHost.panelController.dragging

    Shared.WidgetPanelHost {
        id: photoPanelHost
        movementHost: root.movementHost
        boundsItem: root.movementBounds
        topInset: root.movementTopInset
        locked: root.panelLocked
        enabled: root.visible && root.enabled
        onPositionCommitted: root.saveHostPosition()
    }

    property real _margins:      Math.max(7, ScreenTools.defaultFontPixelHeight * 0.45)
    property real _smallMargins: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.5)

    property var _activeVehicle: globals.activeVehicle
    property var _cameraManager:
        _activeVehicle && _activeVehicle.cameraManager
            ? _activeVehicle.cameraManager
            : null
    property var _camera:
        _cameraManager && _cameraManager.currentCameraInstance
            ? _cameraManager.currentCameraInstance
            : null

    property var _siyiCamera: SiYi.camera

    property bool _localPhotoMode: false

    readonly property bool _hasMavlinkCamera:
        _camera !== null && _camera !== undefined

    readonly property bool _hasSiyiCamera:
        _siyiCamera !== null && _siyiCamera !== undefined

    readonly property bool _siyiConnected:
        _hasSiyiCamera && Boolean(_siyiCamera.isConnected)

    // Prefer a connected SIYI camera. Fall back to MAVLink when SIYI is not
    // connected. When no MAVLink camera exists, keep the SIYI-facing UI
    // visible but disabled until the SIYI TCP connection becomes available.
    readonly property bool _usingSiyi:
        _siyiConnected || !_hasMavlinkCamera

    readonly property bool _cameraInPhotoMode:
        _usingSiyi
            ? _localPhotoMode
            : (_hasMavlinkCamera
               && _camera.cameraMode === MavlinkCameraControl.CAM_MODE_PHOTO)

    readonly property bool _cameraInVideoMode:
        !_cameraInPhotoMode

    readonly property bool _mavlinkVideoCaptureIdle:
        !_hasMavlinkCamera
        || _camera.videoCaptureStatus
            === MavlinkCameraControl.VIDEO_CAPTURE_STATUS_STOPPED

    readonly property bool _mavlinkPhotoCaptureSingleIdle:
        !_hasMavlinkCamera
        || _camera.photoCaptureStatus
            === MavlinkCameraControl.PHOTO_CAPTURE_IDLE

    readonly property bool _mavlinkPhotoCaptureIntervalIdle:
        !_hasMavlinkCamera
        || _camera.photoCaptureStatus
            === MavlinkCameraControl.PHOTO_CAPTURE_INTERVAL_IDLE

    readonly property bool _mavlinkPhotoCaptureIdle:
        _mavlinkPhotoCaptureSingleIdle
        || _mavlinkPhotoCaptureIntervalIdle

    readonly property bool _siyiRecording:
        _usingSiyi
        && _hasSiyiCamera
        && Boolean(_siyiCamera.isRecording)

    readonly property bool _mavlinkRecording:
        !_usingSiyi
        && _hasMavlinkCamera
        && _camera.videoCaptureStatus
            === MavlinkCameraControl.VIDEO_CAPTURE_STATUS_RUNNING

    readonly property bool _mavlinkPhotoInProgress:
        !_usingSiyi
        && _hasMavlinkCamera
        && _camera.photoCaptureStatus
            === MavlinkCameraControl.PHOTO_CAPTURE_IN_PROGRESS

    readonly property bool _isShootingInCurrentMode:
        _cameraInPhotoMode
            ? _mavlinkPhotoInProgress
            : (_siyiRecording || _mavlinkRecording)

    readonly property bool _canRecordVideo:
        _usingSiyi
            ? (_siyiConnected && Boolean(_siyiCamera.enableVideo))
            : (_hasMavlinkCamera
               && Boolean(_camera.capturesVideo)
               && (_mavlinkVideoCaptureIdle || _mavlinkRecording))

    readonly property bool _canTakePhoto:
        _usingSiyi
            ? (_siyiConnected && Boolean(_siyiCamera.enablePhoto))
            : (_hasMavlinkCamera
               && Boolean(_camera.capturesPhotos)
               && _mavlinkPhotoCaptureIdle)

    readonly property bool _captureButtonEnabled:
        _cameraInPhotoMode
            ? _canTakePhoto
            : (_canRecordVideo || _isShootingInCurrentMode)

    readonly property var _primaryBattery:
        _activeVehicle
        && _activeVehicle.batteries
        && _activeVehicle.batteries.count > 0
            ? _activeVehicle.batteries.get(0)
            : null

    readonly property string _batteryText:
        vehicleBatteryText()

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: root.enabled
    }

    Shared.WidgetPanelStyle {
        id: pgrStyle
        titleFontSize: 12
        smallFontSize: 9
        readonly property int buttonFontSize: 10
    }

    function boundedHostPosition(x, y) {
        return photoPanelHost.panelController.boundedPosition(x, y)
    }

    function saveHostPosition() {
        if (widgetSettings && movementHost) {
            widgetSettings.setPhotoVideoPosition(
                movementHost.x,
                movementHost.y
            )
        }
    }

    function factNumber(fact) {
        if (fact === null || fact === undefined) {
            return NaN
        }

        if (fact.rawValue !== undefined) {
            return Number(fact.rawValue)
        }

        if (fact.value !== undefined) {
            return Number(fact.value)
        }

        return Number(fact)
    }

    function vehicleBatteryText() {
        if (!_primaryBattery
                || _primaryBattery.percentRemaining === undefined
                || _primaryBattery.percentRemaining === null) {
            return "-- %"
        }

        var remaining = factNumber(_primaryBattery.percentRemaining)

        if (isNaN(remaining) || remaining < 0) {
            return "-- %"
        }

        return Math.round(remaining) + " %"
    }

    function selectVideoMode() {
        if (_usingSiyi) {
            if (_siyiRecording) {
                return
            }

            _localPhotoMode = false
            return
        }

        if (_hasMavlinkCamera
                && Boolean(_camera.hasModes)
                && _mavlinkPhotoCaptureIdle) {
            _camera.setCameraModeVideo()
        }
    }

    function selectPhotoMode() {
        if (_usingSiyi) {
            if (_siyiRecording) {
                return
            }

            _localPhotoMode = true
            return
        }

        if (_hasMavlinkCamera
                && Boolean(_camera.hasModes)
                && _mavlinkVideoCaptureIdle) {
            _camera.setCameraModePhoto()
        }
    }

    function toggleCapture() {
        if (_usingSiyi) {
            if (!_siyiConnected) {
                console.log("PhotoVideoControl: SIYI camera is not connected")
                return
            }

            if (_cameraInPhotoMode) {
                if (!Boolean(_siyiCamera.enablePhoto)) {
                    console.log("PhotoVideoControl: SIYI photo is unavailable")
                    return
                }

                _siyiCamera.sendCommand(
                    SiYiCamera.CameraCommandTakePhoto
                )
                return
            }

            if (!Boolean(_siyiCamera.enableVideo)) {
                console.log("PhotoVideoControl: SIYI video is unavailable")
                return
            }

            _siyiCamera.sendRecodingCommand(
                _siyiCamera.isRecording
                    ? SiYiCamera.CloseRecording
                    : SiYiCamera.OpenRecording
            )
            return
        }

        if (!_hasMavlinkCamera) {
            return
        }

        if (_cameraInPhotoMode) {
            if (_camera.photoCaptureStatus
                    === MavlinkCameraControl.PHOTO_CAPTURE_INTERVAL_IN_PROGRESS) {
                _camera.stopTakePhoto()
            } else if (_mavlinkPhotoCaptureIdle) {
                _camera.takePhoto()
            }
        } else {
            _camera.toggleVideoRecording()
        }
    }

    ColumnLayout {
        id: mainLayout
        visible: root.expanded

        anchors.fill: parent
        anchors.margins: root._margins
        spacing: Math.max(5, root._smallMargins)

        QGCLabel {
            Layout.alignment: Qt.AlignHCenter
            text:
                !_usingSiyi
                && root._hasMavlinkCamera
                && root._cameraManager
                && root._cameraManager.cameras
                && root._cameraManager.cameras.length > 1
                    ? root._camera.modelName
                    : ""
            visible: text !== ""
            color: pgrStyle.textSecondary
            font.pixelSize: pgrStyle.smallFontSize
            elide: Text.ElideRight
            Layout.maximumWidth: root.width - (root._margins * 2)
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Rectangle {
                id: videoModeButton

                Layout.preferredWidth:
                    (root.width - (root._margins * 2) - parent.spacing) / 2
                Layout.preferredHeight:
                    Math.max(28, ScreenTools.defaultFontPixelHeight * 1.6)

                radius: pgrStyle.buttonRadius
                color:
                    videoModeMouseArea.pressed
                        ? pgrStyle.buttonPressed
                        : root._cameraInVideoMode
                          ? pgrStyle.buttonActive
                          : pgrStyle.buttonIdle
                border.width: 1
                border.color: pgrStyle.buttonBorder

                opacity:
                    root._usingSiyi
                        ? (root._hasSiyiCamera
                           && Boolean(root._siyiCamera.enableVideo)
                               ? 1.0
                               : 0.55)
                        : (root._hasMavlinkCamera
                           && Boolean(root._camera.capturesVideo)
                               ? 1.0
                               : 0.55)

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  13
                        height: 13
                        sourceSize.height: height
                        source: "/qmlimages/camera_video.svg"
                        color:
                            root._cameraInVideoMode
                                ? pgrStyle.textPrimary
                                : pgrStyle.textSecondary
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("VIDEO")
                        color:
                            root._cameraInVideoMode
                                ? pgrStyle.textPrimary
                                : pgrStyle.textSecondary
                        font.pixelSize: pgrStyle.buttonFontSize
                        font.bold: true
                    }
                }

                MouseArea {
                    id: videoModeMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled:
                        root._usingSiyi
                            ? !root._siyiRecording
                            : (root._hasMavlinkCamera
                               && Boolean(root._camera.hasModes)
                               && root._mavlinkPhotoCaptureIdle)

                    onClicked: root.selectVideoMode()
                }
            }

            Rectangle {
                id: photoModeButton

                Layout.preferredWidth:
                    (root.width - (root._margins * 2) - parent.spacing) / 2
                Layout.preferredHeight:
                    Math.max(28, ScreenTools.defaultFontPixelHeight * 1.6)

                radius: pgrStyle.buttonRadius
                color:
                    photoModeMouseArea.pressed
                        ? pgrStyle.buttonPressed
                        : root._cameraInPhotoMode
                          ? pgrStyle.buttonActive
                          : pgrStyle.buttonIdle
                border.width: 1
                border.color: pgrStyle.buttonBorder

                opacity:
                    root._usingSiyi
                        ? (root._hasSiyiCamera
                           && Boolean(root._siyiCamera.enablePhoto)
                               ? 1.0
                               : 0.55)
                        : (root._hasMavlinkCamera
                           && Boolean(root._camera.capturesPhotos)
                               ? 1.0
                               : 0.55)

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  13
                        height: 13
                        sourceSize.height: height
                        source: "/qmlimages/camera_photo.svg"
                        color:
                            root._cameraInPhotoMode
                                ? pgrStyle.textPrimary
                                : pgrStyle.textSecondary
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("PHOTO")
                        color:
                            root._cameraInPhotoMode
                                ? pgrStyle.textPrimary
                                : pgrStyle.textSecondary
                        font.pixelSize: pgrStyle.buttonFontSize
                        font.bold: true
                    }
                }

                MouseArea {
                    id: photoModeMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled:
                        root._usingSiyi
                            ? !root._siyiRecording
                            : (root._hasMavlinkCamera
                               && Boolean(root._camera.hasModes)
                               && root._mavlinkVideoCaptureIdle)

                    onClicked: root.selectPhotoMode()
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth:
                Math.max(58, ScreenTools.defaultFontPixelHeight * 3.6)
            Layout.preferredHeight: Layout.preferredWidth
            opacity: root._captureButtonEnabled ? 1.0 : 0.48

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: width * 0.5
                border.width: 2
                border.color: pgrStyle.textPrimary
            }

            Rectangle {
                anchors {
                    centerIn: parent
                    alignWhenCentered: false
                }

                // Keep the control visually neutral. The currently available
                // SIYI cameras do not expose usable recording state, so the
                // button must not turn into a misleading Stop square.
                width:  parent.width * 0.72
                height: width
                radius: width * 0.5

                color:
                    root._captureButtonEnabled
                    || root._isShootingInCurrentMode
                        ? pgrStyle.recordingColor
                        : pgrStyle.textSecondary
            }

            MouseArea {
                anchors.fill: parent
                enabled:
                    root._captureButtonEnabled
                    || root._isShootingInCurrentMode
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleCapture()
            }
        }

        ColumnLayout {
            id: trackingControls

            Layout.alignment: Qt.AlignHCenter
            spacing: 3
            visible:
                !root._usingSiyi
                && root._hasMavlinkCamera
                && Boolean(root._camera.hasTracking)

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth:
                    Math.max(30, ScreenTools.defaultFontPixelHeight * 1.8)
                Layout.preferredHeight: Layout.preferredWidth

                radius: pgrStyle.buttonRadius
                color:
                    root._camera && root._camera.trackingEnabled
                        ? pgrStyle.recordingColor
                        : pgrStyle.buttonIdle
                border.width: 1
                border.color: pgrStyle.buttonBorder

                QGCColoredImage {
                    anchors.centerIn: parent
                    width:  parent.width * 0.52
                    height: width
                    sourceSize.height: height
                    source: "/qmlimages/TrackingIcon.svg"
                    color: pgrStyle.textPrimary
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root._camera.trackingEnabled =
                            !root._camera.trackingEnabled

                        if (!root._camera.trackingEnabled) {
                            root._camera.stopTracking()
                        }
                    }
                }
            }

            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Camera Tracking")
                color: pgrStyle.textSecondary
                font.pixelSize: pgrStyle.smallFontSize
            }
        }

        Shared.WidgetPanelActions {
            Layout.alignment: Qt.AlignHCenter
            panelController: photoPanelHost.panelController
            coordinateItem: root.movementBounds
            locked: root.panelLocked
            lockEnabled: Boolean(root.widgetSettings)
            onLockToggleRequested: {
                if (root.widgetSettings) root.widgetSettings.photoVideoLocked = !root.panelLocked
            }
            onCollapseRequested: root.expanded = false
        }
    }

    Shared.WidgetCollapsedHandle {
        visible: !root.expanded
        x: root.width - width
        y: 0
        panelController: photoPanelHost.panelController
        coordinateItem: root.movementBounds
        onExpandRequested: root.expanded = true
    }

}
