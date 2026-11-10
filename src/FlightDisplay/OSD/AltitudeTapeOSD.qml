/****************************************************************************
 *
 * AltitudeTapeOSD.qml
 * Vertical altitude tape with compact flight telemetry for Fly View video.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import "../Shared/OSD" as Shared

import QGroundControl.ScreenTools

Item {
    id: root

    readonly property QtObject osdStyle: Shared.OSDStyle {
        transparentBackground: root.transparentBackground
    }

    property var vehicle: null
    property bool displayEnabled: true
    property bool transparentBackground: false
    property bool preferTerrainAltitude: true
    // Slightly wider telemetry card; Battery and Horizon retain their widths.
    property real panelWidth:
        Math.max(100, ScreenTools.defaultFontPixelWidth * 9.2)
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

    readonly property color accentColor: root.osdStyle.accentColor
    readonly property color altitudeColor: root.osdStyle.altitudeColor
    readonly property color panelColor: root.osdStyle.backgroundColor
    readonly property color primaryTextColor: root.osdStyle.valueTextColor
    readonly property color secondaryTextColor: root.osdStyle.secondaryTextColor
    readonly property int readabilityTextStyle: root.osdStyle.textStyle
    readonly property color readabilityShadowColor: root.osdStyle.textShadowColor

    readonly property string altitudeReferenceLabel:
        terrainAltitudeValid ? qsTr("AGL") : qsTr("REL")

    // A moving +/-40-unit window with a labelled mark every 10 units.
    // Reuse delegates; only their values/positions follow live telemetry.
    readonly property real minorStep: 1.0
    readonly property real mediumStep: 5.0
    readonly property real majorStep: 10.0
    readonly property real visibleAltitudeRange: 80.0
    readonly property real pixelsPerAltitudeUnit: altitudeTape.height / visibleAltitudeRange
    readonly property real baseTickAltitude:
        altitudeValid ? Math.floor(altitudeValue / minorStep) * minorStep : 0
    readonly property int tickRadius: Math.ceil(visibleAltitudeRange / (2 * minorStep)) + 2
    readonly property int tickCount: tickRadius * 2 + 1

    readonly property real compactValueFontSize: Math.max(20, Math.round(ScreenTools.defaultFontPixelHeight * 1.20))
    readonly property real compactCaptionFontSize: Math.max(11, Math.round(ScreenTools.defaultFontPixelHeight * 0.60))
    readonly property real compactUnitFontSize: Math.max(11, Math.round(ScreenTools.defaultFontPixelHeight * 0.60))
    readonly property real pointerValueFontSize: Math.max(14, Math.round(ScreenTools.defaultFontPixelHeight * 0.80))
    readonly property real compactTickFontSize: Math.max(10, Math.round(ScreenTools.defaultFontPixelHeight * 0.60))
    readonly property real rowPadding: Math.max(5, Math.round(ScreenTools.defaultFontPixelHeight * 0.25))
    readonly property real horizontalPadding: Math.max(6, Math.round(ScreenTools.defaultFontPixelWidth * 0.55))
    readonly property real rowContentSpacing: 2
    readonly property real telemetryRowHeight: Math.ceil(captionMetrics.height + valueMetrics.height
                                                      + rowContentSpacing + rowPadding * 2 + 1)
    readonly property real panelHeight: telemetryRowHeight * 3
    readonly property real majorTickLength: Math.max(14, Math.round(ScreenTools.defaultFontPixelWidth * 1.5))
    readonly property real tickLabelGap: 4
    readonly property real tickLabelWidth: Math.max(20, Math.ceil(Math.max(
        tickMetrics.advanceWidth(String(Math.floor((altitudeValid ? altitudeValue : 0) - visibleAltitudeRange / 2))),
        tickMetrics.advanceWidth(String(Math.ceil((altitudeValid ? altitudeValue : 0) + visibleAltitudeRange / 2))))))
    readonly property real spineX: tickLabelWidth + tickLabelGap + majorTickLength
    readonly property real pointerGap: 2
    readonly property real pointerArrowWidth: Math.max(6, Math.round(ScreenTools.defaultFontPixelHeight * 0.30))
    readonly property real pointerWidth: Math.max(36, Math.ceil(pointerMetrics.advanceWidth(altitudeText(altitudeValue))) + 8)
    readonly property real pointerHeight: Math.ceil(pointerMetrics.height) + 4
    readonly property real tapeWidth: spineX + pointerGap + pointerArrowWidth + pointerGap + pointerWidth
    // A wider gutter shifts the tape left while the card stays right-aligned.
    readonly property real componentSpacing: Math.max(13, Math.round(ScreenTools.defaultFontPixelWidth * 1.3))

    FontMetrics { id: captionMetrics; font.pixelSize: root.compactCaptionFontSize }
    FontMetrics { id: valueMetrics; font.pixelSize: root.compactValueFontSize; font.bold: true }
    FontMetrics { id: pointerMetrics; font.pixelSize: root.pointerValueFontSize; font.bold: true }
    FontMetrics { id: tickMetrics; font.pixelSize: root.compactTickFontSize }

    width: tapeWidth + componentSpacing + panelWidth
    height: Math.max(260, ScreenTools.defaultFontPixelHeight * 18)

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
        objectName: "altitudeTape"

        anchors.left: parent.left
        y: root.tapeCenterY - height / 2
        width: root.tapeWidth
        height: root.height
        clip: true

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: root.spineX + 1
            width: 2
            color: root.osdStyle.tapeSpineShadowColor
        }
        Rectangle {
            objectName: "altitudeTapeSpine"
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: root.spineX
            width: 1
            color: root.osdStyle.tapeSpineColor
        }

        Repeater {
            model: root.tickCount

            delegate: Item {
                id: tickItem
                objectName: "altitudeTick" + index
                required property int index

                readonly property real tickAltitude: root.baseTickAltitude + (index - root.tickRadius) * root.minorStep
                readonly property real relativeAltitude: tickAltitude - root.altitudeValue
                readonly property bool majorTick: root.isStepMultiple(tickAltitude, root.majorStep)
                readonly property bool mediumTick: !majorTick && root.isStepMultiple(tickAltitude, root.mediumStep)
                readonly property real tickLength: majorTick ? root.majorTickLength : mediumTick ? root.majorTickLength * 0.65 : root.majorTickLength * 0.35

                x: 0
                y: root.altitudeValid ? altitudeTape.height / 2 - relativeAltitude * root.pixelsPerAltitudeUnit - height / 2 : -100
                width: altitudeTape.width
                height: Math.ceil(tickMetrics.height)
                visible: root.altitudeValid && y + height / 2 >= 0 && y + height / 2 <= altitudeTape.height
                    && (!root.terrainAltitudeValid || tickAltitude >= 0)
                    && (majorTick || mediumTick || root.pixelsPerAltitudeUnit >= 4)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    x: root.spineX - tickItem.tickLength + 1
                    width: tickItem.tickLength
                    height: 2
                    color: root.osdStyle.tickShadowColor
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.spineX - tickItem.tickLength
                    width: tickItem.tickLength
                    height: tickItem.majorTick ? 2 : 1
                    color: tickItem.majorTick ? root.osdStyle.majorTickColor : root.osdStyle.minorTickColor
                }
                Text {
                    objectName: "altitudeTickLabel" + tickItem.index
                    x: 0
                    width: root.tickLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(Math.round(tickItem.tickAltitude))
                    visible: tickItem.majorTick && tickItem.y >= 0 && tickItem.y + tickItem.height <= altitudeTape.height
                    color: root.osdStyle.tickLabelColor
                    font.pixelSize: root.compactTickFontSize
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Row {
            id: currentAltitudePointer
            objectName: "currentAltitudePointer"
            x: root.spineX + root.pointerGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.pointerGap
            visible: root.altitudeValid
            z: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: root.pointerArrowWidth
                height: root.pointerHeight
                text: "\u25B6"
                color: root.altitudeColor
                font.pixelSize: Math.max(10, root.pointerValueFontSize * 0.7)
                font.bold: true
                fontSizeMode: Text.Fit
                minimumPixelSize: 6
                clip: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Shared.OSDPanelSurface {
                objectName: "currentAltitudeBadge"
                transparentBackground: root.transparentBackground
                panelStyle: root.osdStyle
                width: root.pointerWidth
                height: root.pointerHeight
                radius: Math.min(5, root.osdStyle.panelRadius)

                Text {
                    objectName: "currentAltitudeBadgeValue"
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    text: root.altitudeText(root.altitudeValue)
                    color: root.primaryTextColor
                    font.pixelSize: root.pointerValueFontSize
                    font.bold: true
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Text {
            x: root.spineX + root.pointerGap
            width: root.pointerWidth + root.pointerArrowWidth + root.pointerGap
            anchors.verticalCenter: parent.verticalCenter
            text: "--"
            visible: !root.altitudeValid
            color: root.secondaryTextColor
            font.pixelSize: root.pointerValueFontSize
            style: root.readabilityTextStyle
            styleColor: root.readabilityShadowColor
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Item {
        id: telemetryPanel
        objectName: "altitudeTelemetryPanel"
        anchors.right: parent.right
        y: root.tapeCenterY - height / 2
        width: root.panelWidth
        height: root.panelHeight

        Shared.OSDPanelSurface {
            objectName: "altitudeTelemetryBackground"
            anchors.fill: parent
            transparentBackground: root.transparentBackground
            panelStyle: root.osdStyle
        }

        Column {
            anchors.fill: parent
            Repeater {
                model: 3
                delegate: Item {
                    id: telemetryRow
                    objectName: "altitudeTelemetryRow" + index
                    required property int index
                    readonly property string caption: index === 0 ? root.altitudeReferenceLabel : index === 1 ? qsTr("VS") : qsTr("SPEED")
                    readonly property string displayValue: index === 0 ? root.altitudeText(root.altitudeValue)
                        : index === 1 ? root.rateText(root.climbRateValue) : root.speedText(root.groundSpeedValue)
                    readonly property string units: index === 0 ? root.altitudeUnits : index === 1 ? root.climbRateUnits : root.groundSpeedUnits
                    width: telemetryPanel.width
                    height: root.telemetryRowHeight

                    Text {
                        objectName: "altitudeTelemetryCaption" + telemetryRow.index
                        x: root.horizontalPadding
                        y: root.rowPadding
                        width: parent.width - root.horizontalPadding * 2
                        text: telemetryRow.caption
                        color: root.secondaryTextColor
                        font.pixelSize: root.compactCaptionFontSize
                        style: root.readabilityTextStyle
                        styleColor: root.readabilityShadowColor
                        elide: Text.ElideRight
                        Accessible.name: telemetryRow.index === 0 ? root.altitudeTitle : telemetryRow.caption
                    }
                    Item {
                        x: root.horizontalPadding
                        y: root.rowPadding + captionMetrics.height + root.rowContentSpacing
                        width: parent.width - root.horizontalPadding * 2
                        height: valueMetrics.height

                        Text {
                            id: valueText
                            objectName: "altitudeTelemetryValue" + telemetryRow.index
                            anchors.left: parent.left
                            anchors.right: unitText.left
                            anchors.rightMargin: 3
                            height: parent.height
                            text: telemetryRow.displayValue
                            color: telemetryRow.index === 0 ? root.altitudeColor : root.primaryTextColor
                            font.pixelSize: root.compactValueFontSize
                            font.bold: true
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                            style: root.readabilityTextStyle
                            styleColor: root.readabilityShadowColor
                        }
                        Text {
                            id: unitText
                            anchors.right: parent.right
                            anchors.baseline: valueText.baseline
                            text: telemetryRow.units
                            color: root.primaryTextColor
                            font.pixelSize: root.compactUnitFontSize
                            font.bold: true
                            style: root.readabilityTextStyle
                            styleColor: root.readabilityShadowColor
                        }
                    }
                    Rectangle {
                        x: root.horizontalPadding
                        width: parent.width - root.horizontalPadding * 2
                        anchors.bottom: parent.bottom
                        height: 1
                        visible: telemetryRow.index < 2
                        color: root.osdStyle.separatorColor
                    }
                }
            }
        }
    }
}
