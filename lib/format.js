.pragma library

const UNITS = ["B", "KiB", "MiB", "GiB", "TiB"];
const MONTHS = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

const KINDS = {
    image: ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "avif", "ico", "tiff"],
    video: ["mp4", "mkv", "webm", "mov", "avi", "m4v"],
    music: ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"],
    archive: ["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2", "tgz"],
    code: ["rs", "py", "js", "mjs", "ts", "qml", "c", "h", "cpp", "hpp", "go", "lua", "sh", "fish",
           "json", "toml", "yaml", "yml", "html", "css", "xml", "kdl", "nix"],
    doc: ["txt", "md", "pdf", "doc", "docx", "odt", "log", "conf", "ini", "csv", "epub"]
};

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

function icon(name, isDir) {
    if (isDir)
        return "folder";
    const s = suffix(name);
    for (const k in KINDS) {
        if (KINDS[k].indexOf(s) >= 0)
            return k;
    }
    return "file";
}

function isImage(name) {
    return KINDS.image.indexOf(suffix(name)) >= 0;
}

function plural(n, one, many) {
    return n + " " + (n === 1 ? one : many);
}
