import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Left rail: masthead, filter field, places and mounted devices.
Item {
    id: rail

    required property var app
    property alias filter: filterField

    width: Tokens.railW

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Tokens.line
    }

    component GroupHead: Item {
        property int number: 1
        property string label: ""

        width: parent.width
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s2

            Text {
                text: "0" + number
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: headLabel
                text: label
                color: Tokens.inkFaint
                font.family: Tokens.ui
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 2
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: Math.max(0, list.width - headLabel.width - 40)
                height: 1
                color: Tokens.lineSoft
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: Tokens.s5
        spacing: Tokens.s4

        Rectangle {
            width: parent.width
            height: 64
            color: "transparent"
            radius: Tokens.radius
            border.width: Tokens.border
            border.color: Tokens.line

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s4 }
                spacing: Tokens.s3

                Text {
                    text: rail.app.brand.mark
                    color: Tokens.ink
                    font.family: Tokens.jp
                    font.pixelSize: 22
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: rail.app.brand.name
                        color: Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        font.letterSpacing: 2.4
                    }
                    Text {
                        text: rail.app.brand.tag
                        color: Tokens.inkMuted
                        font.family: Tokens.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                    }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: rail.app.toggleBrand() }
        }

        Field {
            id: filterField
            width: parent.width
            toolbar: true
            placeholder: "Filtrar esta carpeta…"
            onEdited: t => rail.app.query = t
            onAccepted: rail.app.focusList()
        }
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
        anchors.leftMargin: Tokens.s5
        anchors.rightMargin: Tokens.s5
        anchors.topMargin: Tokens.s3
        contentHeight: list.height + Tokens.s4
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: flick.width

            GroupHead { number: 1; label: "LUGARES" }

            Repeater {
                model: rail.app.places

                Item {
                    id: place
                    required property var modelData
                    readonly property bool sel: rail.app.path === modelData.path

                    width: list.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: Tokens.radius
                        color: place.sel ? Tokens.bone : (placeHover.hovered ? Tokens.tint10 : "transparent")
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                    }
                    Row {
                        x: Tokens.s3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s2

                        Text {
                            visible: place.sel
                            text: "//"
                            color: Tokens.inkOnBoneDim
                            font.family: Tokens.mono
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Icon {
                            visible: !place.sel
                            name: place.modelData.icon
                            size: 16
                            color: Tokens.inkFaint
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: place.modelData.name
                            color: place.sel ? Tokens.inkOnBone : Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, list.width - 90)
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                        text: place.modelData.seal
                        color: place.sel ? Tokens.inkOnBoneDim : Tokens.inkFaint
                        font.family: Tokens.jp
                        font.pixelSize: 12
                    }
                    HoverHandler { id: placeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: rail.app.go(place.modelData.path) }
                }
            }

            Item { width: 1; height: Tokens.s2 }
            GroupHead { number: 2; label: "DISPOSITIVOS" }

            Repeater {
                model: rail.app.devices

                Item {
                    id: device
                    required property var modelData
                    readonly property bool sel: modelData.mounted && rail.app.path === modelData.path

                    width: list.width
                    height: modelData.mounted ? 46 : 36

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: Tokens.radius
                        color: device.sel ? Tokens.tint16 : (deviceHover.hovered ? Tokens.tint10 : "transparent")
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                    }
                    Row {
                        x: Tokens.s3
                        y: device.modelData.mounted ? 8 : 9
                        spacing: Tokens.s2

                        Icon {
                            name: device.modelData.removable ? "usb" : "disk"
                            size: 16
                            color: Tokens.inkFaint
                        }
                        Text {
                            text: device.modelData.name
                            color: device.sel ? Tokens.ink : (device.modelData.mounted ? Tokens.inkDim : Tokens.inkFaint)
                            font.family: Tokens.ui
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, list.width - 100)
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Tokens.s3 + (ejectButton.visible ? 22 : 0) }
                        y: device.modelData.mounted ? 11 : 12
                        text: device.modelData.mounted ? device.modelData.used + "%" : "MONTAR"
                        color: Tokens.inkFaint
                        font.family: Tokens.mono
                        font.pixelSize: device.modelData.mounted ? 10 : 9
                        font.letterSpacing: device.modelData.mounted ? 0 : 1.4
                    }
                    Rectangle {
                        visible: device.modelData.mounted
                        x: Tokens.s3 + 24
                        y: 34
                        width: parent.width - x - Tokens.s3
                        height: 2
                        color: Tokens.lineSoft

                        Rectangle {
                            width: parent.width * Math.min(100, device.modelData.used) / 100
                            height: parent.height
                            color: device.modelData.used >= 90 ? Tokens.alert : Tokens.sun
                        }
                    }
                    HoverHandler { id: deviceHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: device.modelData.mounted ? rail.app.go(device.modelData.path) : rail.app.mount(device.modelData) }

                    Item {
                        id: ejectButton
                        visible: device.modelData.mounted && device.modelData.removable && deviceHover.hovered
                        anchors { right: parent.right; rightMargin: Tokens.s2 }
                        y: 6
                        width: 22
                        height: 22

                        Icon {
                            anchors.centerIn: parent
                            name: "eject"
                            size: 14
                            color: ejectHover.hovered ? Tokens.ink : Tokens.inkFaint
                        }
                        HoverHandler { id: ejectHover }
                        TapHandler { onTapped: rail.app.eject(device.modelData) }
                    }
                }
            }
        }
    }
}
