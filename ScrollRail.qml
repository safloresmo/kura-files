import QtQuick
import QtQuick.Controls

// A thin, square scroll bar that brightens while it is in use.
ScrollBar {
    id: rail

    contentItem: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        color: rail.pressed ? Tokens.ink : Tokens.inkFaint
        opacity: rail.policy === ScrollBar.AlwaysOff ? 0 : (rail.active ? 1 : 0.5)

        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
    }
}
