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
    readonly property string user: Quickshell.env("USER") || ""
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
    property bool dragging: false
    property string dragData: ""
    property bool deep: false
    property var undo: null
    property var redo: null
    property bool undoing: false
    property bool recent: false
    property var transfer: null
    property var activeJob: null
    property var bookmarks: []
    property var info: ({})
    property var trashList: []
    property string infoPath: ""
    property var tabs: [{ path: home, back: [], forward: [] }]
    property int tab: 0
    property var remotes: ({})
    property var thumbs: ({})
    property real zoom: 1.0
    property string otherPath: home
    readonly property bool dual: settings.dual
    readonly property var servers: settings.servers
    property string deepQuery: ""
    property var found: []
    property string appsFor: ""
    property string appsType: ""
    property var targets: []
    property var preview: ({ kind: "none" })
    property string notice: ""
    property bool noticeBad: false

    readonly property string engine: decodeURIComponent(Qt.resolvedUrl("motor/target/release/archivos-motor").toString().replace("file://", ""))
    readonly property var brand: settings.brand === "ryoku"
        ? { mark: "力", name: "RYOKU FILES", tag: "RYOKU // FILES", title: "Ryoku Files" }
        : { mark: settings.ownMark, name: settings.ownName, tag: settings.ownTag, title: settings.ownName + " " + settings.ownMark }

    readonly property int total: rows.length
    readonly property int markedCount: Object.keys(marked).length
    readonly property string trashDir: home + "/.local/share/Trash/files"
    readonly property bool inTrash: path === trashDir
    // list, compact, grid or gallery; a folder keeps its own once it is changed.
    readonly property string mode: {
        const view = settings.views[path];
        if (view && view.mode)
            return view.mode;
        if (view && view.grid !== undefined)
            return view.grid ? "grid" : "list";
        return settings.grid ? "grid" : "list";
    }
    readonly property bool grid: mode === "grid" || mode === "gallery"
    readonly property bool gallery: mode === "gallery"
    readonly property bool compact: mode === "compact"
    readonly property bool ready: dir.status === FolderListModel.Ready
    readonly property var selected: entry(current)
    readonly property string title: recent ? "Recientes" : nameOf(path)

    function nameOf(p) {
        for (const place of places) {
            if (place.path === p)
                return place.name;
        }
        for (const server of servers) {
            if (remotes[server.uri] === p)
                return server.name;
        }
        return p === "/" ? "Raíz" : p.slice(p.lastIndexOf("/") + 1);
    }

    // Tabs keep a path and its history; the rest of the view follows the open one.
    function keepTab() {
        const list = tabs.slice();
        list[tab] = { path: path, back: back, forward: forward };
        tabs = list;
    }
    function showTab(i) {
        if (i < 0 || i >= tabs.length || i === tab)
            return;
        keepTab();
        tab = i;
        back = tabs[i].back;
        forward = tabs[i].forward;
        path = tabs[i].path;
    }
    function newTab(p) {
        keepTab();
        tabs = tabs.concat([{ path: clean(p || path), back: [], forward: [] }]);
        showTab(tabs.length - 1);
    }
    function closeTab(i) {
        if (tabs.length === 1)
            return;
        keepTab();
        const list = tabs.slice();
        list.splice(i, 1);
        const next = Math.min(i < tab ? tab - 1 : tab, list.length - 1);
        tabs = list;
        tab = next;
        back = list[next].back;
        forward = list[next].forward;
        path = list[next].path;
    }

    // Network places: saved in the settings, mounted through GVFS.
    function saveServers(list) {
        settings.servers = list;
        settingsFile.writeAdapter();
        refresh();
    }
    function addServer() {
        dialog.ask("SERVIDOR · DIRECCIÓN", "sftp://usuario@equipo/", uri => {
            Qt.callLater(() => dialog.ask("SERVIDOR · NOMBRE", uri.replace(/^[a-z]+:\/\/([^@\/]*@)?/, "").replace(/\/.*$/, ""),
                name => saveServers(servers.concat([{ name: name, uri: uri }]))));
        });
    }
    function removeServer(server) {
        saveServers(servers.filter(x => x.uri !== server.uri));
    }
    function connectServer(server, secret) {
        const mounted = remotes[server.uri];
        if (mounted) {
            go(mounted);
            return;
        }
        say("CONECTANDO A " + server.name.toUpperCase() + "…");
        const command = secret === undefined ? ["gio", "mount", server.uri]
            : ["sh", "-c", "printf '%s\\n' \"$1\" | gio mount \"$2\"", "sh", secret, server.uri];
        job.createObject(app, {
            command: command,
            okText: "CONECTADO · " + server.name.toUpperCase(),
            failText: "NO SE CONECTÓ A " + server.name.toUpperCase(),
            server: server,
            askedSecret: secret !== undefined
        }).running = true;
    }
    function disconnectServer(server) {
        const mounted = remotes[server.uri];
        if (mounted && (path === mounted || path.indexOf(mounted + "/") === 0))
            go(home);
        run(["gio", "mount", "-u", server.uri], "DESCONECTADO · " + server.name.toUpperCase());
    }
    function serverMenu(server, x, y) {
        const mounted = remotes[server.uri] !== undefined && remotes[server.uri] !== "";
        menu.popup(x, y, [
            { label: mounted ? "Abrir" : "Conectar", act: () => connectServer(server) },
            { label: "Desconectar", armed: mounted, act: () => disconnectServer(server) },
            { sep: true },
            { label: "Quitar de la lista", act: () => removeServer(server) }
        ]);
    }
    // Two panes: the second one is where things get copied or moved to.
    function toggleDual() {
        if (!settings.dual)
            otherPath = path;
        settings.dual = !settings.dual;
        settingsFile.writeAdapter();
    }
    function swapPanes() {
        if (!dual)
            return;
        const mine = path;
        const theirs = otherPath;
        if (mine === theirs)
            return;
        otherPath = mine;
        go(theirs);
    }
    function otherUp() {
        if (otherPath === "/")
            return;
        const i = otherPath.lastIndexOf("/");
        otherPath = i <= 0 ? "/" : otherPath.slice(0, i);
    }
    function sendToOther(moving) {
        const list = picked();
        if (!dual || list.length === 0 || inTrash)
            return;
        if (otherPath === path) {
            say("LOS DOS PANELES MUESTRAN LA MISMA CARPETA", true);
            return;
        }
        marked = {};
        transferTo(moving ? "move" : "copy", otherPath, list.map(e => e.path),
            (moving ? "MOVIDO AL OTRO PANEL · " : "COPIADO AL OTRO PANEL · ") + label(list));
    }
    function setZoom(value) {
        zoom = Math.max(0.6, Math.min(2.4, Math.round(value * 10) / 10));
    }
    function erase() {
        const list = picked();
        if (list.length === 0)
            return;
        dialog.confirm("ELIMINAR PARA SIEMPRE", "Se eliminará " + label(list).toLowerCase() + " sin pasar por la papelera. No se puede deshacer.",
            () => {
                marked = {};
                op(["delete"].concat(list.map(e => e.path)), "ELIMINADO · " + label(list), null);
            }, "SÍ, ELIMINAR");
    }

    signal quit()

    function clean(p) {
        p = String(p).trim();
        if (p === "~" || p.indexOf("~/") === 0)
            p = home + p.slice(1);
        for (const server of servers) {
            const mounted = remotes[server.uri];
            if (mounted && p.indexOf(server.name + ":") === 0)
                p = mounted + "/" + p.slice(server.name.length + 1);
        }
        p = p.replace(/\/+/g, "/");
        if (p.length > 1 && p.charAt(p.length - 1) === "/")
            p = p.slice(0, -1);
        return p || "/";
    }
    function shorten(p) {
        for (const server of servers) {
            const mounted = remotes[server.uri];
            if (mounted && (p === mounted || p.indexOf(mounted + "/") === 0))
                return server.name + ":" + (p.slice(mounted.length) || "/");
        }
        return p === home || p.indexOf(home + "/") === 0 ? "~" + p.slice(home.length) : p;
    }
    function url(p) {
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    function go(p) {
        p = clean(p);
        if (p === path) {
            endSearch();
            return;
        }
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
            Spawn.run(["gio", "open", e.path]);
    }
    function terminal(p) {
        Spawn.run(settings.terminal.trim().split(/\s+/).concat([p]));
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
    function run(command, okText, failText, undoArgs) {
        job.createObject(app, {
            command: command,
            okText: okText,
            failText: failText || "NO SE PUDO",
            undoArgs: undoArgs === undefined ? null : undoArgs
        }).running = true;
    }
    // An engine operation. `undoArgs` is how to take it back: "auto" builds it
    // from what the engine reports, a list is used as given, null means none.
    function op(args, okText, undoArgs) {
        run([engine].concat(args), okText, "", undoArgs === undefined ? "auto" : undoArgs);
    }
    function undoLast() {
        if (!undo) {
            say("NADA QUE DESHACER", true);
            return;
        }
        const last = undo;
        undo = null;
        undoing = true;
        redo = last.again ? { args: last.again, text: last.text } : null;
        op(last.args, "DESHECHO · " + last.text, null);
    }
    function redoLast() {
        if (!redo) {
            say("NADA QUE REHACER", true);
            return;
        }
        const again = redo;
        redo = null;
        op(again.args, again.text, again.args[0] === "trash" ? ["untrash"].concat(again.args.slice(1)) : "auto");
    }
    function cancelTransfer() {
        if (activeJob)
            activeJob.signal(15);
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
    // A folder remembers how it was last looked at.
    function rememberView(next) {
        const asMode = next || mode;
        const asGrid = asMode === "grid" || asMode === "gallery";
        const views = Object.assign({}, settings.views);
        delete views[path];
        const keys = Object.keys(views);
        for (let i = 0; i < keys.length - 299; i++)
            delete views[keys[i]];
        views[path] = { mode: asMode, grid: asGrid, sortKey: sortKey, sortReversed: sortReversed };
        settings.views = views;
        settingsFile.writeAdapter();
    }
    function toggleGrid() {
        rememberView(grid ? "list" : "grid");
    }
    function setMode(next) {
        rememberView(next);
    }
    function setPref(key, value) {
        settings[key] = value;
        settingsFile.writeAdapter();
    }
    function showRecent() {
        deepQuery = "recientes";
        found = [];
        recent = true;
        deep = true;
        rail.filter.clear();
        query = "";
        recents.running = true;
        focusList();
    }

    // A drag carries the marked rows when it starts on one of them, else its own row.
    function beginDrag(i) {
        const e = entry(i);
        if (!e)
            return;
        if (marked[e.path] !== true) {
            marked = {};
            current = i;
            anchor = i;
        }
        dragData = picked().map(x => url(x.path)).join("\r\n");
        dragging = true;
    }
    function dropOn(dest, urls) {
        const inside = dragging;
        const paths = [];
        for (const u of urls) {
            const p = decodeURIComponent(String(u).replace(/^file:\/\//, ""));
            if (p.charAt(0) !== "/" || p === dest)
                continue;
            if (inside && p.slice(0, p.lastIndexOf("/")) === dest)
                continue;
            paths.push(p);
        }
        if (paths.length === 0 || inTrash)
            return;
        const what = paths.length === 1 ? paths[0].slice(paths[0].lastIndexOf("/") + 1).toUpperCase() : paths.length + " ELEMENTOS";
        const where = dest.slice(dest.lastIndexOf("/") + 1).toUpperCase() || "/";
        marked = {};
        if (dest === trashDir)
            op(["trash"].concat(paths), "A LA PAPELERA · " + what, ["untrash"].concat(paths));
        else
            transferTo(inside ? "drop" : "copy", dest, paths, (inside ? "SOLTADO EN " : "COPIADO A ") + where + " · " + what);
    }
    function search(text) {
        const q = String(text).trim();
        if (q === "")
            return;
        deepQuery = q;
        found = [];
        deep = true;
        rail.filter.clear();
        query = "";
        finder.running = false;
        finder.command = showHidden ? [engine, "search", path, q, "hidden"] : [engine, "search", path, q];
        finder.running = true;
        focusList();
    }
    function endSearch() {
        if (!deep)
            return;
        recent = false;
        deep = false;
        found = [];
        rebuild();
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
        transferTo(clip.cut ? "move" : "copy", path, clip.paths, (clip.cut ? "MOVIDO · " : "PEGADO · ") + clip.text);
        if (clip.cut)
            clip = null;
    }
    function trash() {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        marked = {};
        op(["trash"].concat(list.map(e => e.path)), "A LA PAPELERA · " + label(list), ["untrash"].concat(list.map(e => e.path)));
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
    function newFile() {
        if (inTrash)
            return;
        dialog.ask("NUEVO ARCHIVO", "Sin título.txt", value => op(["touch", path, value], "ARCHIVO CREADO · " + value.toUpperCase()));
    }
    function compress(format) {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        say("COMPRIMIENDO…");
        op(["compress", format].concat(list.map(e => e.path)), "COMPRIMIDO · " + label(list));
    }
    function extract() {
        const list = picked().filter(e => !e.isDir && Fmt.icon(e.name, false) === "archive");
        if (list.length !== 1)
            return;
        say("EXTRAYENDO…");
        op(["extract", list[0].path], "EXTRAÍDO · " + list[0].name.toUpperCase());
    }
    function invertMarks() {
        const next = {};
        const base = markedCount > 0 ? marked : (selected ? ({ [selected.path]: true }) : ({}));
        for (const e of rows) {
            if (base[e.path] !== true)
                next[e.path] = true;
        }
        marked = next;
    }
    function isBookmarked(p) {
        return bookmarks.some(b => b.path === p);
    }
    function toggleBookmark(p) {
        const had = isBookmarked(p);
        run([engine, "bookmarks", had ? "remove" : "add", p], had ? "MARCADOR QUITADO" : "MARCADOR AÑADIDO");
    }
    function bookmarkMenu(b, x, y) {
        menu.popup(x, y, [
            { label: "Abrir", act: () => go(b.path) },
            { label: "Quitar marcador", act: () => toggleBookmark(b.path) }
        ]);
    }
    function properties() {
        const e = picked().length === 1 ? picked()[0] : null;
        info = {};
        infoPath = e ? e.path : path;
        teller.running = false;
        teller.command = [engine, "info", infoPath];
        teller.running = true;
        sheet.open();
    }
    function chmod(mode) {
        if (infoPath === "")
            return;
        run([engine, "chmod", mode, infoPath], "PERMISOS · " + mode);
        infoAgain.restart();
    }
    function folderOf(p) {
        const shown = shorten(p);
        const cut = shown.lastIndexOf("/");
        return cut > 0 ? shown.slice(0, cut) : "/";
    }
    function restore() {
        const list = picked();
        if (list.length === 0 || !inTrash)
            return;
        marked = {};
        op(["restore"].concat(list.map(e => e.path)), "RESTAURADO · " + label(list), null);
    }
    function emptyTrash() {
        dialog.confirm("VACIAR PAPELERA", "Se eliminará todo lo que hay en la papelera. No se puede deshacer.",
            () => run(["gio", "trash", "--empty"], "PAPELERA VACÍA"), "SÍ, VACIAR");
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
    // Make one application the default for this kind of file.
    function chooseDefault(e) {
        if (appsFor !== e.path || apps.length === 0 || appsType === "")
            return;
        const kind = appsType;
        palette.choose("ABRIR SIEMPRE " + Fmt.kind(e.name, false).toUpperCase() + " CON", apps.map(a => ({
            label: a.name,
            hint: "",
            act: () => run(["gio", "mime", kind, a.file.slice(a.file.lastIndexOf("/") + 1)], "PREDETERMINADA · " + a.name.toUpperCase())
        })));
    }
    // Copy or move into a folder, asking first when names are already taken there.
    function transferTo(mode, dest, paths, okText) {
        if (paths.length === 0)
            return;
        clash.pending = { mode: mode, dest: dest, paths: paths, okText: okText };
        clash.running = false;
        clash.command = [engine, "conflicts", dest].concat(paths);
        clash.running = true;
    }
    function loadApps(filePath) {
        if (appsFor === filePath)
            return;
        apps = [];
        appsFor = filePath;
        appFinder.running = false;
        appFinder.command = [engine, "apps", filePath];
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
            items.push({ label: "Vaciar papelera", armed: trashList.length > 0, act: () => emptyTrash() });
            menu.popup(x, y, items);
            return;
        }
        tailnet.running = true;
        if (one) {
            items.push({ label: "Abrir", hint: "ENTER", act: () => open(current) });
            if (one.isDir)
                items.push({ label: "Abrir en pestaña nueva", hint: "CTRL+ENTER", act: () => newTab(one.path) });
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
        items.push({ label: "Nuevo archivo", hint: "CTRL+N", act: () => newFile() });
        if (undo)
            items.push({ label: "Deshacer", hint: "CTRL+Z", act: () => undoLast() });
        items.push({ sep: true });
        if (n > 0) {
            items.push({
                label: "Comprimir" + many,
                sub: [
                    { label: "En .zip", act: () => compress("zip") },
                    { label: "En .tar.gz", act: () => compress("tar.gz") },
                    { label: "En .tar.xz", act: () => compress("tar.xz") },
                    { label: "En .7z", act: () => compress("7z") }
                ]
            });
        }
        if (one && !one.isDir && Fmt.icon(one.name, false) === "archive")
            items.push({ label: "Extraer aquí", act: () => extract() });
        if (one && one.isDir)
            items.push({ label: isBookmarked(one.path) ? "Quitar marcador" : "Añadir a marcadores", hint: "CTRL+D", act: () => toggleBookmark(one.path) });
        if (n > 0)
            items.push({ label: "Enviar por Tailscale" + many, armed: sendable, sub: sendable ? () => sendEntries() : null });
        if (n > 0)
            items.push({ label: "Enviar por LocalSend" + many, armed: sendable, act: () => localSend() });
        if (one)
            items.push({ label: "Copiar ruta", act: () => copyPath(one.path) });
        items.push({ label: "Terminal aquí", act: () => terminal(one && one.isDir ? one.path : path) });
        items.push({ label: "Seleccionar todo", hint: "CTRL+A", act: () => markAll() });
        items.push({ label: "Propiedades", hint: "CTRL+I", act: () => properties() });
        if (n > 0) {
            items.push({ sep: true });
            items.push({ label: "A la papelera" + many, hint: "SUPR", act: () => trash() });
            items.push({ label: "Eliminar para siempre" + many, hint: "MAYÚS+SUPR", act: () => erase() });
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
        return apps.map((a, i) => ({ label: a.name, hint: i === 0 ? "PREDET." : "", act: () => openWith(e, a) }))
            .concat([{ sep: true }, { label: "Abrir siempre con…", act: () => chooseDefault(e) }]);
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
            if (n > 0) {
                add("Comprimir en .zip", "ACCIÓN", () => compress("zip"));
                add("Comprimir en .tar.gz", "ACCIÓN", () => compress("tar.gz"));
                add("Comprimir en .7z", "ACCIÓN", () => compress("7z"));
            }
            if (n === 1 && !list[0].isDir && Fmt.icon(list[0].name, false) === "archive")
                add("Extraer aquí", "ACCIÓN", () => extract());
            add("Pegar aquí", "CTRL+V", () => paste());
            add("Nueva carpeta", "CTRL+SHIFT+N", () => newFolder());
            add("Nuevo archivo", "CTRL+N", () => newFile());
            add("Invertir la selección", "CTRL+SHIFT+I", () => invertMarks());
            if (undo)
                add("Deshacer: " + undo.text.toLowerCase(), "CTRL+Z", () => undoLast());
            add(isBookmarked(path) ? "Quitar esta carpeta de marcadores" : "Añadir esta carpeta a marcadores", "CTRL+D", () => toggleBookmark(path));
            add("Seleccionar todo", "CTRL+A", () => markAll());
        }
        add("Ver como lista", "CTRL+1", () => setMode("list"));
        add("Ver como cuadrícula", "CTRL+2", () => setMode("grid"));
        add("Ver como lista compacta", "CTRL+3", () => setMode("compact"));
        add("Ver como galería", "CTRL+4", () => setMode("gallery"));
        add(showHidden ? "Esconder los ocultos" : "Mostrar los ocultos", "CTRL+H", () => showHidden = !showHidden);
        add("Filtrar esta carpeta", "CTRL+F", () => rail.filter.grabFocus());
        if (deep)
            add("Cerrar la búsqueda", "ESC", () => endSearch());
        add("Terminal aquí", "ACCIÓN", () => terminal(path));
        add("Copiar la ruta de esta carpeta", "ACCIÓN", () => copyPath(path));
        add("Subir una carpeta", "ALT+↑", () => goUp());
        add("Atrás", "ALT+←", () => goBack());
        add("Adelante", "ALT+→", () => goForward());
        add("Actualizar", "F5", () => refresh());
        add(dual ? "Cerrar el segundo panel" : "Abrir un segundo panel", "F6", () => toggleDual());
        if (dual) {
            add("Cambiar de panel", "TAB", () => swapPanes());
            if (n > 0) {
                add("Copiar al otro panel", "CTRL+SHIFT+C", () => sendToOther(false));
                add("Mover al otro panel", "CTRL+SHIFT+M", () => sendToOther(true));
            }
        }
        add("Pestaña nueva", "CTRL+T", () => newTab());
        if (tabs.length > 1)
            add("Cerrar la pestaña", "CTRL+W", () => closeTab(tab));
        add("Añadir un servidor", "RED", () => addServer());
        for (const server of servers)
            add((remotes[server.uri] ? "Ir a " : "Conectar a ") + server.name, "RED", () => connectServer(server));
        add("Ordenar por tipo", "ACCIÓN", () => sortBy(3));
        if (redo)
            add("Rehacer: " + redo.text.toLowerCase(), "CTRL+SHIFT+Z", () => redoLast());
        add("Ver lo abierto recientemente", "LUGAR", () => showRecent());
        add("Ajustes", "CTRL+,", () => prefs.open());
        add("Propiedades", "CTRL+I", () => properties());
        add("Ver los atajos de teclado", "F1", () => keysSheet.open());
        add("Cambiar la marca", "ACCIÓN", () => toggleBrand());
        for (const b of bookmarks)
            add("Ir a " + b.name, "MARCADOR", () => go(b.path));
        for (const p of places)
            add("Ir a " + p.name, "LUGAR", () => go(p.path));
        for (const d of devices)
            add((d.mounted ? "Ir a " : "Montar ") + d.name, "DISCO", () => (d.mounted ? go(d.path) : mount(d)));
        add("Salir", "CTRL+Q", () => quit());
        return out;
    }

    function openPrefs() {
        prefs.open();
    }
    function openKeys() {
        keysSheet.open();
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
        previewer.command = [engine, "preview", e.path, look.visible ? "60000" : "2500"];
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
        if (!deep)
            rememberView();
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
        if (!countsReady || deep)
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
        const source = [];
        if (deep) {
            for (const e of found)
                source.push(e);
        } else if (inTrash) {
            // The trash view gathers every disk's trash, not just this folder.
            for (const e of trashList)
                source.push(e);
        } else {
            for (let i = 0; i < dir.count; i++) {
                source.push({
                    name: dir.get(i, "fileName"),
                    path: dir.get(i, "filePath"),
                    size: dir.get(i, "fileSize"),
                    modified: dir.get(i, "fileModified"),
                    isDir: dir.isFolder(i)
                });
            }
        }
        for (const e of source) {
            if (e.isDir)
                dirs++;
            else
                regular++;
            if (matches(e.name))
                list.push(e);
        }
        const flip = sortReversed ? -1 : 1;
        // Recent items arrive newest first; keep that until a column is chosen.
        const asGiven = recent && sortKey === 0 && !sortReversed;
        list.sort((a, b) => {
            if (asGiven)
                return 0;
            if (a.isDir !== b.isDir)
                return a.isDir ? -1 : 1;
            let d = 0;
            if (sortKey === 1 && !a.isDir)
                d = a.size - b.size;
            else if (sortKey === 2)
                d = b.modified - a.modified;
            else if (sortKey === 3)
                d = Fmt.kind(a.name, a.isDir).localeCompare(Fmt.kind(b.name, b.isDir));
            return flip * (d || (a.shown || a.name).localeCompare(b.shown || b.name));
        });
        dirTotal = dirs;
        fileTotal = regular;
        rows = list;
        current = keep === "" ? -1 : list.findIndex(e => e.path === keep);
    }
    function refresh() {
        countsReady = false;
        counter.running = false;
        counter.command = [engine, "counts", path];
        counter.running = true;
        disk.running = false;
        disk.command = ["df", "-B1", "--output=fstype,avail", path];
        disk.running = true;
        blocks.running = true;
        marks.running = true;
        if (servers.length > 0) {
            mounts.running = false;
            mounts.command = [engine, "remote"].concat(servers.map(x => x.uri));
            mounts.running = true;
        }
        if (inTrash)
            trashLister.running = false;
            trashLister.running = true;
        if (grid) {
            painter.running = false;
            painter.command = [engine, "thumbs", path];
            painter.running = true;
        }
    }
    onGridChanged: refresh()

    onPathChanged: {
        const view = settings.views[path];
        sortKey = view ? view.sortKey || 0 : 0;
        sortReversed = view ? view.sortReversed === true : false;
        recent = false;
        deep = false;
        found = [];
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
        showHidden = settings.hidden;
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
            property var servers: []
            property bool dual: false
            property bool hidden: false
            property string terminal: "kitty --directory"
            property var views: ({})
            property string ownMark: "庫"
            property string ownName: "SFM"
            property string ownTag: "KURA // FILES"
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
            property var undoArgs: null
            property var server: null
            property bool askedSecret: false
            property int code: -1
            property var results: []

            function finish() {
                const why = errors.text.trim().split("\n")[0];
                if (app.activeJob === task) {
                    app.activeJob = null;
                    app.transfer = null;
                }
                const again = command[0] === app.engine ? command.slice(1) : null;
                if (undoArgs === "auto")
                    app.undo = results.length > 0 ? { text: okText, args: ["revert"].concat(results), again: again } : app.undo;
                else if (undoArgs !== null && code === 0)
                    app.undo = { text: okText, args: undoArgs, again: again };
                if (app.undoing)
                    app.undoing = false;
                else if (undoArgs !== null)
                    app.redo = null;
                if (server && code !== 0 && !askedSecret) {
                    // Keys did not get us in: ask for the password and try once more.
                    const target = server;
                    dialog.ask("CONTRASEÑA · " + target.name.toUpperCase(), "", secret => app.connectServer(target, secret));
                } else if (code === 0)
                    app.say(okText);
                else if (/access denied/i.test(why) && command[0] === "tailscale")
                    app.say(failText + " · FALTA EL PERMISO: SUDO TAILSCALE SET --OPERATOR=$USER", true);
                else
                    app.say(failText + (why ? " · " + why.toUpperCase() : ""), true);
                app.refresh();
                destroy();
            }

            stdout: SplitParser {
                onRead: line => {
                    const cols = line.split("\t");
                    if (cols[0] === "progress" && cols.length >= 4) {
                        app.activeJob = task;
                        app.transfer = { done: Number(cols[1]), total: Number(cols[2]), name: cols.slice(3).join("\t") };
                    } else if (cols[0] === "done" && cols.length === 4) {
                        task.results = task.results.concat([cols[1], cols[2], cols[3]]);
                    }
                }
            }
            stderr: StdioCollector { id: errors }
            onExited: exitCode => {
                code = exitCode;
                Qt.callLater(finish);
            }
        }
    }
    Process {
        id: clash
        property var pending: null
        stdout: StdioCollector {
            onStreamFinished: {
                const job = clash.pending;
                clash.pending = null;
                if (!job)
                    return;
                const names = text.split("\n").filter(line => line !== "");
                const go = policy => app.op([job.mode].concat(policy ? [policy] : []).concat([job.dest]).concat(job.paths), job.okText);
                if (names.length === 0) {
                    go("");
                    return;
                }
                dialog.choose("YA EXISTE",
                    (names.length === 1 ? "«" + names[0] + "» ya está" : names.length + " elementos ya están") + " en el destino. Reemplazar manda lo que había a la papelera.",
                    [
                        { text: "OMITIR", act: () => (names.length === job.paths.length ? app.say("OMITIDO · NO SE COPIÓ NADA") : go("--skip")) },
                        { text: "REEMPLAZAR", act: () => go("--replace") },
                        { text: "CONSERVAR AMBOS", act: () => go("") }
                    ]);
            }
        }
    }
    Process {
        id: mounts
        property string wanted: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut > 0 && line.length > cut + 1)
                        map[line.slice(0, cut)] = line.slice(cut + 1);
                }
                const fresh = Object.keys(map).find(uri => !app.remotes[uri]);
                const first = Object.keys(app.remotes).length === 0 && !mounts.wanted;
                app.remotes = map;
                if (mounts.wanted && map[mounts.wanted]) {
                    app.go(map[mounts.wanted]);
                    mounts.wanted = "";
                } else if (fresh && !first && app.notice.indexOf("CONECTADO") === 0)
                    app.go(map[fresh]);
            }
        }
    }
    Process {
        id: painter
        stdout: SplitParser {
            onRead: line => {
                const cut = line.indexOf("\t");
                if (cut <= 0)
                    return;
                const next = Object.assign({}, app.thumbs);
                next[line.slice(0, cut)] = line.slice(cut + 1);
                app.thumbs = next;
            }
        }
    }
    Process {
        id: marks
        running: true
        command: [app.engine, "bookmarks", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut > 0)
                        list.push({ path: line.slice(0, cut), name: line.slice(cut + 1) });
                }
                app.bookmarks = list;
            }
        }
    }
    Timer {
        id: infoAgain
        interval: 350
        onTriggered: {
            teller.running = false;
            teller.running = true;
        }
    }
    Process {
        id: trashLister
        command: [app.engine, "trashed"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length !== 5)
                        continue;
                    list.push({
                        name: cols[4].slice(cols[4].lastIndexOf("/") + 1),
                        path: cols[4],
                        size: Number(cols[1]),
                        modified: new Date(cols[2]),
                        isDir: cols[0] === "d",
                        from: cols[3]
                    });
                }
                app.trashList = list;
                app.rebuild();
            }
        }
    }
    Process {
        id: teller
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut > 0)
                        map[line.slice(0, cut)] = line.slice(cut + 1);
                }
                app.info = map;
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
                    const cut = line.indexOf("\t");
                    if (cut > 0)
                        map[line.slice(cut + 1)] = Number(line.slice(0, cut));
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
                app.space = cols.length !== 2 ? ""
                    : cols[0].indexOf("fuse.gvfsd") === 0 ? "EN RED"
                    : cols[0].toUpperCase() + " · " + Fmt.size(cols[1]).toUpperCase() + " LIBRES";
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
                const list = [
                    { name: "Carpeta personal", path: app.home, icon: "home", seal: "自宅" },
                    { name: "Recientes", path: "", icon: "clock", seal: "最近", special: "recent" }
                ];
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
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length < 4)
                        continue;
                    const shown = cols.slice(3).join("\t");
                    const full = (app.path === "/" ? "" : app.path) + "/" + shown;
                    list.push({
                        name: full.slice(full.lastIndexOf("/") + 1),
                        shown: shown,
                        path: full,
                        size: Number(cols[1]),
                        modified: new Date(Number(cols[2]) * 1000),
                        isDir: cols[0] === "d"
                    });
                }
                app.found = list;
                app.rebuild();
            }
        }
    }
    Process {
        id: recents
        command: [app.engine, "recent"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!app.recent)
                    return;
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length < 4)
                        continue;
                    const full = cols.slice(3).join("\t");
                    list.push({
                        name: full.slice(full.lastIndexOf("/") + 1),
                        shown: app.shorten(full),
                        path: full,
                        size: Number(cols[1]),
                        modified: new Date(Number(cols[2]) * 1000),
                        isDir: cols[0] === "d"
                    });
                }
                app.found = list;
                app.rebuild();
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
                    if (cols.length === 2 && cols[0] === "type")
                        app.appsType = cols[1];
                    else if (cols.length === 2)
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
                    app.transferTo("copy", app.path, paths, "PEGADO · " + (paths.length === 1 ? paths[0].slice(paths[0].lastIndexOf("/") + 1).toUpperCase() : paths.length + " ELEMENTOS"));
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
    Shortcut { sequence: "Ctrl+1"; onActivated: app.setMode("list") }
    Shortcut { sequence: "Ctrl+2"; onActivated: app.setMode("grid") }
    Shortcut { sequence: "Ctrl+3"; onActivated: app.setMode("compact") }
    Shortcut { sequence: "Ctrl+4"; onActivated: app.setMode("gallery") }
    Shortcut { sequence: "Alt+Home"; onActivated: app.go(app.home) }
    Shortcut { sequence: "Ctrl+T"; onActivated: app.newTab() }
    Shortcut { sequence: "F6"; onActivated: app.toggleDual() }
    Shortcut { sequence: "Ctrl+,"; onActivated: prefs.open() }
    Shortcut { sequence: "Ctrl+W"; onActivated: app.closeTab(app.tab) }
    Shortcut { sequence: "Ctrl+PgDown"; onActivated: app.showTab((app.tab + 1) % app.tabs.length) }
    Shortcut { sequence: "Ctrl+PgUp"; onActivated: app.showTab((app.tab + app.tabs.length - 1) % app.tabs.length) }
    Shortcut { sequence: "Ctrl++"; onActivated: app.setZoom(app.zoom + 0.2) }
    Shortcut { sequence: "Ctrl+="; onActivated: app.setZoom(app.zoom + 0.2) }
    Shortcut { sequence: "Ctrl+-"; onActivated: app.setZoom(app.zoom - 0.2) }
    Shortcut { sequence: "Ctrl+0"; onActivated: app.setZoom(1) }
    Shortcut { sequence: "F1"; onActivated: keysSheet.open() }
    Shortcut { sequence: "Ctrl+L"; onActivated: pathField.grabFocus() }
    Shortcut { sequence: "Ctrl+H"; onActivated: app.showHidden = !app.showHidden }
    Shortcut { sequence: "Alt+Left"; onActivated: app.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: app.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: app.goUp() }
    Shortcut { sequence: "F5"; onActivated: app.refresh() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: app.quit() }
    Shortcut {
        sequence: "Escape"
        enabled: menu.visible || dialog.visible || look.visible || palette.visible || sheet.visible || keysSheet.visible || prefs.visible
        onActivated: {
            menu.close();
            dialog.close();
            palette.close();
            sheet.close();
            keysSheet.close();
            prefs.close();
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
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            if ((event.key === Qt.Key_Down || event.key === Qt.Key_Up) && shift && app.current >= 0) {
                const to = Math.max(0, Math.min(app.rows.length - 1, app.current + (event.key === Qt.Key_Down ? files.columns : -files.columns)));
                if (app.anchor < 0)
                    app.anchor = app.current;
                const next = {};
                for (let n = Math.min(app.anchor, to); n <= Math.max(app.anchor, to); n++)
                    next[app.rows[n].path] = true;
                app.marked = next;
                app.select(to);
            } else if (event.key === Qt.Key_Down)
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
            else if (event.key === Qt.Key_Tab && app.dual)
                app.swapPanes();
            else if (event.key === Qt.Key_C && ctrl && shift)
                app.sendToOther(false);
            else if (event.key === Qt.Key_M && ctrl && shift)
                app.sendToOther(true);
            else if (event.key === Qt.Key_A && ctrl)
                app.markAll();
            else if (event.key === Qt.Key_Z && ctrl && shift)
                app.redoLast();
            else if (event.key === Qt.Key_Z && ctrl)
                app.undoLast();
            else if (event.key === Qt.Key_I && ctrl && shift)
                app.invertMarks();
            else if (event.key === Qt.Key_I && ctrl)
                app.properties();
            else if (event.key === Qt.Key_D && ctrl)
                app.toggleBookmark(app.selected && app.selected.isDir ? app.selected.path : app.path);
            else if (event.key === Qt.Key_N && ctrl && !shift)
                app.newFile();
            else if (event.key === Qt.Key_Slash)
                rail.filter.grabFocus();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                app.open(app.current);
            else if (event.key === Qt.Key_Backspace)
                app.goUp();
            else if (event.key === Qt.Key_Space)
                look.open();
            else if (event.key === Qt.Key_Delete && shift)
                app.erase();
            else if (event.key === Qt.Key_Delete)
                app.trash();
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && ctrl && app.selected && app.selected.isDir)
                app.newTab(app.selected.path);
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && (event.modifiers & Qt.AltModifier))
                app.showTab(event.key - Qt.Key_1);
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
                if (app.markedCount === 0 && app.current < 0)
                    app.endSearch();
                app.marked = {};
                app.current = -1;
            }
            else if (!ctrl && !(event.modifiers & Qt.AltModifier) && event.text.length === 1 && /^[A-Za-z0-9À-ÿ._-]$/.test(event.text)) {
                // Typing starts filtering the folder.
                rail.filter.text = event.text;
                app.query = event.text;
                rail.filter.grabFocus();
            } else
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
            text: app.inTrash && !app.deep ? Fmt.plural(app.rows.length, "elemento", "elementos") + " en la papelera, de todos los discos."
                : app.recent ? "Lo último que abriste, esté donde esté."
                : app.deep ? Fmt.plural(app.rows.length, "resultado", "resultados") + " para «" + app.deepQuery + "» en esta carpeta y sus subcarpetas."
                : !app.ready ? "Leyendo…"
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

        Row {
            id: tabBar
            anchors { left: parent.left; right: detail.left; top: tools.bottom; topMargin: Tokens.s3; rightMargin: Tokens.s5 }
            visible: app.tabs.length > 1
            height: visible ? 30 : 0
            spacing: Tokens.s2
            clip: true

            Repeater {
                model: app.tabs

                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool on: app.tab === index

                    width: Math.min(220, chipRow.width + Tokens.s4)
                    height: 30
                    radius: Tokens.radius
                    color: on ? Tokens.bone : (chipHover.hovered ? Tokens.tint10 : "transparent")
                    border.width: Tokens.border
                    border.color: on ? Tokens.bone : Tokens.line

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Tokens.s2

                        Text {
                            visible: chip.on
                            text: "//"
                            color: Tokens.inkOnBoneDim
                            font.family: Tokens.mono
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: app.nameOf(chip.on ? app.path : chip.modelData.path).toUpperCase()
                            color: chip.on ? Tokens.inkOnBone : Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackLabel
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 150)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "×"
                            color: chip.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                            font.family: Tokens.ui
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            TapHandler { onTapped: app.closeTab(chip.index) }
                        }
                    }
                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: app.showTab(chip.index) }
                    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: app.closeTab(chip.index) }
                }
            }
            Btn { text: "+"; width: 34; height: 30; onAct: app.newTab() }
        }

        FileList {
            id: files
            app: app
            anchors { left: parent.left; right: detail.left; top: tabBar.bottom; bottom: parent.bottom }
            anchors.topMargin: tabBar.visible ? Tokens.s3 : Tokens.s4
            anchors.rightMargin: Tokens.s5
            anchors.bottomMargin: Tokens.s5
        }
        Detail {
            id: detail
            app: app
            anchors { right: parent.right; top: tools.bottom; topMargin: Tokens.s4 }
            width: app.dual ? Math.round((page.width - Tokens.s5) / 2) : 340
            visible: !app.dual
        }
        SidePane {
            app: app
            visible: app.dual
            anchors { right: parent.right; top: tabBar.bottom; bottom: parent.bottom }
            anchors.topMargin: tabBar.visible ? Tokens.s3 : Tokens.s4
            anchors.bottomMargin: Tokens.s5
            width: detail.width
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

    QuickLook {
        id: look
        app: app
        onVisibleChanged: app.loadPreview()
        onClosed: app.focusList()
    }
    Properties {
        id: sheet
        app: app
        onClosed: app.focusList()
    }
    Preferences {
        id: prefs
        app: app
        store: settings
        onClosed: app.focusList()
    }
    KeySheet {
        id: keysSheet
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
