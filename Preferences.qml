import QtQuick

// The settings, edited in place and saved as they change.
Item {
    id: sheet

    required property var app
    required property var store

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

    anchors.fill: parent
    visible: false
    z: 41

    component Line: Item {
        property string label: ""
        property string note: ""
        default property alias control: slot.data

        width: parent.width
        height: 52

        Rectangle {
            width: parent.width
            height: 1
            color: Tokens.lineSoft
        }
        Column {
            anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            spacing: 2

            Text {
                text: label
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fBody
            }
            Text {
                visible: note !== ""
                text: note
                color: Tokens.inkFaint
                font.family: Tokens.ui
                font.pixelSize: 11
            }
        }
        Item {
            id: slot
            anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            width: 260
            height: 30
        }
    }
    component Head: Item {
        property int number: 1
        property string label: ""

        width: parent.width
        height: 34

        Row {
            x: Tokens.s4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s2

            Text {
                text: "0" + number
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 9
            }
            Text {
                text: label
                color: Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 2
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: sheet.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(640, sheet.width - Tokens.s5)
        height: Math.min(parent.height - Tokens.s7, body.height + 46)
        color: Tokens.paper
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line
        clip: true

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Item {
            id: head
            width: parent.width
            height: 46

            Text {
                anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: Lang.t("// AJUSTES")
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: 12
                font.letterSpacing: Tokens.trackLabel
            }
            Text {
                anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: Lang.t("SE GUARDAN SOLOS · ESC")
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

        Flickable {
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
            contentHeight: body.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width

                Head { number: 1; label: Lang.t("MARCA") }
                Line {
                    label: Lang.t("Nombre")
                    Field { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 240; text: sheet.store.ownName; onCommitted: value => sheet.app.setPref("ownName", value) }
                }
                Line {
                    label: Lang.t("Subtítulo")
                    Field { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 240; text: sheet.store.ownTag; onCommitted: value => sheet.app.setPref("ownTag", value) }
                }
                Line {
                    label: Lang.t("Título de la ventana")
                    Field { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 240; text: sheet.store.ownTitle; onCommitted: value => sheet.app.setPref("ownTitle", value) }
                }
                Line {
                    label: Lang.t("Símbolo")
                    note: Lang.t("Una letra o un kanji")
                    Field { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 70; text: sheet.store.ownMark; onCommitted: value => sheet.app.setPref("ownMark", value) }
                }

                Head { number: 2; label: Lang.t("VER") }
                Line {
                    label: Lang.t("Vista al abrir una carpeta")
                    note: Lang.t("Cada carpeta recuerda la suya si la cambias")
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: [Lang.t("LISTA"), Lang.t("CUADRÍCULA")]
                        current: sheet.store.grid ? Lang.t("CUADRÍCULA") : Lang.t("LISTA")
                        onChose: key => sheet.app.setPref("grid", key === Lang.t("CUADRÍCULA"))
                    }
                }
                Line {
                    label: Lang.t("Iconos")
                    note: Lang.t("Línea, hoja con la extensión escrita, o los del sistema")
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: [Lang.t("LÍNEA"), Lang.t("HOJA"), Lang.t("SISTEMA")]
                        current: sheet.store.iconStyle === "sheet" ? Lang.t("HOJA") : (sheet.store.iconStyle === "system" ? Lang.t("SISTEMA") : Lang.t("LÍNEA"))
                        onChose: key => sheet.app.setPref("iconStyle", key === Lang.t("HOJA") ? "sheet" : (key === Lang.t("SISTEMA") ? "system" : "line"))
                    }
                }
                Line {
                    label: Lang.t("Idioma")
                    note: Lang.t("El de la ventana; un texto sin traducir sale en español")
                    Btn {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const on = sheet.app.languages.find(l => l.key === sheet.store.language);
                            return sheet.store.language === "" ? Lang.t("EL DEL SISTEMA") : (on ? on.name.toUpperCase() : "ESPAÑOL");
                        }
                        onAct: sheet.app.chooseLanguage()
                    }
                }
                Line {
                    label: Lang.t("Tema")
                    note: Lang.t("Colores, letra, esquinas y lado del panel")
                    Btn {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const on = sheet.app.themes.find(t => t.key === sheet.store.theme);
                            return (on ? on.name : Lang.t("El de siempre")).toUpperCase();
                        }
                        onAct: sheet.app.chooseTheme()
                    }
                }
                Line {
                    label: Lang.t("Cabecera")
                    note: Lang.t("Cuánto sitio ocupa el nombre de la carpeta")
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: [Lang.t("COMPLETA"), Lang.t("COMPACTA"), Lang.t("MÍNIMA")]
                        current: sheet.store.header === "minimal" ? Lang.t("MÍNIMA") : (sheet.store.header === "compact" ? Lang.t("COMPACTA") : Lang.t("COMPLETA"))
                        onChose: key => sheet.app.setPref("header", key === Lang.t("MÍNIMA") ? "minimal" : (key === Lang.t("COMPACTA") ? "compact" : "full"))
                    }
                }
                Line {
                    label: Lang.t("Orden y tipos bajo la ruta")
                    Sw { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: sheet.store.sorter; onToggled: value => sheet.app.setPref("sorter", value) }
                }
                Line {
                    label: Lang.t("Abrir donde lo dejé")
                    note: Lang.t("En vez de la carpeta personal")
                    Sw { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: sheet.store.reopen; onToggled: value => sheet.app.setPref("reopen", value) }
                }
                Line {
                    label: Lang.t("Mostrar los ocultos al abrir")
                    Sw { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: sheet.store.hidden; onToggled: value => sheet.app.setPref("hidden", value) }
                }
                Line {
                    label: Lang.t("Dos paneles")
                    Sw { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: sheet.store.dual; onToggled: sheet.app.toggleDual() }
                }

                Head { number: 3; label: Lang.t("HERRAMIENTAS") }
                Line {
                    label: "Terminal"
                    note: Lang.t("La carpeta se añade al final")
                    Field { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 240; tabular: true; text: sheet.store.terminal; onCommitted: value => sheet.app.setPref("terminal", value) }
                }

                Head { number: 4; label: Lang.t("RED") }
                Repeater {
                    model: sheet.store.servers

                    Line {
                        required property var modelData
                        label: modelData.name
                        note: modelData.uri
                        Btn { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; compact: true; text: Lang.t("QUITAR"); onAct: sheet.app.removeServer(modelData) }
                    }
                }
                Line {
                    label: Lang.t("Servidor nuevo")
                    note: Lang.t("SFTP, FTP o WebDAV")
                    Btn {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        compact: true
                        text: Lang.t("AÑADIR")
                        onAct: {
                            sheet.close();
                            sheet.app.addServer();
                        }
                    }
                }
                Item { width: 1; height: Tokens.s3 }
            }
        }
    }
}
