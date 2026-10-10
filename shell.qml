import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

ShellRoot {
    FloatingWindow {
        id: win
        title: app.brand.title
        implicitWidth: 1320
        implicitHeight: 860
        minimumSize: Qt.size(480, 380)
        color: Tokens.paper

        Binding {
            target: Tokens
            property: "uiScale"
            value: Tokens.uiScaleFor(win.screen && win.screen.name ? win.screen.name : "")
        }

        onClosed: Qt.quit()

        App {
            id: app
            anchors.fill: parent
            onQuit: Qt.quit()
        }
    }

    // `qs -p <dir> ipc call archivos go ~/work` drives the open window.
    IpcHandler {
        target: "archivos"
        function go(path: string): void { app.go(path); }
        function back(): void { app.goBack(); }
        function forward(): void { app.goForward(); }
        function up(): void { app.goUp(); }
        function filter(text: string): void { app.query = text; }
        function hidden(on: bool): void { app.showHidden = on; }
        function sort(key: int): void { app.sortBy(key); }
        function select(index: int): void { app.select(index); }
        function open(): void { app.open(app.current); }
        function look(): void { app.quickLook(); }
        function menu(x: int, y: int): void { app.contextMenu(x, y); }
        function brand(): void { app.toggleBrand(); }
        function copy(): void { app.hold(false); }
        function cut(): void { app.hold(true); }
        function paste(): void { app.paste(); }
        function trash(): void { app.trash(); }
        function restore(): void { app.restore(); }
        function undo(): void { app.undoLast(); }
        function reveal(): void { app.showInFolder(app.selected); }
        function chmod(mode: string): void { app.chmod(mode); }
        function view(mode: string): void { app.setMode(mode); }
        function redo(): void { app.redoLast(); }
        function recent(): void { app.showRecent(); }
        function prefs(): void { app.openPrefs(); }
        function dual(): void { app.toggleDual(); }
        function swap(): void { app.swapPanes(); }
        function other(path: string): void { app.otherPath = path; }
        function toOther(move: bool): void { app.sendToOther(move); }
        function tab(path: string): void { app.newTab(path); }
        function showTab(index: int): void { app.showTab(index); }
        function closeTab(index: int): void { app.closeTab(index); }
        function server(name: string, uri: string): void { app.saveServers(app.servers.filter(x => x.uri !== uri).concat([{ name: name, uri: uri }])); }
        function connect(uri: string): void { const s = app.servers.find(x => x.uri === uri); if (s) app.connectServer(s); }
        function disconnect(uri: string): void { const s = app.servers.find(x => x.uri === uri); if (s) app.disconnectServer(s); }
        function zoom(percent: int): void { app.setZoom(percent / 100); }
        function compress(format: string): void { app.compress(format); }
        function extract(): void { app.extract(); }
        function touch(name: string): void { app.op(["touch", app.path, name], "ARCHIVO CREADO · " + name.toUpperCase()); }
        function bookmark(path: string): void { app.toggleBookmark(path); }
        function properties(): void { app.properties(); }
        function keys(): void { app.openKeys(); }
        function invert(): void { app.invertMarks(); }
        function search(text: string): void { app.search(text); }
        function drop(dest: string, source: string): void { app.dragging = true; app.dropOn(dest, ["file://" + source]); app.dragging = false; }
        function mark(index: int): void { app.click(index, Qt.ControlModifier); }
        function all(): void { app.markAll(); }
        function grid(): void { app.toggleGrid(); }
        function palette(): void { app.openPalette(); }
        function send(device: string): void { app.sendTo({ name: device }); }
        function mkdir(name: string): void { app.op(["mkdir", app.path, name], "CARPETA CREADA · " + name.toUpperCase()); }
        function rename(name: string): void { if (app.selected) app.op(["rename", app.selected.path, name], "RENOMBRADO · " + name.toUpperCase()); }
        function state(): string {
            return JSON.stringify({
                path: app.path,
                rows: app.rows.length,
                dirs: app.dirTotal,
                files: app.fileTotal,
                selected: app.selected ? app.selected.name : "",
                preview: app.preview.kind,
                notice: app.notice,
                brand: app.brand.name,
                targets: app.targets.length,
                marked: app.markedCount,
                dual: app.dual,
                other: app.otherPath,
                tabs: app.tabs.map((t, i) => i === app.tab ? app.path : t.path),
                tab: app.tab,
                servers: app.servers.map(x => x.name + (app.remotes[x.uri] ? " (conectado)" : "")),
                thumbs: Object.keys(app.thumbs).length,
                undo: app.undo ? app.undo.text : "",
                bookmarks: app.bookmarks.map(b => b.name),
                info: app.info,
                grid: app.grid,
                devices: app.devices.map(d => d.name + (d.mounted ? "" : " (sin montar)")),
                first: app.rows.length ? app.rows[0].name : "",
                last: app.rows.length ? app.rows[app.rows.length - 1].name : ""
            });
        }
    }
}
