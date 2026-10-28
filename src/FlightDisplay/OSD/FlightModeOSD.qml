/****************************************************************************
 *
 * FlightModeOSD.qml
 * Compact active-flight-mode indicator for the Fly View OSD
 *
 ****************************************************************************/

import QtQuick

import QGroundControl.Controls
import QGroundControl.ScreenTools

Rectangle {
    id: root

    property var vehicle: null
    property bool displayEnabled: true
    property bool transparentBackground: false

    readonly property string currentFlightMode:
        vehicle && vehicle.flightMode
            ? String(vehicle.flightMode).toUpperCase()
            : ""
    readonly property real horizontalPadding:
        Math.max(8, ScreenTools.defaultFontPixelWidth * 0.8)
    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor:
        Qt.rgba(0.0, 0.0, 0.0, 0.96)

    width: Math.max(76, modeLabel.implicitWidth + horizontalPadding * 2)
    height: Math.max(26, ScreenTools.defaultFontPixelHeight * 1.35)
    radius: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.45)
    color:
        transparentBackground
            ? "transparent"
            : Qt.rgba(0.08, 0.10, 0.13, 0.88)
    border.width: 1
    border.color:
        transparentBackground
            ? Qt.rgba(0.14, 0.82, 0.88, 0.88)
            : Qt.rgba(0.14, 0.82, 0.88, 0.30)
    visible:
        displayEnabled
            && vehicle !== null
            && currentFlightMode.length > 0
    enabled: visible

    QGCLabel {
        id: modeLabel

        anchors.centerIn: parent

        text: root.currentFlightMode
        color: Qt.rgba(0.14, 0.82, 0.88, 1.0)
        font.bold: true
        font.pixelSize:
            Math.max(11, ScreenTools.defaultFontPixelHeight * 0.68)
        style: root.readabilityTextStyle
        styleColor: root.readabilityShadowColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
