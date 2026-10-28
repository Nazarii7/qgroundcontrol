/****************************************************************************
 *
 * FlyViewCustomLayer.qml
 * Mount point for custom Fly View widgets
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.FlightDisplay
import SiYi.Object 1.0

import "DropWidget" as DropWidget
import "ControllerInput" as ControllerInput
import "OSD" as OSD

Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets: _toolInsets
    property var mapControl
    property var siyi: SiYi
    property var camera: siyi.camera
    property string zoomMultipleDisplayText: "1.0"
    property bool zoomMultiplePopupVisible: false
    readonly property bool hasCamera:
        camera !== null && camera !== undefined
    readonly property int zoomMultipleValue:
        hasCamera ? Number(camera.zoomMultiple) : 0
    readonly property real _m: ScreenTools.defaultFontPixelHeight * 0.6
    // Shared right-edge inset for fixed OSD elements.
    readonly property real _photoVideoControlEdgeMargin: 6
    readonly property real _topOsdMargin: _m * 0.5
    readonly property real _edgeOsdMargin: _m
    // One shared width keeps the right-side Battery, Altitude and Horizon OSDs
    // visually aligned. The compact factor keeps all telemetry readable while
    // reducing the complete right-side group by another step.
    readonly property real _rightOsdWidth:
        Math.max(136, ScreenTools.defaultFontPixelWidth * 12)
    readonly property real _panelWidth: 220
    readonly property real _headerHeight: 46
    readonly property real _rowHeight: 54
    readonly property real _rowAnimatedHeight: 58
    readonly property real _settingsRowHeight: 44
    // Interactive/movable widgets must always stay above every OSD element.
    // The OSD layer uses z: 1100 throughout this file.
    readonly property real _interactiveWidgetZ: 2000
    readonly property real _topOffset: parentToolInsets ? parentToolInsets.topEdgeRightInset + _m : _m
    readonly property real _controllerTopOffset:
        parentToolInsets ? parentToolInsets.topEdgeRightInset + _m : _m
    // FlyView passes mapControl into this custom layer. In standard QGC the map
    // is the full item when mapControl.pipState.state === fullState. Therefore
    // the video is the main/full item when the map is NOT full. This avoids
    // using videoManager.fullScreen, which represents a different mode.
    readonly property bool _videoIsMain:
        mapControl && mapControl.pipState
            ? mapControl.pipState.state !== mapControl.pipState.fullState
            : false

    function showZoomMultiple(rawZoomMultiple) {
        var value = Number(rawZoomMultiple)
        if (isNaN(value) || value <= 0) {
            return
        }

        zoomMultipleDisplayText = (value / 10).toFixed(1)
        zoomMultiplePopupVisible = true
        zoomMultiplePopupTimer.restart()
    }

    onZoomMultipleValueChanged: {
        showZoomMultiple(zoomMultipleValue)
    }
    QGCToolInsets {
        id: _toolInsets

        leftEdgeTopInset:       parentToolInsets ? parentToolInsets.leftEdgeTopInset : 0
        leftEdgeCenterInset:    parentToolInsets ? parentToolInsets.leftEdgeCenterInset : 0
        leftEdgeBottomInset:    parentToolInsets ? parentToolInsets.leftEdgeBottomInset : 0

        rightEdgeTopInset:
            DropWidgetSettings.dropWidgetVisible
                ? _panelWidth + _m * 2
                : (parentToolInsets
                   ? parentToolInsets.rightEdgeTopInset
                   : 0)
        rightEdgeCenterInset:   parentToolInsets ? parentToolInsets.rightEdgeCenterInset : 0
        rightEdgeBottomInset:   parentToolInsets ? parentToolInsets.rightEdgeBottomInset : 0

        topEdgeLeftInset:       parentToolInsets ? parentToolInsets.topEdgeLeftInset : 0
        topEdgeCenterInset:     parentToolInsets ? parentToolInsets.topEdgeCenterInset : 0
        topEdgeRightInset:      parentToolInsets ? parentToolInsets.topEdgeRightInset : 0

        bottomEdgeLeftInset:    parentToolInsets ? parentToolInsets.bottomEdgeLeftInset : 0
        bottomEdgeCenterInset:  parentToolInsets ? parentToolInsets.bottomEdgeCenterInset : 0
        bottomEdgeRightInset:   parentToolInsets ? parentToolInsets.bottomEdgeRightInset : 0
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

    // Independent top-left group. It respects the standard left-side tool
    // inset, while remaining independent of the centered compass.
    Item {
        id: topLeftOsdBlock

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: _topOsdMargin
        anchors.leftMargin:
            (parentToolInsets ? parentToolInsets.leftEdgeTopInset : 0) + _m

        width: topLeftOsdRow.implicitWidth
        height: topLeftOsdRow.implicitHeight
        z: 1100
        visible: _videoIsMain

        Row {
            id: topLeftOsdRow

            anchors.fill: parent
            spacing: _m

            OSD.LinkOSD {
                id: linkOsd

                displayEnabled:
                    _videoIsMain && DropWidgetSettings.linkOsdVisible
                transparentBackground:
                    DropWidgetSettings.hudTransparentBackground
            }

            OSD.GpsOSD {
                id: gpsOsd

                displayEnabled:
                    _videoIsMain && DropWidgetSettings.gpsOsdVisible
                transparentBackground:
                    DropWidgetSettings.hudTransparentBackground
                vehicle: QGroundControl.multiVehicleManager.activeVehicle
            }
        }
    }

    // The compass is centered against the complete Fly View, rather than
    // against the combined width of the surrounding top OSD widgets. Its
    // fixed heading marker therefore shares the crosshair's vertical axis.
    OSD.CompassOSD {
        id: compassOsd

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: _topOsdMargin

        z: 1100
        displayEnabled:
            _videoIsMain && DropWidgetSettings.compassOsdVisible
        transparentBackground:
            DropWidgetSettings.hudTransparentBackground
        vehicle: QGroundControl.multiVehicleManager.activeVehicle
    }

    // Read-only active flight-mode indicator. It follows the mode confirmed by
    // the autopilot and stays centered exactly ten pixels below the compass.
    OSD.FlightModeOSD {
        id: flightModeOsd

        anchors.top: compassOsd.bottom
        anchors.horizontalCenter: compassOsd.horizontalCenter
        anchors.topMargin: 10

        z: 1100
        displayEnabled: _videoIsMain
        transparentBackground:
            DropWidgetSettings.hudTransparentBackground
        vehicle: QGroundControl.multiVehicleManager.activeVehicle
    }

    // Geometry only. The existing video view keeps ownership and visibility
    // of its waiting label; this reference keeps it below the real upper OSDs.
    Item {
        id: videoStatusLayout
        anchors.left: parent.left
        anchors.right: parent.right
        height: 0
        y: Math.max(_topOsdMargin,
                    compassOsd.visible ? compassOsd.y + compassOsd.height : 0,
                    flightModeOsd.visible ? flightModeOsd.y + flightModeOsd.height : 0)
        visible: _videoIsMain

        Component.onCompleted: mainWindow.videoStatusLayout = videoStatusLayout
        Component.onDestruction: {
            if (mainWindow && mainWindow.videoStatusLayout === videoStatusLayout) {
                mainWindow.videoStatusLayout = null
            }
        }
    }

    // Keep the battery in the actual upper-right corner. PhotoVideoControl is
    // now movable, so it no longer reserves permanent space beside this OSD.
    OSD.BatteryOSD {
        id: batteryOsd

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: _topOsdMargin
        anchors.rightMargin: _photoVideoControlEdgeMargin

        width: _rightOsdWidth
        z: 1100
        visible:
            _videoIsMain
            && DropWidgetSettings.batteryOsdVisible
            && (primaryBattery !== null || secondaryBattery !== null)
        transparentBackground:
            DropWidgetSettings.hudTransparentBackground
        vehicle: QGroundControl.multiVehicleManager.activeVehicle
    }

    // Fixed right-side altitude tape and compact speed panel. This OSD ignores
    // tool insets intentionally: movable widgets may overlap it and are drawn
    // independently. The tape pointer and telemetry panel share the centered
    // horizontal axis of the right-side flight-view zone.
    Item {
        id: rightAltitudeArea

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: _m
        anchors.rightMargin: _photoVideoControlEdgeMargin
        anchors.bottomMargin: _m

        width: altitudeTapeOsd.width
        z: 1100
        visible: _videoIsMain && DropWidgetSettings.altitudeOsdVisible

        OSD.AltitudeTapeOSD {
            id: altitudeTapeOsd

            anchors.right: parent.right
            // The tape pointer and the telemetry panel share the same
            // horizontal centre line in the Fly View.
            y: (rightAltitudeArea.height - height) / 2

            displayEnabled: _videoIsMain
            transparentBackground:
                DropWidgetSettings.hudTransparentBackground
            vehicle: QGroundControl.multiVehicleManager.activeVehicle
            panelWidth: _rightOsdWidth
            tapeCenterY: height / 2
        }
    }

    // Bottom-right aircraft-style artificial horizon. This occupies the same
    // corner as the removed native compass and follows the vehicle's live roll
    // and pitch values. It intentionally remains independent of GPS status.
    OSD.ArtificialHorizonOSD {
        id: artificialHorizonOsd

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: _photoVideoControlEdgeMargin
        anchors.bottomMargin: _edgeOsdMargin

        indicatorSize: _rightOsdWidth
        z: 1100
        displayEnabled:
            _videoIsMain && DropWidgetSettings.horizonOsdVisible
        vehicle: QGroundControl.multiVehicleManager.activeVehicle
    }

    // Compact Home distance and flight-time block immediately to the left of
    // the artificial horizon. Both elements share the same bottom baseline and
    // meet along the horizon circle without an intermediate gap.
    OSD.HomeFlightInfoOSD {
        id: homeFlightInfoOsd

        anchors.right: artificialHorizonOsd.left
        anchors.bottom: parent.bottom
        // The shaped edge follows the horizon circle exactly, so both OSDs
        // read as one continuous block without a visible gap.
        anchors.rightMargin: -homeFlightInfoOsd.arcExtension
        anchors.bottomMargin: _edgeOsdMargin

        z: 1100
        displayEnabled:
            _videoIsMain && DropWidgetSettings.homeOsdVisible
        transparentBackground:
            DropWidgetSettings.hudTransparentBackground
        vehicle: QGroundControl.multiVehicleManager.activeVehicle
        orbitRadius: artificialHorizonOsd.width / 2
        orbitGap: 0
    }

    // Bottom message area between the PiP map on the left and the custom
    // Home/flight-time block plus artificial horizon on the right.
    // bottomEdgeCenterInset is not used here: it represents the HEIGHT of the
    // bottom-right row and would unnecessarily push the message upward even
    // when there is no overlap.
    Item {
        id: bottomMessageArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin:
            parentToolInsets
                ? parentToolInsets.leftEdgeBottomInset + _edgeOsdMargin
                : _edgeOsdMargin
        anchors.rightMargin:
            (parentToolInsets
                 ? parentToolInsets.rightEdgeBottomInset + _edgeOsdMargin
                 : _edgeOsdMargin)
            + (artificialHorizonOsd.visible
                   ? artificialHorizonOsd.width + _edgeOsdMargin
                   : 0)
            + (homeFlightInfoOsd.visible
                   ? homeFlightInfoOsd.width + _edgeOsdMargin
                   : 0)
        anchors.bottomMargin: _edgeOsdMargin

        // Geometry only: MainWindow owns the one persistent message component.
        height: mainWindow.vehicleMessagePresenter
                ? mainWindow.vehicleMessagePresenter.height : 0
        z: 1100

        Component.onCompleted: {
            mainWindow.vehicleMessageLayout = bottomMessageArea
        }
        Component.onDestruction: {
            if (mainWindow && mainWindow.vehicleMessageLayout === bottomMessageArea) {
                mainWindow.vehicleMessageLayout = null
            }
        }
    }

    // Persistent vehicle arming state. ArduPilot/QGC exposes this as the
    // vehicle.armed boolean, so the two authoritative display states are
    // ARMED and DISARMED. With no active vehicle the indicator stays hidden.
    Item {
        id: armedStateOsd

        readonly property var activeVehicle:
            QGroundControl.multiVehicleManager.activeVehicle
        readonly property bool vehicleArmed:
            activeVehicle !== null && activeVehicle.armed
        readonly property color stateColor:
            vehicleArmed
                ? Qt.rgba(1.0, 0.18, 0.18, 1.0)
                : Qt.rgba(0.14, 0.82, 0.88, 1.0)
        readonly property real bracketThickness:
            Math.max(2, ScreenTools.defaultFontPixelWidth * 0.22)
        readonly property real bracketLength:
            Math.max(14, ScreenTools.defaultFontPixelWidth * 1.45)
        readonly property real targetBottomMargin:
            mainWindow.vehicleMessagePresenter && mainWindow.vehicleMessagePresenter.visible
                ? _edgeOsdMargin + bottomMessageArea.height + _m
                : _edgeOsdMargin
        property real animatedBottomMargin: targetBottomMargin

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: animatedBottomMargin

        width: Math.max(220, ScreenTools.defaultFontPixelWidth * 23)
        height: Math.max(58, ScreenTools.defaultFontPixelHeight * 3.4)
        z: 1100
        visible: _videoIsMain && activeVehicle !== null

        Behavior on animatedBottomMargin {
            NumberAnimation {
                duration: 280
                easing.type: Easing.InOutCubic
            }
        }

        Item {
            id: armedStateLeftBracket

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: armedStateOsd.bracketLength
            height: parent.height * 0.58

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: armedStateOsd.bracketThickness
                radius: width / 2
                color: armedStateOsd.stateColor
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: parent.width
                height: armedStateOsd.bracketThickness
                radius: height / 2
                color: armedStateOsd.stateColor
            }

            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: parent.width
                height: armedStateOsd.bracketThickness
                radius: height / 2
                color: armedStateOsd.stateColor
            }
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: armedStateOsd.bracketLength * 1.4
            anchors.rightMargin: armedStateOsd.bracketLength * 1.4

            text: armedStateOsd.vehicleArmed
                  ? qsTr("ARMED")
                  : qsTr("DISARMED")
            color: armedStateOsd.stateColor
            font.pixelSize:
                Math.max(22, ScreenTools.defaultFontPixelHeight * 1.25)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: armedStateRightBracket

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: armedStateOsd.bracketLength
            height: parent.height * 0.58

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: armedStateOsd.bracketThickness
                radius: width / 2
                color: armedStateOsd.stateColor
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: parent.width
                height: armedStateOsd.bracketThickness
                radius: height / 2
                color: armedStateOsd.stateColor
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: parent.width
                height: armedStateOsd.bracketThickness
                radius: height / 2
                color: armedStateOsd.stateColor
            }
        }
    }

    // SIYI reports zoomMultiple in tenths: 10 -> 1.0, 32 -> 3.2. Keep the
    // popup attached to the moving ARMED/DISARMED block so it always remains
    // above it, including while status messages move that block upward.
    Rectangle {
        id: zoomMultiplePopup

        anchors.horizontalCenter: armedStateOsd.horizontalCenter
        anchors.bottom: armedStateOsd.top
        anchors.bottomMargin: _m

        // Camera feedback is independent of the optional Camera Controls
        // panel and remains above the regular OSD layer.
        z: _interactiveWidgetZ + 1
        visible:
            zoomMultiplePopupVisible
                && armedStateOsd.visible
                && _videoIsMain

        width: Math.max(52, zoomMultipleText.implicitWidth + 20)
        height: zoomMultipleText.implicitHeight + 12
        radius: 6

        color: Qt.rgba(0.10, 0.11, 0.15, 0.93)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        Text {
            id: zoomMultipleText

            anchors.centerIn: parent
            text: zoomMultipleDisplayText
            color: "white"
            font.pixelSize: 24
            font.bold: true
        }

        Timer {
            id: zoomMultiplePopupTimer

            interval: 5000
            repeat: false
            running: false

            onTriggered: zoomMultiplePopupVisible = false
        }

        Connections {
            target: hasCamera ? camera : null
            ignoreUnknownSignals: true

            function onIsConnectedChanged() {
                if (!camera.isConnected) {
                    zoomMultiplePopupTimer.stop()
                    zoomMultiplePopupVisible = false
                }
            }
        }

    }

    ControllerInput.ControllerInputPanel {
        id: controllerInputPanel

        anchors.fill: parent
        z: _interactiveWidgetZ

        visible: DropWidgetSettings.controllerInputVisible

        // The custom layer already starts on the same left edge as the camera
        // controls. A zero local left margin therefore aligns both widgets.
        margin: _m
        leftMargin: 4
        topOffset: _controllerTopOffset
        defaultAboveBottomInset: true
        // bottomEdgeLeftInset is the occupied PiP-map height supplied by Fly
        // View. Keep one standard OSD gap between the panel and that map.
        bottomInset:
            parentToolInsets ? parentToolInsets.bottomEdgeLeftInset : 0
        bottomGap: _m
        panelWidth: 320
    }

    DropWidget.DropWidgetController {
        id: dropWidgetController

        activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    }

    Connections {
        target: DropWidgetSettings

        function onDropWidgetVisibleChanged() {
            if (!DropWidgetSettings.dropWidgetVisible) {
                dropWidgetController.holdDropReleased()
            }
        }
    }

    DropWidget.DropControlPanel {
        id: dropControlPanel

        anchors.fill: parent
        z: _interactiveWidgetZ

        visible: DropWidgetSettings.dropWidgetVisible
        enabled: visible

        dropModel: dropWidgetController.dropModel
        paletteObject: qgcPal
        dropTitleProvider: dropWidgetController.dropTitleForServo

        panelWidth: _panelWidth
        margin: _m
        topOffset: _topOffset
        headerHeight: _headerHeight
        rowHeight: _rowHeight
        rowAnimatedHeight: _rowAnimatedHeight
        settingsRowHeight: _settingsRowHeight

        savedPanelX: dropWidgetController.panelX
        savedPanelY: dropWidgetController.panelY
        useSavedPanelPosition: dropWidgetController.hasSavedPanelPosition

        activeDropCount: dropWidgetController.activeDropCount
        availableServoCount: dropWidgetController.availableServoCount
        settingsOpen: dropWidgetController.settingsOpen
        panelExpanded: dropWidgetController.panelExpanded
        holdActive: dropWidgetController.holdActive

        dropMode: dropWidgetController.dropMode
        dropModeAll: dropWidgetController.dropModeAll
        dropModeGroups: dropWidgetController.dropModeGroups
        dropModeIndividual: dropWidgetController.dropModeIndividual

        controlBehavior: dropWidgetController.controlBehavior
        controlBehaviorStandard: dropWidgetController.controlBehaviorStandard
        controlBehaviorStepAndHold: dropWidgetController.controlBehaviorStepAndHold
        controlBehaviorSynchronizedPair: dropWidgetController.controlBehaviorSynchronizedPair
        dropModeEditingEnabled: dropWidgetController.dropModeEditingEnabled
        canDrop: dropWidgetController.canDrop
        showPhysicalPositionWhenIdle: dropWidgetController.showPhysicalPositionWhenIdle
        configurationMessage: dropWidgetController.configurationMessage
        holdButtonIdleText: dropWidgetController.holdButtonIdleText
        holdButtonActiveText: dropWidgetController.holdButtonActiveText

        currentDropLabel: dropWidgetController.currentDropLabel
        nextDropLabel: dropWidgetController.nextDropLabel
        sequenceOrderedTargets: dropWidgetController.sequenceOrderedTargets

        onControlBehaviorChangedFromUi: function(behavior) {
            dropWidgetController.setControlBehavior(behavior)
        }

        onDropModeChangedFromUi: function(mode) {
            dropWidgetController.setDropMode(mode)
        }

        onSequenceOrderMoveRequested: function(servoNumber, direction) {
            dropWidgetController.moveServoInSequence(servoNumber, direction)
        }

        onServoClosedPwmChanged: function(rowIndex, pwmValue) {
            dropWidgetController.setServoClosedPwm(rowIndex, pwmValue)
        }

        onServoOpenPositionPwmChanged: function(rowIndex, positionIndex, pwmValue) {
            dropWidgetController.setServoOpenPositionPwm(rowIndex, positionIndex, pwmValue)
        }

        onServoOpenPositionAddRequested: function(rowIndex) {
            dropWidgetController.addServoOpenPosition(rowIndex)
        }

        onServoOpenPositionRemoveRequested: function(rowIndex, positionIndex) {
            dropWidgetController.removeServoOpenPosition(rowIndex, positionIndex)
        }

        onServoPwmResetRequested: function(rowIndex) {
            dropWidgetController.resetServoPwmPositions(rowIndex)
        }

        onSettingsOpenChangedFromUi: function(open) {
            dropWidgetController.setSettingsOpen(open)
        }

        onPanelExpandedChangedFromUi: function(expanded) {
            dropWidgetController.setPanelExpanded(expanded)
        }

        onPanelPositionChangedFromUi: function(x, y) {
            dropWidgetController.setPanelPosition(x, y)
        }

        onVisibilityToggleRequested: function(rowIndex) {
            dropWidgetController.toggleServoVisibility(rowIndex)
        }

        onHoldPressed: {
            dropWidgetController.holdDropPressed()
        }

        onHoldReleased: {
            dropWidgetController.holdDropReleased()
        }
    }
}
