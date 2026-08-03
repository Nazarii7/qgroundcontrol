import QtQuick

QtObject {
    readonly property color panelBackground: Qt.rgba(0.08, 0.10, 0.13, 0.90)
    readonly property color panelBorder: Qt.rgba(1, 1, 1, 0.16)

    readonly property color buttonIdle: Qt.rgba(1, 1, 1, 0.08)
    readonly property color buttonActive: Qt.rgba(1, 1, 1, 0.22)
    readonly property color buttonPressed: Qt.rgba(1, 1, 1, 0.18)
    readonly property color buttonBorder: Qt.rgba(1, 1, 1, 0.10)

    readonly property color textPrimary: "white"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.62)
    readonly property color textMuted: Qt.rgba(1, 1, 1, 0.45)

    readonly property int panelRadius: 14
    readonly property int buttonRadius: 7

    readonly property int titleFontSize: 12
    readonly property int buttonFontSize: 10
    readonly property int smallFontSize: 9
}
