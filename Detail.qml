import QtQuick
import "lib/format.js" as Fmt

// What is selected: a preview, its facts and the actions on it.
Rectangle {
    id: card

    required property var app
    readonly property var item: app.selected

    color: "transparent"
    radius: Tokens.radius
    border.width: Tokens.border
    border.color: Tokens.line
    implicitHeight: body.height

    component Fact: Item {
        property string label: ""
        property string value: ""

        width: parent.width
        height: 38

        Rectangle {
            width: parent.width
            height: 1
            color: Tokens.lineSoft
        }
        Text {
            anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            text: label
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
        }
        Text {
            anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            width: parent.width - 150
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            text: value
            color: Tokens.inkMuted
            font.family: Tokens.mono
            font.pixelSize: 11
        }
    }

    Column {
        id: body
        width: parent.width

        Item {
            width: parent.width
            height: 46

            Text {
                anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: Lang.t("SELECCIÓN")
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: 12
                font.letterSpacing: Tokens.trackLabel
            }
            Text {
                anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: card.item ? (card.app.current + 1) + Lang.t(" DE ") + card.app.total : Lang.t("NADA")
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

        Item {
            width: parent.width
            height: 176

            Rectangle {
                anchors.fill: parent
                anchors.margins: Tokens.s4
                color: Tokens.tint5
                radius: Tokens.radius
                border.width: Tokens.border
                border.color: Tokens.lineSoft
                clip: true

                Image {
                    id: preview
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: status === Image.Ready
                    source: card.app.preview.kind === "image" ? card.app.url(card.app.preview.path) : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 720
                }
                Text {
                    id: excerpt
                    anchors.fill: parent
                    anchors.margins: Tokens.s2
                    visible: card.app.preview.kind === "text"
                    text: visible ? card.app.preview.text : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    clip: true
                    color: Tokens.inkMuted
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    lineHeight: 1.3
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !preview.visible && !excerpt.visible
                    name: card.item ? card.app.iconFor(card.item.name, card.item.path, card.item.isDir) : "folder"
                    size: 44
                    color: card.item ? card.app.toneFor(card.item.name, card.item.path, card.item.isDir) : Tokens.inkFaint
                }
                Text {
                    // Over a network the file is only fetched when asked to.
                    visible: card.app.preview.kind === "far"
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Tokens.s2 }
                    text: Lang.t("ESPACIO PARA VERLO")
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                }
            }
        }

        Column {
            width: parent.width
            leftPadding: Tokens.s4
            rightPadding: Tokens.s4
            bottomPadding: Tokens.s3
            spacing: 2

            Text {
                width: parent.width - Tokens.s4 * 2
                text: card.item ? card.item.name : card.app.title
                textFormat: Text.PlainText
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: 18
                font.weight: Font.Medium
                elide: Text.ElideMiddle
            }
            Text {
                width: parent.width - Tokens.s4 * 2
                text: card.app.shorten(card.item ? card.item.path : card.app.path)
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 10
                font.letterSpacing: 0.6
                elide: Text.ElideMiddle
            }
        }

        Fact {
            label: Lang.t("Tipo")
            value: card.item ? Lang.words(Fmt.kind(card.item.name, card.item.isDir)) : Lang.t("carpeta")
        }
        Fact {
            label: card.item && !card.item.isDir ? Lang.t("Tamaño") : Lang.t("Contenido")
            value: !card.item ? Fmt.plural(card.app.total, Lang.t("elemento"), Lang.t("elementos"))
                : (card.item.isDir ? card.app.countLabel(card.item.path, true) : Fmt.size(card.item.size))
        }
        Fact {
            visible: card.item !== null
            height: visible ? 38 : 0
            label: Lang.t("Modificado")
            value: card.item ? Lang.words(Fmt.when(card.item.modified)) : ""
        }
        Repeater {
            model: card.app.facts

            Fact {
                required property var modelData
                label: modelData.label
                value: modelData.value
            }
        }

        Item {
            width: parent.width
            height: 136

            Rectangle {
                width: parent.width
                height: 1
                color: Tokens.lineSoft
            }
            Grid {
                anchors.fill: parent
                anchors.margins: Tokens.s4
                columns: 2
                spacing: Tokens.s2

                Btn {
                    width: (parent.width - Tokens.s2) / 2
                    text: Lang.t("ABRIR")
                    primary: true
                    armed: card.item !== null
                    onAct: card.app.open(card.app.current)
                }
                Btn {
                    width: (parent.width - Tokens.s2) / 2
                    text: Lang.t("VISTA RÁPIDA")
                    armed: card.item !== null && !card.item.isDir
                    onAct: card.app.quickLook()
                }
                Btn {
                    width: (parent.width - Tokens.s2) / 2
                    text: Lang.t("RENOMBRAR")
                    armed: card.item !== null && !card.app.inTrash
                    onAct: card.app.rename()
                }
                Btn {
                    width: (parent.width - Tokens.s2) / 2
                    text: card.app.inTrash ? Lang.t("RESTAURAR") : Lang.t("A LA PAPELERA")
                    armed: card.item !== null
                    onAct: card.app.inTrash ? card.app.restore() : card.app.trash()
                }
                Btn {
                    width: (parent.width - Tokens.s2) / 2
                    text: Lang.t("COPIAR RUTA")
                    onAct: card.app.copyPath(card.item ? card.item.path : card.app.path)
                }
                Btn {
                    width: (parent.width - Tokens.s2) / 2
                    text: Lang.t("TERMINAL AQUÍ")
                    onAct: card.app.terminal(card.item && card.item.isDir ? card.item.path : card.app.path)
                }
            }
        }
    }
}
