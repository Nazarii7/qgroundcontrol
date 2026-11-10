/****************************************************************************
 *
 * ArtificialHorizonOSD.qml
 * Compact roll and pitch indicator for the Fly View OSD
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Effects
import "../Shared/OSD" as Shared

import QGroundControl
import QGroundControl.FlightDisplay
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.ScreenTools

Item {
    id: root

    readonly property QtObject osdStyle: Shared.OSDStyle {
        transparentBackground: root.transparentBackground
    }

    property var vehicle: null
    property bool displayEnabled: true
    property bool transparentBackground: WidgetPanelSettings.hudTransparentBackground

    property real indicatorSize:
        Math.max(136, ScreenTools.defaultFontPixelWidth * 12)

    width: indicatorSize
    height: indicatorSize
    visible: displayEnabled && vehicle !== null
    enabled: visible

    // Reuse QGroundControl's standard attitude instrument. It reads roll and
    // pitch directly from the active vehicle and does not depend on GPS Fix.
    QGCAttitudeWidget {
        id: attitudeWidget

        anchors.centerIn: parent

        size: Math.min(root.width, root.height)
        showPitch: true
        showHeading: false
        vehicle: root.vehicle
        visible: false
    }

    // Render the unchanged standard QGC attitude widget through a lightweight
    // contrast pass. This makes its white pitch marks and numbers clearer
    // without duplicating or changing any roll/pitch calculations.
    MultiEffect {
        anchors.fill: attitudeWidget
        source: attitudeWidget

        brightness: root.osdStyle.horizonBrightness
        contrast: root.osdStyle.horizonContrast
        saturation: root.osdStyle.horizonSaturation

        shadowEnabled: true
        shadowColor: root.osdStyle.horizonShadowColor
        shadowOpacity: root.osdStyle.horizonShadowOpacity
        shadowBlur: root.osdStyle.horizonShadowBlur
        shadowHorizontalOffset: root.osdStyle.horizonShadowHorizontalOffset
        shadowVerticalOffset: root.osdStyle.horizonShadowVerticalOffset
    }

    // A dark outer edge plus a fine light inner edge keeps the circular HUD
    // distinct over both bright and dark video while preserving its geometry.
    Rectangle {
        anchors.fill: attitudeWidget
        radius: width / 2
        color: "transparent"
        border.width: Math.max(root.osdStyle.horizonOuterEdgeMinimum,
                              Math.round(root.indicatorSize * root.osdStyle.horizonOuterEdgeScale))
        border.color: root.osdStyle.horizonOuterEdgeColor
        antialiasing: true
    }

    Rectangle {
        anchors.fill: attitudeWidget
        anchors.margins: 1
        radius: width / 2
        color: "transparent"
        border.width: root.osdStyle.borderWidth
        border.color: root.osdStyle.borderColor
        antialiasing: true
    }
}
