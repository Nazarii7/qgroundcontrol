/****************************************************************************
 *
 * CompassOSD.qml
 * Horizontal heading tape for Fly View video OSD.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl.ScreenTools

Rectangle {
    id: root

    property var vehicle: null
    property bool displayEnabled: true
    property bool transparentBackground: false

    readonly property real heading: headingNumber()
    readonly property bool headingValid:
        isFinite(heading) && !isNaN(heading) && heading >= 0

    readonly property color accentColor: Qt.rgba(0.14, 0.82, 0.88, 1.0)
    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor:
        Qt.rgba(0.0, 0.0, 0.0, 0.96)
    readonly property real pixelsPerDegree: tape.width / 180.0
    readonly property real baseTickAngle:
        headingValid ? Math.floor(heading / 10.0) * 10.0 : 0

    width: Math.max(360, ScreenTools.defaultFontPixelWidth * 42)
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
    clip: true

    visible: displayEnabled && vehicle !== null && headingValid

    function headingNumber() {
        if (!vehicle || !vehicle.heading || vehicle.heading.rawValue === undefined) {
            return NaN
        }

        var value = Number(vehicle.heading.rawValue)
        if (!isFinite(value) || isNaN(value)) {
            return NaN
        }

        return normalizeAngle(value)
    }

    function normalizeAngle(value) {
        var normalized = value % 360
        if (normalized < 0) {
            normalized += 360
        }
        return normalized
    }

    function headingLabel(rawAngle) {
        var angle = Math.round(normalizeAngle(rawAngle))

        if (angle === 0 || angle === 360) {
            return "N"
        }
        if (angle === 90) {
            return "E"
        }
        if (angle === 180) {
            return "S"
        }
        if (angle === 270) {
            return "W"
        }

        return angle % 30 === 0 ? String(angle) : ""
    }

    function isCardinalLabel(label) {
        return label === "N" || label === "E" || label === "S" || label === "W"
    }

    Item {
        id: tape

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: headingReadout.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        clip: true

        Repeater {
            model: 25

            delegate: Item {
                id: tickItem

                readonly property real rawAngle:
                    root.baseTickAngle + (index - 12) * 10
                readonly property real relativeAngle:
                    rawAngle - root.heading
                readonly property real normalizedAngle:
                    root.normalizeAngle(rawAngle)
                readonly property bool majorTick:
                    Math.round(normalizedAngle) % 30 === 0
                readonly property string labelText:
                    root.headingLabel(rawAngle)
                readonly property bool highlightedCardinal:
                    root.isCardinalLabel(labelText)
                    && Math.abs(relativeAngle) <= 15

                width: 44
                height: tape.height
                x: tape.width / 2
                   + relativeAngle * root.pixelsPerDegree
                   - width / 2

                Text {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 5

                    text: tickItem.labelText
                    visible: text.length > 0
                    color: tickItem.highlightedCardinal
                           ? root.accentColor
                           : Qt.rgba(1, 1, 1, 0.88)
                    font.pixelSize: 11
                    font.bold: tickItem.highlightedCardinal
                    style: root.readabilityTextStyle
                    styleColor: root.readabilityShadowColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 1
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2

                    width: 2
                    height: tickItem.majorTick ? 10 : 6
                    color: Qt.rgba(0.0, 0.0, 0.0, 0.68)
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3

                    width: 1
                    height: tickItem.majorTick ? 9 : 5
                    color: tickItem.majorTick
                           ? (root.transparentBackground
                              ? Qt.rgba(1, 1, 1, 1.0)
                              : Qt.rgba(1, 1, 1, 0.78))
                           : (root.transparentBackground
                              ? Qt.rgba(1, 1, 1, 0.72)
                              : Qt.rgba(1, 1, 1, 0.42))
                }
            }
        }
    }

    // Fixed aircraft-heading marker. The heading tape moves underneath it.
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: -3

        text: "▼"
        color: Qt.rgba(1, 1, 1, 0.94)
        font.pixelSize: 11
        font.bold: true
        style: root.readabilityTextStyle
        styleColor: root.readabilityShadowColor
        z: 5
    }

    Text {
        id: headingReadout

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 3

        text: root.headingValid ? Math.round(root.heading) + "°" : "--°"
        color: root.accentColor
        font.pixelSize: 12
        font.bold: true
        style: root.readabilityTextStyle
        styleColor: root.readabilityShadowColor
        horizontalAlignment: Text.AlignHCenter
    }
}
