import QtQuick
import "lib/format.js" as Fmt

// The top of the page: where you are, what the folder holds, and the path bar.
Item {
    id: head

    required property var app
    property alias pathField: pathField
    property alias searchField: searchField
    readonly property bool searchShown: head.width >= 640
    // The minimal header has no row of its own for these, so they sit beside the path.
    readonly property int toolCount: !app.bare ? 0 : (head.width >= 700 ? 4 : head.width >= 560 ? 3 : head.width >= 420 ? 2 : 1)

    implicitHeight: app.showSorter ? sorter.y + sorter.height : tools.y + tools.height

    // A square button with a line icon, for the single row of the minimal header.
    component Tool: Rectangle {
        id: tool
        property string icon: ""
        property string hint: ""
        property bool on: false
        signal act()

        width: 36
        height: 36
        radius: Tokens.radius
        color: on ? Tokens.bone : (toolHover.hovered ? Tokens.tint10 : "transparent")
        border.width: Tokens.border
        border.color: on ? Tokens.bone : Tokens.line

        Icon {
            anchors.centerIn: parent
            name: tool.icon
            size: 16
            color: tool.on ? Tokens.inkOnBone : Tokens.ink
        }
        Rectangle {
            visible: toolHover.hovered
            anchors { top: parent.bottom; topMargin: 4; right: parent.right }
            z: 5
            width: hintText.implicitWidth + 12
            height: 20
            radius: Tokens.radius
            color: Tokens.paper
            border.width: Tokens.border
            border.color: Tokens.line

            Text {
                id: hintText
                anchors.centerIn: parent
                text: tool.hint
                color: Tokens.inkDim
                font.family: Tokens.mono
                font.pixelSize: 9
                font.letterSpacing: 1.2
            }
        }
        HoverHandler { id: toolHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tool.act() }
    }

    Item {
        id: eyebrow
        visible: !app.bare
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: app.bare ? 0 : 32

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
                        out.push({ label: s === "~" ? Lang.t("INICIO") : s.toUpperCase(), path: at });
                    }
                    if (!remote && app.path.indexOf(app.home) !== 0)
                        out.unshift({ label: Lang.t("RAÍZ"), path: "/" });
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

            Btn { text: Lang.t("COMANDOS"); onAct: app.openPalette() }
            Btn { visible: head.width >= 420; text: app.grid ? Lang.t("LISTA") : Lang.t("CUADRÍCULA"); onAct: app.toggleGrid() }
            Btn { visible: head.width >= 560; text: Lang.t("OCULTOS"); primary: app.showHidden; onAct: app.showHidden = !app.showHidden }
            Btn { visible: head.width >= 700; text: Lang.t("TERMINAL AQUÍ"); onAct: app.terminal(app.path) }
        }
    }

    Text {
        id: heading
        anchors { left: parent.left; right: parent.right; top: eyebrow.bottom; topMargin: app.short ? 0 : Tokens.s3 }
        visible: !app.bare
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
        text: app.inTrash && !app.deep ? Fmt.plural(app.rows.length, Lang.t("elemento"), Lang.t("elementos")) + Lang.t(" en la papelera, de todos los discos.")
            : app.recent ? Lang.t("Lo último que abriste, esté donde esté.")
            : app.deep ? Fmt.plural(app.rows.length, Lang.t("resultado"), Lang.t("resultados")) + (app.deepInside ? " con «" : Lang.t(" para «")) + app.deepQuery + (app.deepInside ? Lang.t("» dentro, en esta carpeta y sus subcarpetas.") : app.deepWide ? Lang.t("» en toda tu carpeta personal.") : Lang.t("» en esta carpeta y sus subcarpetas."))
            : !app.ready ? Lang.t("Leyendo…")
            : app.unreadable ? Lang.t("No se puede leer.")
            : (app.folderTotal === 0 ? Lang.t("Sin contenido.")
                : Fmt.plural(app.dirTotal, Lang.t("carpeta"), Lang.t("carpetas")) + Lang.t(" y ") + Fmt.plural(app.fileTotal, Lang.t("archivo"), Lang.t("archivos")) + ".")
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fBody
    }

    Row {
        id: tools
        anchors { left: parent.left; right: parent.right; top: app.bare ? eyebrow.bottom : (app.short ? heading.bottom : blurb.bottom); topMargin: app.bare ? 0 : (app.short ? Tokens.s2 : Tokens.s4) }
        spacing: Tokens.s2
        z: 2

        Btn { text: "←"; armed: app.back.length > 0; height: 36; width: 40; onAct: app.goBack() }
        Btn { text: "→"; armed: app.forward.length > 0; height: 36; width: 40; onAct: app.goForward() }
        Btn { text: "↑"; armed: app.path !== "/"; height: 36; width: 40; onAct: app.goUp() }
        Field {
            id: pathField
            width: parent.width - 3 * (40 + Tokens.s2) - (head.searchShown ? searchField.width + Tokens.s2 : 0) - sorterButton.width - Tokens.s2 - head.toolCount * (36 + Tokens.s2)
            toolbar: true
            tabular: true
            placeholder: Lang.t("Ir a una ruta…")
            onAccepted: app.tryPath(text)
            Keys.onTabPressed: app.completePath(text)
        }
        Field {
            id: searchField
            visible: head.searchShown
            width: 220
            toolbar: true
            placeholder: Lang.t("Buscar por nombre…")
            onEdited: t => app.query = t
            onAccepted: app.focusList()
        }
        // Opens the order and kind chips; a dot says something is set while they are hidden.
        Btn {
            id: sorterButton
            height: 36
            width: 92
            text: Lang.t("ORDENAR") + (!app.showSorter && (app.pinType !== "" || app.sortKey !== 0 || app.sortReversed) ? " •" : "")
            primary: app.showSorter
            onAct: app.setPref("sorter", !app.showSorter)
        }
        Tool { visible: head.toolCount >= 1; icon: "command"; hint: Lang.t("COMANDOS"); onAct: app.openPalette() }
        Tool { visible: head.toolCount >= 2; icon: app.grid ? "rows" : "grid"; hint: app.grid ? Lang.t("LISTA") : Lang.t("CUADRÍCULA"); onAct: app.toggleGrid() }
        Tool { visible: head.toolCount >= 3; icon: "eye"; hint: Lang.t("OCULTOS"); on: app.showHidden; onAct: app.showHidden = !app.showHidden }
        Tool { visible: head.toolCount >= 4; icon: "script"; hint: Lang.t("TERMINAL AQUÍ"); onAct: app.terminal(app.path) }
    }

    // How the folder is ordered, and which kinds of file it holds.
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool on: false
        signal act()

        width: chipText.implicitWidth + 18
        height: 26
        radius: Tokens.radius
        color: on ? Tokens.bone : (chipHover.hovered ? Tokens.tint10 : "transparent")
        border.width: Tokens.border
        border.color: on ? Tokens.bone : Tokens.line

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.on ? Tokens.inkOnBone : Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: 9
            font.letterSpacing: 1.2
        }
        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.act() }
    }

    Row {
        id: sorter
        visible: app.showSorter
        anchors { left: parent.left; right: parent.right; top: tools.bottom; topMargin: Tokens.s2 }
        height: 26
        spacing: 6
        clip: true

        Text {
            text: Lang.t("ORDEN")
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 9
            font.letterSpacing: Tokens.trackMark
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 4
        }
        Repeater {
            model: [Lang.t("NOMBRE"), Lang.t("TAMAÑO"), Lang.t("FECHA"), Lang.t("TIPO")]

            Chip {
                required property string modelData
                required property int index
                label: modelData + (app.sortKey === index ? (app.sortReversed ? " ▴" : " ▾") : "")
                on: app.sortKey === index
                onAct: app.sortBy(index)
            }
        }
        Text {
            visible: app.typeCounts.length > 0
            text: Lang.t("TIPOS")
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 9
            font.letterSpacing: Tokens.trackMark
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Tokens.s3
            rightPadding: 4
        }
        Repeater {
            model: app.typeCounts

            Chip {
                required property var modelData
                label: modelData.ext.toUpperCase() + " " + modelData.count
                on: app.pinType === modelData.ext
                onAct: app.pin(modelData.ext)
            }
        }
        Chip {
            visible: app.pinType !== ""
            label: Lang.t("SOLO ESTOS")
            on: app.onlyType
            onAct: app.onlyType = !app.onlyType
        }
    }
}
