import QtQuick

// Presentation only: deliberately no input area, sizing or telemetry logic.
Rectangle {
    id: surface

    property bool transparentBackground: false
    property QtObject panelStyle: null
    readonly property QtObject osdStyle: panelStyle ? panelStyle : defaultStyle

    OSDStyle {
        id: defaultStyle
        transparentBackground: surface.transparentBackground
    }

    radius: osdStyle.panelRadius
    color: osdStyle.backgroundColor
    border.width: osdStyle.borderWidth
    border.color: osdStyle.borderColor
}
