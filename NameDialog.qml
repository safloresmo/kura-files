import QtQuick

// A question asked over the window: a line of text, or a yes or no.
Item {
    id: dialog

    property string heading: ""
    property var done: null
    property string detail: ""
    property bool plain: false
    property string yesText: Lang.t("ACEPTAR")
    property var choices: []
    property bool masked: false
    // Runs when the question is put away without an answer.
    property var refused: null
    property bool emptyOk: false
    // Turns what is being typed into a line shown under the field.
    property var hint: null

    signal closed()
    readonly property string hintText: hint !== null && visible ? hint(field.text) : ""

    // The same, for something that should not be read over a shoulder.
    function askSecret(title, callback) {
        ask(title, "", callback);
        masked = true;
        emptyOk = true;
    }
    function ask(title, value, callback) {
        settle();
        heading = title;
        done = callback;
        plain = false;
        choices = [];
        yesText = Lang.t("ACEPTAR");
        field.text = value;
        visible = true;
        field.grabFocus();
    }
    // A question with several answers: `options` is a list of { text, act }.
    function choose(title, text, options) {
        settle();
        heading = title;
        detail = text;
        done = null;
        choices = options;
        plain = true;
        visible = true;
    }
    function pick(option) {
        refused = null;
        close();
        if (option.act)
            option.act();
    }
    // A yes or no question; the callback runs only on yes.
    function confirm(title, text, callback, yesLabel) {
        settle();
        choices = [];
        yesText = yesLabel || Lang.t("SÍ");
        heading = title;
        detail = text;
        done = callback;
        plain = true;
        visible = true;
        yes.forceActiveFocus();
    }
    // Say what to do if the question just asked goes unanswered.
    function preview(callback) {
        hint = callback;
    }
    function orElse(callback) {
        refused = callback;
    }
    function accept() {
        // A password is taken as typed, spaces and all.
        const value = plain ? "yes" : (masked ? field.text : field.text.trim());
        if (!plain && value === "" && !emptyOk) {
            // Nothing typed is not an answer: the question stays open.
            return;
        }
        const callback = done;
        refused = null;
        close();
        if (callback)
            callback(value);
    }
    // A line that may be left empty, which then means "the one offered".
    function askAny(title, value, callback) {
        ask(title, value, callback);
        emptyOk = true;
    }
    // A question asked while another is open puts that one away as unanswered
    // first, so whoever asked it is told, and nothing of it leaks into this one.
    function settle() {
        const gaveUp = visible ? refused : null;
        refused = null;
        masked = false;
        hint = null;
        emptyOk = false;
        if (gaveUp)
            gaveUp();
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        done = null;
        const gaveUp = refused;
        refused = null;
        if (gaveUp)
            gaveUp();
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
        width: Math.min(dialog.choices.length > 0 ? 620 : 440, dialog.width - Tokens.s5)
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
                secret: dialog.masked
                width: parent.width
                toolbar: true
                onAccepted: dialog.accept()
            }
            Text {
                visible: !dialog.plain && dialog.hint !== null
                width: parent.width
                wrapMode: Text.WordWrap
                text: visible ? dialog.hint(field.text) : ""
                color: Tokens.inkMuted
                font.family: Tokens.mono
                font.pixelSize: 11
                lineHeight: 1.3
            }
            Row {
                anchors.right: parent.right
                spacing: Tokens.s2

                Btn { text: Lang.t("CANCELAR"); onAct: dialog.close() }
                Repeater {
                    model: dialog.choices
                    Btn {
                        required property var modelData
                        required property int index
                        text: modelData.text
                        primary: index === dialog.choices.length - 1
                        onAct: dialog.pick(modelData)
                    }
                }
                Btn { id: yes; visible: dialog.choices.length === 0; text: dialog.yesText; primary: true; onAct: dialog.accept() }
            }
        }
    }
}
