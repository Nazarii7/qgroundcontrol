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

Rectangle {
    id: root

    implicitWidth:  Math.max(ScreenTools.defaultFontPixelWidth * 17, 138)
    implicitHeight: mainLayout.implicitHeight + (_margins * 2)
    width:          implicitWidth
    height:         implicitHeight

    color:        pgrStyle.panelBackground
    radius:       pgrStyle.panelRadius
    border.width: 1
    border.color: pgrStyle.panelBorder

    // The widget must remain present over both map and video, even when
    // neither a vehicle nor a camera is currently connected.
    visible: true

    // Supplied by the FlightDisplay layer. Keeping this as a generic object
    // avoids a reverse import from FlightMap back into FlightDisplay.
    property var widgetSettings: null

    // The top-right Fly View layer hosts this control inside a non-modal
    // Popup so it can move freely across the complete flight view.
    property var movementHost: null
    property Item movementBounds: null
    property real movementTopInset: 0

    readonly property bool panelLocked:
        widgetSettings ? Boolean(widgetSettings.photoVideoLocked) : true

    property bool _panelDragging: false
    property real _dragStartPointerX: 0
    property real _dragStartPointerY: 0
    property real _dragStartHostX: 0
    property real _dragStartHostY: 0

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

    QtObject {
        id: pgrStyle

        readonly property color panelBackground: Qt.rgba(0.08, 0.10, 0.13, 0.90)
        readonly property color panelBorder: Qt.rgba(1, 1, 1, 0.16)

        readonly property color buttonIdle: Qt.rgba(1, 1, 1, 0.08)
        readonly property color buttonActive: Qt.rgba(1, 1, 1, 0.22)
        readonly property color buttonPressed: Qt.rgba(1, 1, 1, 0.18)
        readonly property color buttonBorder: Qt.rgba(1, 1, 1, 0.10)

        readonly property color textPrimary: "white"
        readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.62)
        readonly property color textMuted: Qt.rgba(1, 1, 1, 0.45)

        readonly property int panelRadius: 14
        readonly property int buttonRadius: 7

        readonly property int titleFontSize: 12
        readonly property int buttonFontSize: 10
        readonly property int smallFontSize: 9
    }

    function boundedHostPosition(x, y) {
        if (!movementBounds || !movementHost) {
            return Qt.point(x, y)
        }

        return Qt.point(
            Math.max(0, Math.min(movementBounds.width - movementHost.width, x)),
            Math.max(
                movementTopInset,
                Math.min(movementBounds.height - movementHost.height, y)
            )
        )
    }

    function applyHostPosition(pointerPoint) {
        if (!movementHost) {
            return
        }

        var position = boundedHostPosition(
            _dragStartHostX + pointerPoint.x - _dragStartPointerX,
            _dragStartHostY + pointerPoint.y - _dragStartPointerY
        )

        movementHost.x = position.x
        movementHost.y = position.y
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

    DeadMouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: mainLayout

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
                        ? qgcPal.colorRed
                        : qgcPal.colorGrey
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
                        ? qgcPal.colorRed
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

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 5

            Rectangle {
                id: moveHandle

                Layout.preferredWidth: 34
                Layout.preferredHeight: 28
                visible: !root.panelLocked

                radius: pgrStyle.buttonRadius
                color:
                    moveHandleMouseArea.pressed
                        ? pgrStyle.buttonPressed
                        : pgrStyle.buttonActive
                border.width: 1
                border.color: pgrStyle.buttonBorder

                QGCLabel {
                    anchors.centerIn: parent
                    text: "⋮⋮"
                    color: pgrStyle.textPrimary
                    font.pixelSize: 15
                    font.bold: true
                }

                MouseArea {
                    id: moveHandleMouseArea

                    anchors.fill: parent
                    enabled:
                        !root.panelLocked
                        && root.movementHost
                        && root.movementBounds
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: Qt.SizeAllCursor
                    preventStealing: true

                    function pointerInBounds(mouse) {
                        return mapToItem(
                            root.movementBounds,
                            mouse.x,
                            mouse.y
                        )
                    }

                    onPressed: function(mouse) {
                        var pointerPoint = pointerInBounds(mouse)
                        root._panelDragging = true
                        root._dragStartPointerX = pointerPoint.x
                        root._dragStartPointerY = pointerPoint.y
                        root._dragStartHostX = root.movementHost.x
                        root._dragStartHostY = root.movementHost.y
                        mouse.accepted = true
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed || !root._panelDragging) {
                            return
                        }

                        root.applyHostPosition(pointerInBounds(mouse))
                        mouse.accepted = true
                    }

                    onReleased: function(mouse) {
                        if (root._panelDragging) {
                            root.applyHostPosition(pointerInBounds(mouse))
                        }

                        root._panelDragging = false
                        root.saveHostPosition()
                        mouse.accepted = true
                    }

                    onCanceled: {
                        root._panelDragging = false
                        root.saveHostPosition()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 28

                radius: pgrStyle.buttonRadius
                color:
                    lockMouseArea.pressed
                        ? pgrStyle.buttonPressed
                        : root.panelLocked
                          ? pgrStyle.buttonIdle
                          : pgrStyle.buttonActive
                border.width: 1
                border.color: pgrStyle.buttonBorder

                QGCLabel {
                    anchors.centerIn: parent
                    text: root.panelLocked ? "🔒" : "🔓"
                    color: pgrStyle.textPrimary
                    font.pixelSize: 14
                }

                MouseArea {
                    id: lockMouseArea

                    anchors.fill: parent
                    enabled: Boolean(root.widgetSettings)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.widgetSettings.photoVideoLocked =
                            !root.panelLocked
                    }
                }
            }
        }
    }

}
