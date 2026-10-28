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

// Keep the standard bottom-right row empty. The original TelemetryValuesBar
// and FlyViewInstrumentPanel (the native compass) stay removed. The custom
// artificial horizon is mounted from FlyViewCustomLayer.qml instead.
RowLayout {
    spacing: 0
    visible: false

    width: 0
    height: 0
    implicitWidth: 0
    implicitHeight: 0
}
