import QtQuick

// What a list shows when it has nothing to show.
Column {
    id: empty

    property string caption: ""

    spacing: Tokens.s3

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 116
        height: 116
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.lineSoft

        Text {
            anchors.centerIn: parent
            text: "空"
            color: Tokens.inkDim
            font.family: Tokens.jp
            font.pixelSize: 42
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Lang.t("// VACÍO")
        color: Tokens.inkDim
        font.family: Tokens.mono
        font.pixelSize: 10
        font.letterSpacing: 1.4
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, 380)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: empty.caption
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fSmall
    }
}
