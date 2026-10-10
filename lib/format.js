.pragma library

const UNITS = ["B", "KiB", "MiB", "GiB", "TiB"];
const MONTHS = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

// What a file is, told from its name: an icon, and a tone that groups it with
// its relatives. The first family that lists the extension wins.
const FAMILIES = [
    { icon: "image", tone: "media", ext: ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "avif", "ico", "tiff", "heic", "xcf", "psd", "kra"] },
    { icon: "video", tone: "media", ext: ["mp4", "mkv", "webm", "mov", "avi", "m4v", "flv", "wmv"] },
    { icon: "music", tone: "media", ext: ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac", "mid"] },
    { icon: "archive", tone: "archive", ext: ["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2", "tgz", "lz4"] },
    { icon: "package", tone: "archive", ext: ["deb", "rpm", "pkg", "appimage", "flatpak", "apk", "jar", "exe", "msi", "vpk"] },
    { icon: "disc", tone: "archive", ext: ["iso", "img", "qcow2", "vdi", "vmdk"] },
    { icon: "script", tone: "code", ext: ["sh", "bash", "zsh", "fish", "ps1", "bat"] },
    { icon: "code", tone: "code", ext: ["rs", "py", "js", "mjs", "ts", "tsx", "jsx", "qml", "c", "h", "cpp", "hpp", "go", "lua", "java",
        "kt", "swift", "rb", "php", "html", "css", "scss", "sql", "nix", "vue", "svelte", "zig"] },
    { icon: "config", tone: "code", ext: ["json", "toml", "yaml", "yml", "xml", "kdl", "conf", "ini", "cfg", "env", "desktop", "service", "lock"] },
    { icon: "pdf", tone: "doc", ext: ["pdf", "epub", "djvu", "cbz"] },
    { icon: "doc", tone: "doc", ext: ["txt", "md", "doc", "docx", "odt", "rtf", "log", "tex", "org"] },
    { icon: "data", tone: "doc", ext: ["csv", "tsv", "xls", "xlsx", "ods", "db", "sqlite", "parquet"] },
    { icon: "font", tone: "doc", ext: ["ttf", "otf", "woff", "woff2"] },
    { icon: "key", tone: "system", ext: ["pem", "key", "crt", "gpg", "asc", "pub", "kdbx"] }
];

const IMAGES = ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "avif", "ico", "tiff"];

function size(bytes) {
    let n = Number(bytes);
    if (!(n >= 0))
        return "";
    let u = 0;
    while (n >= 1024 && u < UNITS.length - 1) {
        n /= 1024;
        u++;
    }
    return (u === 0 ? n : n.toFixed(1)) + " " + UNITS[u];
}

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

function when(date) {
    if (!date || isNaN(date.getTime()))
        return "";
    const now = new Date();
    const clock = pad(date.getHours()) + ":" + pad(date.getMinutes());
    if (date.toDateString() === now.toDateString())
        return "hoy · " + clock;
    const day = pad(date.getDate()) + " " + MONTHS[date.getMonth()];
    if (date.getFullYear() === now.getFullYear())
        return day + " · " + clock;
    return day + " " + date.getFullYear();
}

function suffix(name) {
    const i = name.lastIndexOf(".");
    return i > 0 ? name.slice(i + 1).toLowerCase() : "";
}

function kind(name, isDir) {
    if (isDir)
        return "carpeta";
    return suffix(name) || "archivo";
}

function family(name) {
    const s = suffix(name);
    for (const f of FAMILIES) {
        if (f.ext.indexOf(s) >= 0)
            return f;
    }
    return null;
}

function icon(name, isDir) {
    if (isDir)
        return "folder";
    const f = family(name);
    return f ? f.icon : "file";
}

// folder, media, archive, code, doc, system or plain.
function tone(name, isDir) {
    if (isDir)
        return "folder";
    const f = family(name);
    return f ? f.tone : "plain";
}

function isImage(name) {
    return IMAGES.indexOf(suffix(name)) >= 0;
}

// Order names the way people read them: letters by locale, runs of digits by value.
function compare(a, b) {
    const left = a.split(/(\d+)/);
    const right = b.split(/(\d+)/);
    for (let i = 0; i < Math.min(left.length, right.length); i++) {
        if (left[i] === right[i])
            continue;
        const numeric = i % 2 === 1;
        const d = numeric ? Number(left[i]) - Number(right[i]) : left[i].localeCompare(right[i]);
        if (d !== 0)
            return d;
    }
    return left.length - right.length;
}

function plural(n, one, many) {
    return n + " " + (n === 1 ? one : many);
}
