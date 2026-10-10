import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/format.js" as Fmt

// Everything known about one file or folder.
Item {
    id: sheet

    required property var app
    readonly property var info: app.info

    signal closed()

    function open() {
        visible = true;
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        closed();
    }
    function stamp(seconds) {
        const n = Number(seconds);
        return n > 0 ? Fmt.when(new Date(n * 1000)) : "—";
    }

    anchors.fill: parent
    visible: false
    z: 42

    component Fact: Item {
        property string label: ""
        property string value: ""

        visible: value !== ""
        width: parent.width
        height: visible ? 36 : 0

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
            width: parent.width - 170
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            text: value
            color: Tokens.inkMuted
            font.family: Tokens.mono
            font.pixelSize: 11
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: sheet.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(520, sheet.width - Tokens.s5)
        height: body.height
        color: Tokens.paper
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: body
            width: parent.width

            Item {
                width: parent.width
                height: 46

                Text {
                    anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                    text: "// PROPIEDADES"
                    color: Tokens.ink
                    font.family: Tokens.mono
                    font.pixelSize: 12
                    font.letterSpacing: Tokens.trackLabel
                }
                Text {
                    anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                    text: "ESC"
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: 10
                    font.letterSpacing: Tokens.trackMark
                }
            }
            Text {
                leftPadding: Tokens.s4
                bottomPadding: Tokens.s3
                width: parent.width - Tokens.s4
                text: sheet.info.name || "Leyendo…"
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: 20
                font.weight: Font.Medium
                elide: Text.ElideMiddle
            }

            Fact { label: "Ruta"; value: sheet.info.path ? sheet.app.shorten(sheet.info.path) : "" }
            Fact { label: "Enlace a"; value: sheet.info.link || "" }
            Fact { label: "Tipo"; value: sheet.info.kind === "inode/directory" ? "carpeta" : (sheet.info.kind || "") }
            Fact {
                label: "Tamaño"
                value: sheet.info.size === undefined ? ""
                    : Fmt.size(sheet.info.size) + (sheet.info.complete === "false" ? " o más" : "")
            }
            Fact {
                label: "Contenido"
                value: sheet.info.items === undefined ? ""
                    : Fmt.plural(Number(sheet.info.items), "elemento", "elementos") + (sheet.info.complete === "false" ? " o más" : "")
            }
            Fact { label: "Modificado"; value: sheet.info.modified ? sheet.stamp(sheet.info.modified) : "" }
            Fact { label: "Abierto"; value: sheet.info.accessed ? sheet.stamp(sheet.info.accessed) : "" }
            Fact { label: "Creado"; value: sheet.info.created ? sheet.stamp(sheet.info.created) : "" }
            Fact { label: "Permisos"; value: sheet.info.mode ? sheet.info.mode.replace("\t", " · ") : "" }
            Item {
                id: bits
                readonly property int mode: sheet.info.mode ? parseInt(sheet.info.mode.split("\t")[1], 8) : -1
                readonly property var who: ["Dueño", "Grupo", "Otros"]

                visible: mode >= 0 && sheet.info.owner === sheet.app.user
                width: parent.width
                height: visible ? 44 : 0

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokens.lineSoft
                }
                Text {
                    anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                    text: "Cambiar permisos"
                    color: Tokens.inkDim
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody
                }
                Row {
                    anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.s3

                    Repeater {
                        model: 3

                        Row {
                            id: group
                            required property int index
                            spacing: 3

                            Text {
                                text: bits.who[group.index].toUpperCase()
                                color: Tokens.inkFaint
                                font.family: Tokens.mono
                                font.pixelSize: 9
                                font.letterSpacing: 1
                                anchors.verticalCenter: parent.verticalCenter
                                rightPadding: 3
                            }
                            Repeater {
                                model: 3

                                Rectangle {
                                    id: bit
                                    required property int index
                                    readonly property int mask: 1 << ((2 - group.index) * 3 + (2 - index))
                                    readonly property bool on: (bits.mode & mask) !== 0

                                    width: 22
                                    height: 22
                                    radius: Tokens.radius - 2
                                    color: on ? Tokens.bone : "transparent"
                                    border.width: Tokens.border
                                    border.color: on ? Tokens.bone : Tokens.line

                                    Text {
                                        anchors.centerIn: parent
                                        text: "rwx".charAt(bit.index)
                                        color: bit.on ? Tokens.inkOnBone : Tokens.inkFaint
                                        font.family: Tokens.mono
                                        font.pixelSize: 11
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: sheet.app.chmod(((bits.mode & 0o777) ^ bit.mask).toString(8)) }
                                }
                            }
                        }
                    }
                }
            }
            Fact { label: "Propietario"; value: sheet.info.owner ? sheet.info.owner + " · " + (sheet.info.group || "") : "" }

            Item {
                width: parent.width
                height: 64

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokens.lineSoft
                }
                Row {
                    anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.s2

                    Btn { text: "COPIAR RUTA"; onAct: sheet.app.copyPath(sheet.info.path || sheet.app.path) }
                    Btn { text: "CERRAR"; primary: true; onAct: sheet.close() }
                }
            }
        }
    }
}
