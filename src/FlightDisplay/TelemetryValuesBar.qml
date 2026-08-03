import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools

Item {
    id:             control
    implicitWidth:  mainLayout.width + (_toolsMargin * 2)
    implicitHeight: mainLayout.height + (_toolsMargin * 2)

    readonly property bool _darkStyle:
        objectName === "pgrDarkTelemetryBar"

    property real extraWidth: 0 ///< Extra width to add to the background rectangle

    property alias factValueGrid:           factValueGrid
    property alias settingsGroup:           factValueGrid.settingsGroup
    property alias specificVehicleForCard:  factValueGrid.specificVehicleForCard

    Rectangle {
        id:         backgroundRect
        width:      control.width + extraWidth
        height:     control.height
        color:
            control._darkStyle
                ? Qt.rgba(0.08, 0.10, 0.13, 0.90)
                : qgcPal.window

        radius:
            control._darkStyle
                ? 8
                : ScreenTools.defaultFontPixelWidth / 2

        opacity:
            control._darkStyle
                ? 1.0
                : 0.75

        border.width: control._darkStyle ? 1 : 0
        border.color:
            control._darkStyle
                ? Qt.rgba(1.00, 1.00, 1.00, 0.16)
                : "transparent"
    }

    ColumnLayout {
        id:                 mainLayout
        anchors.margins:    _toolsMargin
        anchors.bottom:     parent.bottom
        anchors.left:       parent.left

        RowLayout {
            visible: factValueGrid.settingsUnlocked

            QGCColoredImage {
                source:             "qrc:/InstrumentValueIcons/lock-open.svg"
                mipmap:             true
                width:              ScreenTools.minTouchPixels * 0.75
                height:             width
                sourceSize.width:   width
                color:
                    control._darkStyle
                        ? "white"
                        : qgcPal.text
                fillMode:           Image.PreserveAspectFit

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked:    factValueGrid.settingsUnlocked = false
                }
            }
        }

        HorizontalFactValueGrid {
            id: factValueGrid

            objectName:
                control._darkStyle
                    ? "pgrDarkTelemetryGrid"
                    : ""
        }
    }

    QGCMouseArea {
        id:                         mouseArea
        x:                          mainLayout.x
        y:                          mainLayout.y
        width:                      mainLayout.width
        height:                     mainLayout.height
        acceptedButtons:            Qt.LeftButton | Qt.RightButton
        propagateComposedEvents:    true
        visible:                    !factValueGrid.settingsUnlocked

        onClicked: (mouse) => {
            if (!ScreenTools.isMobile && mouse.button === Qt.RightButton) {
                factValueGrid.settingsUnlocked = true
                mouse.accepted = true
            }
        }

        onPressAndHold: (mouse) => {
            factValueGrid.settingsUnlocked = true
            mouse.accepted = true
        }
    }
}
