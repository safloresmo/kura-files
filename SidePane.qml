import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/format.js" as Fmt

// The other folder of a two pane layout: somewhere to copy or move to.
// Tab swaps it with the main pane, so either side can become the working one.
Rectangle {
    id: pane

    required property var app
    readonly property string path: app.otherPath
    property var rows: []

    function rebuild() {
        const list = [];
        for (let i = 0; i < other.count; i++)
            list.push({ name: other.get(i, "fileName"), path: other.get(i, "filePath"), size: other.get(i, "fileSize"), isDir: other.isFolder(i) });
        list.sort((a, b) => (a.isDir !== b.isDir ? (a.isDir ? -1 : 1) : Fmt.compare(a.name, b.name)));
        rows = list;
    }

    color: "transparent"
    radius: Tokens.radius
    border.width: Tokens.border
    border.color: paneDrop.containsDrag ? Tokens.lineStrong : Tokens.line
    clip: true

    FolderListModel {
        id: other
        folder: pane.app.url(pane.path)
        showDirsFirst: true
        showHidden: pane.app.showHidden
        showDotAndDotDot: false
        onCountChanged: Qt.callLater(pane.rebuild)
        onStatusChanged: Qt.callLater(pane.rebuild)
    }

    DropArea {
        id: paneDrop
        anchors.fill: parent
        onDropped: drop => {
            pane.app.dropOn(pane.path, drop.urls);
            drop.accept(Qt.CopyAction);
        }
    }

    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 46

        Text {
            anchors { left: parent.left; leftMargin: Tokens.s4; right: buttons.left; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
            text: "OTRO PANEL · " + pane.app.shorten(pane.path).toUpperCase()
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: 12
            font.letterSpacing: Tokens.trackLabel
            elide: Text.ElideMiddle
        }
        Row {
            id: buttons
            anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2

            Btn { compact: true; text: "↑"; armed: pane.path !== "/"; onAct: pane.app.otherUp() }
            Btn { compact: true; text: "CAMBIAR"; onAct: pane.app.swapPanes() }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Tokens.line
        }
    }

    ListView {
        id: view
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top }
        model: pane.rows
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail {
            policy: view.contentHeight > view.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        delegate: Item {
            id: row
            required property var modelData

            width: view.width
            height: 36

            Rectangle {
                anchors.fill: parent
                color: rowDrop.containsDrag ? Tokens.tint16 : (rowHover.hovered && row.modelData.isDir ? Tokens.tint5 : "transparent")
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Tokens.lineSoft
            }
            Row {
                x: Tokens.s4
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s3

                Icon {
                    name: pane.app.iconFor(row.modelData.name, row.modelData.path, row.modelData.isDir)
                    size: 16
                    color: pane.app.toneFor(row.modelData.name, row.modelData.path, row.modelData.isDir)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.modelData.name
                    color: row.modelData.isDir ? Tokens.inkDim : Tokens.inkFaint
                    font.family: Tokens.ui
                    font.pixelSize: 14
                    elide: Text.ElideMiddle
                    width: row.width - 130
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: row.modelData.isDir ? "" : Fmt.size(row.modelData.size)
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 10
            }
            HoverHandler { id: rowHover; cursorShape: row.modelData.isDir ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: row.modelData.isDir; onTapped: pane.app.otherPath = row.modelData.path }
            DropArea {
                id: rowDrop
                anchors.fill: parent
                enabled: row.modelData.isDir
                onDropped: drop => {
                    pane.app.dropOn(row.modelData.path, drop.urls);
                    drop.accept(Qt.CopyAction);
                }
            }
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
            anchors { left: parent.left; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2

            Btn { text: "COPIAR AQUÍ"; armed: pane.app.picked().length > 0; onAct: pane.app.sendToOther(false) }
            Btn { text: "MOVER AQUÍ"; armed: pane.app.picked().length > 0; onAct: pane.app.sendToOther(true) }
        }
        Text {
            anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            text: pane.rows.length + " ELEM."
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: Tokens.trackMark
        }
    }
}
