/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay

ToolStrip {
    id: _root

    // Marker consumed internally by ToolStrip/ToolStripHoverButton.
    // objectName is a standard QObject property, so no qmltypes update is
    // required for this assignment.
    objectName: "pgrFlyViewToolStrip"

    // The shared ToolStrip supplies the background from the active QGC palette.
    radius: 10

    border.width: 1
    border.color: QGroundControl.globalPalette.buttonBorder

    signal displayPreFlightChecklist

    FlyViewToolStripActionList {
        id: flyViewToolStripActionList

        onDisplayPreFlightChecklist: _root.displayPreFlightChecklist()
    }

    model: flyViewToolStripActionList.model
}
