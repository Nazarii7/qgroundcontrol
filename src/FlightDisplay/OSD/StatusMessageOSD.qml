/****************************************************************************
 *
 * StatusMessageOSD.qml
 * Single non-modal Fly View message area for vehicle and local command errors.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl.ScreenTools
import QGroundControl.FlightDisplay

Rectangle {
    id: root

    property var vehicle: null
    property bool displayEnabled: true
    // Use the same persisted switch as the other HUD elements.
    property bool transparentBackground: DropWidgetSettings.hudTransparentBackground
    property int displayInterval: 5000
    property int maximumDisplayCount: 2
    property int duplicateQuietInterval: 15000
    property real maximumWidth: -1

    property var messageItems: []
    property var attentionItems: []
    property int currentIndex: 0
    property bool detailsOpen: false
    property bool _componentCompleted: false
    property bool _hadBackendMessages: false
    property int _localMessageSequence: 0
    property var _knownMessageIds: ({})
    property var _duplicateStates: ({})

    // An empty presenter is hidden but must still receive its first message.
    readonly property bool presentationAvailable:
        _componentCompleted && displayEnabled
        && parent !== null && parent.visible && width > 0
    readonly property bool hasLocalMessages: {
        var groups = [messageItems, attentionItems]
        for (var group = 0; group < groups.length; ++group) {
            for (var index = 0; index < groups[group].length; ++index) {
                if (groups[group][index].source === "local") return true
            }
        }
        return false
    }
    readonly property int messageCount: messageItems ? messageItems.length : 0
    readonly property int attentionCount: attentionItems ? attentionItems.length : 0
    readonly property var currentMessage:
        messageCount > 0 && currentIndex >= 0 && currentIndex < messageCount
            ? messageItems[currentIndex] : null
    readonly property int currentSeverity:
        currentMessage ? Number(currentMessage.severity) : 6
    readonly property int attentionSeverity:
        attentionCount > 0 ? Number(attentionItems[0].severity) : 6
    readonly property color normalColor: Qt.rgba(0.14, 0.82, 0.88, 1.0)
    readonly property color warningColor: Qt.rgba(1.0, 0.68, 0.16, 1.0)
    readonly property color errorColor: Qt.rgba(1.0, 0.30, 0.28, 1.0)
    readonly property color severityColor: colorForSeverity(currentSeverity)
    readonly property int readabilityTextStyle: Text.Raised
    readonly property color readabilityShadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.96)

    width: {
        var preferred = Math.max(520, ScreenTools.defaultFontPixelWidth * 70)
        var available = maximumWidth >= 0 ? maximumWidth : (parent ? parent.width : preferred)
        return Math.min(preferred, Math.max(0, available))
    }
    height: contentColumn.implicitHeight + 12
    radius: 9
    color: transparentBackground ? "transparent" : Qt.rgba(0.08, 0.10, 0.13, 0.90)
    border.width: 1
    border.color: transparentBackground
                  ? Qt.rgba(1, 1, 1, 0.62)
                  : Qt.rgba(1, 1, 1, 0.14)
    clip: true
    visible: displayEnabled && (vehicle !== null || hasLocalMessages)
             && (messageCount > 0 || attentionCount > 0)

    function colorForSeverity(severity) {
        return severity <= 3 ? errorColor : (severity <= 5 ? warningColor : normalColor)
    }

    function severityText(severity) {
        switch (severity) {
        case 0: return qsTr("EMERGENCY")
        case 1: return qsTr("ALERT")
        case 2: return qsTr("Critical")
        case 3: return qsTr("Error")
        case 4: return qsTr("Warning")
        case 5: return qsTr("Notice")
        case 6: return qsTr("Info")
        case 7: return qsTr("Debug")
        default: return qsTr("Message")
        }
    }

    function messageField(message, fieldName, fallbackValue) {
        return !message || message[fieldName] === undefined || message[fieldName] === null
                ? fallbackValue : message[fieldName]
    }

    function messageText(message) {
        // Vehicle messages have already been HTML-escaped by StatusTextHandler.
        return String(messageField(message, "text", "")).replace(/\r\n|\n|\r/g, "<br/>")
    }

    function timestampText(message) {
        return String(messageField(message, "timestamp", "")).substring(0, 8)
    }

    function normalizedMessageText(message) {
        return String(messageField(message, "text", ""))
            .replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\s+/g, " ").trim()
    }

    function backendMessageId(message) {
        var id = messageField(message, "id", null)
        return id !== null ? String(id)
            : "legacy|" + String(messageField(message, "componentId", -1)) + "|"
                + String(messageField(message, "severity", 6)) + "|"
                + String(messageField(message, "timestamp", "")) + "|"
                + normalizedMessageText(message)
    }

    function messageIdStateKey(messageId) {
        return "id|" + encodeURIComponent(String(messageId))
    }

    function duplicateKey(message) {
        return "message|" + String(messageField(message, "source", "vehicle")) + "|"
            + String(messageField(message, "componentId", -1)) + "|"
            + String(messageField(message, "severity", 6)) + "|"
            + encodeURIComponent(normalizedMessageText(message))
    }

    function duplicateStateKey(key) {
        return "duplicate|" + encodeURIComponent(key)
    }

    function queueIndexForDuplicateKey(key) {
        for (var index = 0; index < messageItems.length; ++index) {
            if (messageItems[index].duplicateKey === key) return index
        }
        return -1
    }

    function queueItem(message, messageId, key) {
        var severity = Number(messageField(message, "severity", 6))
        if (!isFinite(severity) || isNaN(severity)) severity = 6
        return {
            queueId: String(messageId), duplicateKey: key,
            source: String(messageField(message, "source", "vehicle")),
            componentId: Number(messageField(message, "componentId", -1)),
            severity: severity, text: String(messageField(message, "text", "")),
            timestamp: String(messageField(message, "timestamp", "")),
            lastTimestamp: String(messageField(message, "timestamp", "")),
            repeatCount: 1, displayCount: 0
        }
    }

    function recordAttention(item) {
        if (item.severity > 4) return
        var updated = attentionItems.slice(0)
        for (var index = 0; index < updated.length; ++index) {
            if (updated[index].duplicateKey === item.duplicateKey) {
                var record = Object.assign({}, updated[index])
                record.repeatCount = item.repeatCount
                record.lastTimestamp = item.lastTimestamp
                updated[index] = record
                attentionItems = updated
                return
            }
        }
        // A recorded alert is not an inferred active/resolved health condition.
        // Retain it until the vehicle changes or its actual history is cleared.
        updated.push(Object.assign({}, item))
        updated.sort(function(a, b) { return a.severity - b.severity })
        attentionItems = updated
    }

    function acceptMessage(message, messageId) {
        if (normalizedMessageText(message).length === 0) return
        var key = duplicateKey(message)
        var stateKey = duplicateStateKey(key)
        var state = _duplicateStates[stateKey]
        var now = Date.now()
        var previousSeenMs = state ? Number(state.lastSeenMs) : 0
        var activeIndex = queueIndexForDuplicateKey(key)
        state = state || ({ repeatCount: 0, suppressed: false })
        state.lastSeenMs = now
        state.repeatCount = Number(state.repeatCount || 0) + 1
        _duplicateStates[stateKey] = state

        var item = queueItem(message, messageId, key)
        item.repeatCount = state.repeatCount
        recordAttention(item)

        if (activeIndex >= 0) {
            // Refresh only the counter and last reception time, not the reading
            // timer, first timestamp, queue position, or completed displays.
            var duplicates = messageItems.slice(0)
            var activeItem = Object.assign({}, duplicates[activeIndex])
            activeItem.repeatCount = item.repeatCount
            activeItem.lastTimestamp = item.lastTimestamp
            duplicates[activeIndex] = activeItem
            messageItems = duplicates
            return
        }

        if (state.suppressed && now - previousSeenMs < Math.max(0, duplicateQuietInterval)) {
            return
        }

        state.suppressed = false
        var previousSeverity = currentSeverity
        var hadMessages = messageCount > 0
        var updatedItems = messageItems.slice(0)
        var newIndex = updatedItems.length
        updatedItems.push(item)
        messageItems = updatedItems

        // Urgent messages interrupt a less severe entry, never an equally or
        // more urgent one. Repeated packets cannot continuously restart it.
        if (!hadMessages || (item.severity <= 3 && item.severity < previousSeverity)) {
            switchAnimation.stop()
            messageContent.opacity = 1
            currentIndex = newIndex
            if (item.severity <= 3) detailsOpen = false
            if (cycleTimer.running) cycleTimer.restart()
        }
    }

    function showLocalMessage(text) {
        // Command errors are not in STATUSTEXT. Escape them once for RichText.
        var escaped = String(text).replace(/&/g, "&amp;")
            .replace(/</g, "&lt;").replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;").replace(/'/g, "&#39;")
        _localMessageSequence += 1
        acceptMessage({ source: "local", componentId: -1, severity: 3,
                        text: escaped, timestamp: Qt.formatTime(new Date(), "hh:mm:ss") },
                      "local|" + _localMessageSequence)
    }

    function synchronizeMessages() {
        var sourceMessages = vehicle ? vehicle.statusTextMessages : []
        if (!sourceMessages || !sourceMessages.length) {
            if (_hadBackendMessages) resetQueue()
            _hadBackendMessages = false
            return
        }
        _hadBackendMessages = true
        // The backend is newest-first; preserve arrival order for ordinary text.
        for (var index = sourceMessages.length - 1; index >= 0; --index) {
            var message = sourceMessages[index]
            var messageId = backendMessageId(message)
            var idKey = messageIdStateKey(messageId)
            if (_knownMessageIds[idKey]) continue
            _knownMessageIds[idKey] = true
            acceptMessage(message, messageId)
        }
    }

    function suppressQueueItem(item) {
        var stateKey = duplicateStateKey(item.duplicateKey)
        var state = _duplicateStates[stateKey] || ({})
        state.suppressed = true
        if (!state.lastSeenMs) state.lastSeenMs = Date.now()
        _duplicateStates[stateKey] = state
    }

    function nextQueuedIndex(items, startIndex) {
        if (!items.length) return 0
        var start = startIndex % items.length
        var mostUrgent = 4
        for (var index = 0; index < items.length; ++index) {
            if (items[index].severity < mostUrgent) mostUrgent = items[index].severity
        }
        if (mostUrgent <= 3) {
            for (var offset = 0; offset < items.length; ++offset) {
                var candidate = (start + offset) % items.length
                if (items[candidate].severity === mostUrgent) return candidate
            }
        }
        return start
    }

    function completeCurrentDisplay() {
        if (!currentMessage) { currentIndex = 0; return }
        var updated = messageItems.slice(0)
        var item = Object.assign({}, updated[currentIndex])
        item.displayCount = Number(item.displayCount || 0) + 1
        var nextIndex = currentIndex + 1
        if (item.displayCount >= Math.max(1, maximumDisplayCount)) {
            suppressQueueItem(item)
            updated.splice(currentIndex, 1)
            nextIndex = currentIndex
        } else {
            updated[currentIndex] = item
        }
        currentIndex = nextQueuedIndex(updated, nextIndex)
        messageItems = updated
    }

    function resetQueue() {
        switchAnimation.stop()
        messageContent.opacity = 1
        currentIndex = 0
        messageItems = []
        attentionItems = []
        detailsOpen = false
        _hadBackendMessages = false
        _knownMessageIds = ({})
        _duplicateStates = ({})
    }

    function reloadVehicleMessages() {
        resetQueue()
        synchronizeMessages()
    }

    onVehicleChanged: {
        if (_componentCompleted) reloadVehicleMessages()
    }
    onVisibleChanged: {
        switchAnimation.stop()
        messageContent.opacity = 1
        if (visible && cycleTimer.running) cycleTimer.restart()
    }
    onDetailsOpenChanged: {
        switchAnimation.stop()
        messageContent.opacity = 1
        if (!detailsOpen && cycleTimer.running) cycleTimer.restart()
    }
    Component.onCompleted: {
        reloadVehicleMessages()
        // Publish readiness after initialization, so pending local errors
        // flushed by MainWindow cannot be erased by the initial reload.
        _componentCompleted = true
    }

    Connections {
        target: root.vehicle
        function onStatusTextMessagesChanged() { root.synchronizeMessages() }
    }

    Timer {
        id: cycleTimer
        interval: Math.max(1000, root.displayInterval)
        repeat: true
        running: root.visible && root.messageCount > 0 && !root.detailsOpen
        onTriggered: {
            if (!switchAnimation.running) switchAnimation.restart()
        }
    }

    SequentialAnimation {
        id: switchAnimation
        NumberAnimation {
            target: messageContent; property: "opacity"
            from: 1; to: 0; duration: 120
        }
        ScriptAction { script: root.completeCurrentDisplay() }
        NumberAnimation {
            target: messageContent; property: "opacity"
            from: 0; to: 1; duration: 160
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 4

        RowLayout {
            id: messageContent
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(42, ScreenTools.defaultFontPixelHeight * 2.6)
            visible: root.messageCount > 0
            spacing: 8

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 4
                radius: 2
                color: root.severityColor
            }
            Text {
                text: root.severityText(root.currentSeverity)
                color: root.severityColor
                font.pixelSize: 11
                font.bold: true
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }
            Text {
                text: root.timestampText(root.currentMessage)
                visible: text.length > 0
                color: Qt.rgba(1, 1, 1, 0.65)
                font.pixelSize: 10
                font.family: "monospace"
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                text: root.messageText(root.currentMessage)
                textFormat: Text.RichText
                color: "white"
                font.pixelSize: 12
                font.bold: root.currentSeverity <= 5
                style: root.readabilityTextStyle
                styleColor: root.readabilityShadowColor
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                style: root.transparentBackground ? root.readabilityTextStyle : Text.Normal
                styleColor: root.readabilityShadowColor
                text: root.currentMessage && root.currentMessage.repeatCount > 1
                      ? qsTr("Received %1").arg(root.currentMessage.repeatCount) : ""
                visible: text.length > 0
                color: "#d9e1ea"
                font.pixelSize: 10
            }
            Text {
                style: root.transparentBackground ? root.readabilityTextStyle : Text.Normal
                styleColor: root.readabilityShadowColor
                text: root.messageCount > 1 ? (root.currentIndex + 1) + "/" + root.messageCount : ""
                visible: text.length > 0
                color: Qt.rgba(1, 1, 1, 0.65)
                font.pixelSize: 10
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: root.attentionCount > 0
            spacing: 8

            Text {
                style: root.transparentBackground ? root.readabilityTextStyle : Text.Normal
                styleColor: root.readabilityShadowColor
                text: "\u26a0"
                color: root.colorForSeverity(root.attentionSeverity)
                font.pixelSize: 17
            }
            Text {
                style: root.transparentBackground ? root.readabilityTextStyle : Text.Normal
                styleColor: root.readabilityShadowColor
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: qsTr("Recorded alerts: %1").arg(root.attentionCount)
                color: root.colorForSeverity(root.attentionSeverity)
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
            Button {
                text: root.detailsOpen ? qsTr("Hide details") : qsTr("Details")
                focusPolicy: Qt.NoFocus
                Layout.preferredHeight: 28
                onClicked: root.detailsOpen = !root.detailsOpen
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 5
                    color: parent.hovered ? "#3b485a" : "#273343"
                    border.color: "#65758a"
                }
            }
        }

        ScrollView {
            id: detailsView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(200, detailEntries.implicitHeight)
            visible: root.detailsOpen && root.attentionCount > 0
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                id: detailEntries
                width: detailsView.availableWidth
                spacing: 6

                Repeater {
                    model: root.attentionItems
                    delegate: Rectangle {
                        required property var modelData
                        width: detailEntries.width
                        height: detailColumn.implicitHeight + 16
                        radius: 5
                        color: root.transparentBackground ? "transparent" : "#19222e"
                        border.color: root.colorForSeverity(modelData.severity)

                        Column {
                            id: detailColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 4

                            Text {
                                style: root.transparentBackground ? root.readabilityTextStyle : Text.Normal
                                styleColor: root.readabilityShadowColor
                                width: parent.width
                                text: root.severityText(modelData.severity) + " · "
                                      + qsTr("Received %1 times").arg(modelData.repeatCount)
                                color: root.colorForSeverity(modelData.severity)
                                font.bold: true
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                            }
                            Text {
                                style: root.transparentBackground ? root.readabilityTextStyle : Text.Normal
                                styleColor: root.readabilityShadowColor
                                width: parent.width
                                text: root.messageText(modelData)
                                textFormat: Text.RichText
                                color: "white"
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                            }
                            Text {
                                style: root.transparentBackground ? root.readabilityTextStyle : Text.Normal
                                styleColor: root.readabilityShadowColor
                                width: parent.width
                                text: qsTr("First: %1 · Last received: %2")
                                    .arg(root.timestampText(modelData))
                                    .arg(String(modelData.lastTimestamp).substring(0, 8))
                                color: "#b7c3d2"
                                font.pixelSize: 10
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}