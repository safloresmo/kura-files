import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The keyboard shortcuts, on one sheet.
Item {
    id: sheet

    readonly property var groups: [
        { name: "MOVERSE", keys: [
            ["Enter", "Abrir"], ["Retroceso · Alt+↑", "Subir una carpeta"], ["Alt+← · Alt+→", "Atrás y adelante"],
            ["Alt+Inicio", "Carpeta personal"], ["Ctrl+L · Tab", "Escribir una ruta y completarla"], ["Inicio · Fin", "Primero y último"], ["F5", "Actualizar"],
            ["Ctrl+T · Ctrl+W", "Pestaña nueva y cerrar"], ["Ctrl+RePág · AvPág", "Cambiar de pestaña"], ["F6 · Tab", "Segundo panel y cambiar"]] },
        { name: "SELECCIONAR", keys: [
            ["Ctrl+clic", "Añadir o quitar"], ["Mayús+clic · Mayús+↑↓", "Marcar un tramo"], ["Ctrl+A", "Todo"],
            ["Ctrl+Mayús+I", "Invertir"], ["Esc", "Soltar la selección"]] },
        { name: "ARCHIVOS", keys: [
            ["Ctrl+C · Ctrl+X · Ctrl+V", "Copiar, cortar y pegar"], ["Ctrl+Z · Ctrl+Mayús+Z", "Deshacer y rehacer"], ["F2 · Ctrl+Mayús+D", "Renombrar y duplicar"], ["Ctrl+Mayús+L", "Crear un enlace"],
            ["Ctrl+Mayús+N · Ctrl+N", "Carpeta nueva y archivo nuevo"], ["Supr · Mayús+Supr", "A la papelera o para siempre"],
            ["Ctrl+Mayús+C · Ctrl+Mayús+M", "Copiar o mover al otro panel"],
            ["Ctrl+I", "Propiedades"], ["Ctrl+D", "Marcador"]] },
        { name: "VER Y BUSCAR", keys: [
            ["Espacio · ← →", "Vista rápida y pasar de archivo"], ["Ctrl+G", "Lista o cuadrícula"], ["Ctrl+1 a Ctrl+4", "Lista, cuadrícula, compacta, galería"], ["Ctrl+más · Ctrl+menos", "Zoom"], ["Ctrl+H", "Ocultos"],
            ["Ctrl+F · / · escribir", "Filtrar la carpeta"], ["Ctrl+Shift+F", "Buscar dentro de los archivos"], ["Ctrl+K", "Comandos"], ["Ctrl+,", "Ajustes"], ["F1", "Esta hoja"], ["Ctrl+Q", "Salir"]] }
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
                text: "// ATAJOS"
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
