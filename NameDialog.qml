import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// A question asked over the window: a line of text, or a yes or no.
Item {
    id: dialog

    property string heading: ""
    property var done: null
    property string detail: ""
    property bool plain: false
    property string yesText: "ACEPTAR"

    signal closed()

    function ask(title, value, callback) {
        heading = title;
        done = callback;
        plain = false;
        yesText = "ACEPTAR";
        field.text = value;
        visible = true;
        field.grabFocus();
    }
    // A yes or no question; the callback runs only on yes.
    function confirm(title, text, callback, yesLabel) {
        yesText = yesLabel || "SÍ";
        heading = title;
        detail = text;
        done = callback;
        plain = true;
        visible = true;
        yes.forceActiveFocus();
    }
    function accept() {
        const value = plain ? "yes" : field.text.trim();
        const callback = done;
        close();
        if (callback && value !== "")
            callback(value);
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        done = null;
        closed();
    }

    anchors.fill: parent
    visible: false
    z: 60

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: dialog.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        anchors.centerIn: parent
        width: 440
        height: body.height + Tokens.s5 * 2
        color: Tokens.paper
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: Tokens.line

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: body
            x: Tokens.s5
            y: Tokens.s5
            width: parent.width - Tokens.s5 * 2
            spacing: Tokens.s4

            Text {
                text: "// " + dialog.heading
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: 12
                font.letterSpacing: Tokens.trackLabel
            }
            Text {
                visible: dialog.plain
                width: parent.width
                text: dialog.detail
                wrapMode: Text.WordWrap
                color: Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: Tokens.fBody
            }
            Field {
                id: field
                visible: !dialog.plain
                width: parent.width
                toolbar: true
                onAccepted: dialog.accept()
            }
            Row {
                anchors.right: parent.right
                spacing: Tokens.s2

                Btn { text: "CANCELAR"; onAct: dialog.close() }
                Btn { id: yes; text: dialog.yesText; primary: true; onAct: dialog.accept() }
            }
        }
    }
}
