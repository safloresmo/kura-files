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
    property var clip: null
    property var marked: ({})
    property int anchor: -1
    property var apps: []
    property string appsFor: ""
    property var targets: []
    property var preview: ({ kind: "none" })
    property string notice: ""
    property bool noticeBad: false

    readonly property string binDir: decodeURIComponent(Qt.resolvedUrl("bin").toString().replace("file://", ""))
    readonly property var brand: settings.brand === "ryoku"
        ? { mark: "力", name: "RYOKU FILES", tag: "RYOKU // FILES" }
        : { mark: settings.ownMark, name: settings.ownName, tag: settings.ownTag }

    readonly property int total: rows.length
    readonly property int markedCount: Object.keys(marked).length
    readonly property string trashDir: home + "/.local/share/Trash/files"
    readonly property bool inTrash: path === trashDir
    readonly property bool grid: settings.grid
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
        say("RUTA COPIADA");
    }
    function toggleBrand() {
        settings.brand = settings.brand === "ryoku" ? "own" : "ryoku";
        settingsFile.writeAdapter();
    }

    function say(text, bad) {
        notice = text;
        noticeBad = bad === true;
        noticeClear.restart();
    }
    function run(command, okText, failText) {
        job.createObject(app, { command: command, okText: okText, failText: failText || "NO SE PUDO" }).running = true;
    }
    function op(args, okText) {
        run([binDir + "/archivos-op"].concat(args), okText);
    }
    // What an action applies to: the marked rows, or the one under the cursor.
    function picked() {
        if (markedCount > 0)
            return rows.filter(e => marked[e.path] === true);
        return selected ? [selected] : [];
    }
    function label(list) {
        return list.length === 1 ? list[0].name.toUpperCase() : list.length + " ELEMENTOS";
    }
    function click(i, modifiers) {
        const e = entry(i);
        if (!e)
            return;
        if (modifiers & Qt.ControlModifier) {
            const next = Object.assign({}, marked);
            if (markedCount === 0 && selected && selected.path !== e.path)
                next[selected.path] = true;
            if (next[e.path])
                delete next[e.path];
            else
                next[e.path] = true;
            marked = next;
            anchor = i;
        } else if ((modifiers & Qt.ShiftModifier) && (anchor >= 0 || current >= 0)) {
            const from = anchor >= 0 ? anchor : current;
            const next = {};
            for (let n = Math.min(from, i); n <= Math.max(from, i); n++)
                next[rows[n].path] = true;
            marked = next;
        } else {
            marked = {};
            anchor = i;
        }
        current = i;
        focusList();
    }
    function rightClick(i, x, y) {
        const e = entry(i);
        if (!e) {
            marked = {};
            current = -1;
        } else if (marked[e.path] !== true) {
            marked = {};
            current = i;
            anchor = i;
        }
        focusList();
        contextMenu(x, y);
    }
    function markAll() {
        const next = {};
        for (const e of rows)
            next[e.path] = true;
        marked = next;
    }
    function toggleGrid() {
        settings.grid = !settings.grid;
        settingsFile.writeAdapter();
    }

    function hold(cut) {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        clip = { paths: list.map(e => e.path), text: label(list), cut: cut };
        Spawn.run(["sh", "-c", "printf '%s\\n' \"$@\" | wl-copy -t text/uri-list", "sh"].concat(list.map(e => url(e.path))));
        say((cut ? "CORTADO · " : "COPIADO · ") + clip.text);
    }
    function paste() {
        if (inTrash)
            return;
        if (!clip) {
            pasteboard.running = true;
            return;
        }
        op([clip.cut ? "move" : "copy", path].concat(clip.paths), (clip.cut ? "MOVIDO · " : "PEGADO · ") + clip.text);
        if (clip.cut)
            clip = null;
    }
    function trash() {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        marked = {};
        op(["trash"].concat(list.map(e => e.path)), "A LA PAPELERA · " + label(list));
    }
    function rename() {
        const list = picked();
        if (list.length !== 1 || inTrash)
            return;
        const e = list[0];
        dialog.ask("RENOMBRAR", e.name, value => op(["rename", e.path, value], "RENOMBRADO · " + value.toUpperCase()));
    }
    function newFolder() {
        if (inTrash)
            return;
        dialog.ask("NUEVA CARPETA", "Nueva carpeta", value => op(["mkdir", path, value], "CARPETA CREADA · " + value.toUpperCase()));
    }
    function restore() {
        const list = picked();
        if (list.length === 0 || !inTrash)
            return;
        marked = {};
        run(["gio", "trash", "--restore"].concat(list.map(e => "trash:///" + encodeURIComponent(e.name))), "RESTAURADO · " + label(list));
    }
    function emptyTrash() {
        dialog.confirm("VACIAR PAPELERA", "Se eliminará todo lo que hay en la papelera. No se puede deshacer.",
            () => run(["gio", "trash", "--empty"], "PAPELERA VACÍA"));
    }
    function sendTo(target) {
        const list = picked().filter(e => !e.isDir);
        if (list.length === 0)
            return;
        say("ENVIANDO A " + target.name.toUpperCase() + "…");
        run(["tailscale", "file", "cp", "--"].concat(list.map(e => e.path)).concat([target.name + ":"]),
            "ENVIADO A " + target.name.toUpperCase() + " · " + label(list),
            "NO SE ENVIÓ A " + target.name.toUpperCase());
    }
    // LocalSend picks the receiver in its own window.
    function localSend() {
        const list = picked().filter(e => !e.isDir);
        if (list.length === 0)
            return;
        Spawn.run(["localsend"].concat(list.map(e => e.path)));
        say("ABIERTO EN LOCALSEND · " + label(list));
    }
    function openWith(e, app) {
        Spawn.run(["gio", "launch", app.file, e.path]);
    }
    function loadApps(filePath) {
        if (appsFor === filePath)
            return;
        apps = [];
        appsFor = filePath;
        appFinder.running = false;
        appFinder.command = [binDir + "/archivos-apps", filePath];
        appFinder.running = true;
    }
    function mount(d) {
        say("MONTANDO " + d.name.toUpperCase() + "…");
        run(["udisksctl", "mount", "-b", d.dev], "MONTADO · " + d.name.toUpperCase());
    }
    function eject(d) {
        if (path === d.path || path.indexOf(d.path + "/") === 0)
            go(home);
        run(["udisksctl", "unmount", "-b", d.dev], "EXPULSADO · " + d.name.toUpperCase(), "NO SE EXPULSÓ " + d.name.toUpperCase());
    }

    function contextMenu(x, y) {
        const list = picked();
        const n = list.length;
        const one = n === 1 ? list[0] : null;
        const sendable = list.some(e => !e.isDir);
        const many = n > 1 ? " · " + n : "";
        const items = [];
        if (inTrash) {
            items.push({ label: "Restaurar" + many, armed: n > 0, act: () => restore() });
            items.push({ label: "Vaciar papelera", armed: dir.count > 0, act: () => emptyTrash() });
            menu.popup(x, y, items);
            return;
        }
        tailnet.running = true;
        if (one) {
            items.push({ label: "Abrir", hint: "ENTER", act: () => open(current) });
            if (!one.isDir) {
                loadApps(one.path);
                items.push({ label: "Abrir con", sub: () => appEntries(one) });
            }
            items.push({ label: "Vista rápida", hint: "ESPACIO", armed: !one.isDir, act: () => look.open() });
            items.push({ sep: true });
        }
        if (n > 0) {
            items.push({ label: "Copiar" + many, hint: "CTRL+C", act: () => hold(false) });
            items.push({ label: "Cortar" + many, hint: "CTRL+X", act: () => hold(true) });
        }
        items.push({ label: "Pegar aquí", hint: "CTRL+V", act: () => paste() });
        if (one)
            items.push({ label: "Renombrar", hint: "F2", act: () => rename() });
        items.push({ label: "Nueva carpeta", hint: "CTRL+SHIFT+N", act: () => newFolder() });
        items.push({ sep: true });
        if (n > 0)
            items.push({ label: "Enviar por Tailscale" + many, armed: sendable, sub: sendable ? () => sendEntries() : null });
        if (n > 0)
            items.push({ label: "Enviar por LocalSend" + many, armed: sendable, act: () => localSend() });
        if (one)
            items.push({ label: "Copiar ruta", act: () => copyPath(one.path) });
        items.push({ label: "Terminal aquí", act: () => terminal(one && one.isDir ? one.path : path) });
        items.push({ label: "Seleccionar todo", hint: "CTRL+A", act: () => markAll() });
        if (n > 0) {
            items.push({ sep: true });
            items.push({ label: "A la papelera" + many, hint: "SUPR", act: () => trash() });
        }
        menu.popup(x, y, items);
    }
    function sendEntries() {
        if (targets.length === 0)
            return [{ label: "Sin dispositivos", armed: false }];
        return targets.map(t => ({
            label: t.name,
            hint: t.online ? "EN LÍNEA" : "FUERA",
            armed: t.online,
            act: () => sendTo(t)
        }));
    }
    function appEntries(e) {
        if (appsFor !== e.path || apps.length === 0)
            return [{ label: "Sin aplicaciones", armed: false }];
        return apps.map((a, i) => ({ label: a.name, hint: i === 0 ? "PREDET." : "", act: () => openWith(e, a) }));
    }

    // Everything the palette can run, built when it opens.
    function commands() {
        const list = picked();
        const n = list.length;
        const out = [];
        const add = (text, hint, act) => out.push({ label: text, hint: hint, act: act });
        if (inTrash) {
            if (n > 0)
                add("Restaurar " + label(list).toLowerCase(), "PAPELERA", () => restore());
            add("Vaciar papelera", "PAPELERA", () => emptyTrash());
        } else {
            if (n === 1) {
                add("Abrir " + list[0].name, "ENTER", () => open(current));
                add("Renombrar " + list[0].name, "F2", () => rename());
                if (!list[0].isDir)
                    add("Vista rápida", "ESPACIO", () => look.open());
            }
            if (n > 0) {
                add("Copiar " + label(list).toLowerCase(), "CTRL+C", () => hold(false));
                add("Cortar " + label(list).toLowerCase(), "CTRL+X", () => hold(true));
                add("Mandar a la papelera " + label(list).toLowerCase(), "SUPR", () => trash());
                if (list.some(e => !e.isDir)) {
                    for (const t of targets) {
                        if (t.online)
                            add("Enviar a " + t.name, "TAILSCALE", () => sendTo(t));
                    }
                    add("Enviar por LocalSend", "LOCALSEND", () => localSend());
                }
            }
            add("Pegar aquí", "CTRL+V", () => paste());
            add("Nueva carpeta", "CTRL+SHIFT+N", () => newFolder());
            add("Seleccionar todo", "CTRL+A", () => markAll());
        }
        add(grid ? "Ver como lista" : "Ver como cuadrícula", "CTRL+G", () => toggleGrid());
        add(showHidden ? "Esconder los ocultos" : "Mostrar los ocultos", "CTRL+H", () => showHidden = !showHidden);
        add("Filtrar esta carpeta", "CTRL+F", () => rail.filter.grabFocus());
        add("Terminal aquí", "ACCIÓN", () => terminal(path));
        add("Copiar la ruta de esta carpeta", "ACCIÓN", () => copyPath(path));
        add("Subir una carpeta", "ALT+↑", () => goUp());
        add("Atrás", "ALT+←", () => goBack());
        add("Adelante", "ALT+→", () => goForward());
        add("Actualizar", "F5", () => refresh());
        add("Cambiar la marca", "ACCIÓN", () => toggleBrand());
        for (const p of places)
            add("Ir a " + p.name, "LUGAR", () => go(p.path));
        for (const d of devices)
            add((d.mounted ? "Ir a " : "Montar ") + d.name, "DISCO", () => (d.mounted ? go(d.path) : mount(d)));
        add("Salir", "CTRL+Q", () => quit());
        return out;
    }

    function openPalette() {
        tailnet.running = true;
        palette.open();
    }
    function quickLook() {
        look.open();
    }
    function loadPreview() {
        const e = entry(current);
        previewer.running = false;
        if (!e || e.isDir) {
            preview = { kind: "none" };
            return;
        }
        if (previewer.target !== e.path)
            preview = { kind: "none" };
        previewer.target = e.path;
        previewer.command = [binDir + "/archivos-preview", e.path, look.visible ? "60000" : "2500"];
        previewer.running = true;
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
        files.reveal(current);
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
        blocks.running = true;
    }

    onPathChanged: {
        current = -1;
        marked = {};
        anchor = -1;
        query = "";
        rail.filter.clear();
        pathField.text = shorten(path);
        refresh();
    }
    onQueryChanged: rebuild()
    onCurrentChanged: loadPreview()
    onRowsChanged: loadPreview()
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

    FileView {
        id: settingsFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (app.home + "/.config")) + "/archivos/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: settings
            property string brand: "own"
            property bool grid: false
            property string ownMark: "サ"
            property string ownName: "SFM FILES"
            property string ownTag: "SAFLORESMO // ARCHIVOS"
        }
    }
    Process {
        running: true
        command: ["mkdir", "-p", (Quickshell.env("XDG_CONFIG_HOME") || (app.home + "/.config")) + "/archivos"]
    }
    Timer {
        id: noticeClear
        interval: 7000
        onTriggered: app.notice = ""
    }
    Component {
        id: job

        Process {
            id: task
            property string okText: ""
            property string failText: ""
            property int code: -1

            function finish() {
                const why = errors.text.trim().split("\n")[0];
                if (code === 0)
                    app.say(okText);
                else if (/access denied/i.test(why) && command[0] === "tailscale")
                    app.say(failText + " · FALTA EL PERMISO: SUDO TAILSCALE SET --OPERATOR=$USER", true);
                else
                    app.say(failText + (why ? " · " + why.toUpperCase() : ""), true);
                app.refresh();
                destroy();
            }

            stderr: StdioCollector { id: errors }
            onExited: exitCode => {
                code = exitCode;
                Qt.callLater(finish);
            }
        }
    }
    Process {
        id: tailnet
        running: true
        command: ["tailscale", "file", "cp", "--targets"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length >= 2 && cols[1])
                        list.push({ name: cols[1], online: !(cols[2] || "").startsWith("offline") });
                }
                list.sort((a, b) => (a.online === b.online ? a.name.localeCompare(b.name) : (a.online ? -1 : 1)));
                app.targets = list;
            }
        }
    }
    Process {
        id: previewer
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const now = app.entry(app.current);
                if (!now || now.path !== previewer.target)
                    return;
                const cut = text.indexOf("\n");
                const first = cut < 0 ? text : text.slice(0, cut);
                if (first.indexOf("image ") === 0)
                    app.preview = { kind: "image", path: first.slice(6) };
                else if (first === "text")
                    app.preview = { kind: "text", text: text.slice(cut + 1) };
                else
                    app.preview = { kind: "none" };
            }
        }
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
        command: ["lsblk", "-J", "-b", "-o", "NAME,LABEL,MOUNTPOINTS,SIZE,FSUSE%,RM,HOTPLUG,TYPE,FSTYPE,PATH"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const skip = ["swap", "crypto_LUKS", "LVM2_member", "linux_raid_member"];
                const walk = nodes => {
                    for (const n of nodes || []) {
                        const points = (n.mountpoints || []).filter(m => m);
                        const at = points.find(m => m === "/" || m.indexOf("/run/media/") === 0 || m.indexOf("/mnt/") === 0 || m.indexOf("/media/") === 0);
                        const loose = n.rm === true || n.hotplug === true;
                        const name = n.label || Fmt.size(n.size) + " · " + n.name;
                        if (at) {
                            found.push({
                                name: at === "/" ? "Sistema" : name,
                                path: at,
                                dev: n.path,
                                used: parseInt(n["fsuse%"]) || 0,
                                removable: loose,
                                mounted: true
                            });
                        } else if (loose && points.length === 0 && n.fstype && skip.indexOf(n.fstype) < 0 && n.size >= 268435456) {
                            found.push({ name: name, path: "", dev: n.path, used: 0, removable: true, mounted: false });
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
    Process {
        id: appFinder
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length === 2)
                        list.push({ file: cols[0], name: cols[1] });
                }
                app.apps = list;
            }
        }
    }
    Process {
        id: pasteboard
        command: ["wl-paste", "--no-newline", "-t", "text/uri-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = [];
                for (const line of text.split("\n")) {
                    const uri = line.trim();
                    if (uri.indexOf("file://") === 0)
                        paths.push(decodeURIComponent(uri.slice(7)));
                }
                if (paths.length === 0)
                    app.say("NADA QUE PEGAR", true);
                else
                    app.op(["copy", app.path].concat(paths), "PEGADO · " + (paths.length === 1 ? paths[0].slice(paths[0].lastIndexOf("/") + 1).toUpperCase() : paths.length + " ELEMENTOS"));
            }
        }
    }
    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: blocks.running = true
    }

    Shortcut { sequence: "Ctrl+K"; onActivated: app.openPalette() }
    Shortcut { sequence: "Ctrl+F"; onActivated: rail.filter.grabFocus() }
    Shortcut { sequence: "Ctrl+G"; onActivated: app.toggleGrid() }
    Shortcut { sequence: "Ctrl+L"; onActivated: pathField.grabFocus() }
    Shortcut { sequence: "Ctrl+H"; onActivated: app.showHidden = !app.showHidden }
    Shortcut { sequence: "Alt+Left"; onActivated: app.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: app.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: app.goUp() }
    Shortcut { sequence: "F5"; onActivated: app.refresh() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: app.quit() }
    Shortcut {
        sequence: "Escape"
        enabled: menu.visible || dialog.visible || look.visible || palette.visible
        onActivated: {
            menu.close();
            dialog.close();
            palette.close();
            look.close();
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const page = files.pageStep;
            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
            let handled = true;
            if (event.key === Qt.Key_Down)
                app.select(app.current < 0 ? 0 : app.current + files.columns);
            else if (event.key === Qt.Key_Up)
                app.select(app.current < 0 ? app.rows.length - 1 : app.current - files.columns);
            else if (event.key === Qt.Key_Right && app.grid)
                app.select(app.current + 1);
            else if (event.key === Qt.Key_Left && app.grid)
                app.select(app.current - 1);
            else if (event.key === Qt.Key_Home)
                app.select(0);
            else if (event.key === Qt.Key_End)
                app.select(app.rows.length - 1);
            else if (event.key === Qt.Key_PageDown)
                app.select(app.current + page);
            else if (event.key === Qt.Key_PageUp)
                app.select(app.current - page);
            else if (event.key === Qt.Key_A && ctrl)
                app.markAll();
            else if (event.key === Qt.Key_Slash)
                rail.filter.grabFocus();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                app.open(app.current);
            else if (event.key === Qt.Key_Backspace)
                app.goUp();
            else if (event.key === Qt.Key_Space)
                look.open();
            else if (event.key === Qt.Key_Delete)
                app.trash();
            else if (event.key === Qt.Key_F2)
                app.rename();
            else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier))
                app.hold(false);
            else if (event.key === Qt.Key_X && (event.modifiers & Qt.ControlModifier))
                app.hold(true);
            else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier))
                app.paste();
            else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier))
                app.newFolder();
            else if (event.key === Qt.Key_Escape) {
                app.marked = {};
                app.current = -1;
            }
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
                    text: "— " + app.brand.mark
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

                Btn { text: "COMANDOS"; onAct: app.openPalette() }
                Btn { text: app.grid ? "LISTA" : "CUADRÍCULA"; onAct: app.toggleGrid() }
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
            text: app.notice !== "" ? app.notice : (app.clip ? "PORTAPAPELES · " + app.clip.text + "   " : "") + app.space
            color: app.notice !== "" && app.noticeBad ? Tokens.alert : (app.notice !== "" ? Tokens.ink : Tokens.inkMuted)
            width: parent.width * 0.6
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: Tokens.trackMark
        }
    }

    QuickLook {
        id: look
        app: app
        onVisibleChanged: app.loadPreview()
        onClosed: app.focusList()
    }
    CommandPalette {
        id: palette
        app: app
        onClosed: app.focusList()
    }
    ContextMenu {
        id: menu
        onClosed: app.focusList()
    }
    NameDialog {
        id: dialog
        onClosed: app.focusList()
    }
}
