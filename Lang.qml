pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The words of the window in another language. The program is written in
// Spanish; a language is a file in `idiomas/` (here, or the user's own in
// `~/.config/archivos/idiomas/`) that gives each Spanish text its translation.
// A text with no translation is shown as it is.
Singleton {
    id: lang

    // The language picked in the settings; empty means the system's.
    property string wanted: ""
    // The folder of the languages that come with the program, told by the window.
    property string root: ""

    readonly property string system: {
        const set = Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "";
        const code = set.slice(0, 2).toLowerCase();
        return /^[a-z]{2}$/.test(code) ? code : "es";
    }
    readonly property string code: wanted !== "" ? wanted : system
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

    property var given: ({})
    property var mine: ({})
    // The user's file wins, text by text, over the one that comes along.
    readonly property var table: {
        const all = {};
        for (const k in given)
            all[k] = given[k];
        for (const k in mine)
            all[k] = mine[k];
        return all;
    }

    function parsed(text) {
        try {
            const o = text && text.length ? JSON.parse(text) : null;
            return o && typeof o === "object" ? o : {};
        } catch (e) {
            return {};
        }
    }
    // A text in the language on show. Spaces and punctuation at its ends are
    // kept as they are, so "COPIADO A " and "COPIADO A" are one entry.
    function t(text) {
        const parts = /^([\s·:…,.;«»()?!\/→+\-]*)([\s\S]*?)([\s·:…,.;«»()?!\/→+\-]*)$/.exec(text);
        if (!parts || parts[2] === "")
            return text;
        const found = table[parts[2]];
        return typeof found === "string" && found !== "" ? parts[1] + found + parts[3] : text;
    }
    // The same, word by word, for lines put together elsewhere ("hoy · 12:40").
    function words(text) {
        return String(text).split(" ").map(word => {
            const found = table[word];
            return typeof found === "string" && found !== "" ? found : word;
        }).join(" ");
    }
    // A message from the engine: its opening, up to the colon, is the entry.
    function message(text) {
        const cut = text.indexOf(": ");
        return cut < 0 ? t(text) : t(text.slice(0, cut)) + text.slice(cut);
    }

    FileView {
        path: lang.root !== "" ? lang.root + "/" + lang.code + ".json" : ""
        printErrors: false
        onPathChanged: lang.given = ({})
        onLoaded: lang.given = lang.parsed(text())
        onLoadFailed: lang.given = ({})
    }
    FileView {
        path: lang.configDir + "/archivos/idiomas/" + lang.code + ".json"
        watchChanges: true
        printErrors: false
        onPathChanged: lang.mine = ({})
        onFileChanged: reload()
        onLoaded: lang.mine = lang.parsed(text())
        onLoadFailed: lang.mine = ({})
    }
}
