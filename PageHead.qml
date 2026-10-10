import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/format.js" as Fmt

// The top of the page: where you are, what the folder holds, and the path bar.
Item {
    id: head

    required property var app
    property alias pathField: pathField

    implicitHeight: tools.y + tools.height

    Item {
        id: eyebrow
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 32

        Row {
            id: crumbs
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(0, eyebrow.width - actions.width - Tokens.s4))
            clip: true
            spacing: Tokens.s2

            Text {
                text: "— " + app.brand.mark
                color: Tokens.inkFaint
                font.family: Tokens.jp
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            Repeater {
                model: {
                    const out = [];
                    let at = "";
                    let shown = app.shorten(app.path);
                    const colon = shown.indexOf(":/");
                    if (colon > 0 && shown.charAt(0) !== "/") {
                        at = app.path.slice(0, app.path.length - (shown.length - colon - 1)).replace(/\/$/, "");
                        out.push({ label: shown.slice(0, colon).toUpperCase(), path: at });
                        shown = shown.slice(colon + 1);
                    }
                    const remote = out.length > 0;
                    const parts = shown.split("/").filter(s => s !== "");
                    for (const s of parts) {
                        at = s === "~" ? app.home : at + "/" + s;
                        out.push({ label: s === "~" ? "INICIO" : s.toUpperCase(), path: at });
                    }
                    if (!remote && app.path.indexOf(app.home) !== 0)
                        out.unshift({ label: "RAÍZ", path: "/" });
                    return out.slice(-5);
                }

                Row {
                    id: crumb
                    required property var modelData
                    required property int index
                    spacing: Tokens.s2

                    Text {
                        visible: crumb.index > 0
                        text: "/"
                        color: Tokens.inkFaint
                        font.family: Tokens.mono
                        font.pixelSize: 10
                    }
                    Text {
                        text: crumb.modelData.label
                        color: crumbHover.hovered ? Tokens.ink : Tokens.inkMuted
                        font.family: Tokens.mono
                        font.pixelSize: 10
                        font.letterSpacing: Tokens.trackMark
                        HoverHandler { id: crumbHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: app.go(crumb.modelData.path) }
                    }
                }
            }
        }
        Rectangle {
            anchors { left: crumbs.right; right: actions.left; verticalCenter: parent.verticalCenter }
            anchors.leftMargin: Tokens.s3
            anchors.rightMargin: Tokens.s3
            height: 1
            color: Tokens.lineSoft
        }
        Row {
            id: actions
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2

            Btn { text: "COMANDOS"; onAct: app.openPalette() }
            Btn { visible: head.width >= 420; text: app.grid ? "LISTA" : "CUADRÍCULA"; onAct: app.toggleGrid() }
            Btn { visible: head.width >= 560; text: "OCULTOS"; primary: app.showHidden; onAct: app.showHidden = !app.showHidden }
            Btn { visible: head.width >= 700; text: "TERMINAL AQUÍ"; onAct: app.terminal(app.path) }
        }
    }

    Text {
        id: heading
        anchors { left: parent.left; right: parent.right; top: eyebrow.bottom; topMargin: app.short ? 0 : Tokens.s3 }
        text: app.title
        color: Tokens.ink
        font.family: Tokens.ui
        font.pixelSize: app.short ? 22 : Tokens.fTitle
        elide: Text.ElideMiddle
    }
    Text {
        id: blurb
        visible: !app.short
        anchors { left: parent.left; right: parent.right; top: heading.bottom; topMargin: Tokens.s1 }
        text: app.inTrash && !app.deep ? Fmt.plural(app.rows.length, "elemento", "elementos") + " en la papelera, de todos los discos."
            : app.recent ? "Lo último que abriste, esté donde esté."
            : app.deep ? Fmt.plural(app.rows.length, "resultado", "resultados") + " para «" + app.deepQuery + "» en esta carpeta y sus subcarpetas."
            : !app.ready ? "Leyendo…"
            : (app.folderTotal === 0 ? "Sin contenido."
                : Fmt.plural(app.dirTotal, "carpeta", "carpetas") + " y " + Fmt.plural(app.fileTotal, "archivo", "archivos") + ".")
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fBody
    }

    Row {
        id: tools
        anchors { left: parent.left; right: parent.right; top: app.short ? heading.bottom : blurb.bottom; topMargin: app.short ? Tokens.s2 : Tokens.s4 }
        spacing: Tokens.s2

        Btn { text: "←"; armed: app.back.length > 0; height: 36; width: 40; onAct: app.goBack() }
        Btn { text: "→"; armed: app.forward.length > 0; height: 36; width: 40; onAct: app.goForward() }
        Btn { text: "↑"; armed: app.path !== "/"; height: 36; width: 40; onAct: app.goUp() }
        Field {
            id: pathField
            width: parent.width - 3 * (40 + Tokens.s2)
            toolbar: true
            tabular: true
            placeholder: "Ir a una ruta…"
            onAccepted: app.tryPath(text)
            Keys.onTabPressed: app.completePath(text)
        }
    }
}
