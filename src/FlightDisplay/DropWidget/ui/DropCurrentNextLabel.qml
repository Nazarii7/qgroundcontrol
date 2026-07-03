import QtQuick
import QtQuick.Controls

Column {
    id: labelBlock

    property int activeDropCount: 0
    property bool holdActive: false
    property string currentDropLabel: ""
    property string nextDropLabel: ""

    width: parent ? parent.width : 320
    spacing: 2
    visible: activeDropCount > 0

    Label {
        width: parent.width
        text: labelBlock.holdActive && labelBlock.currentDropLabel.length > 0
              ? labelBlock.currentDropLabel
              : labelBlock.nextDropLabel
        color: Qt.rgba(1, 1, 1, 0.70)
        font.pixelSize: 10
        elide: Text.ElideRight
    }
}