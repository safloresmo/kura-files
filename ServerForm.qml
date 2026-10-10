import QtQuick

// A new server: what kind, where, and who to enter as.
Item {
    id: form

    required property var app
    property string kind: "SFTP"
    readonly property var schemes: ({ "SFTP": "sftp", "FTP": "ftp", "SMB": "smb", "WEBDAV": "davs" })
    readonly property var ports: ({ "SFTP": "22", "FTP": "21", "SMB": "445", "WEBDAV": "443" })

    signal closed()

    function open() {
        kind = "SFTP";
        for (const f of [host, port, user, pass, folder, nick])
            f.text = "";
        visible = true;
        host.grabFocus();
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        pass.text = "";
        closed();
    }
    // The address as the system wants it; the password is never part of it.
    function uri() {
        const who = user.text.trim();
        const where = host.text.trim();
        const door = port.text.trim();
        const path = folder.text.trim().replace(/^\/+/, "");
        return schemes[kind] + "://" + (who !== "" ? encodeURIComponent(who) + "@" : "") + where
            + (door !== "" && door !== ports[kind] ? ":" + door : "") + "/" + path;
    }
    function accept() {
        const where = host.text.trim();
        if (where === "" || /[\s\/]/.test(where)) {
            app.say(Lang.t("ESCRIBE EL SERVIDOR"), true);
            return;
        }
        if (port.text.trim() !== "" && !/^[0-9]{1,5}$/.test(port.text.trim())) {
            app.say(Lang.t("EL PUERTO ES UN NÚMERO"), true);
            return;
        }
        const server = { name: nick.text.trim() || where, uri: uri() };
        const word = pass.text;
        close();
        app.addServerEntry(server, word);
    }

    anchors.fill: parent
    visible: false
    z: 60

    component Line: Item {
        property string label: ""
        default property alias content: slot.data

        width: parent.width
        height: 36

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
        }
        Item {
            id: slot
            anchors { left: parent.left; leftMargin: 120; right: parent.right; top: parent.top; bottom: parent.bottom }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: form.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(480, form.width - Tokens.s5)
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
            spacing: Tokens.s2

            Text {
                bottomPadding: Tokens.s2
                text: Lang.t("// NUEVO SERVIDOR")
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: 12
                font.letterSpacing: Tokens.trackLabel
            }
            Line {
                label: Lang.t("Tipo")
                Seg {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["SFTP", "FTP", "SMB", "WEBDAV"]
                    current: form.kind
                    onChose: key => form.kind = key
                }
            }
            Line {
                label: Lang.t("Servidor")
                Field { id: host; Keys.onTabPressed: port.grabFocus(); Keys.onBacktabPressed: nick.grabFocus(); anchors.fill: parent; toolbar: true; tabular: true; placeholder: Lang.t("equipo.ejemplo.com o 192.168.1.20"); onAccepted: form.accept() }
            }
            Line {
                label: Lang.t("Puerto")
                Field { id: port; Keys.onTabPressed: user.grabFocus(); Keys.onBacktabPressed: host.grabFocus(); anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 110; toolbar: true; tabular: true; placeholder: form.ports[form.kind]; onAccepted: form.accept() }
            }
            Line {
                label: Lang.t("Usuario")
                Field { id: user; Keys.onTabPressed: pass.grabFocus(); Keys.onBacktabPressed: port.grabFocus(); anchors.fill: parent; toolbar: true; tabular: true; placeholder: Lang.t("opcional"); onAccepted: form.accept() }
            }
            Line {
                label: Lang.t("Contraseña")
                Field { id: pass; Keys.onTabPressed: folder.grabFocus(); Keys.onBacktabPressed: user.grabFocus(); anchors.fill: parent; toolbar: true; secret: true; placeholder: Lang.t("no se guarda; vacía si entras con llave"); onAccepted: form.accept() }
            }
            Line {
                label: form.kind === "SMB" ? Lang.t("Recurso") : Lang.t("Carpeta")
                Field { id: folder; Keys.onTabPressed: nick.grabFocus(); Keys.onBacktabPressed: pass.grabFocus(); anchors.fill: parent; toolbar: true; tabular: true; placeholder: form.kind === "SMB" ? Lang.t("nombre de la carpeta compartida") : Lang.t("opcional, por ejemplo /srv/datos"); onAccepted: form.accept() }
            }
            Line {
                label: Lang.t("Nombre")
                Field { id: nick; Keys.onTabPressed: host.grabFocus(); Keys.onBacktabPressed: folder.grabFocus(); anchors.fill: parent; toolbar: true; placeholder: Lang.t("cómo aparece en la lista"); onAccepted: form.accept() }
            }
            Text {
                width: parent.width
                topPadding: Tokens.s1
                elide: Text.ElideMiddle
                text: host.text.trim() === "" ? " " : form.uri()
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 10
            }
            Row {
                anchors.right: parent.right
                topPadding: Tokens.s2
                spacing: Tokens.s2

                Btn { text: Lang.t("CANCELAR"); onAct: form.close() }
                Btn { text: Lang.t("GUARDAR Y CONECTAR"); primary: true; onAct: form.accept() }
            }
        }
    }
}
