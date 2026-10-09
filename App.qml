import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/format.js" as Fmt

Item {
    id: app

    readonly property string home: Quickshell.env("HOME") || "/"
    property string path: home
    property var back: []
    property var forward: []
    property bool showHidden: false
    property string query: ""
    property int sortKey: 0
    property bool sortReversed: false
    property int current: -1

    property var places: [{ name: "Carpeta personal", path: home, icon: "home", seal: "自宅" }]
    property var devices: []
    property var counts: ({})
    property bool countsReady: false
    property string space: ""
    property int dirTotal: 0
    property int fileTotal: 0
    property var rows: []

    readonly property int total: rows.length
    readonly property bool ready: dir.status === FolderListModel.Ready
    readonly property var selected: entry(current)
    readonly property string title: {
        for (const p of places) {
            if (p.path === path)
                return p.name;
        }
        return path === "/" ? "Raíz" : path.slice(path.lastIndexOf("/") + 1);
    }

    signal quit()

    function clean(p) {
        p = String(p).trim();
        if (p === "~" || p.indexOf("~/") === 0)
            p = home + p.slice(1);
        p = p.replace(/\/+/g, "/");
        if (p.length > 1 && p.charAt(p.length - 1) === "/")
            p = p.slice(0, -1);
        return p || "/";
    }
    function shorten(p) {
        return p === home || p.indexOf(home + "/") === 0 ? "~" + p.slice(home.length) : p;
    }
    function url(p) {
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    function go(p) {
        p = clean(p);
        if (p === path)
            return;
        back = back.concat([path]);
        forward = [];
        path = p;
    }
    function goBack() {
        if (back.length === 0)
            return;
        const stack = back.slice();
        const p = stack.pop();
        forward = forward.concat([path]);
        back = stack;
        path = p;
    }
    function goForward() {
        if (forward.length === 0)
            return;
        const stack = forward.slice();
        const p = stack.pop();
        back = back.concat([path]);
        forward = stack;
        path = p;
    }
    function goUp() {
        if (path === "/")
            return;
        const i = path.lastIndexOf("/");
        go(i <= 0 ? "/" : path.slice(0, i));
    }
    function tryPath(p) {
        probe.target = clean(p);
        probe.running = false;
        probe.command = ["test", "-d", probe.target];
        probe.running = true;
    }

    function entry(i) {
        return i >= 0 && i < rows.length ? rows[i] : null;
    }
    function open(i) {
        const e = entry(i);
        if (!e)
            return;
        if (e.isDir)
            go(e.path);
        else
            Spawn.run(["xdg-open", e.path]);
    }
    function terminal(p) {
        Spawn.run(["kitty", "--directory", p]);
    }
    function copyPath(p) {
        Spawn.run(["wl-copy", "--", p]);
    }

    function matches(name) {
        return query === "" || name.toLowerCase().indexOf(query.toLowerCase()) >= 0;
    }
    function sortBy(key) {
        if (sortKey === key)
            sortReversed = !sortReversed;
        else {
            sortKey = key;
            sortReversed = false;
        }
    }
    function iconFor(name, filePath, isDir) {
        if (isDir) {
            for (const p of places) {
                if (p.path === filePath)
                    return p.icon;
            }
        }
        return Fmt.icon(name, isDir);
    }
    function countLabel(dirPath, long) {
        if (!countsReady)
            return "";
        const n = counts[dirPath] || 0;
        return long ? Fmt.plural(n, "elemento", "elementos") : n + " elem.";
    }

    function select(i) {
        if (rows.length === 0)
            return;
        current = Math.max(0, Math.min(rows.length - 1, i));
        files.view.positionViewAtIndex(current, ListView.Contain);
    }
    function focusList() {
        keys.forceActiveFocus();
    }

    // The view reads a sorted, filtered copy of the folder model.
    function rebuild() {
        const keep = selected ? selected.path : "";
        const list = [];
        let dirs = 0;
        let regular = 0;
        for (let i = 0; i < dir.count; i++) {
            const e = {
                name: dir.get(i, "fileName"),
                path: dir.get(i, "filePath"),
                size: dir.get(i, "fileSize"),
                modified: dir.get(i, "fileModified"),
                isDir: dir.isFolder(i)
            };
            if (e.isDir)
                dirs++;
            else
                regular++;
            if (matches(e.name))
                list.push(e);
        }
        const flip = sortReversed ? -1 : 1;
        list.sort((a, b) => {
            if (a.isDir !== b.isDir)
                return a.isDir ? -1 : 1;
            let d = 0;
            if (sortKey === 1 && !a.isDir)
                d = a.size - b.size;
            else if (sortKey === 2)
                d = b.modified - a.modified;
            return flip * (d || a.name.localeCompare(b.name));
        });
        dirTotal = dirs;
        fileTotal = regular;
        rows = list;
        current = keep === "" ? -1 : list.findIndex(e => e.path === keep);
    }
    function refresh() {
        countsReady = false;
        counter.running = false;
        counter.command = ["sh", "-c", "find -L \"$1\" -mindepth 2 -maxdepth 2 -printf '%h\\n' 2>/dev/null | sort | uniq -c", "sh", path];
        counter.running = true;
        disk.running = false;
        disk.command = ["df", "-B1", "--output=fstype,avail", path];
        disk.running = true;
    }

    onPathChanged: {
        current = -1;
        query = "";
        rail.filter.clear();
        pathField.text = shorten(path);
        refresh();
    }
    onQueryChanged: rebuild()
    onSortKeyChanged: rebuild()
    onSortReversedChanged: rebuild()
    Component.onCompleted: {
        const start = Quickshell.env("ARCHIVOS_DIR");
        if (start)
            path = clean(start);
        pathField.text = shorten(path);
        refresh();
        focusList();
    }

    FolderListModel {
        id: dir
        folder: app.url(app.path)
        showDirsFirst: true
        showHidden: app.showHidden
        showDotAndDotDot: false
        caseSensitive: false
        onCountChanged: Qt.callLater(app.rebuild)
        onStatusChanged: Qt.callLater(app.rebuild)
        onRowsInserted: Qt.callLater(app.rebuild)
        onRowsRemoved: Qt.callLater(app.rebuild)
        onModelReset: Qt.callLater(app.rebuild)
    }

    Process {
        id: probe
        property string target: ""
        onExited: code => {
            if (code === 0)
                app.go(target);
            else
                pathField.text = app.shorten(app.path);
            app.focusList();
        }
    }
    Process {
        id: counter
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^\s*(\d+) (.+)$/);
                    if (m)
                        map[m[2]] = Number(m[1]);
                }
                app.counts = map;
                app.countsReady = true;
            }
        }
    }
    Process {
        id: disk
        stdout: StdioCollector {
            onStreamFinished: {
                const row = text.trim().split("\n")[1];
                const cols = row ? row.trim().split(/\s+/) : [];
                app.space = cols.length === 2 ? cols[0].toUpperCase() + " · " + Fmt.size(cols[1]).toUpperCase() + " LIBRES" : "";
            }
        }
    }
    Process {
        id: userDirs
        running: true
        command: ["sh", "-c", "for k in DESKTOP DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS; do printf '%s\\t%s\\n' \"$k\" \"$(xdg-user-dir $k)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const known = {
                    DESKTOP: ["Escritorio", "desktop", "机上"],
                    DOCUMENTS: ["Documentos", "doc", "文書"],
                    DOWNLOAD: ["Descargas", "download", "受信"],
                    MUSIC: ["Música", "music", "音楽"],
                    PICTURES: ["Imágenes", "image", "画像"],
                    VIDEOS: ["Vídeos", "video", "動画"]
                };
                const list = [{ name: "Carpeta personal", path: app.home, icon: "home", seal: "自宅" }];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    const meta = known[cols[0]];
                    if (!meta || !cols[1] || cols[1] === app.home)
                        continue;
                    list.push({ name: meta[0], path: app.clean(cols[1]), icon: meta[1], seal: meta[2] });
                }
                list.push({ name: "Papelera", path: app.home + "/.local/share/Trash/files", icon: "trash", seal: "屑籠" });
                app.places = list;
            }
        }
    }
    Process {
        id: blocks
        running: true
        command: ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINTS,SIZE,FSUSE%,RM,HOTPLUG,TYPE"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const walk = nodes => {
                    for (const n of nodes || []) {
                        const at = (n.mountpoints || []).find(m => m && (m === "/" || m.indexOf("/run/media/") === 0 || m.indexOf("/mnt/") === 0 || m.indexOf("/media/") === 0));
                        if (at) {
                            found.push({
                                name: at === "/" ? "Sistema" : (n.label || n.size + " · " + n.name),
                                path: at,
                                used: parseInt(n["fsuse%"]) || 0,
                                removable: n.rm === true || n.hotplug === true
                            });
                        }
                        walk(n.children);
                    }
                };
                try {
                    walk(JSON.parse(text).blockdevices);
                } catch (e) {
                    return;
                }
                found.sort((a, b) => (a.path === "/" ? -1 : b.path === "/" ? 1 : a.name.localeCompare(b.name)));
                app.devices = found;
            }
        }
    }
    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: blocks.running = true
    }

    Shortcut { sequence: "Ctrl+K"; onActivated: rail.filter.grabFocus() }
    Shortcut { sequence: "Ctrl+L"; onActivated: pathField.grabFocus() }
    Shortcut { sequence: "Ctrl+H"; onActivated: app.showHidden = !app.showHidden }
    Shortcut { sequence: "Alt+Left"; onActivated: app.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: app.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: app.goUp() }
    Shortcut { sequence: "F5"; onActivated: app.refresh() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: app.quit() }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const page = Math.max(1, Math.floor(files.view.height / 40) - 1);
            let handled = true;
            if (event.key === Qt.Key_Down)
                app.select(app.current + 1);
            else if (event.key === Qt.Key_Up)
                app.select(app.current < 0 ? app.rows.length - 1 : app.current - 1);
            else if (event.key === Qt.Key_Home)
                app.select(0);
            else if (event.key === Qt.Key_End)
                app.select(app.rows.length - 1);
            else if (event.key === Qt.Key_PageDown)
                app.select(app.current + page);
            else if (event.key === Qt.Key_PageUp)
                app.select(app.current - page);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                app.open(app.current);
            else if (event.key === Qt.Key_Backspace)
                app.goUp();
            else if (event.key === Qt.Key_Escape)
                app.current = -1;
            else
                handled = false;
            event.accepted = handled;
        }
    }

    Rail {
        id: rail
        app: app
        anchors { left: parent.left; top: parent.top; bottom: foot.top }
    }

    Item {
        id: page
        anchors { left: rail.right; right: parent.right; top: parent.top; bottom: foot.top }
        anchors.leftMargin: Tokens.s6
        anchors.rightMargin: Tokens.s6
        anchors.topMargin: Tokens.s5

        Item {
            id: eyebrow
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 32

            Row {
                id: crumbs
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s2

                Text {
                    text: "— 力"
                    color: Tokens.inkFaint
                    font.family: Tokens.jp
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                Repeater {
                    model: {
                        const parts = app.shorten(app.path).split("/").filter(s => s !== "");
                        const out = [];
                        let at = "";
                        for (const s of parts) {
                            at = s === "~" ? app.home : at + "/" + s;
                            out.push({ label: s === "~" ? "INICIO" : s.toUpperCase(), path: at });
                        }
                        if (app.path.indexOf(app.home) !== 0)
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

                Btn { text: "OCULTOS"; primary: app.showHidden; onAct: app.showHidden = !app.showHidden }
                Btn { text: "TERMINAL AQUÍ"; onAct: app.terminal(app.path) }
            }
        }

        Text {
            id: heading
            anchors { left: parent.left; right: parent.right; top: eyebrow.bottom; topMargin: Tokens.s3 }
            text: app.title
            color: Tokens.ink
            font.family: Tokens.ui
            font.pixelSize: Tokens.fTitle
            elide: Text.ElideMiddle
        }
        Text {
            id: blurb
            anchors { left: parent.left; right: parent.right; top: heading.bottom; topMargin: Tokens.s1 }
            text: !app.ready ? "Leyendo…"
                : (dir.count === 0 ? "Sin contenido."
                    : Fmt.plural(app.dirTotal, "carpeta", "carpetas") + " y " + Fmt.plural(app.fileTotal, "archivo", "archivos") + ".")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
        }

        Row {
            id: tools
            anchors { left: parent.left; right: parent.right; top: blurb.bottom; topMargin: Tokens.s4 }
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
            }
        }

        FileList {
            id: files
            app: app
            anchors { left: parent.left; right: detail.left; top: tools.bottom; bottom: parent.bottom }
            anchors.topMargin: Tokens.s4
            anchors.rightMargin: Tokens.s5
            anchors.bottomMargin: Tokens.s5
        }
        Detail {
            id: detail
            app: app
            anchors { right: parent.right; top: tools.bottom; topMargin: Tokens.s4 }
            width: 340
        }
    }

    Item {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
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
                text: (app.query !== "" ? app.rows.length + " DE " + dir.count + " · " : "")
                    + Fmt.plural(app.dirTotal, "CARPETA", "CARPETAS") + " · " + Fmt.plural(app.fileTotal, "ARCHIVO", "ARCHIVOS")
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: 10
                font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            anchors { right: parent.right; rightMargin: Tokens.s6; verticalCenter: parent.verticalCenter }
            text: app.space
            color: Tokens.inkMuted
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: Tokens.trackMark
        }
    }
}
