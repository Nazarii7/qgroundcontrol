import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: editor

    property var dropModel
    property var dropTitleProvider
    property bool sectionOpen: false
    property bool editingLocked: false

    signal sectionToggleRequested()
    signal closedPwmChanged(int rowIndex, int pwmValue)
    signal openPositionPwmChanged(int rowIndex, int positionIndex, int pwmValue)
    signal openPositionAddRequested(int rowIndex)
    signal openPositionRemoveRequested(int rowIndex, int positionIndex)
    signal pwmResetRequested(int rowIndex)

    implicitHeight: content.implicitHeight

    function parsePositions(raw, fallbackPwm) {
        var result = []

        if (raw && raw.length > 0) {
            try {
                var parsed = JSON.parse(raw)

                if (parsed && parsed.length !== undefined) {
                    for (var i = 0; i < parsed.length; i++) {
                        var value = parseInt(parsed[i])

                        if (!isNaN(value)) {
                            result.push(value)
                        }
                    }
                }
            } catch (e) {
                console.warn("DROP_PWM_EDITOR: invalid positions json", raw, e)
            }
        }

        if (result.length <= 0) {
            result.push(fallbackPwm)
        }

        return result
    }

    function positionSummary(raw, fallbackPwm) {
        return parsePositions(raw, fallbackPwm).join(", ")
    }

    Column {
        id: content
        width: parent.width
        spacing: 6

        RowLayout {
            width: parent.width
            height: 28
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: "PWM positions"
                color: "white"
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 24

                Label {
                    anchors.centerIn: parent
                    text: editor.sectionOpen ? "−" : "+"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        editor.sectionToggleRequested()
                    }
                }
            }
        }

        Column {
            width: parent.width
            visible: editor.sectionOpen
            spacing: 8

            Label {
                width: parent.width
                visible: editor.editingLocked
                text: "PWM settings are locked while Drop hold is active."
                color: Qt.rgba(1.0, 0.76, 0.36, 0.92)
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: editor.dropModel

                delegate: Item {
                    id: servoDelegate

                    required property int index
                    required property int servoNumber
                    required property bool active
                    required property bool servoAvailable
                    required property int closedPwm
                    required property int openPwm
                    required property string openPositionsJson
                    required property int currentPositionIndex

                    property int rowIndexValue: index
                    property var positions: editor.parsePositions(openPositionsJson, openPwm)

                    width: parent.width
                    height: active && servoAvailable ? pwmCard.implicitHeight : 0
                    visible: height > 0

                    Rectangle {
                        id: pwmCard
                        width: parent.width
                        implicitHeight: pwmContent.implicitHeight + 16
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.045)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Column {
                            id: pwmContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 7

                            RowLayout {
                                width: parent.width
                                spacing: 8

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Label {
                                        width: parent.width
                                        text: editor.dropTitleProvider ? editor.dropTitleProvider(servoNumber) : ("SERVO " + servoNumber)
                                        color: "white"
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        width: parent.width
                                        text: "Closed " + closedPwm + " · Open " + editor.positionSummary(openPositionsJson, openPwm)
                                        color: Qt.rgba(1, 1, 1, 0.62)
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 22
                                    radius: 6
                                    color: editor.editingLocked ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.09)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.13)
                                    opacity: editor.editingLocked ? 0.45 : 1.0

                                    Label {
                                        anchors.centerIn: parent
                                        text: "Reset"
                                        color: "white"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !editor.editingLocked
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            editor.pwmResetRequested(index)
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 6

                                Label {
                                    Layout.preferredWidth: 52
                                    text: "Closed"
                                    color: Qt.rgba(1, 1, 1, 0.70)
                                    font.pixelSize: 10
                                }

                                TextField {
                                    Layout.fillWidth: true
                                    enabled: !editor.editingLocked
                                    text: String(closedPwm)
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    selectByMouse: true
                                    font.pixelSize: 10
                                    color: "white"

                                    validator: IntValidator { bottom: 800; top: 2200 }

                                    background: Rectangle {
                                        radius: 5
                                        color: Qt.rgba(0, 0, 0, 0.20)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.14)
                                    }

                                    onEditingFinished: {
                                        var value = parseInt(text)
                                        if (!isNaN(value)) {
                                            editor.closedPwmChanged(index, value)
                                        } else {
                                            text = String(closedPwm)
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: positions

                                delegate: RowLayout {
                                    id: positionRow

                                    property int positionIndex: index

                                    width: pwmContent.width
                                    spacing: 6

                                    Label {
                                        Layout.preferredWidth: 52
                                        text: "P" + (index + 1)
                                        color: Qt.rgba(1, 1, 1, 0.70)
                                        font.pixelSize: 10
                                    }

                                    TextField {
                                        Layout.fillWidth: true
                                        enabled: !editor.editingLocked
                                        text: String(modelData)
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        selectByMouse: true
                                        font.pixelSize: 10
                                        color: "white"

                                        validator: IntValidator { bottom: 800; top: 2200 }

                                        background: Rectangle {
                                            radius: 5
                                            color: Qt.rgba(0, 0, 0, 0.20)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.14)
                                        }

                                        onEditingFinished: {
                                            var value = parseInt(text)
                                            if (!isNaN(value)) {
                                                editor.openPositionPwmChanged(servoDelegate.rowIndexValue, positionRow.positionIndex, value)
                                            } else {
                                                text = String(modelData)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        radius: 5
                                        color: !editor.editingLocked && positions.length > 1
                                               ? Qt.rgba(1, 1, 1, 0.09)
                                               : Qt.rgba(1, 1, 1, 0.04)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.13)
                                        opacity: !editor.editingLocked && positions.length > 1 ? 1.0 : 0.35

                                        Label {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: "white"
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !editor.editingLocked && positions.length > 1
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                editor.openPositionRemoveRequested(servoDelegate.rowIndexValue, positionRow.positionIndex)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 26
                                radius: 6
                                color: editor.editingLocked ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.13)
                                opacity: editor.editingLocked ? 0.45 : 1.0

                                Label {
                                    anchors.centerIn: parent
                                    text: "+ Add open position"
                                    color: "white"
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !editor.editingLocked
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        editor.openPositionAddRequested(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
