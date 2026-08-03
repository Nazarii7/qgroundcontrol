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

    // UI-only state. It does not alter or reset the three widget settings.
    property bool _widgetsSectionExpanded: true

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

    // The settings gear is a permanent Fly View control. Camera-specific
    // options are shown only when a MAVLink camera exists.
    readonly property bool _canOpenSettings: true

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

    function openSettings() {
        var dialog = settingsDialogComponent.createObject(mainWindow)
        if (!dialog) {
            console.warn("PhotoVideoControl: unable to create Settings dialog")
            return
        }

        dialog.open()
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

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 1
            Layout.preferredWidth:
                Math.max(27, ScreenTools.defaultFontPixelHeight * 1.55)
            Layout.preferredHeight: Layout.preferredWidth

            radius: pgrStyle.buttonRadius
            color:
                settingsMouseArea.pressed
                    ? pgrStyle.buttonPressed
                    : pgrStyle.buttonIdle
            border.width: 1
            border.color: pgrStyle.buttonBorder
            opacity: 1.0

            QGCColoredImage {
                anchors.centerIn: parent
                width:  parent.width * 0.58
                height: width
                sourceSize.height: height
                source: "/res/gear-black.svg"
                color: pgrStyle.textPrimary
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            MouseArea {
                id: settingsMouseArea

                anchors.fill: parent
                enabled: root._canOpenSettings
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openSettings()
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
    }


        Component {
            id: settingsDialogComponent

            Popup {
                id: settingsPopup

                parent: mainWindow.contentItem

                modal: true
                focus: true
                padding: 0

                closePolicy:
                    Popup.CloseOnEscape
                    | Popup.CloseOnPressOutside

                width:
                    Math.max(
                        ScreenTools.defaultFontPixelWidth * 31,
                        292
                    )

                height: settingsContent.implicitHeight

                x:
                    parent
                        ? Math.round((parent.width - width) / 2)
                        : 0

                y:
                    parent
                        ? Math.round((parent.height - height) / 2)
                        : 0

                property var _videoSettings:
                    QGroundControl.settingsManager.videoSettings

                property var _videoFitFact:
                    _videoSettings
                        ? _videoSettings.videoFit
                        : null

                Overlay.modal: Rectangle {
                    color: Qt.rgba(0, 0, 0, 0.28)
                }

                background: Rectangle {
                    color: pgrStyle.panelBackground
                    radius: pgrStyle.panelRadius

                    border.width: 1
                    border.color: pgrStyle.panelBorder
                }

                contentItem: ColumnLayout {
                    id: settingsContent

                    width: settingsPopup.width
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            Math.max(
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

                                font.pixelSize:
                                    Math.max(
                                        pgrStyle.titleFontSize,
                                        ScreenTools.defaultFontPixelHeight
                                    )
                                font.bold: true
                            }

                            Rectangle {
                                Layout.preferredWidth:
                                    Math.max(
                                        64,
                                        ScreenTools.defaultFontPixelWidth * 8
                                    )

                                Layout.preferredHeight:
                                    Math.max(
                                        31,
                                        ScreenTools.defaultFontPixelHeight * 1.75
                                    )

                                radius: pgrStyle.buttonRadius

                                color:
                                    closeMouseArea.pressed
                                        ? pgrStyle.buttonPressed
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

                                    onClicked: settingsPopup.close()
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: root._margins * 1.4
                        spacing:
                            Math.max(
                                10,
                                ScreenTools.defaultFontPixelHeight * 0.65
                            )

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root._margins

                            QGCLabel {
                                Layout.fillWidth: true

                                text: qsTr("Video Grid Lines")
                                color: pgrStyle.textPrimary
                                font.pixelSize: pgrStyle.buttonFontSize
                            }

                            Rectangle {
                                id: gridLinesSwitch

                                Layout.preferredWidth:
                                    Math.max(
                                        42,
                                        ScreenTools.defaultFontPixelWidth * 5
                                    )

                                Layout.preferredHeight:
                                    Math.max(
                                        22,
                                        ScreenTools.defaultFontPixelHeight * 1.25
                                    )

                                radius: height / 2

                                color:
                                    settingsPopup._videoSettings
                                    && Boolean(
                                        settingsPopup
                                            ._videoSettings
                                            .gridLines
                                            .rawValue
                                    )
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
                                        settingsPopup._videoSettings
                                        && Boolean(
                                            settingsPopup
                                                ._videoSettings
                                                .gridLines
                                                .rawValue
                                        )
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
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (!settingsPopup._videoSettings) {
                                            return
                                        }

                                        var gridFact =
                                            settingsPopup
                                                ._videoSettings
                                                .gridLines

                                        gridFact.rawValue =
                                            Boolean(gridFact.rawValue)
                                                ? 0
                                                : 1
                                    }
                                }
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

                                Layout.preferredWidth:
                                    Math.max(
                                        112,
                                        ScreenTools.defaultFontPixelWidth * 13
                                    )

                                Layout.preferredHeight:
                                    Math.max(
                                        32,
                                        ScreenTools.defaultFontPixelHeight * 1.8
                                    )

                                // Match SIYI QGC exactly. The underlying QGC
                                // Fact may contain legacy fourth-mode metadata,
                                // but this UI intentionally exposes only these
                                // three supported modes.
                                model: [
                                    qsTr("Fit Width"),
                                    qsTr("Fit Height"),
                                    qsTr("Stretch")
                                ]

                                currentIndex: {
                                    var fact =
                                        settingsPopup._videoFitFact

                                    if (!fact) {
                                        return 0
                                    }

                                    var value = Number(fact.rawValue)

                                    if (!isFinite(value)) {
                                        return 0
                                    }

                                    // A previously saved legacy value 3 is
                                    // treated as Stretch.
                                    return Math.max(
                                        0,
                                        Math.min(2, value)
                                    )
                                }

                                onActivated: (index) => {
                                    var fact =
                                        settingsPopup._videoFitFact

                                    if (!fact) {
                                        return
                                    }

                                    // FlightDisplayViewVideo reads this exact
                                    // numeric raw value: 0, 1 or 2.
                                    fact.rawValue = index
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    rightPadding: videoFitCombo.indicator.width + 10

                                    text: videoFitCombo.displayText
                                    color: pgrStyle.textPrimary

                                    font.pixelSize:
                                        pgrStyle.buttonFontSize

                                    verticalAlignment:
                                        Text.AlignVCenter

                                    elide: Text.ElideRight
                                }

                                indicator: Canvas {
                                    x:
                                        videoFitCombo.width
                                        - width
                                        - 9

                                    y:
                                        Math.round(
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
                                        ctx.fillStyle =
                                            pgrStyle.textPrimary
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
                                    height:
                                        Math.max(
                                            32,
                                            ScreenTools.defaultFontPixelHeight
                                            * 1.8
                                        )

                                    highlighted:
                                        videoFitCombo.highlightedIndex
                                        === index

                                    contentItem: Text {
                                        leftPadding: 8

                                        text: modelData
                                        color: pgrStyle.textPrimary

                                        font.pixelSize:
                                            pgrStyle.buttonFontSize

                                        verticalAlignment:
                                            Text.AlignVCenter
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

                                    implicitHeight:
                                        Math.min(
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
                                        color:
                                            Qt.rgba(
                                                0.08,
                                                0.10,
                                                0.13,
                                                0.98
                                            )

                                        radius: pgrStyle.buttonRadius

                                        border.width: 1
                                        border.color:
                                            pgrStyle.panelBorder
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
                                id: widgetsSectionToggleButton

                                Layout.preferredWidth:
                                    Math.max(
                                        28,
                                        ScreenTools.defaultFontPixelHeight * 1.65
                                    )

                                Layout.preferredHeight:
                                    Layout.preferredWidth

                                radius: pgrStyle.buttonRadius

                                color:
                                    widgetsSectionToggleMouseArea.containsMouse
                                        ? pgrStyle.buttonHover
                                        : pgrStyle.buttonIdle

                                border.width: 1
                                border.color: pgrStyle.buttonBorder

                                QGCLabel {
                                    anchors.centerIn: parent

                                    text:
                                        root._widgetsSectionExpanded
                                            ? "−"
                                            : "+"

                                    color: pgrStyle.textPrimary
                                    font.pixelSize:
                                        Math.max(
                                            pgrStyle.buttonFontSize,
                                            ScreenTools.defaultFontPixelHeight
                                        )

                                    font.bold: true
                                }

                                MouseArea {
                                    id: widgetsSectionToggleMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root._widgetsSectionExpanded =
                                            !root._widgetsSectionExpanded
                                    }
                                }
                            }
                        }

                        Item {
                            id: widgetsSectionBody

                            Layout.fillWidth: true
                            Layout.preferredHeight:
                                root._widgetsSectionExpanded
                                    ? widgetsSectionColumn.implicitHeight
                                    : 0

                            Layout.minimumHeight: 0
                            clip: true

                            ColumnLayout {
                                id: widgetsSectionColumn

                                width: parent.width
                                spacing: root._smallMargins
                                visible: root._widgetsSectionExpanded

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root._margins

                        QGCLabel {
                            Layout.fillWidth: true

                            text: qsTr("Camera Controls")
                            color: pgrStyle.textPrimary
                            font.pixelSize: pgrStyle.buttonFontSize
                        }

                        Rectangle {
                            id: cameraControlsVisibilitySwitch

                            Layout.preferredWidth:
                                Math.max(
                                    42,
                                    ScreenTools.defaultFontPixelWidth * 5
                                )

                            Layout.preferredHeight:
                                Math.max(
                                    22,
                                    ScreenTools.defaultFontPixelHeight * 1.25
                                )

                            radius: height / 2

                            color:
                                root.widgetSettings
                                && Boolean(
                                    root
                                        .widgetSettings
                                        .cameraControlsVisible
                                )
                                    ? Qt.rgba(0.00, 0.80, 0.35, 0.95)
                                    : pgrStyle.buttonIdle

                            border.width: 1
                            border.color: pgrStyle.buttonBorder
                            opacity: root.widgetSettings ? 1.0 : 0.45

                            Rectangle {
                                width: parent.height - 6
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter

                                x:
                                    root.widgetSettings
                                    && Boolean(
                                        root
                                            .widgetSettings
                                            .cameraControlsVisible
                                    )
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
                                enabled: root.widgetSettings !== null
                                hoverEnabled: true
                                cursorShape:
                                    enabled
                                        ? Qt.PointingHandCursor
                                        : Qt.ArrowCursor

                                onClicked: {
                                    root
                                        .widgetSettings
                                        .cameraControlsVisible =
                                            !Boolean(
                                                root
                                                    .widgetSettings
                                                    .cameraControlsVisible
                                            )
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root._margins

                        QGCLabel {
                            Layout.fillWidth: true

                            text: qsTr("Drop Widget")
                            color: pgrStyle.textPrimary
                            font.pixelSize: pgrStyle.buttonFontSize
                        }

                        Rectangle {
                            id: dropWidgetVisibilitySwitch

                            Layout.preferredWidth:
                                Math.max(
                                    42,
                                    ScreenTools.defaultFontPixelWidth * 5
                                )

                            Layout.preferredHeight:
                                Math.max(
                                    22,
                                    ScreenTools.defaultFontPixelHeight * 1.25
                                )

                            radius: height / 2

                            color:
                                root.widgetSettings
                                && Boolean(
                                    root
                                        .widgetSettings
                                        .dropWidgetVisible
                                )
                                    ? Qt.rgba(0.00, 0.80, 0.35, 0.95)
                                    : pgrStyle.buttonIdle

                            border.width: 1
                            border.color: pgrStyle.buttonBorder
                            opacity: root.widgetSettings ? 1.0 : 0.45

                            Rectangle {
                                width: parent.height - 6
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter

                                x:
                                    root.widgetSettings
                                    && Boolean(
                                        root
                                            .widgetSettings
                                            .dropWidgetVisible
                                    )
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
                                enabled: root.widgetSettings !== null
                                hoverEnabled: true
                                cursorShape:
                                    enabled
                                        ? Qt.PointingHandCursor
                                        : Qt.ArrowCursor

                                onClicked: {
                                    root
                                        .widgetSettings
                                        .dropWidgetVisible =
                                            !Boolean(
                                                root
                                                    .widgetSettings
                                                    .dropWidgetVisible
                                            )
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root._margins

                        QGCLabel {
                            Layout.fillWidth: true

                            text: qsTr("Camera Logs")
                            color: pgrStyle.textPrimary
                            font.pixelSize: pgrStyle.buttonFontSize
                        }

                        Rectangle {
                            id: cameraLogsVisibilitySwitch

                            Layout.preferredWidth:
                                Math.max(
                                    42,
                                    ScreenTools.defaultFontPixelWidth * 5
                                )

                            Layout.preferredHeight:
                                Math.max(
                                    22,
                                    ScreenTools.defaultFontPixelHeight * 1.25
                                )

                            radius: height / 2

                            color:
                                root.widgetSettings
                                && Boolean(
                                    root
                                        .widgetSettings
                                        .cameraLogsVisible
                                )
                                    ? Qt.rgba(0.00, 0.80, 0.35, 0.95)
                                    : pgrStyle.buttonIdle

                            border.width: 1
                            border.color: pgrStyle.buttonBorder
                            opacity: root.widgetSettings ? 1.0 : 0.45

                            Rectangle {
                                width: parent.height - 6
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter

                                x:
                                    root.widgetSettings
                                    && Boolean(
                                        root
                                            .widgetSettings
                                            .cameraLogsVisible
                                    )
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
                                enabled: root.widgetSettings !== null
                                hoverEnabled: true
                                cursorShape:
                                    enabled
                                        ? Qt.PointingHandCursor
                                        : Qt.ArrowCursor

                                onClicked: {
                                    root
                                        .widgetSettings
                                        .cameraLogsVisible =
                                            !Boolean(
                                                root
                                                    .widgetSettings
                                                    .cameraLogsVisible
                                            )
                                }
                            }
                        }
                    }
                            }
                        }

                    }
                }

                onClosed: destroy()
            }
        }

}
