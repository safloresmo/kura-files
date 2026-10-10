import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

// The picture that stands for one entry, in the style chosen in the settings:
// a line glyph, a sheet with the extension written on it, or the icon the
// system theme has for that kind of file.
Item {
    id: icon

    required property var app
    property string name: ""
    property string path: ""
    property bool isDir: false
    property real size: 18
    // Small icons have no room for a written extension, so they stay glyphs.
    property bool large: false

    readonly property string glyph: app.iconFor(name, path, isDir)
    readonly property color tone: app.toneFor(name, path, isDir)
    readonly property string style: app.iconStyle === "system" ? "system"
        : (app.iconStyle === "sheet" && large && !isDir ? "sheet" : "line")
    readonly property bool written: style === "sheet"

    readonly property var themed: ({
            "folder": "folder", "home": "user-home", "desktop": "user-desktop", "download": "folder-download",
            "trash": "user-trash", "image": "image-x-generic", "video": "video-x-generic", "music": "audio-x-generic",
            "archive": "package-x-generic", "package": "application-x-executable", "disc": "application-x-cd-image",
            "script": "text-x-script", "code": "text-x-script", "config": "text-x-generic", "pdf": "application-pdf",
            "doc": "text-x-generic", "data": "x-office-spreadsheet", "font": "font-x-generic",
            "key": "application-pgp-keys", "model": "application-x-blender", "print": "text-x-generic",
            "board": "application-x-kicad-pcb", "file": "application-octet-stream", "web": "text-html",
            "sheet": "x-office-spreadsheet", "slides": "x-office-presentation", "book": "application-epub+zip",
            "vector": "image-svg+xml", "mail": "message-rfc822", "calendar": "text-calendar", "contact": "text-vcard",
            "lock": "application-pgp-encrypted", "lib": "application-x-sharedlib", "log": "text-x-log",
            "game": "applications-games", "notebook": "application-x-ipynb+json", "diff": "text-x-patch",
            "wave": "audio-x-generic", "subtitle": "text-x-generic", "chip": "application-x-firmware",
            "shader": "text-x-script", "draft": "image-vnd.dxf", "link": "text-html", "seal": "text-x-copying",
            "info": "text-x-readme", "git": "text-x-generic", "container": "text-dockerfile", "list": "audio-x-mpegurl",
            "map": "application-gpx+xml"
        })
    readonly property string themedName: {
        if (isDir) {
            const special = { "doc": "folder-documents", "music": "folder-music", "image": "folder-pictures", "video": "folder-videos" };
            return special[glyph] || themed[glyph] || "folder";
        }
        return themed[glyph] || "application-octet-stream";
    }

    width: size
    height: size

    Icon {
        anchors.centerIn: parent
        visible: icon.style !== "system"
        name: icon.written ? "file" : icon.glyph
        size: icon.size
        color: icon.tone
    }
    Text {
        visible: icon.written
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(icon.size * 0.50)
        text: icon.app.tagFor(icon.name, false).slice(0, 4)
        color: icon.tone
        font.family: Tokens.mono
        font.pixelSize: Math.max(7, Math.round(icon.size * (text.length > 3 ? 0.16 : 0.21)))
        font.bold: true
    }
    Image {
        anchors.fill: parent
        visible: icon.style === "system"
        source: visible ? Quickshell.iconPath(icon.themedName, isDir ? "folder" : "application-octet-stream") : ""
        sourceSize.width: Math.round(icon.size * 2)
        sourceSize.height: Math.round(icon.size * 2)
        asynchronous: true
    }
}
