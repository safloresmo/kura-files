import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The open tabs, shown once there is more than one.
Row {
    id: strip

    required property var app

    visible: app.tabs.length > 1
    height: visible ? 30 : 0
    spacing: Tokens.s2
    clip: true

    Repeater {
        model: app.tabs

        Rectangle {
            id: chip
            required property var modelData
            required property int index
            readonly property bool on: app.tab === index

            width: Math.min(220, chipRow.width + Tokens.s4)
            height: 30
            radius: Tokens.radius
            color: on ? Tokens.bone : (chipHover.hovered ? Tokens.tint10 : "transparent")
            border.width: Tokens.border
            border.color: on ? Tokens.bone : Tokens.line

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Tokens.s2

                Text {
                    visible: chip.on
                    text: "//"
                    color: Tokens.inkOnBoneDim
                    font.family: Tokens.mono
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: app.nameOf(chip.on ? app.path : chip.modelData.path).toUpperCase()
                    color: chip.on ? Tokens.inkOnBone : Tokens.inkDim
                    font.family: Tokens.ui
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackLabel
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 150)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "×"
                    color: chip.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                    font.family: Tokens.ui
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    TapHandler { onTapped: app.closeTab(chip.index) }
                }
            }
            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: app.showTab(chip.index) }
            TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: app.closeTab(chip.index) }
        }
    }
    Btn { text: "+"; width: 34; height: 30; onAct: app.newTab() }
}
