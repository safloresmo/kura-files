import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

ShellRoot {
    FloatingWindow {
        id: win
        title: "Archivos"
        implicitWidth: 1320
        implicitHeight: 860
        minimumSize: Qt.size(980, 620)
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
        function state(): string {
            return JSON.stringify({
                path: app.path,
                rows: app.rows.length,
                dirs: app.dirTotal,
                files: app.fileTotal,
                selected: app.selected ? app.selected.name : "",
                first: app.rows.length ? app.rows[0].name : "",
                last: app.rows.length ? app.rows[app.rows.length - 1].name : ""
            });
        }
    }
}
