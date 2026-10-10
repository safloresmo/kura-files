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
            height: 36
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
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: brandName
                        text: rail.app.brand.name
                        color: Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        font.letterSpacing: 2.4
                    }
                    Text {
                        visible: text !== "" && brandName.width + implicitWidth < rail.width - 110
                        text: rail.app.brand.tag
                        color: Tokens.inkMuted
                        font.family: Tokens.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                        anchors.baseline: brandName.baseline
                    }
                }
            }
        }

        Field {
            id: filterField
            width: parent.width
            toolbar: true
            placeholder: "Filtrar esta carpeta…"
            onEdited: t => rail.app.query = t
            onAccepted: rail.app.focusList()
        }
        Btn {
            visible: rail.app.query !== "" && !rail.app.inTrash
            width: parent.width
            compact: true
            text: "BUSCAR EN SUBCARPETAS"
            onAct: rail.app.search(rail.app.query)
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
                    readonly property bool special: modelData.special === "recent"
                    readonly property bool sel: special ? rail.app.recent : (!rail.app.recent && rail.app.path === modelData.path)

                    width: list.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: Tokens.radius
                        color: place.sel ? Tokens.bone : (placeDrop.containsDrag ? Tokens.tint16 : (placeHover.hovered ? Tokens.tint10 : "transparent"))
                        border.width: placeDrop.containsDrag ? Tokens.border : 0
                        border.color: Tokens.lineStrong
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
                    TapHandler { onTapped: place.special ? rail.app.showRecent() : rail.app.go(place.modelData.path) }
                    DropArea {
                        id: placeDrop
                        anchors.fill: parent
                        enabled: !place.special
                        onDropped: drop => {
                            rail.app.dropOn(place.modelData.path, drop.urls);
                            drop.accept(Qt.CopyAction);
                        }
                    }
                }
            }

            Item { width: 1; height: rail.app.bookmarks.length > 0 ? Tokens.s2 : 0 }
            GroupHead {
                visible: rail.app.bookmarks.length > 0
                height: visible ? 34 : 0
                number: 2
                label: "MARCADORES"
            }

            Repeater {
                model: rail.app.bookmarks

                Item {
                    id: mark
                    required property var modelData
                    readonly property bool sel: rail.app.path === modelData.path

                    width: list.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: Tokens.radius
                        color: mark.sel ? Tokens.bone : (markDrop.containsDrag ? Tokens.tint16 : (markHover.hovered ? Tokens.tint10 : "transparent"))
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                    }
                    Row {
                        x: Tokens.s3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s2

                        Text {
                            visible: mark.sel
                            text: "//"
                            color: Tokens.inkOnBoneDim
                            font.family: Tokens.mono
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Icon {
                            visible: !mark.sel
                            name: "folder"
                            size: 16
                            color: Tokens.inkFaint
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: mark.modelData.name
                            color: mark.sel ? Tokens.inkOnBone : Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, list.width - 60)
                        }
                    }
                    HoverHandler { id: markHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: rail.app.go(mark.modelData.path) }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: point => {
                            const scene = mark.mapToItem(null, point.position.x, point.position.y);
                            rail.app.bookmarkMenu(mark.modelData, scene.x, scene.y);
                        }
                    }
                    DropArea {
                        id: markDrop
                        anchors.fill: parent
                        onDropped: drop => {
                            rail.app.dropOn(mark.modelData.path, drop.urls);
                            drop.accept(Qt.CopyAction);
                        }
                    }
                }
            }

            Item { width: 1; height: Tokens.s2 }
            GroupHead { id: devicesHead; number: rail.app.bookmarks.length > 0 ? 3 : 2; label: "DISPOSITIVOS" }

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
                        color: device.sel || deviceDrop.containsDrag ? Tokens.tint16 : (deviceHover.hovered ? Tokens.tint10 : "transparent")
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
                    DropArea {
                        id: deviceDrop
                        anchors.fill: parent
                        enabled: device.modelData.mounted
                        onDropped: drop => {
                            rail.app.dropOn(device.modelData.path, drop.urls);
                            drop.accept(Qt.CopyAction);
                        }
                    }

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

            Item { width: 1; height: Tokens.s2 }
            GroupHead { number: devicesHead.number + 1; label: "RED" }

            Repeater {
                model: rail.app.servers

                Item {
                    id: server
                    required property var modelData
                    readonly property string mounted: rail.app.remotes[modelData.uri] || ""
                    readonly property bool sel: mounted !== "" && (rail.app.path === mounted || rail.app.path.indexOf(mounted + "/") === 0)

                    width: list.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: Tokens.radius
                        color: server.sel ? Tokens.bone : (serverHover.hovered ? Tokens.tint10 : "transparent")
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                    }
                    Row {
                        x: Tokens.s3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s2

                        Text {
                            visible: server.sel
                            text: "//"
                            color: Tokens.inkOnBoneDim
                            font.family: Tokens.mono
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Icon {
                            visible: !server.sel
                            name: "network"
                            size: 16
                            color: Tokens.inkFaint
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: server.modelData.name
                            color: server.sel ? Tokens.inkOnBone : (server.mounted !== "" ? Tokens.inkDim : Tokens.inkFaint)
                            font.family: Tokens.ui
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, list.width - 110)
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                        text: server.mounted !== "" ? "接続" : "CONECTAR"
                        color: server.sel ? Tokens.inkOnBoneDim : Tokens.inkFaint
                        font.family: server.mounted !== "" ? Tokens.jp : Tokens.mono
                        font.pixelSize: server.mounted !== "" ? 12 : 9
                        font.letterSpacing: server.mounted !== "" ? 0 : 1.4
                    }
                    HoverHandler { id: serverHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: rail.app.connectServer(server.modelData) }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: point => {
                            const scene = server.mapToItem(null, point.position.x, point.position.y);
                            rail.app.serverMenu(server.modelData, scene.x, scene.y);
                        }
                    }
                }
            }

            Item {
                width: list.width
                height: 34

                Text {
                    x: Tokens.s3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+  AÑADIR SERVIDOR"
                    color: addHover.hovered ? Tokens.ink : Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                }
                HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: rail.app.addServer() }
            }

            Item { visible: rail.app.labelCounts.length > 0; width: 1; height: visible ? Tokens.s2 : 0 }
            GroupHead { visible: rail.app.labelCounts.length > 0; height: visible ? 34 : 0; number: devicesHead.number + 2; label: "ETIQUETAS" }

            Repeater {
                model: rail.app.labelCounts

                Item {
                    id: tagRow
                    required property var modelData
                    readonly property bool sel: rail.app.deep && rail.app.labelShown === modelData.key && rail.app.deepQuery.indexOf("etiqueta ") === 0

                    width: list.width
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius
                        color: tagRow.sel ? Tokens.tint10 : (tagHover.hovered ? Tokens.tint5 : "transparent")
                    }
                    Rectangle {
                        x: Tokens.s3 + 4
                        width: 10
                        height: 10
                        radius: 5
                        color: tagRow.modelData.hue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        x: Tokens.s3 + 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: tagRow.modelData.name
                        color: tagRow.sel ? Tokens.ink : Tokens.inkDim
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fRow
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                        text: tagRow.modelData.count
                        color: Tokens.inkFaint
                        font.family: Tokens.mono
                        font.pixelSize: 10
                    }
                    HoverHandler { id: tagHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: rail.app.showLabel(tagRow.modelData.key) }
                }
            }
        }
    }
}
