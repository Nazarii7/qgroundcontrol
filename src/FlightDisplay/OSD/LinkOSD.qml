/****************************************************************************
 *
 * LinkOSD.qml
 * Compact Doodle operating-frequency and per-antenna RSSI overlay for Fly View.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl.ScreenTools
import QGroundControl.DoodleLink 1.0

Rectangle {
    id: root

    property bool displayEnabled: true
    property bool transparentBackground: false

    readonly property color accentColor: Qt.rgba(0.14, 0.82, 0.88, 1.0)
    readonly property var antennaRssi: DoodleLinkManager.antennaRssi
    readonly property real frequencyMHz: Number(DoodleLinkManager.frequencyMHz)
    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor:
        Qt.rgba(0.0, 0.0, 0.0, 0.96)

    width: Math.max(164, ScreenTools.defaultFontPixelWidth * 18)
    height: Math.max(58, ScreenTools.defaultFontPixelHeight * 3.35)
    radius: 8
    color:
        transparentBackground
            ? "transparent"
            : Qt.rgba(0.08, 0.10, 0.13, 0.86)
    border.width: 1
    border.color:
        transparentBackground
            ? Qt.rgba(1, 1, 1, 0.62)
            : Qt.rgba(1, 1, 1, 0.14)

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
                       : (root.transparentBackground
                          ? Qt.rgba(1, 1, 1, 0.58)
                          : Qt.rgba(1, 1, 1, 0.28))
            }

            Text {
                text: "LINK"
                color: Qt.rgba(1, 1, 1, 0.90)
                font.pixelSize: 10
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: root.frequencyText()
                color: Qt.rgba(1, 1, 1, 0.90)
                font.pixelSize: 10
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
                color: Qt.rgba(1, 1, 1, 0.62)
                font.pixelSize: 10
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Text {
                text: root.antennaText(0)
                color: "white"
                font.pixelSize: 12
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "A2"
                color: Qt.rgba(1, 1, 1, 0.62)
                font.pixelSize: 10
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Text {
                text: root.antennaText(1)
                color: "white"
                font.pixelSize: 12
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
