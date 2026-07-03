import QtQuick
import QtQuick.Controls

Item {
    id: list

    property var dropModel
    property var dropTitleProvider
    property var orderedTargets: []

    property int activeDropCount: 0
    property real rowHeight: 54
    property real rowAnimatedHeight: 58

    width: parent ? parent.width : 320
    height: activeDropCount > 0 ? rowsColumn.implicitHeight : 0
    visible: activeDropCount > 0

    Column {
        id: rowsColumn

        width: list.width
        spacing: 0

        Repeater {
            model: list.orderedTargets && list.orderedTargets.length > 0
                   ? list.orderedTargets
                   : []

            delegate: Item {
                id: rowDelegate

                required property var modelData

                readonly property int rowIndex: modelData.rowIndex
                readonly property var row: list.dropModel && rowIndex >= 0 && rowIndex < list.dropModel.count
                                           ? list.dropModel.get(rowIndex)
                                           : null

                readonly property bool rowVisible: row && row.active && row.servoAvailable

                width: rowsColumn.width
                height: rowVisible ? list.rowAnimatedHeight : 0
                opacity: rowVisible ? 1.0 : 0.0
                visible: height > 0 || opacity > 0

                Behavior on height {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.InOutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                DropControlRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top

                    rowIndex: rowDelegate.rowIndex
                    titleText: row && list.dropTitleProvider
                               ? list.dropTitleProvider(row.servoNumber)
                               : row
                                 ? ("SERVO " + row.servoNumber)
                                 : ""

                    subtitleText: row ? ("SERVO " + row.servoNumber) : ""

                    rowHeight: list.rowHeight
                    rowAnimatedHeight: list.rowAnimatedHeight

                    rowActive: row ? row.active : false
                    rowIsOpen: row ? row.isOpen : false
                    rowBusy: row ? row.busy : false
                    rowAvailable: row ? row.servoAvailable : false
                    rowUnavailableText: row ? row.availabilityText : ""

                    rowCurrentPwm: row ? row.currentPwm : 1000
                    rowCurrentPositionLabel: row ? row.currentPositionLabel : "Closed"
                    rowNextOpenPwm: row ? row.nextOpenPwm : 2000
                    rowNextPositionLabel: row ? row.nextPositionLabel : "P1"
                }
            }
        }
    }
}