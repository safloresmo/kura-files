import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/format.js" as Fmt

// The folder contents as a bordered card, as sortable rows or as a grid.
Rectangle {
    id: card

    required property var app

    readonly property int sizeW: 110
    readonly property int whenW: 160
    readonly property int kindW: 96
    readonly property int cellW: Math.round(136 * app.zoom)
    readonly property int cellH: Math.round(124 * app.zoom)
    readonly property int columns: app.grid ? Math.max(1, Math.floor(tiles.width / cellW)) : 1
    readonly property int pageStep: app.grid ? Math.max(1, Math.floor(tiles.height / cellH)) * columns
        : Math.max(1, Math.floor(view.height / 40) - 1)

    function reveal(i) {
        if (app.grid)
            tiles.positionViewAtIndex(i, GridView.Contain);
        else
            view.positionViewAtIndex(i, ListView.Contain);
    }
    function indexAt(x, y) {
        if (app.grid) {
            const p = tiles.mapFromItem(card, x, y);
            return p.y >= 0 ? tiles.indexAt(p.x + tiles.contentX, p.y + tiles.contentY) : -1;
        }
        const p = view.mapFromItem(card, x, y);
        return p.y >= 0 ? view.indexAt(p.x, p.y + view.contentY) : -1;
    }

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

    DropArea {
        id: folderDrop
        anchors.fill: parent
        onDropped: drop => {
            card.app.dropOn(card.app.path, drop.urls);
            drop.accept(Qt.CopyAction);
        }
    }

    Item {
        id: title
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 46

        Text {
            anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            text: card.app.inTrash ? "PAPELERA" : (card.app.deep ? "RESULTADOS · " + card.app.deepQuery.toUpperCase() : "CONTENIDO")
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: 12
            font.letterSpacing: Tokens.trackLabel
        }
        Text {
            anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            text: card.app.markedCount > 0 ? card.app.markedCount + " MARCADOS"
                : (card.app.query !== "" ? "FILTRO · " + card.app.query.toUpperCase() : (card.app.showHidden ? "CON OCULTOS" : ""))
            color: card.app.markedCount > 0 ? Tokens.inkDim : Tokens.inkFaint
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
        id: columnsHead
        anchors { left: parent.left; right: parent.right; top: title.bottom }
        anchors.leftMargin: Tokens.s4
        anchors.rightMargin: Tokens.s4
        height: 34

        HeadCell {
            anchors.left: parent.left
            width: card.app.grid ? 120 : parent.width - card.sizeW - card.whenW - card.kindW
            label: "NOMBRE"
            key: 0
        }
        HeadCell {
            x: card.app.grid ? 140 : parent.width - card.kindW - card.whenW - card.sizeW
            width: card.sizeW - Tokens.s5
            label: "TAMAÑO"
            key: 1
            alignRight: !card.app.grid
        }
        HeadCell {
            x: card.app.grid ? 260 : parent.width - card.kindW - card.whenW
            width: card.whenW
            label: "MODIFICADO"
            key: 2
        }
        HeadCell {
            x: card.app.grid ? 420 : parent.width - card.kindW
            width: card.kindW
            label: "TIPO"
            key: 3
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: columnsHead.bottom }
        height: 1
        color: Tokens.lineSoft
    }

    ListView {
        id: view
        anchors { left: parent.left; right: parent.right; top: columnsHead.bottom; bottom: parent.bottom }
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        visible: !card.app.grid
        model: card.app.grid ? [] : card.app.rows
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
            readonly property bool marked: card.app.marked[modelData.path] === true
            readonly property bool lit: sel || marked

            width: view.width
            height: 40

            Rectangle {
                anchors.fill: parent
                color: row.sel ? Tokens.tint16 : (row.marked ? Tokens.tint10 : (rowHover.hovered ? Tokens.tint5 : "transparent"))
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
                    visible: row.lit
                    text: "//"
                    color: Tokens.inkDim
                    font.family: Tokens.mono
                    font.pixelSize: 11
                    width: 18
                    anchors.verticalCenter: parent.verticalCenter
                }
                Icon {
                    visible: !row.lit
                    name: card.app.iconFor(row.modelData.name, row.modelData.path, row.modelData.isDir)
                    color: Tokens.inkFaint
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.modelData.shown || row.modelData.name
                    color: row.lit ? Tokens.ink : (row.modelData.name.charAt(0) === "." ? Tokens.inkFaint : Tokens.inkDim)
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fRow
                    font.weight: row.lit ? Font.Medium : Font.Normal
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

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": card.app.dragData })
            Drag.onDragFinished: card.app.dragging = false

            DragHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: {
                    if (active)
                        card.app.beginDrag(row.index);
                    row.Drag.active = active;
                }
            }
            DropArea {
                id: rowDrop
                anchors.fill: parent
                enabled: row.modelData.isDir
                onDropped: drop => {
                    card.app.dropOn(row.modelData.path, drop.urls);
                    drop.accept(Qt.CopyAction);
                }
            }
            Rectangle {
                anchors.fill: parent
                visible: rowDrop.containsDrag
                color: Tokens.tint10
                border.width: Tokens.border
                border.color: Tokens.lineStrong
            }

            HoverHandler { id: rowHover }
            TapHandler {
                id: rowTap
                onTapped: card.app.click(row.index, rowTap.point.modifiers)
                onDoubleTapped: card.app.open(row.index)
            }
        }
    }

    GridView {
        id: tiles
        anchors { left: parent.left; right: parent.right; top: columnsHead.bottom; bottom: parent.bottom }
        anchors.topMargin: Tokens.s3
        anchors.leftMargin: Tokens.s3
        anchors.rightMargin: Tokens.s3
        anchors.bottomMargin: 1
        visible: card.app.grid
        model: card.app.grid ? card.app.rows : []
        cellWidth: Math.floor(width / card.columns)
        cellHeight: card.cellH
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail {
            policy: tiles.contentHeight > tiles.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        delegate: Item {
            id: tile
            required property int index
            required property var modelData

            readonly property bool sel: card.app.current === index
            readonly property bool marked: card.app.marked[modelData.path] === true
            readonly property bool lit: sel || marked

            width: tiles.cellWidth
            height: tiles.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Tokens.radius
                color: tile.sel ? Tokens.tint16 : (tile.marked ? Tokens.tint10 : (tileHover.hovered ? Tokens.tint5 : "transparent"))
                border.width: tile.lit ? Tokens.border : 0
                border.color: Tokens.line
            }
            Item {
                id: art
                anchors { top: parent.top; topMargin: 14; horizontalCenter: parent.horizontalCenter }
                width: Math.round(96 * card.app.zoom)
                height: Math.round(60 * card.app.zoom)

                Image {
                    id: thumb
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: tile.modelData.isDir ? ""
                        : Fmt.isImage(tile.modelData.name) ? card.app.url(tile.modelData.path)
                        : card.app.thumbs[tile.modelData.path] ? card.app.url(card.app.thumbs[tile.modelData.path]) : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 384
                    sourceSize.height: 240
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !thumb.visible
                    name: card.app.iconFor(tile.modelData.name, tile.modelData.path, tile.modelData.isDir)
                    size: Math.round(34 * card.app.zoom)
                    color: tile.lit ? Tokens.inkDim : Tokens.inkFaint
                }
            }
            Text {
                anchors { top: art.bottom; topMargin: 8; left: parent.left; right: parent.right }
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                horizontalAlignment: Text.AlignHCenter
                text: (tile.lit ? "// " : "") + (tile.modelData.shown || tile.modelData.name)
                color: tile.lit ? Tokens.ink : (tile.modelData.name.charAt(0) === "." ? Tokens.inkFaint : Tokens.inkDim)
                font.family: Tokens.ui
                font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": card.app.dragData })
            Drag.onDragFinished: card.app.dragging = false

            DragHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: {
                    if (active)
                        card.app.beginDrag(tile.index);
                    tile.Drag.active = active;
                }
            }
            DropArea {
                id: tileDrop
                anchors.fill: parent
                enabled: tile.modelData.isDir
                onDropped: drop => {
                    card.app.dropOn(tile.modelData.path, drop.urls);
                    drop.accept(Qt.CopyAction);
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Tokens.radius
                visible: tileDrop.containsDrag
                color: Tokens.tint10
                border.width: Tokens.border
                border.color: Tokens.lineStrong
            }

            HoverHandler { id: tileHover }
            TapHandler {
                id: tileTap
                onTapped: card.app.click(tile.index, tileTap.point.modifiers)
                onDoubleTapped: card.app.open(tile.index)
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: point => {
            const i = card.indexAt(point.position.x, point.position.y);
            const scene = card.mapToItem(null, point.position.x, point.position.y);
            card.app.rightClick(i, scene.x, scene.y);
        }
    }

    Empty {
        anchors.centerIn: view
        visible: card.app.ready && card.app.rows.length === 0
        caption: card.app.deep ? "Nada coincide con «" + card.app.deepQuery + "» en las subcarpetas."
            : card.app.query !== "" ? "Nada coincide con «" + card.app.query + "»."
            : (card.app.inTrash ? "La papelera está vacía." : "Esta carpeta está vacía.")
    }
}
