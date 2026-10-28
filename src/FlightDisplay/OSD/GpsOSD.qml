/****************************************************************************
 *
 * GpsOSD.qml
 * Compact GPS status overlay for Fly View video OSD.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl.ScreenTools

Rectangle {
    id: root

    property var vehicle: null
    property bool displayEnabled: true
    property bool transparentBackground: false

    readonly property var gpsGroup:
        vehicle && vehicle.gps ? vehicle.gps : null

    readonly property int fixType:
        factInteger(gpsGroup ? gpsGroup.lock : null, -1)

    readonly property int satelliteCount:
        factInteger(gpsGroup ? gpsGroup.count : null, -1)

    readonly property color accentColor: Qt.rgba(0.14, 0.82, 0.88, 1.0)
    readonly property color goodColor: Qt.rgba(0.34, 0.90, 0.28, 1.0)
    readonly property color warningColor: Qt.rgba(1.0, 0.76, 0.25, 1.0)
    readonly property color badColor: Qt.rgba(1.0, 0.36, 0.32, 1.0)
    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor:
        Qt.rgba(0.0, 0.0, 0.0, 0.96)

    readonly property string fixStatusText: statusTextForFix(fixType)
    readonly property color fixStatusColor: statusColorForFix(fixType)
    readonly property int satelliteBars: barsForSatellites(satelliteCount, fixType)

    width: Math.max(128, ScreenTools.defaultFontPixelWidth * 14)
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
        default:
            return "--"
        }
    }

    function statusColorForFix(value) {
        if (value >= 6) {
            return goodColor
        }
        if (value >= 3) {
            return goodColor
        }
        if (value === 2) {
            return warningColor
        }
        return badColor
    }

    function barsForSatellites(count, lockType) {
        if (lockType < 2 || count <= 0) {
            return 0
        }
        if (count <= 5) {
            return 1
        }
        if (count <= 8) {
            return 2
        }
        if (count <= 11) {
            return 3
        }
        if (count <= 15) {
            return 4
        }
        return 5
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
                text: "GPS"
                color: Qt.rgba(1, 1, 1, 0.90)
                font.pixelSize: 10
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 16

            text: root.fixStatusText
            color: root.fixStatusColor
            font.pixelSize: 11
            font.bold: true
            style: root.readabilityTextStyle
            styleColor: root.readabilityShadowColor
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 15
            spacing: 5

            Text {
                text: root.satelliteCount >= 0 ? String(root.satelliteCount) : "--"
                color: Qt.rgba(1, 1, 1, 0.88)
                font.pixelSize: 11
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }

            Item { Layout.fillWidth: true }

            Row {
                Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                spacing: 2

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index

                        width: 4
                        height: 4 + index * 2
                        radius: 1
                        anchors.bottom: parent.bottom
                        color: index < root.satelliteBars
                               ? root.fixStatusColor
                               : (root.transparentBackground
                                  ? Qt.rgba(1, 1, 1, 0.48)
                                  : Qt.rgba(1, 1, 1, 0.18))
                    }
                }
            }
        }
    }
}
