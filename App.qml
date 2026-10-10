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
    property var flags: ({})
    property var changed: ({})
    property bool unreadable: false
    // A path to put the cursor on as soon as it shows up in the list.
    property string wanted: ""
    // Sorting by kind: the extensions found in the folder, one of them
    // optionally floated to the top or shown alone.
    property var typeCounts: []
    property string pinType: ""
    property bool onlyType: false
    readonly property bool showSorter: settings.sorter
    readonly property string iconStyle: settings.iconStyle
    property bool settled: false
    property var facts: []
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
    // What can be taken back, oldest first, and what was taken back and can be done again.
    property var undoStack: []
    property var redoStack: []
    readonly property var undo: undoStack.length > 0 ? undoStack[undoStack.length - 1] : null
    readonly property var redo: redoStack.length > 0 ? redoStack[redoStack.length - 1] : null
    property bool undoing: false
    property bool redoing: false
    property bool recent: false
    // The transfers under way: { id, label, name, done, total, paused }.
    property var transfers: []
    property var jobTasks: ({})
    property int jobCount: 0
    // All of them as one, for the strip at the bottom.
    readonly property var transfer: {
        if (transfers.length === 0)
            return null;
        let done = 0, total = 0;
        for (const t of transfers) {
            done += t.done;
            total += t.total;
        }
        return { done: done, total: total, name: transfers.length > 1 ? transfers.length + " TRABAJOS" : transfers[0].name };
    }
    property var bookmarks: []
    property var info: ({})
    property var trashList: []
    property string infoPath: ""
    property var tabs: [{ path: home, back: [], forward: [] }]
    property int tab: 0
    property var remotes: ({})
    // Archives being looked into: the cache folder of each, and the name to show for it.
    property var peeks: ({})
    property var thumbs: ({})
    property real zoom: 1.0
    // The layout sheds pieces as the window shrinks: the selection card first,
    // then the rail, then the roomy page header.
    property bool railForced: false
    readonly property bool showDetail: width >= 1180 && (current >= 0 || markedCount > 0)
    readonly property bool showRail: width >= 860 || railForced
    // full, compact or minimal: how much room the folder's name takes.
    readonly property string header: settings.header
    readonly property bool bare: header === "minimal"
    readonly property bool short: height < 620 || header !== "full"
    property string otherPath: home
    readonly property bool dual: settings.dual
    readonly property var servers: settings.servers
    property string deepQuery: ""
    property bool deepInside: false
    // Folders opened in place in the list: each one's path and what it holds.
    property var expanded: ({})
    readonly property bool canExpand: !grid && !deep && !inTrash && query === ""
    function isExpanded(p) {
        return expanded[p] !== undefined;
    }
    function unfold(e) {
        if (!e || !e.isDir || !canExpand || isExpanded(e.path))
            return;
        branch.createObject(app, { dirPath: e.path }).running = true;
    }
    function fold(e) {
        if (!e || !isExpanded(e.path))
            return;
        // What was open below it closes with it.
        const next = {};
        for (const p in expanded) {
            if (p !== e.path && p.indexOf(e.path + "/") !== 0)
                next[p] = expanded[p];
        }
        expanded = next;
        rebuild();
    }
    function toggleExpand(e) {
        if (e && isExpanded(e.path))
            fold(e);
        else
            unfold(e);
    }
    // The row of the folder that holds this one, when it is open in the list.
    function parentRow(e) {
        const parent = e.path.slice(0, e.path.lastIndexOf("/"));
        return rows.findIndex(r => r.path === parent);
    }
    // The results come from everywhere under the home folder, not from below this one.
    property bool deepWide: false
    property string digest: ""
    property var found: []
    property string appsFor: ""
    // Service menus: what other file managers call actions, read from their folders and ours.
    property int menuCount: 0
    property var actions: []
    property string actionsFor: ""
    property string appsType: ""
    property var targets: []
    property var preview: ({ kind: "none" })
    property string notice: ""
    property bool noticeBad: false

    readonly property string engine: decodeURIComponent(Qt.resolvedUrl("motor/target/release/archivos-motor").toString().replace("file://", ""))
    readonly property var brand: ({ mark: settings.ownMark, name: settings.ownName, tag: settings.ownTag, title: settings.ownTitle })

    readonly property int total: rows.length
    readonly property int folderTotal: dir.count
    readonly property string typedPath: head.pathField.text
    readonly property bool looking: look.visible
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
        serverForm.open();
    }
    // Keep a server from the form and go in; a password given there is used once and forgotten.
    function addServerEntry(server, secret) {
        saveServers(servers.filter(x => x.uri !== server.uri).concat([server]));
        connectServer(server, secret !== "" ? secret : undefined);
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
        mounter.createObject(app, { server: server, secret: secret === undefined ? "" : secret }).running = true;
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
        if (list.length === 0 || inTrash)
            return;
        dialog.confirm("ELIMINAR PARA SIEMPRE", "Se eliminará " + label(list).toLowerCase() + " sin pasar por la papelera. No se puede deshacer.",
            () => {
                marked = {};
                op(["delete"].concat(list.map(e => e.path)), "ELIMINADO · " + label(list), null);
            }, "SÍ, ELIMINAR");
    }

    signal quit()
    property alias dialog: dialog
    property alias serverForm: serverForm
    property alias jobsPanel: jobsPanel
    property alias pickBar: pickBar

    // Set when another program is waiting for a file: open, save or folder.
    readonly property string pick: Quickshell.env("ARCHIVOS_PICK") || ""
    readonly property bool pickMulti: Quickshell.env("ARCHIVOS_PICK_MULTI") === "1"
    readonly property string pickName: Quickshell.env("ARCHIVOS_PICK_NAME") || ""
    readonly property string pickTitle: Quickshell.env("ARCHIVOS_PICK_TITLE")
        || (pick === "save" ? "Guardar como" : pick === "folder" ? "Elegir carpeta" : pick === "open" ? "Abrir archivo" : "")
    // What would be handed over if the button were pressed now.
    readonly property var pickPaths: {
        if (pick === "folder") {
            const dirs = picked().filter(e => e.isDir);
            return dirs.length === 1 ? [dirs[0].path] : [path];
        }
        if (pick === "open") {
            const files = picked().filter(e => !e.isDir);
            return pickMulti ? files.map(e => e.path) : (files.length === 1 ? [files[0].path] : []);
        }
        return [];
    }
    readonly property bool pickReady: pick === "save" ? !inTrash : pickPaths.length > 0
    readonly property string pickSummary: pickPaths.length === 0 ? "Elige un archivo."
        : pickPaths.length === 1 ? shorten(pickPaths[0]) : Fmt.plural(pickPaths.length, "archivo", "archivos")
    function pickAnswer(paths) {
        answer.command = ["sh", "-c", 'out=$1; shift; printf "%s\\n" "$@" > "$out"', "sh", Quickshell.env("ARCHIVOS_PICK_OUT") || "/dev/null"].concat(paths);
        answer.running = true;
    }
    function pickDone() {
        if (pick !== "save") {
            if (pickPaths.length > 0)
                pickAnswer(pickPaths);
            return;
        }
        const name = pickBar.nameField.text.trim();
        if (name === "" || name.indexOf("/") >= 0 || inTrash) {
            say("ESCRIBE UN NOMBRE", true);
            return;
        }
        const target = (path === "/" ? "" : path) + "/" + name;
        if (rows.some(e => e.name === name))
            dialog.confirm("YA EXISTE", "«" + name + "» ya está en esta carpeta. ¿Reemplazarlo?", () => pickAnswer([target]), "REEMPLAZAR");
        else
            pickAnswer([target]);
    }

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
        for (const dir in peeks) {
            if (p === dir || p.indexOf(dir + "/") === 0)
                return peeks[dir] + ":" + (p.slice(dir.length) || "/");
        }
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
    // What was typed, as a real path, keeping a trailing slash.
    function expand(text) {
        const typed = String(text).trim();
        const tail = typed.length > 1 && typed.charAt(typed.length - 1) === "/" ? "/" : "";
        const real = clean(typed);
        return real === "/" ? real : real + tail;
    }
    function completePath(text) {
        completer.running = false;
        completer.command = [engine, "complete", expand(text)];
        completer.running = true;
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
        else if (pick === "open")
            pickAnswer([e.path]);
        else if (pick === "save")
            pickBar.nameField.text = e.name;
        else if (pick === "")
            Spawn.run(["gio", "open", e.path]);
    }
    function terminal(p) {
        Spawn.run(settings.terminal.trim().split(/\s+/).concat([p]));
    }
    function copyPath(p) {
        Spawn.run(["wl-copy", "--", p]);
        say("RUTA COPIADA");
    }

    function say(text, bad) {
        notice = text;
        noticeBad = bad === true;
        noticeClear.restart();
    }
    function run(command, okText, failText, undoArgs) {
        const task = job.createObject(app, {
            command: command,
            okText: okText,
            failText: failText || "NO SE PUDO",
            undoArgs: undoArgs === undefined ? null : undoArgs,
            tid: ++jobCount
        });
        jobTasks[task.tid] = task;
        task.running = true;
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
        undoStack = undoStack.slice(0, -1);
        undoing = true;
        if (last.again)
            redoStack = redoStack.concat([{ args: last.again, text: last.text }]);
        else
            redoStack = [];
        op(last.args, "DESHECHO · " + last.text, null);
    }
    function redoLast() {
        if (!redo) {
            say("NADA QUE REHACER", true);
            return;
        }
        const again = redo;
        redoStack = redoStack.slice(0, -1);
        redoing = true;
        op(again.args, again.text, again.args[0] === "trash" ? ["untrash"].concat(again.args.slice(1)) : "auto");
    }
    // What asks for the administrator's password and runs a command as root.
    readonly property string elevator: Quickshell.env("ARCHIVOS_PKEXEC") || "pkexec"
    // Whether a failed engine command is worth repeating as root. The trash is
    // left out: root has a different one.
    function canElevate(command, why) {
        const kinds = ["copy", "move", "drop", "mkdir", "touch", "rename", "rename-many", "delete", "chmod", "chmod-tree", "extract", "compress", "link"];
        return command[0] === engine && kinds.indexOf(command[1]) >= 0 && /os error 13|permission denied|permiso denegado/i.test(why);
    }
    function offerElevated(command, okText, failText) {
        // The command comes as a list of the process, not as an array of ours.
        const asRoot = [elevator];
        for (let i = 0; i < command.length; i++)
            asRoot.push(String(command[i]));
        dialog.confirm("PERMISO DENEGADO", "Tu usuario no puede hacer esto aquí. ¿Repetirlo como administrador? Te pedirá la contraseña y no se podrá deshacer.",
            () => run(asRoot, okText, failText, null), "COMO ADMINISTRADOR");
    }
    function pushUndo(step) {
        undoStack = undoStack.concat([step]).slice(-40);
    }
    function trackJob(task, done, total, name) {
        const now = { id: task.tid, label: task.okText.split(" · ")[0], name: name, done: done, total: total, paused: task.paused };
        const at = transfers.findIndex(t => t.id === task.tid);
        transfers = at < 0 ? transfers.concat([now]) : transfers.map(t => t.id === task.tid ? now : t);
    }
    function dropJob(task) {
        delete jobTasks[task.tid];
        if (transfers.some(t => t.id === task.tid))
            transfers = transfers.filter(t => t.id !== task.tid);
    }
    function cancelJob(id) {
        const task = jobTasks[id];
        if (!task)
            return;
        // A stopped process cannot hear the request to end, so wake it first.
        if (task.paused)
            task.signal(18);
        task.signal(15);
    }
    function pauseJob(id) {
        const task = jobTasks[id];
        if (!task)
            return;
        task.paused = !task.paused;
        task.signal(task.paused ? 19 : 18);
        transfers = transfers.map(t => t.id === id ? Object.assign({}, t, { paused: task.paused }) : t);
    }
    function cancelTransfer() {
        for (const t of transfers)
            cancelJob(t.id);
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
        if (key === "reopen" && value === true)
            settings.lastPath = path;
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
        sources.loadRecent();
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
    function search(text, inside) {
        const q = String(text).trim();
        if (q === "")
            return;
        deepQuery = q;
        deepInside = inside === true;
        deepWide = false;
        found = [];
        deep = true;
        rail.filter.clear();
        query = "";
        finder.running = false;
        finder.command = [engine, deepInside ? "inside" : "search", path, q].concat(showHidden ? ["hidden"] : []);
        finder.running = true;
        focusList();
    }
    // Names anywhere under the home folder, from an index, so it answers at once.
    function searchEverywhere(text) {
        const q = String(text === undefined ? "" : text).trim();
        if (q === "") {
            dialog.ask("BUSCAR EN TODA TU CARPETA PERSONAL", "", value => searchEverywhere(value));
            return;
        }
        deepQuery = q;
        deepInside = false;
        deepWide = true;
        recent = false;
        found = [];
        deep = true;
        rail.filter.clear();
        query = "";
        labelLister.running = false;
        labelLister.command = [engine, "everywhere", q].concat(showHidden ? ["hidden"] : []);
        labelLister.running = true;
        focusList();
    }
    function searchInside() {
        if (inTrash)
            return;
        dialog.ask("BUSCAR DENTRO DE LOS ARCHIVOS", "", value => search(value, true));
    }
    function makeLink() {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        op(["link", dual && otherPath !== "" ? otherPath : path].concat(list.map(e => e.path)), "ENLAZADO · " + label(list));
    }
    function checksum() {
        if (infoPath === "" || summer.running)
            return;
        digest = "…";
        summer.command = [engine, "sum", infoPath];
        summer.running = true;
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
        // A cut is spent once the move really starts, not if the question is cancelled.
        const held = clip;
        transferTo(clip.cut ? "move" : "copy", path, clip.paths, (clip.cut ? "MOVIDO · " : "PEGADO · ") + clip.text,
            () => {
                if (held.cut && clip === held)
                    clip = null;
            });
    }
    function trash() {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        marked = {};
        op(["trash"].concat(list.map(e => e.path)), "A LA PAPELERA · " + label(list), ["untrash"].concat(list.map(e => e.path)));
    }
    // The name a pattern gives the nth of a set, as the engine works it out.
    function patterned(pattern, index, total, original) {
        const number = String(index + 1).padStart(String(total).length, "0");
        let name = pattern.indexOf("{n}") >= 0 ? pattern.split("{n}").join(number) : pattern + " " + number;
        const dot = original.lastIndexOf(".");
        if (name.indexOf(".") < 0 && dot > 0)
            name += original.slice(dot);
        return name;
    }
    function rename() {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        if (list.length > 1) {
            dialog.ask("RENOMBRAR " + list.length + " · {n} ES EL NÚMERO", "nombre {n}", pattern => {
                marked = {};
                op(["rename-many", pattern].concat(list.map(x => x.path)), "RENOMBRADOS · " + list.length + " ELEMENTOS");
            });
            dialog.preview(text => {
                const pattern = text.trim();
                if (pattern === "")
                    return "";
                const lines = list.slice(0, 4).map((e, i) => e.name + "  →  " + patterned(pattern, i, list.length, e.name));
                if (list.length > 4)
                    lines.push("… y " + (list.length - 4) + " más");
                return lines.join("\n");
            });
            return;
        }
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
    // Look inside an archive without unpacking it next to the original.
    function peek() {
        const list = picked().filter(e => !e.isDir && Fmt.icon(e.name, false) === "archive");
        if (list.length !== 1)
            return;
        say("ABRIENDO " + list[0].name.toUpperCase() + "…");
        peeker.name = list[0].name;
        peeker.command = [engine, "peek", list[0].path];
        peeker.running = true;
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
        digest = "";
        summer.running = false;
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
    function chmodTree() {
        if (infoPath === "")
            return;
        dialog.confirm("PERMISOS", "Todo lo que hay dentro tomará los permisos de esta carpeta. No se puede deshacer.",
            () => run([engine, "chmod-tree", infoPath], "PERMISOS APLICADOS A TODO"), "APLICAR");
    }
    function folderOf(p) {
        const shown = shorten(p);
        const cut = shown.lastIndexOf("/");
        return cut > 0 ? shown.slice(0, cut) : "/";
    }
    function duplicate() {
        const list = picked();
        if (list.length === 0 || inTrash)
            return;
        op(["copy", path].concat(list.map(e => e.path)), "DUPLICADO · " + label(list));
    }
    // How much the marked files weigh, for the footer.
    readonly property string markedWeight: {
        if (markedCount === 0)
            return "";
        let bytes = 0;
        for (const e of rows) {
            if (marked[e.path] === true && !e.isDir)
                bytes += Number(e.size) || 0;
        }
        return Fmt.size(bytes).toUpperCase();
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
    function transferTo(mode, dest, paths, okText, started) {
        if (paths.length === 0)
            return;
        // One question at a time: a second transfer would take the first one's answer.
        if (clash.pending !== null || dialog.visible) {
            say("RESPONDE PRIMERO A LA PREGUNTA ANTERIOR", true);
            return;
        }
        clash.pending = { mode: mode, dest: dest, paths: paths, okText: okText, started: started };
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
    function loadActions(paths) {
        const key = paths.join("\n");
        if (actionsFor === key)
            return;
        actions = [];
        actionsFor = key;
        actionFinder.running = false;
        actionFinder.command = [engine, "actions"].concat(paths);
        actionFinder.running = true;
    }
    function actionEntries(paths) {
        if (actionsFor !== paths.join("\n") || actions.length === 0)
            return [{ label: "Sin acciones para esto", armed: false }];
        return actions.map(a => ({
            label: (a.group !== "" ? a.group + " · " : "") + a.name,
            act: () => run([engine, "act", a.file, a.id].concat(paths), "ACCIÓN · " + a.name.toUpperCase())
        }));
    }
    // Packs of actions fetched from a repository: { name, url, count }.
    property var packs: []
    function packJob(args, okText) {
        say("TRAYENDO…");
        packer.okText = okText;
        packer.command = [engine].concat(args);
        packer.running = true;
    }
    function installPack() {
        dialog.ask("INSTALAR ACCIONES · DIRECCIÓN DEL REPOSITORIO", "https://github.com/", url => packJob(["pack-add", url], "ACCIONES INSTALADAS"));
        dialog.preview(() => "Se copian a tu equipo y aparecen en el clic derecho. Son programas de otra persona: instala solo los de quien te fíes.");
    }
    function removePack(p) {
        dialog.confirm("QUITAR ACCIONES", "Se borrará «" + p.name + "» con sus " + p.count + " acciones.",
            () => packJob(["pack-remove", p.name], "ACCIONES QUITADAS · " + p.name.toUpperCase()), "QUITAR");
    }
    function openActionsFolder() {
        const dir = home + "/.config/archivos/acciones";
        Quickshell.execDetached(["mkdir", "-p", dir]);
        go(dir);
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
        sources.loadTargets();
        if (one && deep)
            items.push({ label: "Mostrar en su carpeta", act: () => showInFolder(one) });
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
        if (n > 0 && menuCount > 0) {
            const paths = list.map(e => e.path);
            loadActions(paths);
            items.push({ label: "Acciones" + many, sub: () => actionEntries(paths) });
            items.push({ sep: true });
        }
        if (n > 0)
            items.push({ label: "Etiqueta" + many, sub: () => labelEntries() });
        if (n > 0) {
            items.push({ label: "Copiar" + many, hint: "CTRL+C", act: () => hold(false) });
            items.push({ label: "Cortar" + many, hint: "CTRL+X", act: () => hold(true) });
        }
        items.push({ label: "Pegar aquí", hint: "CTRL+V", act: () => paste() });
        if (n > 0)
            items.push({ label: "Renombrar" + many, hint: "F2", act: () => rename() });
        if (n > 0)
            items.push({ label: "Duplicar" + many, hint: "CTRL+SHIFT+D", act: () => duplicate() });
            items.push({ label: dual ? "Enlazar en el otro panel" : "Crear enlace", hint: "CTRL+SHIFT+L", act: () => makeLink() });
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
            items.push({ label: "Ver por dentro", act: () => peek() });
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
            if (n === 1 && deep)
                add("Mostrar " + list[0].name + " en su carpeta", "ACCIÓN", () => showInFolder(list[0]));
            if (n === 1) {
                add("Abrir " + list[0].name, "ENTER", () => open(current));
                add("Renombrar " + list[0].name, "F2", () => rename());
                if (!list[0].isDir)
                    add("Vista rápida", "ESPACIO", () => look.open());
            }
            if (n > 0) {
                add("Duplicar " + label(list).toLowerCase(), "CTRL+SHIFT+D", () => duplicate());
                add((dual ? "Enlazar en el otro panel " : "Crear un enlace a ") + label(list).toLowerCase(), "CTRL+SHIFT+L", () => makeLink());
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
                add("Ver por dentro sin extraer", "ACCIÓN", () => peek());
                add("Extraer aquí", "ACCIÓN", () => extract());
            add("Pegar aquí", "CTRL+V", () => paste());
            add("Nueva carpeta", "CTRL+SHIFT+N", () => newFolder());
            add("Nuevo archivo", "CTRL+N", () => newFile());
            add("Buscar dentro de los archivos", "CTRL+SHIFT+F", () => searchInside());
            add("Buscar en toda tu carpeta personal", "CTRL+ALT+F", () => searchEverywhere());
            add("Rehacer el índice de búsqueda", "ACCIÓN", () => run([engine, "index"], "ÍNDICE REHECHO"));
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
        add("Filtrar esta carpeta", "CTRL+F", () => focusFilter());
        if (deep)
            add("Cerrar la búsqueda", "ESC", () => endSearch());
        add("Abrir la carpeta de acciones propias", "ACCIÓN", () => openActionsFolder());
        add("Instalar acciones desde un repositorio", "ACCIÓN", () => installPack());
        for (const p of packs) {
            add("Actualizar las acciones de " + p.name, "ACCIONES", () => packJob(["pack-add", p.url], "ACTUALIZADAS · " + p.name.toUpperCase()));
            add("Quitar las acciones de " + p.name, "ACCIONES", () => removePack(p));
        }
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
        if (width < 860)
            add(railForced ? "Esconder el panel lateral" : "Mostrar el panel lateral", "F9", () => railForced = !railForced);
        add(showSorter ? "Esconder el orden y los tipos" : "Mostrar el orden y los tipos", "ACCIÓN", () => setPref("sorter", !showSorter));
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
        sources.loadTargets();
        palette.open();
    }
    function quickLook() {
        look.open();
    }
    function loadPreview() {
        const e = entry(current);
        previewer.running = false;
        facter.running = false;
        if (facter.target !== (e ? e.path : path))
            facts = [];
        facter.target = e ? e.path : path;
        facter.command = [engine, "facts", facter.target];
        facter.running = true;
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
        if (!isDir && flags[filePath] === "exec" && Fmt.icon(name, false) === "file")
            return "script";
        return Fmt.icon(name, isDir);
    }
    // Each family of files gets its own tone from the theme, so a folder full
    // of mixed things can be read at a glance.
    // One colour per kind of file, soft enough to sit on the dark page. Folders
    // take the theme's accent and plain files stay neutral.
    readonly property var hues: ({
            "image": "#f2bc85", "vector": "#f0a868", "video": "#f29b8a", "music": "#e7a6d0", "wave": "#d99ad6",
            "subtitle": "#e9c4a0", "list": "#c9c2b0", "game": "#d7a3e8",
            "archive": "#f0a58f", "package": "#e0b872", "disc": "#d6b08c", "download": "#a9c4d8",
            "model": "#8fd7e8", "print": "#86d6c2", "board": "#a5d6a0", "draft": "#9fc3e8", "chip": "#b9df9a",
            "script": "#c8dc8c", "web": "#8cc3ff", "code": "#b3b8f5", "shader": "#c9a8f2", "data": "#9db4f2",
            "config": "#b8c9d5", "notebook": "#f2c078", "diff": "#e8d28a", "container": "#7fc6f0", "git": "#f0a080",
            "pdf": "#f09a9a", "doc": "#cfd3d6", "book": "#d8c3a5", "sheet": "#9bd3a4", "slides": "#f0b27a", "log": "#a8b0b6",
            "font": "#d0c8e8", "mail": "#a6c8ee", "calendar": "#f0a8a8", "contact": "#c3d6a8", "map": "#9fd6b5",
            "link": "#9fcde9", "seal": "#d8c890", "info": "#9fcde9",
            "key": "#e6d27a", "lock": "#e0c060", "lib": "#9aa3ab", "trash": "#8b9297"
        })
    function toneFor(name, filePath, isDir) {
        const glyph = iconFor(name, filePath, isDir);
        if (isDir)
            return Tokens.sun;
        return hues[glyph] || Tokens.inkFaint;
    }
    // The extension as a short tag, so two files with the same icon still differ.
    function tagFor(name, isDir) {
        return isDir ? "" : Fmt.tag(name);
    }
    function pin(ext) {
        if (pinType === ext) {
            pinType = "";
            onlyType = false;
        } else {
            pinType = ext;
        }
    }
    // The name filter lives in the page head when there is room, else in the rail.
    function focusFilter() {
        if (head.searchShown)
            head.searchField.grabFocus();
        else
            rail.filter.grabFocus();
    }
    // Colour labels: a file or folder can wear one, kept by path in the settings.
    readonly property var labelHues: [
        { key: "red", name: "Rojo", hue: "#e8707a" }, { key: "orange", name: "Naranja", hue: "#e8a25c" },
        { key: "yellow", name: "Amarillo", hue: "#e6cf6a" }, { key: "green", name: "Verde", hue: "#8fd18a" },
        { key: "blue", name: "Azul", hue: "#7fb4f0" }, { key: "purple", name: "Morado", hue: "#c39af0" }
    ]
    readonly property var labels: settings.labels
    // The colours in use, with how many things wear each.
    readonly property var labelCounts: {
        const counts = {};
        for (const p in labels)
            counts[labels[p]] = (counts[labels[p]] || 0) + 1;
        return labelHues.filter(h => counts[h.key] > 0).map(h => ({ key: h.key, name: h.name, hue: h.hue, count: counts[h.key] }));
    }
    function labelHue(filePath) {
        const key = labels[filePath];
        if (key === undefined)
            return "";
        const found = labelHues.find(h => h.key === key);
        return found ? found.hue : "";
    }
    function saveLabels(next) {
        settings.labels = next;
        settingsFile.writeAdapter();
    }
    // Put a colour on what is picked; an empty key takes it off.
    function setLabel(key) {
        const next = Object.assign({}, labels);
        for (const e of picked()) {
            if (key === "")
                delete next[e.path];
            else
                next[e.path] = key;
        }
        saveLabels(next);
        if (deepQuery.indexOf("etiqueta ") === 0 && deep)
            showLabel(labelShown);
    }
    // A label follows its file when the file is renamed or moved.
    function carryLabels(results) {
        let next = null;
        for (let i = 0; i + 2 < results.length; i += 3) {
            const from = results[i + 1], to = results[i + 2];
            if (results[i] !== "move" || labels[from] === undefined)
                continue;
            next = next || Object.assign({}, labels);
            next[to] = next[from];
            delete next[from];
        }
        if (next)
            saveLabels(next);
    }
    property string labelShown: ""
    // Everything that wears one colour, wherever it lives.
    function showLabel(key) {
        const hue = labelHues.find(h => h.key === key);
        if (!hue)
            return;
        labelShown = key;
        deepQuery = "etiqueta " + hue.name.toLowerCase();
        deepInside = false;
        deepWide = true;
        recent = false;
        deep = true;
        rail.filter.clear();
        query = "";
        found = [];
        labelLister.command = [engine, "stat"].concat(Object.keys(labels).filter(p => labels[p] === key));
        labelLister.running = true;
        focusList();
    }
    function labelEntries() {
        return labelHues.map(h => ({ label: h.name, act: () => setLabel(h.key) }))
            .concat([{ sep: true }, { label: "Quitar la etiqueta", act: () => setLabel("") }]);
    }
    function flagFor(filePath) {
        const flag = flags[filePath];
        const mark = flag === "link" ? "→" : (flag === "exec" ? "*" : "");
        const git = changed[filePath];
        return git ? (mark === "" ? git : mark + " " + git) : mark;
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
        // A huge folder is put together once, when all of it has been read.
        if (!deep && !inTrash && dir.status === FolderListModel.Loading && dir.count > 5000)
            return;
        const keep = selected ? selected.path : "";
        let list = [];
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
        const kinds = {};
        for (const e of source) {
            if (!e.isDir) {
                const ext = Fmt.suffix(e.name);
                if (ext !== "")
                    kinds[ext] = (kinds[ext] || 0) + 1;
            }
        }
        typeCounts = Object.keys(kinds).map(ext => ({ ext: ext, count: kinds[ext] }))
            .sort((a, b) => b.count - a.count || a.ext.localeCompare(b.ext)).slice(0, 12);
        if (pinType !== "" && kinds[pinType] === undefined) {
            pinType = "";
            onlyType = false;
        }
        const pinned = e => pinType !== "" && !e.isDir && Fmt.suffix(e.name) === pinType;
        for (const e of source) {
            if (onlyType && pinType !== "" && !pinned(e))
                continue;
            if (e.isDir)
                dirs++;
            else
                regular++;
            if (matches(e.name))
                list.push(e);
        }
        for (const e of list)
            e.key = Fmt.sortKey(e.shown || e.name);
        const flip = sortReversed ? -1 : 1;
        // Recent items arrive newest first; keep that until a column is chosen.
        const asGiven = recent && sortKey === 0 && !sortReversed;
        const order = (a, b) => {
            if (asGiven)
                return 0;
            if (pinned(a) !== pinned(b))
                return pinned(a) ? -1 : 1;
            if (a.isDir !== b.isDir)
                return a.isDir ? -1 : 1;
            let d = 0;
            if (sortKey === 1 && !a.isDir)
                d = a.size - b.size;
            else if (sortKey === 2)
                d = b.modified - a.modified;
            else if (sortKey === 3)
                d = Fmt.kind(a.name, a.isDir).localeCompare(Fmt.kind(b.name, b.isDir));
            return flip * (d || Fmt.compareKeys(a.key, b.key));
        };
        list.sort(order);
        // Opened folders show what they hold right under them, a step in.
        let shown = list;
        if (canExpand && Object.keys(expanded).length > 0) {
            shown = [];
            const place = (entries, depth) => {
                for (const e of entries) {
                    e.depth = depth;
                    shown.push(e);
                    const inside = expanded[e.path];
                    if (e.isDir && inside !== undefined) {
                        const kids = inside.map(k => Object.assign({ key: Fmt.sortKey(k.name) }, k));
                        kids.sort(order);
                        place(kids, depth + 1);
                    }
                }
            };
            place(list, 0);
        }
        list = shown;
        dirTotal = dirs;
        fileTotal = regular;
        rows = list;
        const target = wanted !== "" ? list.findIndex(e => e.path === wanted) : -1;
        if (target >= 0) {
            wanted = "";
            current = target;
            Qt.callLater(() => files.reveal(target));
        } else {
            current = keep === "" ? -1 : list.findIndex(e => e.path === keep);
        }
    }
    // The folder on show no longer exists: step up, and say so.
    function climbOut() {
        if (path === "/")
            return;
        const gone = title;
        path = path.slice(0, path.lastIndexOf("/")) || "/";
        say("YA NO EXISTE · " + gone.toUpperCase(), true);
    }
    // Leave a search or the recent list and land on the item, in its own folder.
    function showInFolder(e) {
        if (!e)
            return;
        const parent = e.path.slice(0, e.path.lastIndexOf("/")) || "/";
        wanted = e.path;
        forget.restart();
        if (parent === path)
            endSearch();
        else
            go(parent);
    }
    // Go to the folder that holds `p` and leave the cursor on it.
    function showPath(p) {
        showInFolder({ path: clean(p) });
    }
    function refresh() {
        countsReady = false;
        sources.reload();
        // Opened folders are read again too.
        for (const p in expanded)
            branch.createObject(app, { dirPath: p }).running = true;
    }
    onGridChanged: refresh()

    onPathChanged: {
        expanded = ({});
        pinType = "";
        onlyType = false;
        if (settled && pick === "" && settings.reopen && settings.lastPath !== path)
            setPref("lastPath", path);
        unreadable = false;
        changed = {};
        Qt.callLater(loadPreview);
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
        head.pathField.text = shorten(path);
        refresh();
    }
    onQueryChanged: {
        filterSoon.restart();
        if (rail.filter.text !== query && !rail.filter.focused)
            rail.filter.text = query;
        if (head.searchField.text !== query && !head.searchField.focused)
            head.searchField.text = query;
    }
    onPinTypeChanged: rebuild()
    onOnlyTypeChanged: rebuild()
    onCurrentChanged: loadPreview()
    onRowsChanged: loadPreview()
    onSortKeyChanged: rebuild()
    onSortReversedChanged: rebuild()
    Component.onCompleted: {
        showHidden = settings.hidden;
        const start = Quickshell.env("ARCHIVOS_DIR");
        if (start)
            path = clean(start);
        else if (settings.reopen && settings.lastPath !== "") {
            settled = true;
            path = settings.lastPath;
        }
        const shown = Quickshell.env("ARCHIVOS_SHOW");
        if (shown) {
            wanted = clean(shown);
            forget.restart();
        }
        head.pathField.text = shorten(path);
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
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: app.settled = true
        // The settings can arrive after the window is up: apply the ones that
        // only matter at the start, once.
        onLoaded: {
            if (app.settled)
                return;
            app.settled = true;
            app.showHidden = settings.hidden;
            if (!Quickshell.env("ARCHIVOS_DIR") && settings.reopen && settings.lastPath !== "")
                app.path = settings.lastPath;
        }

        JsonAdapter {
            id: settings
            property bool grid: false
            property var servers: []
            property var labels: ({})
            property bool dual: false
            property bool hidden: false
            property bool sorter: false
            property string iconStyle: "line"
            property string header: "minimal"
            property bool reopen: false
            property string lastPath: ""
            property string terminal: "kitty --directory"
            property var views: ({})
            property string ownMark: "庫"
            property string ownName: "KURA"
            property string ownTag: "FILES"
            property string ownTitle: "Kura Files"
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
    // Mounting a server is a conversation: it may ask whether to trust a new
    // machine, and for a name or a password, before it lets us in.
    Component {
        id: mounter

        Process {
            id: mount
            property var server: null
            property string secret: ""
            property string heard: ""
            property bool gaveUp: false

            function answer(text) {
                write(text + "\n");
            }
            function giveUp() {
                gaveUp = true;
                signal(15);
            }
            function listen(data) {
                heard += data;
                const tail = heard.replace(/\s+$/, "");
                const name = server.name.toUpperCase();
                if (/Choice:$/.test(tail)) {
                    const print = /SHA256:[A-Za-z0-9+\/=]+/.exec(heard);
                    heard = "";
                    dialog.confirm("SERVIDOR NUEVO · " + name,
                        "Es la primera vez que entras en este equipo, así que no se puede comprobar que sea quien dice ser."
                        + (print ? " Su huella es " + print[0] + "." : "") + " ¿Confiar en él y seguir?",
                        () => mount.answer("1"), "CONFIAR");
                    dialog.orElse(() => mount.answer("2"));
                } else if (/Password:$/.test(tail)) {
                    heard = "";
                    if (secret !== "") {
                        const once = secret;
                        secret = "";
                        answer(once);
                    } else {
                        dialog.askSecret("CONTRASEÑA · " + name, text => mount.answer(text));
                        dialog.orElse(() => mount.giveUp());
                    }
                } else if (/(User|Domain):$/.test(tail)) {
                    const domain = /Domain:$/.test(tail);
                    heard = "";
                    dialog.ask((domain ? "DOMINIO · " : "USUARIO · ") + name, domain ? "WORKGROUP" : "", text => mount.answer(text));
                    dialog.orElse(() => mount.giveUp());
                }
            }

            command: [Quickshell.env("ARCHIVOS_GIO") || "gio", "mount", server ? server.uri : ""]
            // The questions are matched by their English wording.
            environment: ({ "LC_ALL": "C" })
            stdinEnabled: true
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => mount.listen(data)
            }
            stderr: StdioCollector { id: mountErrors }
            onExited: exitCode => {
                const name = server.name.toUpperCase();
                const why = mountErrors.text.trim().split("\n").pop();
                if (exitCode === 0)
                    app.say("CONECTADO · " + name);
                else if (gaveUp)
                    app.say("CONEXIÓN CANCELADA · " + name, true);
                else
                    app.say("NO SE CONECTÓ A " + name + (why ? " · " + why.toUpperCase() : ""), true);
                app.refresh();
                destroy();
            }
        }
    }
    Component {
        id: job

        Process {
            id: task
            property string okText: ""
            property string failText: ""
            property var undoArgs: null
            property int code: -1
            property var results: []
            property int tid: 0
            property bool paused: false

            function finish() {
                const why = errors.text.trim().split("\n")[0];
                app.dropJob(task);
                const again = command[0] === app.engine ? command.slice(1) : null;
                // Land on what the operation just made, when it is in this folder.
                if (code === 0 && results.length >= 3 && undoArgs !== null) {
                    const made = results[results.length - 1];
                    if (made.slice(0, made.lastIndexOf("/")) === app.path) {
                        app.wanted = made;
                        forget.restart();
                        Qt.callLater(app.rebuild);
                    }
                }
                app.carryLabels(results);
                if (undoArgs === "auto")
                    results.length > 0 && app.pushUndo({ text: okText, args: ["revert"].concat(results), again: again });
                else if (undoArgs !== null && code === 0)
                    app.pushUndo({ text: okText, args: undoArgs, again: again });
                if (app.undoing)
                    app.undoing = false;
                else if (app.redoing)
                    app.redoing = false;
                else if (undoArgs !== null)
                    app.redoStack = [];
                if (code === 0)
                    app.say(okText);
                else if (app.canElevate(command, why)) {
                    const again = command;
                    const done = okText;
                    const sorry = failText;
                    app.say(failText + " · HACE FALTA SER ADMINISTRADOR", true);
                    app.offerElevated(again, done, sorry);
                }
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
                        app.trackJob(task, Number(cols[1]), Number(cols[2]), cols.slice(3).join("\t"));
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
                const go = policy => {
                    if (job.started)
                        job.started();
                    app.op([job.mode].concat(policy ? [policy] : []).concat([job.dest]).concat(job.paths), job.okText);
                };
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
    Timer {
        id: infoAgain
        interval: 350
        onTriggered: {
            teller.running = false;
            teller.running = true;
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
        id: summer
        stdout: StdioCollector {
            onStreamFinished: app.digest = text.trim() || "no se pudo calcular"
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
    // Typing in a huge folder would otherwise rebuild the list on every key.
    Timer {
        id: forget
        interval: 2500
        onTriggered: app.wanted = ""
    }
    Timer {
        id: filterSoon
        interval: 50
        onTriggered: app.rebuild()
    }
    Process {
        id: completer
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim();
                if (found === "")
                    return;
                const slash = found.charAt(found.length - 1) === "/" ? "/" : "";
                head.pathField.text = app.shorten(app.clean(found)) + (app.clean(found) === "/" ? "" : slash);
            }
        }
    }
    Process {
        id: facter
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const now = app.entry(app.current);
                if ((now ? now.path : app.path) !== facter.target)
                    return;
                const list = [];
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut > 0)
                        list.push({ label: line.slice(0, cut), value: line.slice(cut + 1) });
                }
                app.facts = list;
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
                head.pathField.text = app.shorten(app.path);
            app.focusList();
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
        id: answer
        onExited: app.quit()
    }
    Process {
        id: peeker
        property string name: ""
        stdout: StdioCollector { id: peekOut }
        stderr: StdioCollector { id: peekErr }
        onExited: code => {
            const dir = peekOut.text.trim();
            if (code !== 0 || dir === "") {
                app.say("NO SE PUDO ABRIR" + (peekErr.text.trim() ? " · " + peekErr.text.trim().toUpperCase() : ""), true);
                return;
            }
            const next = Object.assign({}, app.peeks);
            next[dir] = name;
            app.peeks = next;
            app.say("");
            app.go(dir);
        }
    }
    Component {
        id: branch

        Process {
            id: reader
            property string dirPath: ""
            command: [app.engine, "list", dirPath].concat(app.showHidden ? ["hidden"] : [])
            stdout: StdioCollector {
                onStreamFinished: {
                    const list = [];
                    for (const line of text.split("\n")) {
                        const cols = line.split("\t");
                        if (cols.length < 4)
                            continue;
                        const name = cols.slice(3).join("\t");
                        list.push({
                            name: name,
                            path: reader.dirPath + "/" + name,
                            size: Number(cols[1]),
                            modified: new Date(Number(cols[2]) * 1000),
                            isDir: cols[0] === "d"
                        });
                    }
                    // The folder may have been closed, or left, while it was being read.
                    if (reader.dirPath.indexOf(app.path === "/" ? "/" : app.path + "/") === 0) {
                        const next = Object.assign({}, app.expanded);
                        next[reader.dirPath] = list;
                        app.expanded = next;
                        app.rebuild();
                    }
                    reader.destroy();
                }
            }
        }
    }
    Process {
        id: labelLister
        stdout: StdioCollector {
            onStreamFinished: {
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
        id: menuCounter
        command: [app.engine, "menus"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: app.menuCount = Number(text.trim()) || 0
        }
    }
    Process {
        id: packLister
        command: [app.engine, "pack-list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length === 3)
                        list.push({ name: cols[0], url: cols[1], count: Number(cols[2]) });
                }
                app.packs = list;
            }
        }
    }
    Process {
        id: packer
        property string okText: ""
        stderr: StdioCollector { id: packErrors }
        onExited: code => {
            const why = packErrors.text.trim().split("\n").pop();
            app.say(code === 0 ? okText : "NO SE PUDO" + (why ? " · " + why.toUpperCase() : ""), code !== 0);
            // What is on offer changed: count again and forget what was listed.
            app.actionsFor = "";
            menuCounter.running = true;
            packLister.running = true;
        }
    }
    Process {
        id: actionFinder
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length >= 4)
                        list.push({ file: cols[0], id: cols[1], group: cols[2], name: cols.slice(3).join(" ") });
                }
                app.actions = list;
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

    Shortcut { sequence: "Ctrl+K"; onActivated: app.openPalette() }
    Shortcut { sequence: "Ctrl+F"; onActivated: app.focusFilter() }
    Shortcut { sequence: "Ctrl+Shift+F"; onActivated: app.searchInside() }
    Shortcut { sequence: "Ctrl+Alt+F"; onActivated: app.searchEverywhere() }
    Shortcut { sequence: "Ctrl+G"; onActivated: app.toggleGrid() }
    Shortcut { sequence: "Ctrl+1"; onActivated: app.setMode("list") }
    Shortcut { sequence: "Ctrl+2"; onActivated: app.setMode("grid") }
    Shortcut { sequence: "Ctrl+3"; onActivated: app.setMode("compact") }
    Shortcut { sequence: "Ctrl+4"; onActivated: app.setMode("gallery") }
    Shortcut { sequence: "Alt+Home"; onActivated: app.go(app.home) }
    Shortcut { sequence: "Ctrl+T"; onActivated: app.newTab() }
    Shortcut { sequence: "F6"; onActivated: app.toggleDual() }
    Shortcut { sequence: "F9"; onActivated: app.railForced = !app.railForced }
    Shortcut { sequence: "Ctrl+,"; onActivated: prefs.open() }
    Shortcut { sequence: "Ctrl+W"; onActivated: app.closeTab(app.tab) }
    Shortcut { sequence: "Ctrl+PgDown"; onActivated: app.showTab((app.tab + 1) % app.tabs.length) }
    Shortcut { sequence: "Ctrl+PgUp"; onActivated: app.showTab((app.tab + app.tabs.length - 1) % app.tabs.length) }
    Shortcut { sequence: "Ctrl++"; onActivated: app.setZoom(app.zoom + 0.2) }
    Shortcut { sequence: "Ctrl+="; onActivated: app.setZoom(app.zoom + 0.2) }
    Shortcut { sequence: "Ctrl+-"; onActivated: app.setZoom(app.zoom - 0.2) }
    Shortcut { sequence: "Ctrl+0"; onActivated: app.setZoom(1) }
    Shortcut { sequence: "F1"; onActivated: keysSheet.open() }
    Shortcut { sequence: "Ctrl+L"; onActivated: head.pathField.grabFocus() }
    Shortcut { sequence: "Ctrl+H"; onActivated: app.showHidden = !app.showHidden }
    Shortcut { sequence: "Alt+Left"; onActivated: app.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: app.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: app.goUp() }
    Shortcut { sequence: "F5"; onActivated: app.refresh() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: app.quit() }
    Shortcut {
        sequence: "Escape"
        enabled: menu.visible || dialog.visible || serverForm.visible || look.visible || palette.visible || sheet.visible || keysSheet.visible || prefs.visible
        onActivated: {
            menu.close();
            dialog.close();
            serverForm.close();
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
            else if (event.key === Qt.Key_Right && (app.grid || app.looking))
                app.select(app.current + 1);
            else if (event.key === Qt.Key_Left && (app.grid || app.looking))
                app.select(app.current - 1);
            else if (event.key === Qt.Key_Right && app.selected && app.selected.isDir)
                app.unfold(app.selected);
            else if (event.key === Qt.Key_Left && app.selected) {
                // Close an open folder; from inside one, step out to it.
                if (app.isExpanded(app.selected.path))
                    app.fold(app.selected);
                else if (app.parentRow(app.selected) >= 0)
                    app.select(app.parentRow(app.selected));
            }
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
            else if (event.key === Qt.Key_D && ctrl && shift)
                app.duplicate();
            else if (event.key === Qt.Key_L && ctrl && shift)
                app.makeLink();
            else if (event.key === Qt.Key_D && ctrl)
                app.toggleBookmark(app.selected && app.selected.isDir ? app.selected.path : app.path);
            else if (event.key === Qt.Key_N && ctrl && !shift)
                app.newFile();
            else if (event.key === Qt.Key_Slash)
                app.focusFilter();
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
                (head.searchShown ? head.searchField : rail.filter).text = event.text;
                app.query = event.text;
                app.focusFilter();
            } else
                handled = false;
            event.accepted = handled;
        }
    }

    Sources {
        id: sources
        app: app
    }

    Rail {
        id: rail
        app: app
        visible: app.showRail
        width: visible ? Tokens.railW : 0
        anchors { left: parent.left; top: parent.top; bottom: foot.top }
    }

    Item {
        id: page
        anchors { left: rail.right; right: parent.right; top: parent.top; bottom: pickBar.top }
        anchors.leftMargin: app.width < 700 ? Tokens.s4 : Tokens.s6
        anchors.rightMargin: app.width < 700 ? Tokens.s4 : Tokens.s6
        anchors.topMargin: app.short && !app.bare ? Tokens.s3 : Tokens.s5

        PageHead {
            id: head
            app: app
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: implicitHeight
        }

        TabStrip {
            id: tabBar
            app: app
            anchors { left: parent.left; right: detail.left; top: head.bottom; topMargin: Tokens.s3; rightMargin: detail.shown ? Tokens.s5 : 0 }
        }

        FileList {
            id: files
            app: app
            anchors { left: parent.left; right: detail.left; top: tabBar.bottom; bottom: parent.bottom }
            anchors.topMargin: tabBar.visible ? Tokens.s3 : Tokens.s4
            anchors.rightMargin: detail.shown ? Tokens.s5 : 0
            anchors.bottomMargin: app.short ? Tokens.s3 : Tokens.s5
        }
        Detail {
            id: detail
            app: app
            anchors { right: parent.right; top: head.bottom; topMargin: Tokens.s4 }
            readonly property bool shown: app.dual || app.showDetail
            width: !shown ? 0 : (app.dual ? Math.round((page.width - Tokens.s5) / 2) : 340)
            height: Math.min(implicitHeight, page.height - y - Tokens.s5)
            clip: true
            visible: !app.dual && app.showDetail
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

    Footer {
        id: foot
        app: app
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    }
    Jobs {
        id: jobsPanel
        app: app
        anchors { right: parent.right; rightMargin: Tokens.s5; bottom: foot.top; bottomMargin: Tokens.s2 }
    }
    ChooserBar {
        id: pickBar
        app: app
        anchors { left: rail.right; right: parent.right; bottom: foot.top }
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
    ServerForm {
        id: serverForm
        app: app
        onClosed: app.focusList()
    }
}
