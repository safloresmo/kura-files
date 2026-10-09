import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/format.js" as Fmt

// The folder contents as a bordered card: sortable header and one row per entry.
Rectangle {
    id: card

    required property var app
    property alias view: view

    readonly property int sizeW: 110
    readonly property int whenW: 160
    readonly property int kindW: 96

    color: "transparent"
    radius: Tokens.radius
    border.width: Tokens.border
    border.color: Tokens.line
    clip: true

    component HeadCell: Item {
        property string label: ""
        property int key: 0
        property bool alignRight: false

        height: parent.height

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: alignRight ? undefined : parent.left
            anchors.right: alignRight ? parent.right : undefined
            text: label + (card.app.sortKey === key ? (card.app.sortReversed ? "  ▴" : "  ▾") : "")
            color: card.app.sortKey === key ? Tokens.inkDim : Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: Tokens.trackMark
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: card.app.sortBy(key) }
    }

    Item {
        id: title
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 46

        Text {
            anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            text: "CONTENIDO"
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: 12
            font.letterSpacing: Tokens.trackLabel
        }
        Text {
            anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            text: card.app.query !== "" ? "FILTRO · " + card.app.query.toUpperCase() : (card.app.showHidden ? "CON OCULTOS" : "")
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: Tokens.trackMark
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Tokens.line
        }
    }

    Item {
        id: columns
        anchors { left: parent.left; right: parent.right; top: title.bottom }
        anchors.leftMargin: Tokens.s4
        anchors.rightMargin: Tokens.s4
        height: 34

        HeadCell {
            anchors.left: parent.left
            width: parent.width - card.sizeW - card.whenW - card.kindW
            label: "NOMBRE"
            key: 0
        }
        HeadCell {
            x: parent.width - card.kindW - card.whenW - card.sizeW
            width: card.sizeW - Tokens.s5
            label: "TAMAÑO"
            key: 1
            alignRight: true
        }
        HeadCell {
            x: parent.width - card.kindW - card.whenW
            width: card.whenW
            label: "MODIFICADO"
            key: 2
        }
        Text {
            x: parent.width - card.kindW
            anchors.verticalCenter: parent.verticalCenter
            text: "TIPO"
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 10
            font.letterSpacing: Tokens.trackMark
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: columns.bottom }
        height: 1
        color: Tokens.lineSoft
    }

    ListView {
        id: view
        anchors { left: parent.left; right: parent.right; top: columns.bottom; bottom: parent.bottom }
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        model: card.app.rows
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail {
            policy: view.contentHeight > view.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        delegate: Item {
            id: row
            required property int index
            required property var modelData

            readonly property bool sel: card.app.current === index

            width: view.width
            height: 40

            Rectangle {
                anchors.fill: parent
                color: row.sel ? Tokens.tint16 : (rowHover.hovered ? Tokens.tint5 : "transparent")
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

                Text {
                    visible: row.sel
                    text: "//"
                    color: Tokens.inkDim
                    font.family: Tokens.mono
                    font.pixelSize: 11
                    width: 18
                    anchors.verticalCenter: parent.verticalCenter
                }
                Icon {
                    visible: !row.sel
                    name: card.app.iconFor(row.modelData.name, row.modelData.path, row.modelData.isDir)
                    color: Tokens.inkFaint
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.modelData.name
                    color: row.sel ? Tokens.ink : (row.modelData.name.charAt(0) === "." ? Tokens.inkFaint : Tokens.inkDim)
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fRow
                    font.weight: row.sel ? Font.Medium : Font.Normal
                    elide: Text.ElideMiddle
                    width: row.width - card.sizeW - card.whenW - card.kindW - 80
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                x: row.width - Tokens.s4 - card.kindW - card.whenW - card.sizeW
                width: card.sizeW - Tokens.s5
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.isDir ? card.app.countLabel(row.modelData.path) : Fmt.size(row.modelData.size)
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 11
            }
            Text {
                x: row.width - Tokens.s4 - card.kindW - card.whenW
                anchors.verticalCenter: parent.verticalCenter
                text: Fmt.when(row.modelData.modified)
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 11
            }
            Text {
                x: row.width - Tokens.s4 - card.kindW
                width: card.kindW
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                text: Fmt.kind(row.modelData.name, row.modelData.isDir)
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 11
            }

            HoverHandler { id: rowHover }
            TapHandler {
                onTapped: {
                    card.app.current = row.index;
                    card.app.focusList();
                }
                onDoubleTapped: card.app.open(row.index)
            }
        }
    }

    Empty {
        anchors.centerIn: view
        visible: card.app.ready && card.app.rows.length === 0
        caption: card.app.query !== "" ? "Nada coincide con «" + card.app.query + "»." : "Esta carpeta está vacía."
    }
}
