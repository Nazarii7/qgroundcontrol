/****************************************************************************
 *
 * ArtificialHorizonOSD.qml
 * Compact roll and pitch indicator for the Fly View OSD
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.ScreenTools

Item {
    id: root

    property var vehicle: null
    property bool displayEnabled: true

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

        brightness: 0.03
        contrast: 0.24
        saturation: 0.08

        shadowEnabled: true
        shadowColor: Qt.rgba(0.0, 0.0, 0.0, 1.0)
        shadowOpacity: 0.88
        shadowBlur: 0.28
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 1
    }

    // A dark outer edge plus a fine light inner edge keeps the circular HUD
    // distinct over both bright and dark video while preserving its geometry.
    Rectangle {
        anchors.fill: attitudeWidget
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, Math.round(root.indicatorSize * 0.012))
        border.color: Qt.rgba(0.0, 0.0, 0.0, 0.94)
        antialiasing: true
    }

    Rectangle {
        anchors.fill: attitudeWidget
        anchors.margins: 1
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.78)
        antialiasing: true
    }
}
