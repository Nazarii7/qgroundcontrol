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

    // PGR Camera / Drop Widget / Settings palette.
    color: Qt.rgba(0.08, 0.10, 0.13, 0.90)
    radius: 10

    border.width: 1
    border.color: Qt.rgba(1.00, 1.00, 1.00, 0.16)

    signal displayPreFlightChecklist

    FlyViewToolStripActionList {
        id: flyViewToolStripActionList

        onDisplayPreFlightChecklist: _root.displayPreFlightChecklist()
    }

    model: flyViewToolStripActionList.model
}
