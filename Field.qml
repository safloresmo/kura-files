import QtQuick

// A line of text to type in.
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: ""
    // Monospaced, for what a file would hold: paths, addresses, numbers.
    property bool tabular: false
    // Taller, to sit in a row of buttons.
    property bool toolbar: false
    // Masked, for a password.
    property bool secret: false
    readonly property bool focused: input.activeFocus

    signal committed(string value)
    signal edited(string value)
    signal accepted()

    function clear() {
        input.text = "";
    }
    function grabFocus() {
        input.forceActiveFocus();
    }

    implicitWidth: 200
    implicitHeight: toolbar ? 36 : 30
    radius: Tokens.radius
    color: "transparent"
    border.width: input.activeFocus ? 2 : Tokens.border
    border.color: input.activeFocus ? Tokens.ink : (hover.hovered ? Tokens.lineStrong : Tokens.line)

    Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
    HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        echoMode: field.secret ? TextInput.Password : TextInput.Normal
        color: Tokens.ink
        selectionColor: Tokens.bone
        selectedTextColor: Tokens.inkOnBone
        font.family: field.tabular ? Tokens.mono : Tokens.ui
        font.pixelSize: field.tabular ? 11 : 12
        onTextEdited: field.edited(text)
        // Escape empties the field, and says so like any other edit.
        Keys.onEscapePressed: {
            text = "";
            field.edited("");
        }
        onAccepted: {
            field.committed(text);
            field.accepted();
        }
        onActiveFocusChanged: {
            if (!activeFocus)
                field.committed(text);
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && input.preeditText === ""
            width: parent.width
            elide: Text.ElideRight
            text: field.placeholder
            color: Tokens.inkFaint
            font: input.font
        }
    }
}
