import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Large preview of the selected file, over the window.
Item {
    id: look

    required property var app
    readonly property var item: app.selected
    readonly property var preview: app.preview

    signal closed()

    function open() {
        if (!item)
            return;
        visible = true;
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        closed();
    }

    anchors.fill: parent
    visible: false
    z: 40

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: look.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Tokens.s7
        color: Tokens.paper
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line
        clip: true

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Item {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 46

            Text {
                anchors { left: parent.left; leftMargin: Tokens.s4; right: tag.left; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: look.item ? look.item.name : ""
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow
                font.weight: Font.Medium
                elide: Text.ElideMiddle
            }
            Text {
                id: tag
                anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: "VISTA RÁPIDA · ESC"
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 10
                font.letterSpacing: Tokens.trackMark
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Tokens.line
            }
        }

        Image {
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
            anchors.margins: Tokens.s4
            visible: look.preview.kind === "image"
            source: look.visible && look.preview.kind === "image" ? look.app.url(look.preview.path) : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }

        Flickable {
            id: scroll
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
            anchors.margins: Tokens.s4
            visible: look.preview.kind === "text"
            contentWidth: width
            contentHeight: body.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail {}

            Text {
                id: body
                width: scroll.width - Tokens.s3
                text: look.preview.kind === "text" ? look.preview.text : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Tokens.inkDim
                font.family: Tokens.mono
                font.pixelSize: 12
                lineHeight: 1.35
            }
        }

        Column {
            anchors.centerIn: parent
            visible: look.preview.kind === "none"
            spacing: Tokens.s3

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: look.item ? look.app.iconFor(look.item.name, look.item.path, look.item.isDir) : "file"
                size: 64
                color: Tokens.inkFaint
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "// SIN VISTA PREVIA_"
                color: Tokens.inkDim
                font.family: Tokens.mono
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }
        }
    }
}
