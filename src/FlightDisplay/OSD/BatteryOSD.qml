/****************************************************************************
 *
 * BatteryOSD.qml
 * Compact battery telemetry overlay for Fly View.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Shared/OSD" as Shared

import QGroundControl.ScreenTools

Shared.OSDPanelSurface {
    id: root

    property var vehicle: null
    // Local display preferences only; never writes flight-controller parameters.
    property bool cellDetailsExpanded: false
    property int selectedCellCount: 0
    property real maximumExpandedHeight: Number.POSITIVE_INFINITY
    readonly property real baseHeight: Math.max(58, ScreenTools.defaultFontPixelHeight * 3.2)
    readonly property real expandedHeight: Math.min(baseHeight + cellDetailsColumn.implicitHeight + 10,
                                                  Math.max(baseHeight, maximumExpandedHeight))
    readonly property bool revealCellButton: cellDetailsExpanded || batteryHover.hovered
                                            || cellDetailsToggle.activeFocus || ScreenTools.isMobile
    // This project's selector offers even series counts. Default still reads
    // the vehicle's telemetry, including other real battery configurations.
    readonly property var cellCountValues: [0, 2, 4, 6, 8, 10, 12, 14, 16]
    readonly property var cellCountOptions: cellCountValues.map(function(value) {
        return value === 0 ? qsTr("Default") : String(value) + "S"
    })
    onVehicleChanged: selectedCellCount = 0

    HoverHandler { id: batteryHover }


    readonly property int readabilityTextStyle: root.osdStyle.textStyle
    readonly property color readabilityShadowColor: root.osdStyle.textShadowColor

    // Primary QGC battery monitor (Battery 0).
    readonly property var primaryBattery:
        vehicle && vehicle.batteries && vehicle.batteries.count > 0
            ? vehicle.batteries.get(0)
            : null

    // Optional secondary monitor. Used only as a fallback when Battery 0
    // current is unavailable/saturated, preserving the existing behavior.
    readonly property var secondaryBattery:
        vehicle && vehicle.batteries && vehicle.batteries.count > 1
            ? vehicle.batteries.get(1)
            : null

    readonly property real primaryVoltage: factNumber(primaryBattery ? primaryBattery.voltage : null)
    readonly property real secondaryVoltage: factNumber(secondaryBattery ? secondaryBattery.voltage : null)
    readonly property real totalVoltage: isUsableVoltage(primaryVoltage)
                                         ? primaryVoltage
                                         : (isUsableVoltage(secondaryVoltage) ? secondaryVoltage : NaN)

    readonly property real primaryCurrent: factNumber(primaryBattery ? primaryBattery.current : null)
    readonly property real secondaryCurrent: factNumber(secondaryBattery ? secondaryBattery.current : null)
    readonly property bool primaryCurrentUsable: isUsableCurrent(primaryCurrent)
    readonly property bool secondaryCurrentUsable: isUsableCurrent(secondaryCurrent)
    readonly property real current: primaryCurrentUsable
                                    ? primaryCurrent
                                    : (secondaryCurrentUsable ? secondaryCurrent : NaN)
    readonly property string currentSource: primaryCurrentUsable
                                            ? "battery0"
                                            : (secondaryCurrentUsable ? "battery1" : "none")

    // Match voltage to the monitor selected by the existing current fallback.
    // Never multiply one monitor's pack voltage by another monitor's current,
    // or sum monitors that may describe the same electrical supply.
    readonly property real powerVoltage: currentSource === "battery0" ? primaryVoltage
        : currentSource === "battery1" ? secondaryVoltage : NaN
    readonly property real powerWatts: isUsableVoltage(powerVoltage) && isUsableCurrent(current)
        ? powerVoltage * current : NaN
    readonly property string powerText: isFinite(powerWatts) ? powerWatts.toFixed(1) + " W" : "-- W"

    readonly property real primaryConsumed: factNumber(primaryBattery ? primaryBattery.mahConsumed : null)
    readonly property real secondaryConsumed: factNumber(secondaryBattery ? secondaryBattery.mahConsumed : null)
    readonly property real consumed: currentSource === "battery1" && isUsableConsumed(secondaryConsumed)
                                     ? secondaryConsumed
                                     : (isUsableConsumed(primaryConsumed)
                                        ? primaryConsumed
                                        : (isUsableConsumed(secondaryConsumed) ? secondaryConsumed : NaN))

    readonly property real primaryRemaining: factNumber(primaryBattery ? primaryBattery.percentRemaining : null)
    readonly property real secondaryRemaining: factNumber(secondaryBattery ? secondaryBattery.percentRemaining : null)
    readonly property real remaining: isUsableRemaining(primaryRemaining)
                                      ? primaryRemaining
                                      : (isUsableRemaining(secondaryRemaining) ? secondaryRemaining : NaN)

    // Read the same monitor that supplies pack voltage. The existing current,
    // consumption and charge fallback rules above are preserved.
    readonly property var voltageBattery: isUsableVoltage(primaryVoltage) ? primaryBattery
                                         : isUsableVoltage(secondaryVoltage) ? secondaryBattery : null
    readonly property real reportedCellVoltage: factNumber(voltageBattery
        && voltageBattery.cellVoltage !== undefined ? voltageBattery.cellVoltage : null)
    readonly property bool reportedCellVoltageUsable: isFinite(reportedCellVoltage)
        && reportedCellVoltage > 0 && reportedCellVoltage <= 6
        && (!isUsableVoltage(totalVoltage) || totalVoltage / reportedCellVoltage >= 1.5)
    readonly property int reportedSeriesCount: {
        if (!reportedCellVoltageUsable || !isUsableVoltage(totalVoltage)) return 0
        var ratio = totalVoltage / reportedCellVoltage
        var rounded = Math.round(ratio)
        return rounded >= 2 && rounded <= 16 && Math.abs(ratio - rounded) < 0.1 ? rounded : 0
    }
    readonly property bool manualCellCount: selectedCellCount > 0 && cellCountValues.indexOf(selectedCellCount) >= 0
    readonly property real averageCellVoltage: manualCellCount
        ? (isUsableVoltage(totalVoltage) ? totalVoltage / selectedCellCount : NaN)
        : (reportedCellVoltageUsable ? reportedCellVoltage : NaN)
    readonly property string averageCellText: isFinite(averageCellVoltage) && averageCellVoltage > 0
        ? averageCellVoltage.toFixed(2) + " V" : "-- V"
    readonly property bool cellSelectionWarning: manualCellCount
        && ((reportedSeriesCount > 0 && selectedCellCount !== reportedSeriesCount)
            || (isFinite(averageCellVoltage) && averageCellVoltage > 5))
    readonly property string cellSourceText: {
        if (cellSelectionWarning) {
            if (reportedSeriesCount > 0 && selectedCellCount !== reportedSeriesCount)
                return qsTr("Check S selection: telemetry indicates %1S.").arg(reportedSeriesCount)
            return qsTr("Check S selection: %1 V / %2S = %3 V/cell.")
                .arg(totalVoltage.toFixed(2)).arg(selectedCellCount).arg(averageCellVoltage.toFixed(2))
        }
        if (manualCellCount) return qsTr("%1S · pack V / %1 · average").arg(selectedCellCount)
        if (reportedCellVoltageUsable) return reportedSeriesCount > 0
            ? qsTr("Default · %1S · average from telemetry").arg(reportedSeriesCount) : qsTr("Default · average from telemetry")
        return qsTr("No cell telemetry. Select S for average.")
    }
    readonly property string percentageExplanation: isUsableRemaining(remaining)
        ? qsTr("Vehicle reports %1% remaining. This OSD does not calculate charge from voltage.").arg(String(remaining))
        : qsTr("Remaining charge is not reported by the vehicle.")

    // Matches the shared compact width used by Altitude and Horizon. The Fly
    // View can still override this value with its single layout source.
    width: Math.max(136, ScreenTools.defaultFontPixelWidth * 12)
    height: cellDetailsExpanded ? expandedHeight : baseHeight
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

    visible: primaryBattery !== null || secondaryBattery !== null

    function factNumber(fact) {
        if (fact === null || fact === undefined || fact.rawValue === undefined) {
            return NaN
        }

        var raw = fact.rawValue
        if (raw === null || typeof raw === "boolean" || String(raw).trim().length === 0) {
            return NaN
        }
        var value = Number(raw)
        return isFinite(value) ? value : NaN
    }

    function isUsableVoltage(value) {
        return isFinite(value) && !isNaN(value) && value > 0
    }

    function isUsableRemaining(value) {
        return isFinite(value) && !isNaN(value) && value >= 0 && value <= 100
    }

    function isUsableConsumed(value) {
        return isFinite(value) && !isNaN(value) && value >= 0
    }

    function isUsableCurrent(value) {
        if (!isFinite(value) || isNaN(value)) {
            return false
        }

        // MAVLink BATTERY_STATUS.current_battery is int16 in centi-amps.
        // +/-327.67 A is the transport limit. A value at the clamp is treated
        // as invalid telemetry rather than shown as a real current value.
        return Math.abs(value) < 327.6
    }

    function voltageText(value) {
        return !isUsableVoltage(value) ? "-- V" : value.toFixed(2) + " V"
    }

    function currentText(value) {
        return !isUsableCurrent(value) ? "-- A" : value.toFixed(1) + " A"
    }

    function remainingText(value) {
        return !isUsableRemaining(value) ? "--%" : Math.round(value) + "%"
    }

    function consumedText(value) {
        return !isUsableConsumed(value) ? "-- mAh" : Math.round(value) + " mAh"
    }

    function normalizedRemaining() {
        if (!root.isUsableRemaining(root.remaining)) {
            return 0
        }
        return Math.max(0, Math.min(100, root.remaining)) / 100.0
    }

    Item {
        id: batteryHeader
        width: parent.width
        height: root.baseHeight
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 23
                spacing: 6

                Item {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 20

                    Rectangle {
                        id: batteryBody
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 20
                        radius: 3
                        color: "transparent"
                        border.width: 1
                        border.color: root.osdStyle.iconColor
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, (parent.width - 4) * root.normalizedRemaining())
                            height: parent.height - 4
                            radius: 2
                            color: root.osdStyle.batteryFillColor
                            visible: root.isUsableRemaining(root.remaining)
                        }

                        Text {
                            anchors.centerIn: parent
                            objectName: "batteryPercentText"
                            text: root.remainingText(root.remaining)
                            HoverHandler { id: percentageHover }
                            ToolTip.visible: percentageHover.hovered
                            ToolTip.delay: 700
                            ToolTip.text: root.percentageExplanation
                            color: root.osdStyle.primaryTextColor
                            font.pixelSize: root.osdStyle.smallFontSize
                            font.bold: true
                            style: root.readabilityTextStyle
                            styleColor: root.readabilityShadowColor
                        }
                    }

                    Rectangle {
                        anchors.left: batteryBody.right
                        anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 8
                        radius: 1
                        color: root.osdStyle.iconColor
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    objectName: "batteryVoltageText"
                    text: root.voltageText(root.totalVoltage)
                    color: root.osdStyle.primaryTextColor
                    font.pixelSize: root.osdStyle.emphasisFontSize
                    font.bold: true
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    horizontalAlignment: Text.AlignRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.osdStyle.separatorColor
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 3

                Text {
                    objectName: "batteryCurrentText"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    text: root.currentText(root.current)
                    color: root.osdStyle.currentColor
                    font.pixelSize: root.osdStyle.bodyFontSize
                    font.bold: true
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 8
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }

                ToolButton {
                    id: cellDetailsToggle
                    objectName: "batteryCellDetailsToggle"
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    padding: 0
                    opacity: root.revealCellButton ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    focusPolicy: Qt.TabFocus
                    Accessible.name: root.cellDetailsExpanded ? qsTr("Close battery cell details") : qsTr("Open battery cell details")
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: Accessible.name
                    onClicked: root.cellDetailsExpanded = !root.cellDetailsExpanded
                    contentItem: Text {
                        text: root.cellDetailsExpanded ? "▴" : "▾"
                        color: root.osdStyle.primaryTextColor
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 3
                        color: cellDetailsToggle.down ? root.osdStyle.buttonHoverBackground
                            : cellDetailsToggle.hovered || cellDetailsToggle.activeFocus ? root.osdStyle.buttonBackground : "transparent"
                        border.width: cellDetailsToggle.activeFocus ? 1 : 0
                        border.color: root.osdStyle.buttonBorderColor
                    }
                }

                Text {
                    objectName: "batteryConsumedText"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    text: root.consumedText(root.consumed)
                    color: root.osdStyle.labelColor
                    font.pixelSize: root.osdStyle.bodyFontSize
                    font.bold: true
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 8
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    Flickable {
        id: cellDetailsViewport
        objectName: "batteryCellDetailsViewport"
        x: 8
        y: root.baseHeight
        width: Math.max(0, parent.width - 16)
        height: Math.max(0, root.height - root.baseHeight)
        contentHeight: cellDetailsColumn.implicitHeight + 10
        contentWidth: width
        clip: true
        visible: root.cellDetailsExpanded || height > 0.5
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: cellDetailsColumn
            width: Math.max(0, cellDetailsViewport.width - 4)
            spacing: 5

            Rectangle {
                width: parent.width
                height: 1
                color: root.osdStyle.separatorColor
            }
            ComboBox {
                id: cellCountSelector
                objectName: "batteryCellCountSelector"
                width: parent.width
                height: 24
                model: root.cellCountOptions
                currentIndex: Math.max(0, root.cellCountValues.indexOf(root.selectedCellCount))
                Accessible.name: qsTr("Battery series cell count for display")
                onActivated: function(index) { root.selectedCellCount = root.cellCountValues[index] }
                leftPadding: 6
                rightPadding: 18
                contentItem: Text {
                    text: cellCountSelector.displayText
                    color: root.osdStyle.primaryTextColor
                    font.pixelSize: 10
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    x: cellCountSelector.width - width - 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▾"
                    color: root.osdStyle.primaryTextColor
                    font.pixelSize: 10
                }
                background: Rectangle {
                    radius: 4
                    color: root.osdStyle.buttonBackground
                    border.width: 1
                    border.color: root.osdStyle.buttonBorderColor
                }
                delegate: ItemDelegate {
                    width: cellCountSelector.width
                    height: 24
                    highlighted: cellCountSelector.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: root.osdStyle.primaryTextColor
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.highlighted ? root.osdStyle.buttonHoverBackground : root.osdStyle.solidBackground
                    }
                }
                popup: Popup {
                    y: cellCountSelector.height + 2
                    width: cellCountSelector.width
                    height: Math.min(180, contentItem.implicitHeight + 4)
                    padding: 2
                    background: Rectangle {
                        color: root.osdStyle.solidDetailBackground
                        radius: 4
                        border.width: 1
                        border.color: root.osdStyle.buttonBorderColor
                    }
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: cellCountSelector.popup.visible ? cellCountSelector.delegateModel : null
                        currentIndex: cellCountSelector.highlightedIndex
                        ScrollBar.vertical: ScrollBar { }
                    }
                }
            }
            RowLayout {
                width: parent.width
                spacing: 4
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    text: qsTr("AVG/CELL")
                    color: root.osdStyle.secondaryTextColor
                    font.pixelSize: 9
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }
                Text {
                    id: cellAverageValue
                    objectName: "batteryCellAverageValue"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignBaseline
                    text: root.averageCellText.replace(/ V$/, "")
                    horizontalAlignment: Text.AlignRight
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 8
                    color: root.cellSelectionWarning ? root.osdStyle.warningColor : root.osdStyle.primaryTextColor
                    font.pixelSize: 13
                    font.bold: true
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }
                Text {
                    id: cellAverageUnit
                    objectName: "batteryCellAverageUnit"
                    text: "V"
                    Layout.alignment: Qt.AlignBaseline
                    // Equal unit columns also align the numbers before V/W.
                    Layout.preferredWidth: Math.max(cellAverageUnit.implicitWidth, batteryPowerUnit.implicitWidth)
                    Layout.minimumWidth: Layout.preferredWidth
                    horizontalAlignment: Text.AlignRight
                    color: root.cellSelectionWarning ? root.osdStyle.warningColor : root.osdStyle.primaryTextColor
                    font.pixelSize: 13
                    font.bold: true
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }
            }
            Text {
                objectName: "batteryCellSourceText"
                width: parent.width
                text: root.cellSourceText
                color: root.cellSelectionWarning ? root.osdStyle.warningColor : root.osdStyle.secondaryTextColor
                font.pixelSize: 9
                wrapMode: Text.WordWrap
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }
            RowLayout {
                width: parent.width
                spacing: 4
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    text: qsTr("POWER")
                    color: root.osdStyle.secondaryTextColor
                    font.pixelSize: 9
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }
                Text {
                    objectName: "batteryPowerValue"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignBaseline
                    text: root.powerText.replace(/ W$/, "")
                    horizontalAlignment: Text.AlignRight
                    color: root.osdStyle.primaryTextColor
                    font.pixelSize: 13
                    font.bold: true
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 8
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }
                Text {
                    id: batteryPowerUnit
                    objectName: "batteryPowerUnit"
                    text: "W"
                    Layout.alignment: Qt.AlignBaseline
                    // Equal unit columns also align the numbers before V/W.
                    Layout.preferredWidth: Math.max(cellAverageUnit.implicitWidth, batteryPowerUnit.implicitWidth)
                    Layout.minimumWidth: Layout.preferredWidth
                    horizontalAlignment: Text.AlignRight
                    color: root.osdStyle.primaryTextColor
                    font.pixelSize: 13
                    font.bold: true
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }
            }
            Text {
                width: parent.width
                visible: !isFinite(root.powerWatts)
                text: qsTr("Power: voltage/current unavailable.")
                color: root.osdStyle.secondaryTextColor
                font.pixelSize: 9
                wrapMode: Text.WordWrap
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }
        }
    }
}
