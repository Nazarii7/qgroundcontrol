import QtQuick
import QGroundControl.ScreenTools

// Fixed OSD palette, independent of the application Indoor / Outdoor scheme.
// Neutral colors match the supplied QGCPalette dark scheme: window,
// groupBorder, text, colorGrey, windowShadeDark, button and buttonBorder.
// Do not set QGCPalette.globalTheme here: it changes the entire application.
// Backgrounds always remain translucent: normal mode is 80% opaque;
// transparent mode is 25% opaque. Text and indicators keep their own alpha.
QtObject {
    property bool transparentBackground: false

    property real borderWidth: 1
    property real panelRadius: 9
    // Shared alpha for the lighter background mode (75% transparency).
    property real transparentBackgroundOpacity: 0.25
    property color solidBackground: "#cc222222"
    property color solidBorderColor: "#707070"
    property color transparentBorderColor: Qt.rgba(1, 1, 1, 0.62)
    readonly property color backgroundColor: transparentBackground
        ? Qt.rgba(solidBackground.r, solidBackground.g, solidBackground.b, transparentBackgroundOpacity)
        : solidBackground
    readonly property color borderColor: transparentBackground ? transparentBorderColor : solidBorderColor

    property color primaryTextColor: "#ffffff"
    property color labelColor: "#ffffff"
    property color mutedTextColor: "#bfbfbf"
    property color softTextColor: "#bfbfbf"
    property color metadataTextColor: "#bfbfbf"
    property color strongTextColor: "#ffffff"
    property color iconColor: "#ffffff"
    readonly property color valueTextColor: transparentBackground ? primaryTextColor : "#ffffff"
    readonly property color secondaryTextColor: transparentBackground ? labelColor : "#bfbfbf"
    readonly property color separatorColor: transparentBackground ? Qt.rgba(1, 1, 1, 0.52) : "#707070"
    property int textStyle: Text.Raised
    property color textShadowColor: Qt.rgba(0, 0, 0, 0.96)
    readonly property int optionalTextStyle: transparentBackground ? textStyle : Text.Normal

    property color accentColor: Qt.rgba(0.14, 0.82, 0.88, 1)
    property color armedColor: Qt.rgba(1, 0.18, 0.18, 1)
    property color altitudeColor: Qt.rgba(1, 0.80, 0, 1)
    property color gpsGoodColor: Qt.rgba(0.34, 0.90, 0.28, 1)
    property color gpsWarningColor: Qt.rgba(1, 0.76, 0.25, 1)
    property color gpsBadColor: Qt.rgba(1, 0.36, 0.32, 1)
    property color warningColor: Qt.rgba(1, 0.68, 0.16, 1)
    property color errorColor: Qt.rgba(1, 0.30, 0.28, 1)
    property color batteryFillColor: Qt.rgba(0.22, 0.78, 0.38, 0.95)
    property color currentColor: Qt.rgba(0.30, 0.86, 0.91, 0.98)
    readonly property color inactiveLinkColor: transparentBackground ? Qt.rgba(1, 1, 1, 0.58) : "#707070"
    readonly property color inactiveIndicatorColor: transparentBackground ? Qt.rgba(1, 1, 1, 0.48) : "#626262"

    property color tickShadowColor: Qt.rgba(0, 0, 0, 0.68)
    property color tickLabelColor: Qt.rgba(1, 1, 1, 0.84)
    property color tapeSpineShadowColor: Qt.rgba(0, 0, 0, 0.58)
    readonly property color tapeSpineColor: transparentBackground ? Qt.rgba(1, 1, 1, 0.82) : Qt.rgba(1, 1, 1, 0.30)
    readonly property color majorTickColor: transparentBackground ? primaryTextColor : Qt.rgba(1, 1, 1, 0.86)
    readonly property color minorTickColor: transparentBackground ? Qt.rgba(1, 1, 1, 0.80) : Qt.rgba(1, 1, 1, 0.55)

    property color receivedTextColor: "#ffffff"
    property color historyTextColor: "#bfbfbf"
    property color solidDetailBackground: "#cc282828"
    readonly property color detailBackgroundColor: transparentBackground
        ? Qt.rgba(solidDetailBackground.r, solidDetailBackground.g, solidDetailBackground.b, transparentBackgroundOpacity)
        : solidDetailBackground
    property color buttonBackground: "#626270"
    property color buttonHoverBackground: "#707070"
    property color buttonBorderColor: "#adadb8"
    property real buttonRadius: 5
    property string timestampFontFamily: "monospace"
    readonly property string fixedFontFamily: ScreenTools.fixedFontFamily

    property int tinyFontSize: 10
    property int smallFontSize: 11
    property int bodyFontSize: 12
    property int emphasisFontSize: 13
    property int alertSymbolFontSize: 17
    property int zoomFontSize: 24
    readonly property real armedStateFontSize: Math.max(22, ScreenTools.defaultFontPixelHeight * 1.25)
    readonly property real unitFontSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.62)
    readonly property real captionFontSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.60)
    readonly property real telemetryCaptionFontSize: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.64)
    readonly property real flightModeFontSize: Math.max(11, ScreenTools.defaultFontPixelHeight * 0.68)
    readonly property real tickLabelFontSize: Math.max(11, ScreenTools.defaultFontPixelHeight * 0.70)
    readonly property real tapePointerFontSize: Math.max(18, ScreenTools.defaultFontPixelHeight * 1.10)
    readonly property real tapeValueFontSize: Math.max(18, ScreenTools.defaultFontPixelHeight * 1.12)
    readonly property real altitudeValueFontSize: Math.max(26, ScreenTools.defaultFontPixelHeight * 1.55)
    readonly property real rateValueFontSize: Math.max(24, ScreenTools.defaultFontPixelHeight * 1.48)
    readonly property real homeValueFontSize: Math.max(17, ScreenTools.defaultFontPixelHeight * 1.05)
    readonly property real timeValueFontSize: Math.max(15, ScreenTools.defaultFontPixelHeight * 0.90)
    readonly property real waitingFontSize: Math.max(18, ScreenTools.defaultFontPixelHeight * 1.05)

    // Instrument-specific contrast pass; roll/pitch rendering remains QGC-owned.
    property real horizonBrightness: 0.03
    property real horizonContrast: 0.24
    property real horizonSaturation: 0.08
    property color horizonShadowColor: "black"
    property real horizonShadowOpacity: 0.88
    property real horizonShadowBlur: 0.28
    property real horizonShadowHorizontalOffset: 0
    property real horizonShadowVerticalOffset: 1
    property color horizonOuterEdgeColor: Qt.rgba(0, 0, 0, 0.94)
    property real horizonOuterEdgeMinimum: 2
    property real horizonOuterEdgeScale: 0.012
}
