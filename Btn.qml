import QtQuick

// A button: a framed label that fills when it is the main choice.
Rectangle {
    id: btn

    property alias text: label.text
    property bool primary: false
    property bool armed: true
    property bool compact: false

    signal act()

    function activate() {
        if (armed)
            act();
    }

    implicitWidth: label.width + (compact ? 20 : 30)
    implicitHeight: compact ? 24 : 32
    radius: Tokens.radius
    opacity: armed ? 1 : 0.5
    color: primary && armed ? Tokens.bone
        : (press.pressed && armed ? Tokens.tint16 : (hover.hovered && armed ? Tokens.tint10 : "transparent"))
    border.width: Tokens.border
    border.color: activeFocus || (primary && armed) ? Tokens.bone : (hover.hovered && armed ? Tokens.lineStrong : Tokens.line)
    activeFocusOnTab: true

    Behavior on color { ColorAnimation { duration: Tokens.snap } }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activate();
            event.accepted = true;
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: btn.primary && btn.armed ? Tokens.inkOnBone : Tokens.ink
        font.family: Tokens.ui
        font.pixelSize: btn.compact ? 10 : 11
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackLabel
    }
    HoverHandler { id: hover; cursorShape: btn.armed ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { id: press; onTapped: btn.activate() }
}
