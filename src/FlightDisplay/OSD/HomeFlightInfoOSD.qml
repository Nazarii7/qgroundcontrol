/****************************************************************************
 *
 * HomeFlightInfoOSD.qml
 * Compact Home distance and flight-time indicator for the Fly View OSD
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools

Item {
    id: root

    property var vehicle: null
    property bool displayEnabled: true
    property bool transparentBackground: false
    property real orbitRadius: Math.max(1, height / 2)
    property real orbitGap: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.6)

    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor:
        Qt.rgba(0.0, 0.0, 0.0, 0.96)

    readonly property var distanceToHomeFact:
        vehicle && vehicle.factExists("distanceToHome")
            ? vehicle.getFact("distanceToHome")
            : null
    readonly property var flightTimeFact:
        vehicle && vehicle.factExists("flightTime")
            ? vehicle.getFact("flightTime")
            : null

    readonly property real distanceToHomeValue:
        distanceToHomeFact && distanceToHomeFact.value !== undefined
            ? Number(distanceToHomeFact.value)
            : NaN
    readonly property bool distanceToHomeValid:
        isFinite(distanceToHomeValue)
    readonly property string distanceToHomeText:
        distanceToHomeValid && distanceToHomeFact.valueString !== undefined
            ? String(distanceToHomeFact.valueString)
            : "--"
    readonly property string distanceToHomeUnits:
        distanceToHomeValid && distanceToHomeFact.units
            ? String(distanceToHomeFact.units)
            : ""
    readonly property string flightTimeText:
        flightTimeFact
            && flightTimeFact.valueString !== undefined
            && flightTimeFact.valueString !== null
                ? String(flightTimeFact.valueString)
                : "--:--:--"

    readonly property real contentMargin:
        Math.max(6, ScreenTools.defaultFontPixelWidth * 0.65)
    readonly property real contentWidth:
        Math.max(210, ScreenTools.defaultFontPixelWidth * 22)
    readonly property real arcRadius:
        Math.max(orbitRadius + orbitGap, orbitRadius)
    readonly property real arcExtension:
        arcRadius
            - Math.sqrt(
                Math.max(
                    0,
                    arcRadius * arcRadius - orbitRadius * orbitRadius
                )
            )
    readonly property color panelColor:
        transparentBackground
            ? "transparent"
            : Qt.rgba(0.08, 0.10, 0.13, 0.90)
    readonly property color panelBorderColor:
        transparentBackground
            ? Qt.rgba(1.0, 1.0, 1.0, 0.62)
            : Qt.rgba(1.0, 1.0, 1.0, 0.16)

    // Keep the Home block exactly as high as StatusMessageOSD so both bottom
    // OSD elements form one visual row beside the artificial horizon.
    // The additional width is a circular shoulder which follows the left side
    // of the horizon at the configured orbitGap, including a seamless zero-gap
    // connection.
    width: contentWidth + arcExtension
    height: Math.max(54, ScreenTools.defaultFontPixelHeight * 3.2)
    visible: displayEnabled && vehicle !== null
    enabled: visible

    Canvas {
        id: panelBackground

        anchors.fill: parent
        antialiasing: true

        property color backgroundColor: root.panelColor
        property color outlineColor: root.panelBorderColor

        onBackgroundColorChanged: requestPaint()
        onOutlineColorChanged: requestPaint()

        onPaint: {
            var context = getContext("2d")
            var panelWidth = root.contentWidth
            var panelHeight = root.height
            var radius = root.arcRadius
            var circleCenterX = panelWidth + radius
            var circleCenterY = panelHeight - root.orbitRadius
            var topDeltaY = -circleCenterY
            var bottomDeltaY = root.orbitRadius
            var topDeltaX = -Math.sqrt(
                Math.max(0, radius * radius - topDeltaY * topDeltaY)
            )
            var bottomDeltaX = -Math.sqrt(
                Math.max(0, radius * radius - bottomDeltaY * bottomDeltaY)
            )
            var topX = circleCenterX + topDeltaX
            var bottomX = circleCenterX + bottomDeltaX
            var startAngle = Math.atan2(topDeltaY, topDeltaX)
            var endAngle = Math.atan2(bottomDeltaY, bottomDeltaX)
            var cornerRadius = Math.min(9, panelHeight / 4)

            context.clearRect(0, 0, width, height)
            context.beginPath()
            context.moveTo(cornerRadius, 0)
            context.lineTo(topX, 0)
            context.arc(
                circleCenterX,
                circleCenterY,
                radius,
                startAngle,
                endAngle,
                true
            )
            context.lineTo(cornerRadius, panelHeight)
            context.quadraticCurveTo(0, panelHeight, 0, panelHeight - cornerRadius)
            context.lineTo(0, cornerRadius)
            context.quadraticCurveTo(0, 0, cornerRadius, 0)
            context.closePath()
            context.fillStyle = backgroundColor
            context.fill()
            context.lineWidth = 1
            context.lineJoin = "round"
            context.strokeStyle = outlineColor
            context.stroke()
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: root.contentMargin
        width: root.contentWidth - root.contentMargin * 2
        spacing: Math.max(7, ScreenTools.defaultFontPixelWidth * 0.7)

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("HOME")
                color: Qt.rgba(1.0, 1.0, 1.0, 0.72)
                font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.60)
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.max(3, ScreenTools.defaultFontPixelWidth * 0.3)

                QGCLabel {
                    text: root.distanceToHomeText
                    color: "white"
                    font.bold: true
                    font.pixelSize: Math.max(17, ScreenTools.defaultFontPixelHeight * 1.05)
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }

                QGCLabel {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 1
                    text: root.distanceToHomeUnits
                    color: "white"
                    font.bold: true
                    font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.62)
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    visible: text.length > 0
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: 1
            Layout.bottomMargin: 1
            width: 1
            color: root.transparentBackground
                   ? Qt.rgba(1.0, 1.0, 1.0, 0.52)
                   : Qt.rgba(1.0, 1.0, 1.0, 0.17)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("FLIGHT TIME")
                color: Qt.rgba(1.0, 1.0, 1.0, 0.72)
                font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.60)
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            QGCLabel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.flightTimeText
                color: "white"
                font.bold: true
                font.family: ScreenTools.fixedFontFamily
                font.pixelSize: Math.max(15, ScreenTools.defaultFontPixelHeight * 0.90)
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
