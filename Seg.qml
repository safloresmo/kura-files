import QtQuick

// A few named choices, one of them taken.
Row {
    id: seg

    property var options: []
    property string current: ""

    signal chose(string key)

    spacing: Tokens.s1

    Repeater {
        model: seg.options

        Rectangle {
            id: piece
            required property string modelData
            readonly property bool on: seg.current === modelData

            width: Math.max(52, label.implicitWidth + 18)
            height: 24
            radius: Tokens.radius
            color: on ? Tokens.bone : (hover.hovered ? Tokens.tint10 : "transparent")
            border.width: Tokens.border
            border.color: on ? Tokens.bone : (hover.hovered ? Tokens.lineStrong : Tokens.line)

            Text {
                id: label
                anchors.centerIn: parent
                text: piece.modelData
                color: piece.on ? Tokens.inkOnBone : Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 0.6
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: seg.chose(piece.modelData) }
        }
    }
}
