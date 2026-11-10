import QtQuick

MouseArea {
    id: area

    property var panelController: null
    property Item coordinateItem: null
    property bool clickableWhenLocked: false
    property real dragThreshold: 4

    property var _gestureController: null
    property Item _gestureCoordinates: null
    property point _pressPoint: Qt.point(0, 0)
    property bool _pressUnlocked: false
    property bool _tapEligible: false
    property bool _attemptedDrag: false
    property bool _dragStarted: false

    signal tapRequested()

    enabled: panelController !== null && coordinateItem !== null
             && panelController.enabled
             && (!panelController.locked || clickableWhenLocked)
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    preventStealing: true
    cursorShape: panelController && !panelController.locked
                 ? Qt.SizeAllCursor : Qt.PointingHandCursor

    function resetGesture() {
        _gestureController = null
        _gestureCoordinates = null
        _pressUnlocked = false
        _tapEligible = false
        _attemptedDrag = false
        _dragStarted = false
    }

    function cancelGesture() {
        var controller = _gestureController
        var ownedDrag = _dragStarted
        resetGesture()
        if (ownedDrag && controller) {
            controller.cancelDrag()
        }
    }

    function pointFor(mouse) {
        return mapToItem(_gestureCoordinates, mouse.x, mouse.y)
    }

    function updateGesture(point) {
        if (!_gestureController || !_gestureCoordinates
                || !isFinite(point.x) || !isFinite(point.y)) {
            return
        }
        var dx = point.x - _pressPoint.x
        var dy = point.y - _pressPoint.y
        var threshold = isFinite(dragThreshold) ? Math.max(1, dragThreshold) : 4
        if (dx * dx + dy * dy >= threshold * threshold) {
            // A drag attempt on a locked button must not become an unlock tap.
            _tapEligible = false
            if (!_attemptedDrag && _pressUnlocked) {
                _attemptedDrag = true
                _dragStarted = _gestureController.beginDrag(_pressPoint.x, _pressPoint.y)
            }
        }
        if (_dragStarted) {
            _gestureController.dragTo(point.x, point.y)
        }
    }

    onPressed: function(mouse) {
        cancelGesture()
        _gestureController = panelController
        _gestureCoordinates = coordinateItem
        _pressPoint = pointFor(mouse)
        _pressUnlocked = !panelController.locked
        _tapEligible = clickableWhenLocked
        mouse.accepted = true
    }

    onPositionChanged: function(mouse) {
        if (pressed && _gestureController && _gestureCoordinates) {
            updateGesture(pointFor(mouse))
            mouse.accepted = true
        }
    }

    onReleased: function(mouse) {
        if (_gestureController && _gestureCoordinates) {
            var point = pointFor(mouse)
            updateGesture(point)
            var controller = _gestureController
            var ownedDrag = _dragStarted
            var shouldTap = _tapEligible
            resetGesture()
            if (ownedDrag) {
                controller.endDrag(point.x, point.y)
            } else if (shouldTap) {
                tapRequested()
            }
        }
        mouse.accepted = true
    }

    onCanceled: cancelGesture()
    onVisibleChanged: { if (!visible) cancelGesture() }
    onEnabledChanged: { if (!enabled) cancelGesture() }
    onPanelControllerChanged: cancelGesture()
    onCoordinateItemChanged: cancelGesture()
    onWheel: function(wheel) { wheel.accepted = true }

    Connections {
        target: area.panelController
        function onLockedChanged() {
            if (area._pressUnlocked && area.panelController.locked) {
                area.cancelGesture()
            }
        }
    }
}
