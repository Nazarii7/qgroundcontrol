/****************************************************************************
 *
 * LinkOSD.qml
 * Compact Doodle operating-frequency and per-antenna RSSI overlay for Fly View.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import "../Shared/OSD" as Shared

import QGroundControl.ScreenTools
import QGroundControl.DoodleLink 1.0

Shared.OSDPanelSurface {
    id: root

    property bool displayEnabled: true


    readonly property color accentColor: root.osdStyle.accentColor
    readonly property var antennaRssi: DoodleLinkManager.antennaRssi
    readonly property real frequencyMHz: Number(DoodleLinkManager.frequencyMHz)
    readonly property int readabilityTextStyle: root.osdStyle.textStyle
    readonly property color readabilityShadowColor: root.osdStyle.textShadowColor

    width: Math.max(164, ScreenTools.defaultFontPixelWidth * 18)
    height: Math.max(58, ScreenTools.defaultFontPixelHeight * 3.35)

    visible: displayEnabled

    function antennaText(index) {
        if (!DoodleLinkManager.valid
                || antennaRssi === null
                || antennaRssi === undefined
                || index < 0
                || index >= antennaRssi.length) {
            return "-- dBm"
        }

        var value = Number(antennaRssi[index])
        if (!isFinite(value) || isNaN(value)) {
            return "-- dBm"
        }

        return Math.round(value) + " dBm"
    }

    function frequencyText() {
        if (!isFinite(frequencyMHz) || isNaN(frequencyMHz) || frequencyMHz <= 0) {
            return "-- MHz"
        }

        return Math.round(frequencyMHz) + " MHz"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 5

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: width / 2
                color: DoodleLinkManager.valid
                       ? root.accentColor
                       : (root.osdStyle.inactiveLinkColor)
            }

            Text {
                text: "LINK"
                color: root.osdStyle.labelColor
                font.pixelSize: root.osdStyle.tinyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: root.frequencyText()
                color: root.osdStyle.labelColor
                font.pixelSize: root.osdStyle.tinyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            Text {
                text: "A1"
                color: root.osdStyle.mutedTextColor
                font.pixelSize: root.osdStyle.tinyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Text {
                text: root.antennaText(0)
                color: root.osdStyle.primaryTextColor
                font.pixelSize: root.osdStyle.bodyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "A2"
                color: root.osdStyle.mutedTextColor
                font.pixelSize: root.osdStyle.tinyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Text {
                text: root.antennaText(1)
                color: root.osdStyle.primaryTextColor
                font.pixelSize: root.osdStyle.bodyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
