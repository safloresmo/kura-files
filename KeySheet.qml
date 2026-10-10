import QtQuick

// The keyboard shortcuts, on one sheet.
Item {
    id: sheet

    readonly property var groups: [
        { name: Lang.t("MOVERSE"), keys: [
            ["Enter", Lang.t("Abrir")], [Lang.t("Retroceso · Alt+↑"), Lang.t("Subir una carpeta")], ["Alt+← · Alt+→", Lang.t("Atrás y adelante")],
            ["Alt+Inicio", Lang.t("Carpeta personal")], ["Ctrl+L · Tab", Lang.t("Escribir una ruta y completarla")], [Lang.t("Inicio · Fin"), Lang.t("Primero y último")], ["F5", Lang.t("Actualizar")],
            ["Ctrl+T · Ctrl+W", Lang.t("Pestaña nueva y cerrar")], [Lang.t("Ctrl+RePág · AvPág"), Lang.t("Cambiar de pestaña")], [Lang.t("F6 · Tab"), Lang.t("Segundo panel y cambiar")]] },
        { name: Lang.t("SELECCIONAR"), keys: [
            ["Ctrl+clic", Lang.t("Añadir o quitar")], [Lang.t("Mayús+clic · Mayús+↑↓"), Lang.t("Marcar un tramo")], ["Ctrl+A", Lang.t("Todo")],
            [Lang.t("Ctrl+Mayús+I"), Lang.t("Invertir")], ["Esc", Lang.t("Soltar la selección")]] },
        { name: Lang.t("ARCHIVOS"), keys: [
            ["Ctrl+C · Ctrl+X · Ctrl+V", Lang.t("Copiar, cortar y pegar")], [Lang.t("Ctrl+Z · Ctrl+Mayús+Z"), Lang.t("Deshacer y rehacer")], [Lang.t("F2 · Ctrl+Mayús+D"), Lang.t("Renombrar y duplicar")], [Lang.t("Ctrl+Mayús+L"), Lang.t("Crear un enlace")], ["→ · ←", Lang.t("Abrir y cerrar una carpeta en la lista")],
            [Lang.t("Ctrl+Mayús+N · Ctrl+N"), Lang.t("Carpeta nueva y archivo nuevo")], [Lang.t("Supr · Mayús+Supr"), Lang.t("A la papelera o para siempre")],
            [Lang.t("Ctrl+Mayús+C · Ctrl+Mayús+M"), Lang.t("Copiar o mover al otro panel")],
            ["Ctrl+I", Lang.t("Propiedades")], ["Ctrl+D", Lang.t("Marcador")]] },
        { name: Lang.t("VER Y BUSCAR"), keys: [
            [Lang.t("Espacio · ← →"), Lang.t("Vista rápida y pasar de archivo")], ["Ctrl+G", Lang.t("Lista o cuadrícula")], ["Ctrl+1 a Ctrl+4", Lang.t("Lista, cuadrícula, compacta, galería")], [Lang.t("Ctrl+más · Ctrl+menos"), "Zoom"], ["Ctrl+H", Lang.t("Ocultos")],
            [Lang.t("Ctrl+F · / · escribir"), Lang.t("Filtrar la carpeta")], ["Ctrl+Shift+F", Lang.t("Buscar dentro de los archivos")], ["Ctrl+Alt+F", Lang.t("Buscar en toda la carpeta personal")], ["Ctrl+K", Lang.t("Comandos")], ["Ctrl+,", Lang.t("Ajustes")], ["F1", Lang.t("Esta hoja")], ["Ctrl+Q", Lang.t("Salir")]] }
    ]

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
    z: 43

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
        width: Math.min(900, parent.width - Tokens.s5)
        height: Math.min(parent.height - Tokens.s5, head.height + grid.height + Tokens.s4 * 2)
        clip: true
        color: Tokens.paper
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Item {
            id: head
            width: parent.width
            height: 46

            Text {
                anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: Lang.t("// ATAJOS")
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
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Tokens.line
            }
        }

        Flickable {
            anchors { top: head.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: Tokens.s4
            contentHeight: grid.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        Grid {
            id: grid
            width: parent.width
            columns: sheet.width < 760 ? 1 : 2
            columnSpacing: Tokens.s5
            rowSpacing: Tokens.s4

            Repeater {
                model: sheet.groups

                Column {
                    id: group
                    required property var modelData
                    required property int index
                    width: grid.columns === 1 ? grid.width : (grid.width - Tokens.s5) / 2

                    Row {
                        spacing: Tokens.s2
                        height: 26

                        Text {
                            text: "0" + (group.index + 1)
                            color: Tokens.inkFaint
                            font.family: Tokens.mono
                            font.pixelSize: 9
                        }
                        Text {
                            text: group.modelData.name
                            color: Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            font.letterSpacing: 2
                        }
                    }
                    Repeater {
                        model: group.modelData.keys

                        Item {
                            id: line
                            required property var modelData
                            width: group.width
                            height: 30

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Tokens.lineSoft
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: line.modelData[1]
                                color: Tokens.inkDim
                                font.family: Tokens.ui
                                font.pixelSize: 13
                            }
                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: line.modelData[0].toUpperCase()
                                color: Tokens.inkMuted
                                font.family: Tokens.mono
                                font.pixelSize: 9
                                font.letterSpacing: 1
                            }
                        }
                    }
                }
            }
        }
        }
    }
}
