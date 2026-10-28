/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Palette
import QGroundControl.ScreenTools

ColumnLayout {
    width: _rightPanelWidth

    TerrainProgress {
        Layout.alignment:       Qt.AlignTop
        Layout.preferredWidth:  _rightPanelWidth
    }

    // Reserve a predictable default dock below the upper-right Battery OSD.
    // The actual control lives in Overlay.overlay, so layouts cannot force it
    // back after the operator unlocks and drags it.
    Item {
        id: photoVideoControlSlot

        Layout.alignment: Qt.AlignTop | Qt.AlignRight
        Layout.topMargin:
            Math.max(58, ScreenTools.defaultFontPixelHeight * 3.2)
            + ScreenTools.defaultFontPixelHeight * 0.6
        Layout.preferredWidth: photoVideoControl.implicitWidth
        Layout.preferredHeight: photoVideoControl.implicitHeight

        visible: DropWidgetSettings.photoVideoVisible

        property real rightEdgeCenterInset: visible ? parent.width - x : 0

        Popup {
            id: photoVideoPopup

            parent: Overlay.overlay
            visible: DropWidgetSettings.photoVideoVisible && photoVideoControlSlot.visible
            modal: false
            focus: false
            padding: 0
            closePolicy: Popup.NoAutoClose
            z: 2000

            width: photoVideoControl.implicitWidth
            height: photoVideoControl.implicitHeight

            function boundedPosition(x, y) {
                if (!parent) {
                    return Qt.point(x, y)
                }

                return Qt.point(
                    Math.max(0, Math.min(parent.width - width, x)),
                    Math.max(
                        ScreenTools.toolbarHeight,
                        Math.min(parent.height - height, y)
                    )
                )
            }

            function updatePosition() {
                if (!parent) {
                    return
                }

                var dockPoint = photoVideoControlSlot.mapToItem(parent, 0, 0)
                var savedX = Number(DropWidgetSettings.photoVideoX)
                var savedY = Number(DropWidgetSettings.photoVideoY)
                var desiredX = savedX >= 0 ? savedX : dockPoint.x
                var desiredY = savedY >= 0 ? savedY : dockPoint.y
                var position = boundedPosition(desiredX, desiredY)

                x = position.x
                y = position.y
            }

            onOpened: Qt.callLater(updatePosition)

            background: Item {
            }

            contentItem: PhotoVideoControl {
                id: photoVideoControl

                widgetSettings: DropWidgetSettings

                // These properties are supplied through Binding instead of
                // inline assignments. Qt Creator can otherwise validate this
                // type against stale generated QML module metadata and report
                // false M16 "Invalid property name" diagnostics even though
                // the properties exist in PhotoVideoControl.qml.
                Binding {
                    target: photoVideoControl
                    property: "movementHost"
                    value: photoVideoPopup
                }

                Binding {
                    target: photoVideoControl
                    property: "movementBounds"
                    value: photoVideoPopup.parent
                }

                Binding {
                    target: photoVideoControl
                    property: "movementTopInset"
                    value: ScreenTools.toolbarHeight
                }
            }
        }

        Connections {
            target: photoVideoPopup.parent
            ignoreUnknownSignals: true

            function onWidthChanged() {
                photoVideoPopup.updatePosition()
            }

            function onHeightChanged() {
                photoVideoPopup.updatePosition()
            }
        }

        Connections {
            target: DropWidgetSettings
            ignoreUnknownSignals: true

            function onPhotoVideoXChanged() {
                if (!photoVideoControl._panelDragging) {
                    photoVideoPopup.updatePosition()
                }
            }

            function onPhotoVideoYChanged() {
                if (!photoVideoControl._panelDragging) {
                    photoVideoPopup.updatePosition()
                }
            }

            function onPhotoVideoVisibleChanged() {
                if (DropWidgetSettings.photoVideoVisible) {
                    Qt.callLater(photoVideoPopup.updatePosition)
                }
            }
        }
    }
}
