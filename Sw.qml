import QtQuick

// A switch: the knob sits right and lit when it is on.
Rectangle {
    id: sw

    property bool on: false

    signal toggled(bool v)

    function activate() {
        toggled(!on);
    }

    implicitWidth: 54
    implicitHeight: 24
    radius: Tokens.radius
    color: on ? Tokens.tint16 : Tokens.tint5
    border.width: Tokens.border
    border.color: activeFocus ? Tokens.bone : (on ? Tokens.lineStrong : Tokens.line)
    activeFocusOnTab: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activate();
            event.accepted = true;
        }
    }

    Rectangle {
        width: 25
        height: 17
        x: sw.on ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        radius: Tokens.radius
        color: sw.on ? Tokens.bone : Tokens.inkFaint

        Behavior on x { NumberAnimation { duration: Tokens.snap } }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: sw.activate() }
}
