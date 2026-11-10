import QtQuick
import "../../Shared/Widget" as Shared

Shared.WidgetPanelStyle {
    // These colors describe the Drop control, not generic widget chrome.
    readonly property color dropIdle: successBackground
    readonly property color dropActive: dangerBackground
}
