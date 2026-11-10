import QtQml

// Presentation state only. Never sends commands or changes persisted mappings.
QtObject {
    id: root
    objectName: "controllerInputStatusModel"

    property bool controllerConnected: false
    property var activeVehicle: null

    // Shared project preset. This is the single place to edit available buttons.
    // Compatibility is not device/model authentication: a generic HID name cannot
    // report the selected EdgeTX model. Live USB signals are never filtered.
    property bool useProjectControllerProfile: true
    property string controllerName: ""
    property int reportedAxisCount: 0
    property int reportedButtonCount: 0
    property var projectControllerProfile: ({
        id: "gx12-ls2qgc-classic",
        label: "GX12 / LS-2QGC",
        expectedAxisCount: 8,
        expectedButtonCount: 24,
        compatibleNameHints: ["gx12", "hid-compliant game controller"],
        buttons: [
            { index: 0, channel: 9, source: "SB -100%" },
            { index: 1, channel: 10, source: "SB 0%" },
            { index: 2, channel: 11, source: "SB 100%" },
            { index: 3, channel: 12, source: "SA 100%" },
            { index: 4, channel: 13, source: "SD 100%" },
            { index: 5, channel: 14, source: "SH 100%" },
            { index: 6, channel: 15, source: "SG 100%" }
        ]
    })

    readonly property bool projectProfileActive: {
        var profile = projectControllerProfile
        if (!useProjectControllerProfile || !controllerConnected || !profile
                || reportedAxisCount !== profile.expectedAxisCount
                || reportedButtonCount !== profile.expectedButtonCount) {
            return false
        }
        var name = String(controllerName).toLowerCase()
        var hints = profile.compatibleNameHints || []
        for (var i = 0; i < hints.length; ++i) {
            var hint = String(hints[i]).toLowerCase()
            if (hint.length > 0 && name.indexOf(hint) !== -1) {
                return true
            }
        }
        return false
    }

    readonly property int configuredButtonCount: {
        var count = 0
        if (projectProfileActive) {
            for (var i = 0; i < reportedButtonCount; ++i) {
                if (profileButtonInfo(i) !== null) {
                    ++count
                }
            }
        }
        return count
    }

    function profileButtonInfo(index) {
        if (!root.projectProfileActive || index < 0 || index >= root.reportedButtonCount) {
            return null
        }
        var entries = root.projectControllerProfile.buttons || []
        for (var i = 0; i < entries.length; ++i) {
            if (Number(entries[i].index) === index) {
                return entries[i]
            }
        }
        return null
    }

    function isButtonConfigured(index) {
        if (index < 0 || index >= root.reportedButtonCount) {
            return false
        }
        // Unknown controllers keep their complete raw-input display.
        return !root.projectProfileActive || root.profileButtonInfo(index) !== null
    }

    function buttonDescription(index) {
        if (!root.projectProfileActive) {
            return qsTr("Button %1 - reported by controller").arg(index)
        }
        var entry = root.profileButtonInfo(index)
        return entry !== null
                ? qsTr("Button %1 - CH%2 - %3").arg(index).arg(entry.channel).arg(entry.source)
                : qsTr("Button %1 - not configured in %2").arg(index).arg(root.projectControllerProfile.label)
    }

    readonly property bool hasVehicle: activeVehicle !== null && activeVehicle !== undefined
    readonly property var linkManager: hasVehicle && activeVehicle.vehicleLinkManager
                                      ? activeVehicle.vehicleLinkManager : null
    readonly property bool vehicleStateKnown: linkManager !== null
                                             && linkManager.communicationLost !== undefined
    readonly property bool communicationLost: vehicleStateKnown
                                             && Boolean(linkManager.communicationLost)
    readonly property bool vehicleConnected: hasVehicle && vehicleStateKnown && !communicationLost

    // Remember a previously connected vehicle even if QGC removes its object.
    // These are session-only UI flags, not settings and not link-management state.
    property bool vehicleWasConnected: false
    property bool vehicleLossRemembered: false

    readonly property string vehicleState: {
        if (hasVehicle) {
            if (!vehicleStateKnown) {
                return "checking"
            }
            return communicationLost ? "lost" : "connected"
        }
        if (vehicleLossRemembered) {
            return "lost"
        }
        return vehicleWasConnected ? "disconnected" : "waiting"
    }

    readonly property bool canEditMappings: controllerConnected && vehicleConnected
    readonly property bool canEditButtonMappings: canEditMappings
    readonly property string statusCode: {
        if (vehicleState === "lost" || vehicleState === "disconnected") {
            return vehicleState
        }
        if (!controllerConnected) {
            return hasVehicle ? "controller-missing" : "devices-missing"
        }
        if (vehicleState === "checking") {
            return "vehicle-checking"
        }
        return vehicleConnected ? "connected" : "controller-only"
    }

    readonly property string severity: {
        if (statusCode === "lost") {
            return "error"
        }
        if (statusCode === "connected") {
            return "success"
        }
        return statusCode === "devices-missing" ? "neutral" : "warning"
    }

    readonly property string title: {
        switch (statusCode) {
        case "lost": return qsTr("Vehicle communication lost")
        case "disconnected": return qsTr("Vehicle disconnected")
        case "controller-missing": return qsTr("USB controller not connected")
        case "devices-missing": return qsTr("Controller and vehicle not connected")
        case "vehicle-checking": return qsTr("Checking vehicle connection")
        case "controller-only": return qsTr("Vehicle not connected")
        default: return qsTr("Controller and vehicle connected")
        }
    }

    readonly property string message: {
        if (statusCode === "lost" || statusCode === "disconnected") {
            return controllerConnected
                    ? qsTr("USB controller is still connected. Reconnect the vehicle to configure mappings. Raw inputs remain available.")
                    : qsTr("USB controller is also disconnected. Reconnect both devices to configure mappings.")
        }
        switch (statusCode) {
        case "controller-missing":
            return vehicleConnected
                    ? qsTr("Vehicle is connected. Connect a USB controller to view inputs and configure mappings.")
                    : qsTr("Connect a USB controller to view its inputs. Waiting for vehicle link status.")
        case "devices-missing":
            return qsTr("Connect a USB controller and a vehicle to configure mappings.")
        case "vehicle-checking":
            return qsTr("Waiting for vehicle link status. Mapping is disabled; USB inputs remain available.")
        case "controller-only":
            return qsTr("Connect a vehicle to configure mappings. USB inputs remain available.")
        default:
            return qsTr("Mapping is available. Camera operation also requires a camera connection.")
        }
    }

    readonly property string buttonMappingMessage: {
        if (!controllerConnected) {
            return qsTr("Connect a USB controller to configure button actions.")
        }
        if (vehicleState === "lost") {
            return qsTr("Vehicle communication lost. Restore the vehicle connection to edit vehicle button actions.")
        }
        if (vehicleState === "checking") {
            return qsTr("Waiting for vehicle link status before enabling vehicle button mapping.")
        }
        return qsTr("Connect a vehicle to edit vehicle button actions. USB raw inputs remain available.")
    }

    function rememberConnectionState() {
        if (communicationLost) {
            root.vehicleLossRemembered = true
        } else if (vehicleConnected) {
            root.vehicleWasConnected = true
            root.vehicleLossRemembered = false
        }
    }

    onVehicleConnectedChanged: rememberConnectionState()
    onCommunicationLostChanged: rememberConnectionState()
    Component.onCompleted: rememberConnectionState()
}
