import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The keyboard shortcuts, on one sheet.
Item {
    id: sheet

    readonly property var groups: [
        { name: "MOVERSE", keys: [
            ["Enter", "Abrir"], ["Retroceso · Alt+↑", "Subir una carpeta"], ["Alt+← · Alt+→", "Atrás y adelante"],
            ["Alt+Inicio", "Carpeta personal"], ["Ctrl+L", "Escribir una ruta"], ["Inicio · Fin", "Primero y último"], ["F5", "Actualizar"]] },
        { name: "SELECCIONAR", keys: [
            ["Ctrl+clic", "Añadir o quitar"], ["Mayús+clic · Mayús+↑↓", "Marcar un tramo"], ["Ctrl+A", "Todo"],
            ["Ctrl+Mayús+I", "Invertir"], ["Esc", "Soltar la selección"]] },
        { name: "ARCHIVOS", keys: [
            ["Ctrl+C · Ctrl+X · Ctrl+V", "Copiar, cortar y pegar"], ["Ctrl+Z", "Deshacer"], ["F2", "Renombrar"],
            ["Ctrl+Mayús+N · Ctrl+N", "Carpeta nueva y archivo nuevo"], ["Supr", "A la papelera"],
            ["Ctrl+I", "Propiedades"], ["Ctrl+D", "Marcador"]] },
        { name: "VER Y BUSCAR", keys: [
            ["Espacio", "Vista rápida"], ["Ctrl+G", "Lista o cuadrícula"], ["Ctrl+H", "Ocultos"],
            ["Ctrl+F · / · escribir", "Filtrar la carpeta"], ["Ctrl+K", "Comandos"], ["F1", "Esta hoja"], ["Ctrl+Q", "Salir"]] }
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
        width: Math.min(900, parent.width - Tokens.s7)
        height: head.height + grid.height + Tokens.s5
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

        Grid {
            id: grid
            anchors { top: head.bottom; left: parent.left; right: parent.right }
            anchors.margins: Tokens.s4
            columns: 2
            columnSpacing: Tokens.s5
            rowSpacing: Tokens.s4

            Repeater {
                model: sheet.groups

                Column {
                    id: group
                    required property var modelData
                    required property int index
                    width: (grid.width - Tokens.s5) / 2

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
