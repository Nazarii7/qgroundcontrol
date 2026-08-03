import QtQuick

import SiYi.Object 1.0

MouseArea {
    id: root

    property var camera: SiYi.camera

    // Enabled by FlyViewVideo only while the full video view is active.
    property bool controlEnabled: true

    property int minDelta: 5
    property int commandInterval: 100
    property int maxCommand: 100
    property bool debugLogging: true

    readonly property bool mouseControlActive:
        root.controlEnabled
        && root.camera !== null
        && root.camera !== undefined
        && root.camera.isConnected
        && root.camera.enableControl
        && !root.camera.isTracking

    signal requestToggleFullScreen()

    acceptedButtons: Qt.LeftButton
    hoverEnabled: false
    preventStealing: true
    propagateComposedEvents: false

    enabled: root.mouseControlActive
    visible: root.mouseControlActive

    cursorShape: Qt.ArrowCursor

    property bool hasBeenMoved: false
    property int originX: 0
    property int originY: 0
    property int currentX: 0
    property int currentY: 0
    property int yaw: 0
    property int pitch: 0

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function stopControl(reason) {
        controlTimer.stop()
        controlTimer.sendEnabled = false

        if (root.camera
                && root.camera.isConnected
                && root.camera.enableControl) {
            root.camera.turn(0, 0)
        }

        if (root.debugLogging) {
            console.log(
                "PGR_SIYI_MOUSE: stop",
                "reason:", reason
            )
        }

        root.originX = 0
        root.originY = 0
        root.currentX = 0
        root.currentY = 0
        root.yaw = 0
        root.pitch = 0
    }

    onPressed: (mouse) => {
        mouse.accepted = true

        root.hasBeenMoved = false
        root.originX = mouse.x
        root.originY = mouse.y
        root.currentX = mouse.x
        root.currentY = mouse.y
        root.yaw = 0
        root.pitch = 0

        // Allow the first movement command immediately.
        controlTimer.sendEnabled = true
        controlTimer.start()

        if (root.debugLogging) {
            console.log(
                "PGR_SIYI_MOUSE: pressed",
                "x:", mouse.x,
                "y:", mouse.y,
                "width:", root.width,
                "height:", root.height
            )
        }
    }

    onPositionChanged: (mouse) => {
        if (!root.pressed || !root.mouseControlActive) {
            return
        }

        root.currentX = mouse.x
        root.currentY = mouse.y

        root.yaw = root.currentX - root.originX
        root.pitch = root.currentY - root.originY

        const absYaw = Math.abs(root.yaw)
        const absPitch = Math.abs(root.pitch)

        if (absYaw <= root.minDelta && absPitch <= root.minDelta) {
            return
        }

        root.hasBeenMoved = true

        if (!controlTimer.sendEnabled) {
            return
        }

        controlTimer.sendEnabled = false

        var yawCommand = 0
        var pitchCommand = 0

        if (absYaw > absPitch) {
            yawCommand = Math.round(
                root.yaw * root.maxCommand / Math.max(1, root.width)
            )
            yawCommand = root.clamp(
                yawCommand,
                -root.maxCommand,
                root.maxCommand
            )
        } else {
            pitchCommand = Math.round(
                -root.pitch * root.maxCommand / Math.max(1, root.height)
            )
            pitchCommand = root.clamp(
                pitchCommand,
                -root.maxCommand,
                root.maxCommand
            )
        }

        if (root.debugLogging) {
            console.log(
                "PGR_SIYI_MOUSE: turn",
                "dx:", root.yaw,
                "dy:", root.pitch,
                "yaw:", yawCommand,
                "pitch:", pitchCommand
            )
        }

        root.camera.turn(yawCommand, pitchCommand)
    }

    onReleased: {
        root.stopControl("released")
    }

    onCanceled: {
        root.stopControl("canceled")
    }

    onDoubleClicked: (mouse) => {
        mouse.accepted = true
        root.requestToggleFullScreen()
    }

    onMouseControlActiveChanged: {
        if (!root.mouseControlActive && controlTimer.running) {
            root.stopControl("mouse control disabled")
        }
    }

    Component.onDestruction: {
        if (controlTimer.running) {
            root.stopControl("component destroyed")
        }
    }

    Timer {
        id: controlTimer

        interval: root.commandInterval
        repeat: true
        running: false

        property bool sendEnabled: false

        onTriggered: {
            controlTimer.sendEnabled = true
        }
    }
}
