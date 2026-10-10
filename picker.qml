import QtQuick
import Quickshell

// The window other programs get when they ask for a file to open or save.
// ARCHIVOS_PICK says what is wanted; the answer goes to ARCHIVOS_PICK_OUT.
ShellRoot {
    FloatingWindow {
        id: win
        title: app.pickTitle
        implicitWidth: 1100
        implicitHeight: 720
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
}
