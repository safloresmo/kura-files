import QtQuick

// Context menu drawn inside the window. Each entry is
// { label, hint, armed, act, sub } or { sep: true }; sub is a list of
// entries or a function returning one.
Item {
    id: menu

    property var items: []
    property int subIndex: -1
    property real atX: 0
    property real atY: 0
    readonly property var subItems: {
        const sub = subIndex >= 0 && items[subIndex] ? items[subIndex].sub : null;
        return typeof sub === "function" ? sub() : (sub || []);
    }

    signal closed()

    function popup(x, y, entries) {
        items = entries;
        subIndex = -1;
        atX = x;
        atY = y;
        visible = true;
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        items = [];
        closed();
    }

    anchors.fill: parent
    visible: false
    z: 50

    component Entry: Item {
        id: entry
        property var item: ({})
        property bool open: false
        readonly property bool armed: item.armed !== false
        signal chosen()
        signal entered()

        width: parent ? parent.width : 0
        height: item.sep ? 9 : 30

        Rectangle {
            visible: entry.item.sep === true
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            width: parent.width - 16
            height: 1
            color: Tokens.lineSoft
        }
        Rectangle {
            visible: !entry.item.sep
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            radius: Tokens.radius - 2
            color: entry.armed && (entryHover.hovered || entry.open) ? Tokens.tint10 : "transparent"
        }
        Text {
            visible: !entry.item.sep
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            width: parent.width - 28 - hint.width - 8
            elide: Text.ElideRight
            text: entry.item.label || ""
            color: entry.armed ? Tokens.ink : Tokens.inkFaint
            font.family: Tokens.ui
            font.pixelSize: 13
        }
        Text {
            id: hint
            visible: !entry.item.sep
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: entry.item.sub ? ">" : (entry.item.hint || "")
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 9
            font.letterSpacing: 1
        }
        HoverHandler {
            id: entryHover
            enabled: !entry.item.sep
            cursorShape: entry.armed ? Qt.PointingHandCursor : Qt.ArrowCursor
            onHoveredChanged: if (hovered) entry.entered()
        }
        TapHandler {
            enabled: !entry.item.sep && entry.armed
            onTapped: entry.chosen()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: panel
        x: Math.max(8, Math.min(menu.atX, menu.width - width - 8))
        y: Math.max(8, Math.min(menu.atY, menu.height - height - 8))
        width: 270
        height: list.height + 8
        color: Tokens.paperLift
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: list
            y: 4
            width: parent.width

            Repeater {
                model: menu.items

                Entry {
                    required property var modelData
                    required property int index
                    item: modelData
                    open: menu.subIndex === index
                    onEntered: menu.subIndex = modelData.sub ? index : -1
                    onChosen: {
                        if (modelData.sub)
                            return;
                        const act = modelData.act;
                        menu.close();
                        if (act)
                            act();
                    }
                }
            }
        }
    }

    Rectangle {
        id: side
        visible: menu.subIndex >= 0
        x: panel.x + panel.width + 4 + width > menu.width ? panel.x - width - 4 : panel.x + panel.width + 4
        y: {
            let top = panel.y + 4;
            for (let i = 0; i < menu.subIndex; i++)
                top += menu.items[i].sep ? 9 : 30;
            return Math.max(8, Math.min(top - 4, menu.height - height - 8));
        }
        width: 270
        height: sideList.height + 8
        color: Tokens.paperLift
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: sideList
            y: 4
            width: parent.width

            Repeater {
                model: menu.subItems

                Entry {
                    required property var modelData
                    item: modelData
                    onChosen: {
                        const act = modelData.act;
                        menu.close();
                        if (act)
                            act();
                    }
                }
            }
        }
    }
}
