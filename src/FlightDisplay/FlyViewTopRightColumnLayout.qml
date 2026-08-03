/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
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

    // PhotoVideoControl is null-safe and stays visible over both map and video,
    // including the disconnected state.
    Loader {
        id:                 photoVideoControlLoader
        Layout.alignment:   Qt.AlignTop | Qt.AlignRight
        sourceComponent:    photoVideoControlComponent

        onLoaded: {
            if (item) {
                item.widgetSettings = DropWidgetSettings
            }
        }

        property real rightEdgeCenterInset: visible ? parent.width - x : 0

        Component {
            id: photoVideoControlComponent

            PhotoVideoControl {
            }
        }
    }
}
