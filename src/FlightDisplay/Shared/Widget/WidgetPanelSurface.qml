import QtQuick

Rectangle {
    id: surface

    property bool transparentBackground: false
    property bool surfaceInputEnabled: true
    property QtObject panelStyle: null
    readonly property QtObject effectiveStyle: panelStyle ? panelStyle : defaultStyle

    WidgetPanelStyle { id: defaultStyle }

    radius: effectiveStyle.panelRadius
    color: transparentBackground ? "transparent" : effectiveStyle.panelBackground
    border.width: 1
    border.color: transparentBackground
                  ? effectiveStyle.transparentPanelBorder : effectiveStyle.panelBorder

    // This area is behind the derived panel's controls. It covers only the
    // visible panel, so clicks cannot reach video/gimbal controls underneath.
    MouseArea {
        anchors.fill: parent
        enabled: surface.surfaceInputEnabled
        acceptedButtons: Qt.AllButtons
        onPressed: function(mouse) { mouse.accepted = true }
        onWheel: function(wheel) { wheel.accepted = true }
    }
}
