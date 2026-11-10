import QtQuick

// Fixed dark colors for all custom widgets, independent of Indoor / Outdoor.
// Alpha belongs to the background color, never to the complete widget:
// panel backgrounds are approximately 95% opaque; text and controls stay crisp.
QtObject {
    property color panelBackground: "#f2222222"
    property color panelBorder: "#707070"
    property color transparentPanelBorder: Qt.rgba(1, 1, 1, 0.62)
    property color cardBackground: "#333333"
    property color cardBorder: "#626262"
    property color buttonIdle: "#626270"
    property color buttonActive: "#707070"
    property color buttonPressed: "#333333"
    property color buttonBorder: "#adadb8"
    property color focusBorder: "#8cb3be"
    property color lockColor: "#F7C948"
    property color textPrimary: "#ffffff"
    property color textSecondary: "#bfbfbf"
    property color textMuted: "#909090"

    // Neutral surfaces used by headers, sections, selectors and raw inputs.
    property color headerBackground: "#333333"
    property color headerBorder: "#707070"
    property color sectionExpandedBackground: "#3a3a3a"
    property color subsectionBackground: "#282828"
    property color subsectionExpandedBackground: "#333333"
    property color popupBackground: "#f2282828"
    property color trackBackground: "#222222"
    property color trackMarker: "#707070"
    property color inactiveIndicator: "#707070"
    property color inactiveButton: "#333333"
    property color accentColor: "#8cb3be"
    property color accentBackground: "#304047"
    property color keyholeColor: "#222222"
    property color badgeTextColor: "#222222"
    property color textShadowColor: "#111111"

    // Semantic colors: retain the existing meaning of green, red and yellow.
    property color successText: "#7fd49a"
    property color successBackground: "#204d32"
    property color successBorder: "#4e9b6b"
    property color dangerText: "#f28b91"
    property color dangerBackground: "#5d282d"
    property color dangerHoverBackground: "#713339"
    property color dangerPressedBackground: "#843e45"
    property color dangerBorder: "#b65b65"
    property color warningText: lockColor
    property color recordingColor: "#f32836"

    property int panelRadius: 14
    property int cardRadius: 9
    property int buttonRadius: 7
    property int buttonWidth: 34
    property int buttonHeight: 28
    property int buttonSpacing: 8
    property int panelPadding: 10
    property int headerHeight: 36
    property int collapsedWidth: 58
    property int collapsedHeight: 52
    property int dragThreshold: 4
    property int titleFontSize: 15
    property int bodyFontSize: 12
    property int smallFontSize: 10
    property int tinyFontSize: 9
}
