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

import "DropWidget" as DropWidget

Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets: _toolInsets
    property var mapControl

    readonly property real _m: ScreenTools.defaultFontPixelHeight * 0.6
    readonly property real _panelWidth: 220
    readonly property real _headerHeight: 46
    readonly property real _rowHeight: 54
    readonly property real _rowAnimatedHeight: 58
    readonly property real _settingsRowHeight: 44
    readonly property real _topOffset: parentToolInsets ? parentToolInsets.topEdgeRightInset + _m : _m

    QGCToolInsets {
        id: _toolInsets

        leftEdgeTopInset:       parentToolInsets ? parentToolInsets.leftEdgeTopInset : 0
        leftEdgeCenterInset:    parentToolInsets ? parentToolInsets.leftEdgeCenterInset : 0
        leftEdgeBottomInset:    parentToolInsets ? parentToolInsets.leftEdgeBottomInset : 0

        rightEdgeTopInset:      _panelWidth + _m * 2
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

    DropWidget.DropWidgetController {
        id: dropWidgetController

        activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    }

    DropWidget.DropControlPanel {
        id: dropControlPanel

        anchors.fill: parent

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

        currentDropLabel: dropWidgetController.currentDropLabel
        nextDropLabel: dropWidgetController.nextDropLabel
        sequenceOrderedTargets: dropWidgetController.sequenceOrderedTargets

        onDropModeChangedFromUi: function(mode) {
            dropWidgetController.setDropMode(mode)
        }

        onSequenceOrderMoveRequested: function(servoNumber, direction) {
            dropWidgetController.moveServoInSequence(servoNumber, direction)
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