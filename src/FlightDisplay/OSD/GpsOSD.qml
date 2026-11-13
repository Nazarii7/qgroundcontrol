/****************************************************************************
 *
 * GpsOSD.qml
 * Compact GPS / VisNav status overlay for Fly View video OSD.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import "../Shared/OSD" as Shared

import QGroundControl.ScreenTools

Shared.OSDPanelSurface {
    id: root

    property var vehicle: null
    property bool displayEnabled: true

    readonly property var navigation: vehicle && vehicle.navigation ? vehicle.navigation : null
    readonly property bool navigationDetected: navigation !== null && navigation.identified
    // Until discovery finishes, GPS1 is not evidence of the selected source.
    // Use the same layout throughout discovery, synchronization and operation.
    readonly property bool discoveryPending: vehicle !== null && navigation !== null
                                            && !navigationDetected && !vehicle.initialConnectComplete
    readonly property int navigationSource: navigationDetected ? navigation.activeSource : -1
    readonly property bool initializing: navigationDetected && navigation.initializing
    readonly property bool linkAlive: vehicle !== null && vehicle.vehicleLinkManager
                                      && !vehicle.vehicleLinkManager.communicationLost
    readonly property string navigationTitle: navigationDetected
        ? initializing
            ? navigation.requestedSource === 0 ? "SYNC GPS"
              : navigation.requestedSource === 1 ? "SYNC VISNAV" : "SYNC SD"
            : navigationSource === 0 ? "GPS" : navigationSource === 1 ? "VISNAV" : "NAV · --"
        : discoveryPending ? "NAV · --" : "GPS"
    readonly property bool selectedDataAvailable: linkAlive && !discoveryPending && !initializing
                                                && (!navigationDetected || navigation.activeDataAvailable)

    readonly property var gpsGroup: !vehicle ? null
        : navigationDetected ? navigationSource === 0 ? vehicle.gps
                               : navigationSource === 1 ? vehicle.gps2 : null
        : discoveryPending ? null : vehicle.gps

    readonly property int fixType:
        selectedDataAvailable ? factInteger(gpsGroup ? gpsGroup.lock : null, -1) : -1

    // Display the counter reported by the selected source: GPS1 or GPS2.
    // Its value is telemetry from that source, without conversion or estimation.
    readonly property bool showSatelliteCount: !discoveryPending
                                              && (!navigationDetected || navigationSource === 0
                                                  || navigationSource === 1)
    readonly property int satelliteCount:
        selectedDataAvailable && showSatelliteCount
            ? factInteger(gpsGroup ? gpsGroup.count : null, -1) : -1
    readonly property string satelliteText: "SAT " + (satelliteCount >= 0 ? String(satelliteCount) : "--")
    readonly property string controlStatusText: discoveryPending ? "READ NAV CONFIG"
        : navigationDetected ? navigation.statusText : ""

    readonly property color accentColor: root.osdStyle.accentColor
    readonly property color goodColor: root.osdStyle.gpsGoodColor
    readonly property color warningColor: root.osdStyle.gpsWarningColor
    readonly property color badColor: root.osdStyle.gpsBadColor
    readonly property int readabilityTextStyle: root.osdStyle.textStyle
    readonly property color readabilityShadowColor: root.osdStyle.textShadowColor

    readonly property string fixStatusText: statusTextForFix(fixType)
    readonly property color fixStatusColor: statusColorForFix(fixType)

    width: Math.max(128, ScreenTools.defaultFontPixelWidth * 14)
    height: Math.max(58, ScreenTools.defaultFontPixelHeight * 3.35)

    visible: displayEnabled && vehicle !== null

    function factInteger(fact, fallbackValue) {
        if (fact === null || fact === undefined || fact.rawValue === undefined) {
            return fallbackValue
        }

        var value = Number(fact.rawValue)
        if (!isFinite(value) || isNaN(value)) {
            return fallbackValue
        }

        return Math.round(value)
    }

    function statusTextForFix(value) {
        switch (value) {
        case 0:
            return "NO GPS"
        case 1:
            return "NO FIX"
        case 2:
            return "2D FIX"
        case 3:
            return "3D FIX"
        case 4:
            return "DGPS"
        case 5:
            return "RTK FLOAT"
        case 6:
            return "RTK FIX"
        case 7:
            return "STATIC FIX"
        case 8:
            return "PPP"
        default:
            return "--"
        }
    }

    function statusColorForFix(value) {
        if (value < 0 || value > 8) {
            return root.osdStyle.mutedTextColor
        }
        if (value >= 3) {
            return goodColor
        }
        if (value === 2) {
            return warningColor
        }
        return badColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        spacing: 1

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 5

            Item {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14

                Rectangle {
                    anchors.centerIn: parent
                    width: 11
                    height: 11
                    radius: width / 2
                    color: "transparent"
                    border.width: root.transparentBackground ? 2 : 1
                    border.color: root.accentColor

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3
                        height: 3
                        radius: width / 2
                        color: root.accentColor
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: 1
                    height: 3
                    color: root.accentColor
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 1
                    height: 3
                    color: root.accentColor
                }
            }

            Text {
                objectName: "navigationTitleText"
                Layout.fillWidth: true
                text: root.navigationTitle
                color: root.osdStyle.labelColor
                font.pixelSize: root.osdStyle.tinyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            spacing: 5

            Text {
                objectName: "fixStatusText"
                Layout.fillWidth: true
                text: root.fixStatusText
                color: root.fixStatusColor
                font.pixelSize: root.osdStyle.smallFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                objectName: "satelliteCountText"
                visible: root.showSatelliteCount
                text: root.satelliteText
                color: root.osdStyle.labelColor
                font.pixelSize: root.osdStyle.tinyFontSize
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            objectName: "controlStatusText"
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            text: root.controlStatusText
            color: root.navigationDetected && root.navigation.confirmationFailed ? root.badColor
                   : root.discoveryPending || root.initializing
                     || (root.navigationDetected && root.navigation.pending) ? root.warningColor
                   : root.osdStyle.labelColor
            font.pixelSize: root.osdStyle.tinyFontSize
            style: root.readabilityTextStyle
            styleColor: root.readabilityShadowColor
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
