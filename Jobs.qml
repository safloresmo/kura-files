import QtQuick

// The transfers under way, each with its own pause and cancel.
Rectangle {
    id: jobs

    required property var app

    visible: false
    width: 420
    height: list.height + 2
    radius: Tokens.radius
    color: Tokens.paper
    border.width: Tokens.border
    border.color: Tokens.lineStrong
    z: 30

    Connections {
        target: jobs.app
        function onTransfersChanged() {
            if (jobs.app.transfers.length === 0)
                jobs.visible = false;
        }
    }

    Column {
        id: list
        x: 1
        y: 1
        width: parent.width - 2

        Repeater {
            model: jobs.app.transfers

            Item {
                id: row
                required property var modelData
                width: list.width
                height: 56

                Text {
                    id: what
                    anchors { left: parent.left; leftMargin: Tokens.s4; right: buttons.left; rightMargin: Tokens.s3; top: parent.top; topMargin: 10 }
                    elide: Text.ElideMiddle
                    text: row.modelData.label
                    color: Tokens.ink
                    font.family: Tokens.mono
                    font.pixelSize: 10
                    font.letterSpacing: Tokens.trackMark
                }
                Text {
                    anchors { left: what.left; right: what.right; top: what.bottom; topMargin: 4 }
                    elide: Text.ElideMiddle
                    text: (row.modelData.paused ? "EN PAUSA · " : "") + (row.modelData.total > 0 ? Math.floor(100 * row.modelData.done / row.modelData.total) : 0) + "% · " + row.modelData.name
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 12
                }
                Row {
                    id: buttons
                    anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.s2

                    Btn { compact: true; text: row.modelData.paused ? "SEGUIR" : "PAUSA"; onAct: jobs.app.pauseJob(row.modelData.id) }
                    Btn { compact: true; text: "CANCELAR"; onAct: jobs.app.cancelJob(row.modelData.id) }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    height: 2
                    width: row.modelData.total > 0 ? parent.width * Math.min(1, row.modelData.done / row.modelData.total) : 0
                    color: row.modelData.paused ? Tokens.inkFaint : Tokens.sun
                }
            }
        }
    }
}
