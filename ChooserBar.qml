import QtQuick

// Shown when another program asked for a file: what is being chosen, and the answer.
Item {
    id: bar

    required property var app
    property alias nameField: nameField

    visible: app.pick !== ""
    height: visible ? 60 : 0

    Rectangle {
        width: parent.width
        height: 1
        color: Tokens.line
    }
    Text {
        id: ask
        anchors { left: parent.left; leftMargin: Tokens.s5; verticalCenter: parent.verticalCenter }
        text: app.pickTitle.toUpperCase()
        color: Tokens.inkDim
        font.family: Tokens.mono
        font.pixelSize: 10
        font.letterSpacing: Tokens.trackMark
    }
    Field {
        id: nameField
        visible: app.pick === "save"
        anchors { left: ask.right; leftMargin: Tokens.s4; right: buttons.left; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
        toolbar: true
        placeholder: Lang.t("Nombre del archivo…")
        text: app.pickName
        onAccepted: app.pickDone()
    }
    Text {
        visible: app.pick !== "save"
        anchors { left: ask.right; leftMargin: Tokens.s4; right: buttons.left; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
        elide: Text.ElideMiddle
        text: app.pickSummary
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fBody
    }
    Row {
        id: buttons
        anchors { right: parent.right; rightMargin: Tokens.s5; verticalCenter: parent.verticalCenter }
        spacing: Tokens.s2

        Btn { text: Lang.t("CANCELAR"); onAct: app.quit() }
        Btn {
            text: app.pick === "save" ? Lang.t("GUARDAR") : (app.pick === "folder" ? Lang.t("ELEGIR ESTA CARPETA") : Lang.t("ABRIR"))
            primary: true
            armed: app.pickReady
            onAct: app.pickDone()
        }
    }
}
