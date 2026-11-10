import QtQuick
import QGroundControl.FlightDisplay

// Geometry adapter for a Popup (or Item) whose x/y are in boundsItem's space.
// It does not read settings or write persistence by itself.
Item {
    id: host

    property var movementHost: null
    property Item boundsItem: null
    property real topInset: 0
    property bool locked: true
    property alias panelController: panelState
    readonly property bool ready: _initialized && panelState.ready
    property bool _initialized: false
    property bool _syncing: false

    signal positionCommitted(real x, real y)

    visible: false

    function syncToHost() {
        if (!_initialized || _syncing || !movementHost || !panelState.ready) return
        _syncing = true
        movementHost.x = panelState.panelX
        movementHost.y = panelState.panelY
        _syncing = false
    }

    function syncFromHost() {
        if (_syncing || !movementHost || !panelState.enabled || panelState.dragging) return
        var x = Number(movementHost.x)
        var y = Number(movementHost.y)
        if (!isFinite(x) || !isFinite(y)) return
        _syncing = true
        panelState.setPosition(x, y)
        _initialized = panelState.ready
        _syncing = false
        syncToHost()
    }

    function scheduleHostSync() {
        if (!_syncing) Qt.callLater(syncFromHost)
    }

    WidgetPanelController {
        id: panelState
        enabled: host.enabled && host.movementHost !== null && host.boundsItem !== null
                 && host.boundsItem.width > 0 && host.boundsItem.height > 0
                 && host.movementHost.width > 0 && host.movementHost.height > 0
                 && host.movementHost.visible
        locked: host.locked
        bounds: Qt.rect(0, Math.min(Math.max(0, host.topInset), host.boundsItem ? host.boundsItem.height : 0),
                        host.boundsItem ? host.boundsItem.width : 0,
                        host.boundsItem ? Math.max(0, host.boundsItem.height - Math.max(0, host.topInset)) : 0)
        panelSize: Qt.size(host.movementHost ? host.movementHost.width : 0,
                           host.movementHost ? host.movementHost.height : 0)
        defaultPosition: Qt.point(host.movementHost ? host.movementHost.x : 0,
                                  host.movementHost ? host.movementHost.y : 0)
        onPositionChanged: host.syncToHost()
        onReadyChanged: host.syncToHost()
        onEnabledChanged: { if (enabled) host.scheduleHostSync() }
        onPositionCommitted: function(x, y) {
            host.syncToHost()
            host.positionCommitted(x, y)
        }
    }

    Connections {
        target: host.movementHost
        function onXChanged() { host.scheduleHostSync() }
        function onYChanged() { host.scheduleHostSync() }
        function onWidthChanged() { host.scheduleHostSync() }
        function onHeightChanged() { host.scheduleHostSync() }
        function onVisibleChanged() { host.scheduleHostSync() }
    }

    onMovementHostChanged: { _initialized = false; scheduleHostSync() }
    onBoundsItemChanged: { _initialized = false; scheduleHostSync() }
    Component.onCompleted: scheduleHostSync()
}
