pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The look of the whole window: colours, type and spacing in one place.
// Everything has a built-in value. `~/.config/archivos/tema.json` may replace
// any of them, and where the desktop publishes a palette taken from the
// wallpaper (its own file, or the one pywal and its relatives write) the
// colours follow it.
Singleton {
    id: t

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")

    // The user's own choices: { paper, paperLift, ink, inkDim, bone, inkOnBone, sun, ui, mono, scale }.
    property var own: ({})
    // The desktop's palette, by role, and whether it is meant to be followed.
    property var fromDesk: ({})
    property var wal: ({})
    readonly property var desk: Object.keys(fromDesk).length > 0 ? fromDesk : wal
    property var deskScheme: null
    property bool follow: true
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
    readonly property color alert: "#e2342a"

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

    readonly property int radius: px(6)
    readonly property real border: 1
    readonly property int railW: px(268)
    readonly property int snap: 90

    FileView {
        path: t.configDir + "/archivos/tema.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: t.own = t.parsed(text())
        onLoadFailed: t.own = ({})
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
            t.follow = typeof o.followWallpaper === "boolean" ? o.followWallpaper : true;
        }
        onLoadFailed: t.follow = true
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
