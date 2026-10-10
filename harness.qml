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
        implicitWidth: 1400
        implicitHeight: 900
        color: Tokens.paper

        App {
            id: app
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
                grid: app.grid,
                notice: app.notice,
                undo: app.undo ? app.undo.text : "",
                bookmarks: app.bookmarks.length,
                names: app.rows.map(e => e.name).join(" | "),
                dual: app.dual,
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
        function other(path: string): void { app.otherPath = path; }
        function shot(file: string): void { app.grabToImage(result => result.saveToFile(file)); }
        function focused(): string { return String(win.backingWindow ? win.backingWindow.active : "?"); }
    }
}
