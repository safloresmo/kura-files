import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/format.js" as Fmt

// The strip at the bottom: what the folder holds, and what is going on.
Item {
    id: foot

    required property var app

    height: 52

    Rectangle {
        width: parent.width
        height: 1
        color: Tokens.line
    }
    Row {
        anchors { left: parent.left; leftMargin: Tokens.s5; verticalCenter: parent.verticalCenter }
        spacing: Tokens.s3

        Text {
            text: "///"
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 6
            height: 6
            color: app.ready ? Tokens.ink : Tokens.inkFaint
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: (app.query !== "" ? app.rows.length + " DE " + app.folderTotal + " · " : "")
                + Fmt.plural(app.dirTotal, "CARPETA", "CARPETAS") + " · " + Fmt.plural(app.fileTotal, "ARCHIVO", "ARCHIVOS")
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: Tokens.trackMark
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Rectangle {
        visible: app.transfer !== null
        height: 2
        width: app.transfer && app.transfer.total > 0 ? parent.width * Math.min(1, app.transfer.done / app.transfer.total) : 0
        color: Tokens.sun
    }
    Btn {
        id: cancel
        visible: app.transfer !== null
        anchors { right: parent.right; rightMargin: Tokens.s6; verticalCenter: parent.verticalCenter }
        compact: true
        text: "CANCELAR"
        onAct: app.cancelTransfer()
    }
    Text {
        anchors { right: cancel.visible ? cancel.left : parent.right; rightMargin: cancel.visible ? Tokens.s3 : Tokens.s6; verticalCenter: parent.verticalCenter }
        text: app.transfer !== null
            ? "COPIANDO · " + app.transfer.name.toUpperCase() + " · " + (app.transfer.total > 0 ? Math.floor(100 * app.transfer.done / app.transfer.total) : 0) + "%"
            : app.notice !== "" ? app.notice : (app.clip ? "PORTAPAPELES · " + app.clip.text + "   " : "") + app.space
        color: app.transfer !== null ? Tokens.ink : (app.notice !== "" && app.noticeBad ? Tokens.alert : (app.notice !== "" ? Tokens.ink : Tokens.inkMuted))
        width: parent.width * 0.55
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
        font.family: Tokens.mono
        font.pixelSize: 10
        font.letterSpacing: Tokens.trackMark
    }
}
