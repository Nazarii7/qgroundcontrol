/****************************************************************************
 *
 * BatteryOSD.qml
 * Compact battery telemetry overlay for Fly View.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl.ScreenTools

Rectangle {
    id: root

    property var vehicle: null
    property bool transparentBackground: false

    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor:
        Qt.rgba(0.0, 0.0, 0.0, 0.96)

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

    // Matches the shared compact width used by Altitude and Horizon. The Fly
    // View can still override this value with its single layout source.
    width: Math.max(136, ScreenTools.defaultFontPixelWidth * 12)
    height: Math.max(58, ScreenTools.defaultFontPixelHeight * 3.2)
    radius: 9
    color:
        transparentBackground
            ? "transparent"
            : Qt.rgba(0.08, 0.10, 0.13, 0.86)
    border.width: 1
    border.color:
        transparentBackground
            ? Qt.rgba(1, 1, 1, 0.62)
            : Qt.rgba(1, 1, 1, 0.16)

    visible: primaryBattery !== null || secondaryBattery !== null

    function factNumber(fact) {
        if (fact === null || fact === undefined || fact.rawValue === undefined) {
            return NaN
        }

        var value = Number(fact.rawValue)
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
                    border.color: Qt.rgba(1, 1, 1, 0.92)
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, (parent.width - 4) * root.normalizedRemaining())
                        height: parent.height - 4
                        radius: 2
                        color: Qt.rgba(0.22, 0.78, 0.38, 0.95)
                        visible: root.isUsableRemaining(root.remaining)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.remainingText(root.remaining)
                        color: "white"
                        font.pixelSize: 11
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
                    color: Qt.rgba(1, 1, 1, 0.92)
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: root.voltageText(root.totalVoltage)
                color: "white"
                font.pixelSize: 13
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.transparentBackground
                   ? Qt.rgba(1, 1, 1, 0.52)
                   : Qt.rgba(1, 1, 1, 0.18)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: 6

            Text {
                text: root.currentText(root.current)
                color: Qt.rgba(0.30, 0.86, 0.91, 0.98)
                font.pixelSize: 12
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: root.consumedText(root.consumed)
                color: Qt.rgba(1, 1, 1, 0.90)
                font.pixelSize: 12
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
