import QtQuick

// Command palette: type to find an action, a place or a path, Enter to run it.
Item {
    id: palette

    required property var app
    property var all: []
    property string query: ""
    property int at: 0
    property string heading: "COMANDOS"
    property bool searching: true

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        const out = [];
        if (searching && (q.charAt(0) === "/" || q.charAt(0) === "~")) {
            const target = query.trim();
            out.push({ label: "Ir a " + target, hint: "RUTA", act: () => palette.app.tryPath(target) });
        }
        const words = q.split(/\s+/).filter(w => w !== "");
        for (const c of all) {
            const text = c.label.toLowerCase();
            if (words.every(w => text.indexOf(w) >= 0))
                out.push(c);
        }
        if (searching && (q !== "" && out.length === 0 || (q !== "" && q.charAt(0) !== "/" && q.charAt(0) !== "~"))) {
            const text = query.trim();
            out.push({ label: "Buscar «" + text + "» en subcarpetas", hint: "BÚSQUEDA", act: () => palette.app.search(text) });
        }
        return out;
    }

    signal closed()

    // Pick one of a fixed list, with the same typing and keys as the commands.
    function choose(title, entries) {
        heading = title;
        searching = false;
        all = entries;
        query = "";
        field.clear();
        at = 0;
        visible = true;
        field.grabFocus();
    }
    function open() {
        heading = "COMANDOS";
        searching = true;
        all = app.commands();
        query = "";
        field.clear();
        at = 0;
        visible = true;
        field.grabFocus();
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        all = [];
        closed();
    }
    function runAt(i) {
        const c = shown[i];
        close();
        if (c && c.act)
            c.act();
    }
    function move(delta) {
        if (shown.length === 0)
            return;
        at = Math.max(0, Math.min(shown.length - 1, at + delta));
        list.positionViewAtIndex(at, ListView.Contain);
    }

    anchors.fill: parent
    visible: false
    z: 45

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: palette.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.14)
        width: Math.min(620, parent.width - Tokens.s7)
        height: head.height + Math.min(palette.shown.length, 9) * 36 + Tokens.s4 + (palette.shown.length === 0 ? 44 : 0)
        color: Tokens.paper
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line
        clip: true

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: head
            x: Tokens.s4
            y: Tokens.s4
            width: parent.width - Tokens.s4 * 2
            spacing: Tokens.s3
            bottomPadding: Tokens.s2

            Item {
                width: parent.width
                height: 14

                Text {
                    text: "// " + palette.heading
                    color: Tokens.ink
                    font.family: Tokens.mono
                    font.pixelSize: 11
                    font.letterSpacing: Tokens.trackLabel
                }
                Text {
                    anchors.right: parent.right
                    text: palette.shown.length + " · ENTER PARA EJECUTAR"
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: Tokens.trackMark
                }
            }
            Field {
                id: field
                width: parent.width
                toolbar: true
                placeholder: "Una acción, un lugar o una ruta…"
                onEdited: t => {
                    palette.query = t;
                    palette.at = 0;
                }
                onAccepted: palette.runAt(palette.at)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        palette.move(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        palette.move(-1);
                        event.accepted = true;
                    }
                }
            }
        }

        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
            anchors.bottomMargin: Tokens.s2
            model: palette.shown
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property int index
                required property var modelData
                readonly property bool sel: palette.at === index

                width: list.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.s2
                    anchors.rightMargin: Tokens.s2
                    radius: Tokens.radius - 2
                    color: row.sel ? Tokens.tint16 : (rowHover.hovered ? Tokens.tint5 : "transparent")
                }
                Text {
                    anchors { left: parent.left; leftMargin: Tokens.s4 + 2; verticalCenter: parent.verticalCenter }
                    width: parent.width - hint.width - Tokens.s4 * 3
                    elide: Text.ElideMiddle
                    text: (row.sel ? "//  " : "") + row.modelData.label
                    color: row.sel ? Tokens.ink : Tokens.inkDim
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody
                }
                Text {
                    id: hint
                    anchors { right: parent.right; rightMargin: Tokens.s4 + 2; verticalCenter: parent.verticalCenter }
                    text: row.modelData.hint || ""
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: palette.runAt(row.index) }
            }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Tokens.s4 }
            visible: palette.shown.length === 0
            text: "// NADA COINCIDE_"
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: 1.4
        }
    }
}
