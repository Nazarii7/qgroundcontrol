/****************************************************************************
 *
 * AltitudeTapeOSD.qml
 * Vertical altitude tape with compact flight telemetry for Fly View video.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl.ScreenTools

Item {
    id: root

    property var vehicle: null
    property bool displayEnabled: true
    property bool transparentBackground: false
    property bool preferTerrainAltitude: true
    // Exposed so the parent can give Battery, Altitude and Horizon one exact
    // shared width.
    property real panelWidth:
        Math.max(ScreenTools.defaultFontPixelWidth * 12, 136)
    // Vertical center shared by the tape pointer and the telemetry panel.
    // The parent places this line at the Fly View crosshair height.
    property real tapeCenterY: height / 2

    readonly property var terrainAltitudeFact:
        vehicle && vehicle.altitudeAboveTerr
            ? vehicle.altitudeAboveTerr
            : null
    readonly property var relativeAltitudeFact:
        vehicle && vehicle.altitudeRelative
            ? vehicle.altitudeRelative
            : null
    readonly property var climbRateFact:
        vehicle && vehicle.climbRate
            ? vehicle.climbRate
            : null
    readonly property var groundSpeedFact:
        vehicle && vehicle.groundSpeed
            ? vehicle.groundSpeed
            : null

    // QGC exposes MAVLink GPS_FIX_TYPE through vehicle.gps.lock:
    // 0/1 = no fix, 2 = 2D, 3 and higher = 3D/DGPS/RTK.
    readonly property var gpsFixFact:
        vehicle && vehicle.gps && vehicle.gps.lock
            ? vehicle.gps.lock
            : null

    readonly property real gpsFixType: factNumber(gpsFixFact)
    readonly property real terrainAltitudeValue: factNumber(terrainAltitudeFact)
    readonly property bool gpsHas3DFix:
        numberIsValid(gpsFixType) && gpsFixType >= 3

    readonly property bool terrainAltitudeValid:
        preferTerrainAltitude
        && gpsHas3DFix
        && numberIsValid(terrainAltitudeValue)
        && terrainAltitudeValue >= 0
    readonly property var activeAltitudeFact:
        terrainAltitudeValid ? terrainAltitudeFact : relativeAltitudeFact

    readonly property real altitudeValue: factNumber(activeAltitudeFact)
    readonly property real climbRateValue: factNumber(climbRateFact)
    readonly property real groundSpeedValue: factNumber(groundSpeedFact)

    readonly property bool altitudeValid: numberIsValid(altitudeValue)
    readonly property bool climbRateValid: numberIsValid(climbRateValue)
    readonly property bool groundSpeedValid: numberIsValid(groundSpeedValue)

    readonly property string altitudeTitle:
        terrainAltitudeValid ? qsTr("ALTITUDE (AGL)") : qsTr("ALTITUDE (REL)")
    readonly property string altitudeUnits: factUnits(activeAltitudeFact, "m")
    readonly property string climbRateUnits: factUnits(climbRateFact, "m/s")
    readonly property string groundSpeedUnits: factUnits(groundSpeedFact, "m/s")

    readonly property color accentColor: Qt.rgba(0.14, 0.82, 0.88, 1.0)
    readonly property color altitudeColor: Qt.rgba(1.0, 0.80, 0.0, 1.0)
    readonly property color panelColor:
        transparentBackground
            ? "transparent"
            : Qt.rgba(0.08, 0.10, 0.13, 0.90)
    readonly property color primaryTextColor:
        transparentBackground
            ? Qt.rgba(1.0, 1.0, 1.0, 1.0)
            : Qt.rgba(1.0, 1.0, 1.0, 0.96)
    readonly property color secondaryTextColor:
        transparentBackground
            ? Qt.rgba(1.0, 1.0, 1.0, 0.90)
            : Qt.rgba(1.0, 1.0, 1.0, 0.68)
    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor:
        Qt.rgba(0.0, 0.0, 0.0, 0.96)

    readonly property real minorStep: 5.0
    readonly property real mediumStep: 10.0
    readonly property real majorStep: 50.0
    readonly property real visibleAltitudeRange: 210.0
    readonly property real pixelsPerAltitudeUnit: altitudeTape.height / visibleAltitudeRange
    readonly property real baseTickAltitude:
        altitudeValid ? Math.floor(altitudeValue / minorStep) * minorStep : 0

    readonly property real tapeWidth:
        Math.max(112, ScreenTools.defaultFontPixelWidth * 13.5)
    readonly property real panelHeight:
        Math.max(220, ScreenTools.defaultFontPixelHeight * 12.6)
    readonly property real componentSpacing:
        Math.max(7, ScreenTools.defaultFontPixelWidth * 0.8)
    width: tapeWidth + componentSpacing + panelWidth
    height: Math.max(370, ScreenTools.defaultFontPixelHeight * 22)

    visible: displayEnabled && vehicle !== null

    function numberIsValid(value) {
        return isFinite(value) && !isNaN(value)
    }

    function factNumber(fact) {
        if (fact === null || fact === undefined) {
            return NaN
        }

        if (fact.cookedValue !== undefined) {
            var cooked = Number(fact.cookedValue)
            if (numberIsValid(cooked)) {
                return cooked
            }
        }

        if (fact.rawValue !== undefined) {
            var raw = Number(fact.rawValue)
            if (numberIsValid(raw)) {
                return raw
            }
        }

        return NaN
    }

    function factIsValid(fact) {
        return numberIsValid(factNumber(fact))
    }

    function factUnits(fact, fallbackUnits) {
        if (fact !== null
                && fact !== undefined
                && fact.units !== undefined
                && fact.units !== null
                && String(fact.units).length > 0) {
            return String(fact.units)
        }

        return fallbackUnits
    }

    function normalizedZero(value, precision) {
        if (!numberIsValid(value)) {
            return NaN
        }

        var threshold = 0.5 / Math.pow(10, precision)
        return Math.abs(value) < threshold ? 0 : value
    }

    function altitudeText(value) {
        var normalized = normalizedZero(value, 1)
        if (!numberIsValid(normalized)) {
            return "--"
        }

        // Near the takeoff point tenths of a unit are useful and match the
        // precision of QGC's standard relative-altitude telemetry.
        return Math.abs(normalized) < 10
               ? normalized.toFixed(1)
               : String(Math.round(normalized))
    }

    function rateText(value) {
        var normalized = normalizedZero(value, 1)
        return numberIsValid(normalized) ? normalized.toFixed(1) : "--"
    }

    function speedText(value) {
        var normalized = normalizedZero(value, 1)
        return numberIsValid(normalized) ? normalized.toFixed(1) : "--"
    }

    function isStepMultiple(value, step) {
        var quotient = value / step
        return Math.abs(quotient - Math.round(quotient)) < 0.001
    }

    Item {
        id: altitudeTape

        anchors.left: parent.left
        y: root.tapeCenterY - height / 2
        width: root.tapeWidth
        height: root.height
        clip: true

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: Math.round(parent.width * 0.27) + 1
            width: 2
            color: Qt.rgba(0.0, 0.0, 0.0, 0.58)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: Math.round(parent.width * 0.27)
            width: 1
            color: root.transparentBackground
                   ? Qt.rgba(1.0, 1.0, 1.0, 0.82)
                   : Qt.rgba(1.0, 1.0, 1.0, 0.30)
        }

        Repeater {
            model: 45

            delegate: Item {
                id: tickItem

                required property int index

                readonly property real tickAltitude:
                    root.baseTickAltitude + (index - 22) * root.minorStep
                readonly property real relativeAltitude:
                    tickAltitude - root.altitudeValue
                readonly property bool majorTick:
                    root.isStepMultiple(tickAltitude, root.majorStep)
                readonly property bool mediumTick:
                    !majorTick && root.isStepMultiple(tickAltitude, root.mediumStep)
                readonly property bool currentTick:
                    Math.abs(relativeAltitude) < root.minorStep * 0.51

                x: 0
                y: root.altitudeValid
                   ? altitudeTape.height / 2
                     - relativeAltitude * root.pixelsPerAltitudeUnit
                     - height / 2
                   : -100
                width: altitudeTape.width
                height: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.72)
                visible:
                    root.altitudeValid
                    && y > -height
                    && y < altitudeTape.height
                    && (!root.terrainAltitudeValid || tickAltitude >= 0)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    x: Math.round(parent.width * 0.27) + 1
                    width: tickItem.majorTick
                           ? Math.max(24, parent.width * 0.24)
                           : (tickItem.mediumTick
                              ? Math.max(16, parent.width * 0.17)
                              : Math.max(10, parent.width * 0.11))
                    height: tickItem.currentTick ? 4 : 2
                    radius: height / 2
                    color: Qt.rgba(0.0, 0.0, 0.0, 0.68)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(parent.width * 0.27)
                    width: tickItem.majorTick
                           ? Math.max(24, parent.width * 0.24)
                           : (tickItem.mediumTick
                              ? Math.max(16, parent.width * 0.17)
                              : Math.max(10, parent.width * 0.11))
                    height: tickItem.currentTick ? 3 : 1
                    radius: height / 2
                    color: tickItem.currentTick
                           ? root.accentColor
                           : (tickItem.majorTick
                              ? (root.transparentBackground
                                 ? Qt.rgba(1.0, 1.0, 1.0, 1.0)
                                 : Qt.rgba(1.0, 1.0, 1.0, 0.86))
                              : (root.transparentBackground
                                 ? Qt.rgba(1.0, 1.0, 1.0, 0.80)
                                 : Qt.rgba(1.0, 1.0, 1.0, 0.55)))
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Math.round(parent.width * 0.57)
                    anchors.rightMargin: 2

                    text: String(Math.round(tickItem.tickAltitude))
                    visible: tickItem.majorTick
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.84)
                    font.pixelSize: Math.max(11, ScreenTools.defaultFontPixelHeight * 0.70)
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(parent.width * 0.22)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            visible: root.altitudeValid
            z: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(17, ScreenTools.defaultFontPixelWidth * 2.0)
                text: "\u25B6"
                color: root.altitudeColor
                font.pixelSize: Math.max(18, ScreenTools.defaultFontPixelHeight * 1.10)
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: Math.max(62, ScreenTools.defaultFontPixelWidth * 7.0)
                height: Math.max(36, ScreenTools.defaultFontPixelHeight * 2.15)
                radius: 5
                color:
                    root.transparentBackground
                        ? "transparent"
                        : Qt.rgba(0.08, 0.10, 0.13, 0.94)
                border.width: 1
                border.color:
                    root.transparentBackground
                        ? Qt.rgba(1.0, 1.0, 1.0, 0.62)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.12)

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5

                    text: root.altitudeText(root.altitudeValue)
                    color: root.primaryTextColor
                    font.pixelSize: Math.max(18, ScreenTools.defaultFontPixelHeight * 1.12)
                    font.bold: true
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "--"
            visible: !root.altitudeValid
            color: root.secondaryTextColor
            font.pixelSize: Math.max(18, ScreenTools.defaultFontPixelHeight * 1.1)
            font.bold: true
            style: root.readabilityTextStyle
            styleColor: root.readabilityShadowColor
        }
    }

    Item {
        id: telemetryPanel

        anchors.right: parent.right
        y: (root.height - root.panelHeight) / 2
        width: root.panelWidth
        height: root.panelHeight

        Rectangle {
            id: telemetryPanelBackground

            anchors.fill: parent
            radius: Math.min(9, width / 4)
            color: root.panelColor
            border.width: 1
            border.color:
                root.transparentBackground
                    ? Qt.rgba(1.0, 1.0, 1.0, 0.62)
                    : Qt.rgba(1.0, 1.0, 1.0, 0.18)
        }

        ColumnLayout {
            readonly property real horizontalMargin:
                Math.max(9, ScreenTools.defaultFontPixelWidth * 0.95)
            readonly property real verticalMargin:
                Math.max(7, ScreenTools.defaultFontPixelHeight * 0.42)

            x: horizontalMargin
            y: verticalMargin
            width: root.panelWidth - horizontalMargin * 2
            height: root.panelHeight - verticalMargin * 2
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top

                    text: root.altitudeTitle
                    color: root.primaryTextColor
                    font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.64)
                    font.bold: false
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    elide: Text.ElideRight
                }

                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    spacing: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.45)

                    Text {
                        id: altitudeValueText

                        text: root.altitudeText(root.altitudeValue)
                        color: root.altitudeColor
                        font.pixelSize: Math.max(26, ScreenTools.defaultFontPixelHeight * 1.55)
                        font.bold: true
                        style: root.readabilityTextStyle
                        styleColor: root.readabilityShadowColor
                    }

                    Text {
                        anchors.baseline: altitudeValueText.baseline
                        text: root.altitudeUnits
                        color: root.primaryTextColor
                        font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.62)
                        font.bold: true
                        style: root.readabilityTextStyle
                        styleColor: root.readabilityShadowColor
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.transparentBackground
                       ? Qt.rgba(1.0, 1.0, 1.0, 0.48)
                       : Qt.rgba(1.0, 1.0, 1.0, 0.14)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 5

                    text: qsTr("VS")
                    color: root.secondaryTextColor
                    font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.62)
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                }

                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    spacing: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.45)

                    Text {
                        id: climbRateValueText

                        text: root.rateText(root.climbRateValue)
                        color: root.primaryTextColor
                        font.pixelSize: Math.max(24, ScreenTools.defaultFontPixelHeight * 1.48)
                        font.bold: true
                        style: root.readabilityTextStyle
                        styleColor: root.readabilityShadowColor
                    }

                    Text {
                        anchors.baseline: climbRateValueText.baseline
                        text: root.climbRateUnits
                        color: root.primaryTextColor
                        font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.62)
                        font.bold: true
                        style: root.readabilityTextStyle
                        styleColor: root.readabilityShadowColor
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.transparentBackground
                       ? Qt.rgba(1.0, 1.0, 1.0, 0.48)
                       : Qt.rgba(1.0, 1.0, 1.0, 0.14)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 5

                    text: qsTr("SPEED (GND)")
                    color: root.secondaryTextColor
                    font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.62)
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    elide: Text.ElideRight
                }

                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    spacing: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.45)

                    Text {
                        id: groundSpeedValueText

                        text: root.speedText(root.groundSpeedValue)
                        color: root.primaryTextColor
                        font.pixelSize: Math.max(24, ScreenTools.defaultFontPixelHeight * 1.48)
                        font.bold: true
                        style: root.readabilityTextStyle
                        styleColor: root.readabilityShadowColor
                    }

                    Text {
                        anchors.baseline: groundSpeedValueText.baseline
                        text: root.groundSpeedUnits
                        color: root.primaryTextColor
                        font.pixelSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.62)
                        font.bold: true
                        style: root.readabilityTextStyle
                        styleColor: root.readabilityShadowColor
                    }
                }
            }
        }
    }
}
