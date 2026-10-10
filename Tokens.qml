pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The look of the whole window: colours, type and spacing in one place.
// Everything has a built-in value. A theme (a file in `temas/`, here or in
// `~/.config/archivos/temas/`) may replace any of them, and so may
// `~/.config/archivos/tema.json`, which wins over the theme. Where the desktop
// publishes a palette taken from the wallpaper (its own file, or the one pywal
// and its relatives write) the colours follow it, unless the theme says no.
Singleton {
    id: t

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")

    // The user's own choices, over whatever theme is on. Same keys as a theme:
    // paper, paperLift, ink, inkDim, bone, inkOnBone, sun, ui, mono, scale,
    // radius, border, railWidth, rail ("left" or "right"), follow, hues.
    property var personal: ({})
    // The theme picked in the settings, by file name without ".json". The
    // folder of the themes that come with the program is told by the window.
    property string themeName: ""
    property string themeRoot: ""
    property var themeMine: ({})
    property var themeGiven: ({})
    readonly property var theme: Object.keys(themeMine).length > 0 ? themeMine : themeGiven
    // Both layers as one: what the user set by hand, then the theme.
    readonly property var own: {
        const all = {};
        for (const k in theme)
            all[k] = theme[k];
        for (const k in personal)
            all[k] = personal[k];
        return all;
    }
    function amount(key, base, low, high) {
        const v = own[key];
        return typeof v === "number" && v >= low && v <= high ? v : base;
    }
    // A file kind's own colour, when the theme names one.
    function hue(kind) {
        const table = own.hues;
        return table && usable(table[kind]) ? table[kind] : "";
    }
    readonly property bool railRight: own.rail === "right"
    // The desktop's palette, by role, and whether it is meant to be followed.
    property var fromDesk: ({})
    property var wal: ({})
    readonly property var desk: Object.keys(fromDesk).length > 0 ? fromDesk : wal
    property var deskScheme: null
    property bool followDesk: true
    readonly property bool follow: followDesk && own.follow !== false
    property string deskFont: ""
    property var screenScales: ({})

    function usable(v) {
        return typeof v === "string" && v.length > 0;
    }
    function parsed(text) {
        try {
            const o = text && text.length ? JSON.parse(text) : null;
            return o && typeof o === "object" ? o : {};
        } catch (e) {
            return {};
        }
    }
    // One colour: the user's, else the desktop's for that role, else ours.
    function tone(key, role, base) {
        if (usable(own[key]))
            return own[key];
        if (deskScheme && usable(deskScheme[role]))
            return deskScheme[role];
        if (follow && usable(desk[role]))
            return desk[role];
        return base;
    }
    function faded(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    readonly property color paper: tone("paper", "surface", "#000000")
    // On light paper the soft colours of the file kinds are deepened to stay readable.
    readonly property bool light: 0.299 * paper.r + 0.587 * paper.g + 0.114 * paper.b > 0.5
    function onPaper(colour) {
        return light ? Qt.darker(colour, 1.9) : colour;
    }
    readonly property color paperLift: tone("paperLift", "surfaceContainerLow", "#0a0a0a")
    readonly property color ink: tone("ink", "onSurface", "#cdc4ba")
    // A palette that only names its text colour gets the dimmer one from it.
    readonly property color inkDim: tone("inkDim", "onSurfaceVariant", followed && !usable(desk.onSurfaceVariant) ? Qt.tint(ink, faded(paper, 0.22)) : "#b0a9a0")
    readonly property bool followed: follow && usable(desk.onSurface)
    readonly property color inkMuted: faded(inkDim, 0.88)
    readonly property color inkFaint: faded(inkDim, 0.68)
    readonly property color bone: tone("bone", "inverseSurface", "#cdc4ba")
    readonly property color inkOnBone: tone("inkOnBone", "inverseOnSurface", "#000000")
    readonly property color inkOnBoneDim: faded(inkOnBone, 0.62)
    readonly property color line: faded(ink, 0.26)
    readonly property color lineSoft: faded(ink, 0.13)
    readonly property color lineStrong: faded(ink, 0.42)
    readonly property color tint5: faded(ink, 0.05)
    readonly property color tint10: faded(ink, 0.10)
    readonly property color tint16: faded(ink, 0.16)
    readonly property color sun: tone("sun", "primary", "#e2342a")
    readonly property color alert: usable(own.alert) ? own.alert : "#e2342a"

    readonly property string ui: usable(own.ui) ? own.ui : (deskFont !== "" ? deskFont : "Space Grotesk")
    readonly property string mono: usable(own.mono) ? own.mono : (deskFont !== "" ? deskFont : "SpaceMono Nerd Font")
    readonly property string jp: "Noto Sans CJK JP"

    // Sizes go through px() so one number makes the whole window larger or smaller.
    property real uiScale: 1
    readonly property real ownScale: typeof own.scale === "number" && own.scale > 0 ? Math.max(0.5, Math.min(2, own.scale)) : 1
    function uiScaleFor(screen) {
        const v = screen ? screenScales[screen] : undefined;
        return ownScale * (typeof v === "number" && v > 0 ? Math.max(0.5, Math.min(2, v)) : 1);
    }
    function px(n) {
        return Math.round(n * uiScale);
    }

    readonly property int fTitle: px(32)
    readonly property int fRow: px(15)
    readonly property int fBody: px(14)
    readonly property int fSmall: px(13)
    readonly property real trackLabel: 1.4
    readonly property real trackMark: 2.2

    readonly property int s1: px(4)
    readonly property int s2: px(8)
    readonly property int s3: px(12)
    readonly property int s4: px(16)
    readonly property int s5: px(24)
    readonly property int s6: px(32)
    readonly property int s7: px(48)

    readonly property int radius: px(amount("radius", 6, 0, 24))
    readonly property real border: amount("border", 1, 0, 4)
    readonly property int railW: px(amount("railWidth", 268, 200, 420))
    readonly property int snap: 90

    FileView {
        path: t.configDir + "/archivos/tema.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: t.personal = t.parsed(text())
        onLoadFailed: t.personal = ({})
    }
    FileView {
        path: t.themeName !== "" ? t.configDir + "/archivos/temas/" + t.themeName + ".json" : ""
        watchChanges: true
        printErrors: false
        onPathChanged: t.themeMine = ({})
        onFileChanged: reload()
        onLoaded: t.themeMine = t.parsed(text())
        onLoadFailed: t.themeMine = ({})
    }
    FileView {
        path: t.themeName !== "" && t.themeRoot !== "" ? t.themeRoot + "/" + t.themeName + ".json" : ""
        printErrors: false
        onPathChanged: t.themeGiven = ({})
        onLoaded: t.themeGiven = t.parsed(text())
        onLoadFailed: t.themeGiven = ({})
    }
    FileView {
        path: t.cacheDir + "/ryoku/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const next = t.parsed(text());
            // A file caught half written keeps the colours it replaces.
            if (Object.keys(next).length > 0)
                t.fromDesk = next;
        }
        onLoadFailed: t.fromDesk = ({})
    }
    // pywal's file, read only where the desktop has no palette of its own.
    FileView {
        path: t.cacheDir + "/wal/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const o = t.parsed(text());
            const special = o.special || {};
            const colors = o.colors || {};
            if (!t.usable(special.background) || !t.usable(special.foreground))
                return;
            t.wal = {
                surface: special.background,
                surfaceContainerLow: colors.color0 || special.background,
                onSurface: special.foreground,
                inverseSurface: special.foreground,
                inverseOnSurface: special.background,
                primary: colors.color4 || colors.color2 || special.foreground
            };
        }
        onLoadFailed: t.wal = ({})
    }
    FileView {
        path: t.configDir + "/ryoku/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const o = t.parsed(text());
            t.followDesk = typeof o.followWallpaper === "boolean" ? o.followWallpaper : true;
        }
        onLoadFailed: t.followDesk = true
    }
    FileView {
        path: t.configDir + "/ryoku/shell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const o = t.parsed(text());
            t.deskScheme = o.themePalette && typeof o.themePalette === "object" ? o.themePalette : null;
            t.deskFont = t.usable(o.fontFamily) ? o.fontFamily : "";
            t.screenScales = o.displays && o.displays.ui_scale && typeof o.displays.ui_scale === "object" ? o.displays.ui_scale : ({});
        }
        onLoadFailed: {
            t.deskScheme = null;
            t.deskFont = "";
            t.screenScales = ({});
        }
    }
}
