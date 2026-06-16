import QtQuick

Item {
    id: sequence

    visible: false

    readonly property int modeAll: 0
    readonly property int modeGroups: 1
    readonly property int modeIndividual: 2

    property int dropMode: modeAll
    property var dropModel

    property int currentGroupIndex: 0
    property int currentServoIndex: 0

    property var servoOrder: []
    property var orderedTargetsPreview: []

    property string currentActionLabel: ""
    property string nextActionLabel: "Next: All selected"

    signal sequenceChanged()

    onDropModeChanged: {
        resetSequence()
    }

    function setDropMode(mode) {
        if (mode !== modeAll && mode !== modeGroups && mode !== modeIndividual) {
            return
        }

        if (dropMode === mode) {
            return
        }

        dropMode = mode
        resetSequence()
    }

    function resetSequence() {
        currentGroupIndex = 0
        currentServoIndex = 0
        updateSequenceInfo()
    }

    function rawSelectedTargets() {
        var targets = []

        if (!dropModel) {
            return targets
        }

        for (var i = 0; i < dropModel.count; i++) {
            var row = dropModel.get(i)

            if (row.active && row.servoAvailable) {
                targets.push({
                    "rowIndex": i,
                    "servoNumber": row.servoNumber,
                    "openPwm": row.openPwm,
                    "closedPwm": row.closedPwm
                })
            }
        }

        return targets
    }

    function sanitizeServoOrder(order) {
        var targets = rawSelectedTargets()
        var allowed = {}
        var result = []
        var used = {}

        for (var i = 0; i < targets.length; i++) {
            allowed[String(targets[i].servoNumber)] = true
        }

        for (var j = 0; order && j < order.length; j++) {
            var servoNumber = order[j]
            var key = String(servoNumber)

            if (allowed[key] && !used[key]) {
                result.push(servoNumber)
                used[key] = true
            }
        }

        for (var k = 0; k < targets.length; k++) {
            var targetKey = String(targets[k].servoNumber)

            if (!used[targetKey]) {
                result.push(targets[k].servoNumber)
                used[targetKey] = true
            }
        }

        return result
    }

    function selectedTargets() {
        var targets = rawSelectedTargets()
        var order = sanitizeServoOrder(servoOrder)
        var targetByServo = {}
        var used = {}
        var result = []

        for (var i = 0; i < targets.length; i++) {
            targetByServo[String(targets[i].servoNumber)] = targets[i]
        }

        for (var j = 0; j < order.length; j++) {
            var key = String(order[j])

            if (targetByServo[key] && !used[key]) {
                result.push(targetByServo[key])
                used[key] = true
            }
        }

        return result
    }

    function setServoOrder(order) {
        servoOrder = sanitizeServoOrder(order)
        resetSequence()
    }

    function moveServoInOrder(servoNumber, direction) {
        var targets = selectedTargets()
        var order = []

        for (var i = 0; i < targets.length; i++) {
            order.push(targets[i].servoNumber)
        }

        var currentIndex = order.indexOf(servoNumber)

        if (currentIndex < 0) {
            return
        }

        var nextIndex = currentIndex + direction

        if (nextIndex < 0 || nextIndex >= order.length) {
            return
        }

        var temp = order[currentIndex]
        order[currentIndex] = order[nextIndex]
        order[nextIndex] = temp

        setServoOrder(order)
    }

    function targetsToText(targets) {
        var names = []

        for (var i = 0; i < targets.length; i++) {
            names.push("SERVO " + targets[i].servoNumber)
        }

        return names.join(", ")
    }

    function groupsForCurrentMode() {
        var targets = selectedTargets()

        if (targets.length <= 0) {
            return []
        }

        if (dropMode === modeGroups) {
            var midpoint = Math.ceil(targets.length / 2)
            var groupOne = targets.slice(0, midpoint)
            var groupTwo = targets.slice(midpoint)
            var groups = []

            if (groupOne.length > 0) {
                groups.push(groupOne)
            }

            if (groupTwo.length > 0) {
                groups.push(groupTwo)
            }

            return groups
        }

        if (dropMode === modeIndividual) {
            var individualGroups = []

            for (var i = 0; i < targets.length; i++) {
                individualGroups.push([ targets[i] ])
            }

            return individualGroups
        }

        return [ targets ]
    }

    function currentTargets() {
        var groups = groupsForCurrentMode()

        if (groups.length <= 0) {
            return []
        }

        if (dropMode === modeGroups) {
            return groups[currentGroupIndex % groups.length]
        }

        if (dropMode === modeIndividual) {
            return groups[currentServoIndex % groups.length]
        }

        return groups[0]
    }

    function currentLabel() {
        var groups = groupsForCurrentMode()

        if (groups.length <= 0) {
            return "Current: no selected servos"
        }

        if (dropMode === modeGroups) {
            var groupIndex = currentGroupIndex % groups.length
            return "Current: Group " + (groupIndex + 1) + "/" + groups.length + " — " + targetsToText(groups[groupIndex])
        }

        if (dropMode === modeIndividual) {
            var servoIndex = currentServoIndex % groups.length
            return "Current: " + targetsToText(groups[servoIndex]) + " (" + (servoIndex + 1) + "/" + groups.length + ")"
        }

        return "Current: All selected — " + targetsToText(groups[0])
    }

    function advanceSequence() {
        var groups = groupsForCurrentMode()

        if (groups.length <= 0) {
            currentGroupIndex = 0
            currentServoIndex = 0
            updateSequenceInfo()
            return
        }

        if (dropMode === modeGroups) {
            currentGroupIndex = (currentGroupIndex + 1) % groups.length
        } else if (dropMode === modeIndividual) {
            currentServoIndex = (currentServoIndex + 1) % groups.length
        }

        updateSequenceInfo()
    }

    function updateSequenceInfo() {
        servoOrder = sanitizeServoOrder(servoOrder)

        var targets = selectedTargets()
        orderedTargetsPreview = targets

        var groups = groupsForCurrentMode()

        if (groups.length <= 0) {
            currentActionLabel = "Current: no selected servos"
            nextActionLabel = "Next: no selected servos"
            sequenceChanged()
            return
        }

        currentActionLabel = currentLabel()

        if (dropMode === modeGroups) {
            var groupIndex = currentGroupIndex % groups.length
            nextActionLabel = "Next: Group " + (groupIndex + 1) + "/" + groups.length + " — " + targetsToText(groups[groupIndex])
            sequenceChanged()
            return
        }

        if (dropMode === modeIndividual) {
            var servoIndex = currentServoIndex % groups.length
            nextActionLabel = "Next: " + targetsToText(groups[servoIndex]) + " (" + (servoIndex + 1) + "/" + groups.length + ")"
            sequenceChanged()
            return
        }

        nextActionLabel = "Next: All selected — " + targetsToText(groups[0])
        sequenceChanged()
    }
}