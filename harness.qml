import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

// Test harness: the same window, plus synthetic mouse and keyboard input
// driven over IPC, so the interface can be exercised without a person.
//   qs -p harness.qml ipc call input click 500 300 1 0
ShellRoot {
    FloatingWindow {
        id: win
        title: "archivos-test"
        implicitWidth: Number(Quickshell.env("HARNESS_W")) || 1400
        implicitHeight: Number(Quickshell.env("HARNESS_H")) || 900
        color: Tokens.paper

        App {
            id: app
            onQuit: Qt.quit()
            anchors.fill: parent
        }
    }

    TestEvent { id: events }

    IpcHandler {
        target: "input"
        function click(x: int, y: int, button: int, modifiers: int): void { events.mouseClick(app, x, y, button, modifiers, 30); }
        function doubleClick(x: int, y: int): void { events.mouseDoubleClickSequence(app, x, y, Qt.LeftButton, Qt.NoModifier, 30); }
        function move(x: int, y: int): void { events.mouseMove(app, x, y, 30, Qt.NoButton, Qt.NoModifier); }
        function press(x: int, y: int): void { events.mousePress(app, x, y, Qt.LeftButton, Qt.NoModifier, 30); }
        function drag(x: int, y: int): void { events.mouseMove(app, x, y, 30, Qt.LeftButton, Qt.NoModifier); }
        function release(x: int, y: int): void { events.mouseRelease(app, x, y, Qt.LeftButton, Qt.NoModifier, 30); }
        function wheel(x: int, y: int, delta: int): void { events.mouseWheel(app, x, y, Qt.NoButton, Qt.NoModifier, 0, delta, 30); }
        function key(code: int, modifiers: int): void { events.keyClick(code, modifiers, 30); }
        function type(text: string): void {
            for (let i = 0; i < text.length; i++)
                events.keyClickChar(text.charAt(i), Qt.NoModifier, 20);
        }
        function state(): string {
            return JSON.stringify({
                path: app.path,
                rows: app.rows.length,
                current: app.current,
                selected: app.selected ? app.selected.name : "",
                marked: app.markedCount,
                query: app.query,
                deep: app.deep,
                hidden: app.showHidden,
                labels: app.labelCounts.map(l => l.key + ":" + l.count).join(" "),
                packs: app.packs.map(p => p.name + ":" + p.count).join(" "),
                hint: app.dialog.hintText,
                shown: app.shorten(app.path),
                servers: app.servers.map(x => x.name + " " + x.uri).join(" | "),
                undos: app.undoStack.length,
                redos: app.redoStack.length,
                jobs: app.transfers.map(t => (t.paused ? "paused" : "running")).join(" "),
                pick: app.pickPaths.join(" | "),
                actions: app.actions.map(a => (a.group !== "" ? a.group + " · " : "") + a.name).join(" | "),
                detail: app.showDetail,
                digest: app.digest,
                grid: app.grid,
                notice: app.notice,
                undo: app.undo ? app.undo.text : "",
                bookmarks: app.bookmarks.length,
                names: app.rows.slice(0, 40).map(e => e.name).join(" | "),
                dual: app.dual,
                sorter: app.showSorter,
                icons: app.iconStyle,
                pin: app.pinType,
                only: app.onlyType,
                types: app.typeCounts.map(t => t.ext + ":" + t.count).join(" "),
                clip: app.clip ? app.clip.text : "",
                changed: Object.keys(app.changed).length,
                unreadable: app.unreadable,
                facts: app.facts.map(f => f.label + "=" + f.value).join("; "),
                typed: app.typedPath,
                looking: app.looking,
                preview: app.preview.kind,
                perms: app.info.mode ? app.info.mode.split("\t")[1] : "",
                trashed: app.trashList.length,
                mode: app.mode,
                redo: app.redo ? app.redo.text : "",
                recent: app.recent,
                sort: app.sortKey,
                other: app.otherPath.split("/").pop(),
                here: app.path.split("/").pop(),
                dragging: app.dragging
            });
        }
        function go(path: string): void { app.go(path); }
        function pin(ext: string): void { app.pin(ext); }
        function only(on: bool): void { app.onlyType = on; }
        function search(text: string): void { app.search(text); }
        function inside(text: string): void { app.search(text, true); }
        function everywhere(text: string): void { app.searchEverywhere(text); }
        function sum(): void { app.properties(); app.checksum(); }
        function point(path: string): void { app.showPath(path); }
        function actions(): void { app.loadActions(app.picked().map(e => e.path)); }
        function act(index: int): void { app.actionEntries(app.picked().map(e => e.path))[index].act(); }
        function pickName(text: string): void { app.pickBar.nameField.text = text; }
        function pickDone(): void { app.pickDone(); }
        function copyTo(dest: string, source: string): void { app.transferTo("copy", dest, [source], "COPIADO"); }
        function pauseAll(): void { for (const t of app.transfers) app.pauseJob(t.id); }
        function cancelAll(): void { app.cancelTransfer(); }
        function serverForm(): void { app.addServer(); }
        function peek(): void { app.peek(); }
        function pack(address: string): void { app.packJob(["pack-add", address], "ACCIONES INSTALADAS"); }
        function unpack(name: string): void { app.packJob(["pack-remove", name], "ACCIONES QUITADAS"); }
        function label(key: string): void { app.setLabel(key); }
        function showLabel(key: string): void { app.showLabel(key); }
        function expand(): void { app.toggleExpand(app.selected); }
        function reveal(): void { app.showInFolder(app.selected); }
        function pref(key: string, on: bool): void { app.setPref(key, on); }
        function set(key: string, value: string): void { app.setPref(key, value); }
        function other(path: string): void { app.otherPath = path; }
        function shot(file: string): void { app.grabToImage(result => result.saveToFile(file)); }
        function focused(): string { return String(win.backingWindow ? win.backingWindow.active : "?"); }
    }
}
