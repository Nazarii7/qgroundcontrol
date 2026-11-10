/****************************************************************************
 *
 * FlightModeOSD.qml
 * Compact active-flight-mode indicator for the Fly View OSD
 *
 ****************************************************************************/

import QtQuick
import "../Shared/OSD" as Shared

import QGroundControl.Controls
import QGroundControl.ScreenTools

Shared.OSDPanelSurface {
    id: root

    property var vehicle: null
    property bool displayEnabled: true


    readonly property string currentFlightMode:
        vehicle && vehicle.flightMode
            ? String(vehicle.flightMode).toUpperCase()
            : ""
    readonly property real horizontalPadding:
        Math.max(8, ScreenTools.defaultFontPixelWidth * 0.8)
    readonly property int readabilityTextStyle: root.osdStyle.textStyle
    readonly property color readabilityShadowColor: root.osdStyle.textShadowColor

    width: Math.max(76, modeLabel.implicitWidth + horizontalPadding * 2)
    height: Math.max(26, ScreenTools.defaultFontPixelHeight * 1.35)
    visible:
        displayEnabled
            && vehicle !== null
            && currentFlightMode.length > 0
    enabled: visible

    QGCLabel {
        id: modeLabel

        anchors.centerIn: parent

        text: root.currentFlightMode
        color: root.osdStyle.accentColor
        font.bold: true
        font.pixelSize: root.osdStyle.flightModeFontSize
        style: root.readabilityTextStyle
        styleColor: root.readabilityShadowColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
