.pragma library

const UNITS = ["B", "KiB", "MiB", "GiB", "TiB"];
const MONTHS = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

// What a file is, told from its name: an icon, and a tone that groups it with
// its relatives. The first family that lists the extension wins.
const FAMILIES = [
    { icon: "image", tone: "media", ext: ["png", "jpg", "jpeg", "jpe", "webp", "gif", "bmp", "avif", "ico", "tiff", "tif", "heic", "heif",
        "jxl", "tga", "dds", "exr", "hdr", "qoi", "raw", "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "raf"] },
    { icon: "vector", tone: "media", ext: ["svg", "svgz", "ai", "eps", "xcf", "psd", "psb", "kra", "ora", "fig", "sketch", "xd", "afdesign",
        "afphoto", "cdr", "clip", "procreate"] },
    { icon: "video", tone: "media", ext: ["mp4", "mkv", "webm", "mov", "avi", "m4v", "flv", "wmv", "mpg", "mpeg", "m2ts", "3gp",
        "ogv", "vob", "rm"] },
    { icon: "music", tone: "media", ext: ["mp3", "flac", "ogg", "oga", "opus", "wav", "m4a", "aac", "wma", "aiff", "aif", "ape", "alac",
        "mid", "midi", "mka", "amr", "caf"] },
    { icon: "wave", tone: "media", ext: ["flp", "als", "logicx", "ptx", "rpp", "aup", "aup3", "sf2", "sfz", "nki", "vst", "vst3", "mod",
        "xm", "it", "s3m"] },
    { icon: "subtitle", tone: "media", ext: ["srt", "ass", "ssa", "vtt", "sub", "idx", "lrc", "sbv"] },
    { icon: "list", tone: "media", ext: ["m3u", "m3u8", "pls", "xspf", "cue"] },

    { icon: "archive", tone: "archive", ext: ["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2", "tgz", "tbz2", "txz", "lz", "lz4",
        "lzma", "lzo", "z", "cab", "ace", "arj", "cpio", "zpaq", "br", "sit", "pak", "pk3", "wad"] },
    { icon: "package", tone: "archive", ext: ["deb", "rpm", "pkg", "appimage", "flatpak", "flatpakref", "snap", "apk", "xapk", "aab",
        "ipa", "jar", "war", "exe", "msi", "msix", "dmg", "run", "whl", "gem", "crate", "nupkg", "vsix", "xpi", "crx", "vpk"] },
    { icon: "disc", tone: "archive", ext: ["iso", "img", "qcow2", "qcow", "vdi", "vmdk", "vhdx", "ova", "ovf", "nrg", "mdf",
        "bin", "toast", "wim", "squashfs", "sfs"] },
    { icon: "download", tone: "archive", ext: ["torrent", "part", "crdownload", "aria2", "download", "partial"] },

    { icon: "model", tone: "maker", ext: ["stl", "3mf", "obj", "step", "stp", "iges", "igs", "ply", "fbx", "glb", "gltf", "blend",
        "blend1", "f3d", "f3z", "scad", "vrm", "dae", "amf", "usd", "usda", "usdc", "usdz", "abc", "3ds", "max", "ma", "mb", "c4d",
        "skp", "x3d", "wrl", "ifc", "fcstd", "sldprt", "sldasm", "ipt", "iam", "catpart", "brep", "x_t", "pmx", "pmd", "vmd"] },
    { icon: "print", tone: "maker", ext: ["gcode", "bgcode", "gco", "g", "nc", "ngc", "tap", "ctb", "cbddlp", "photon", "sl1", "sl1s",
        "ufp", "chitubox", "lys", "goo"] },
    { icon: "board", tone: "maker", ext: ["kicad_pcb", "kicad_sch", "kicad_pro", "kicad_mod", "kicad_sym", "kicad_prl", "kicad_dru",
        "kicad_wks", "gbr", "ger", "gtl", "gbl", "gto", "gbo", "gts", "gbs", "gko", "gm1", "drl", "xln", "brd", "sch", "dsn", "fzz",
        "fzpz", "lbr", "pcbdoc", "schdoc", "easyeda"] },
    { icon: "draft", tone: "maker", ext: ["dxf", "dwg", "dwf", "dgn", "ggb", "drawio", "excalidraw", "vsdx", "vsd", "dia", "graffle",
        "puml", "plantuml", "mmd", "dot", "gv"] },
    { icon: "chip", tone: "maker", ext: ["hex", "uf2", "elf", "axf", "bit", "bitstream", "fw", "rom", "dfu", "srec", "s19", "eep",
        "ino", "pde", "ld", "svd", "dts", "dtsi", "dtb", "overlay"] },

    { icon: "script", tone: "code", ext: ["sh", "bash", "zsh", "fish", "ksh", "csh", "ps1", "psm1", "bat", "cmd", "nu", "awk", "sed",
        "expect", "command", "tool"] },
    { icon: "web", tone: "code", ext: ["html", "htm", "xhtml", "css", "scss", "sass", "less", "styl", "vue", "svelte", "astro", "jsx",
        "tsx", "ejs", "hbs", "handlebars", "mustache", "pug", "jade", "twig", "liquid", "njk", "erb", "haml", "jsp", "asp", "aspx",
        "cshtml", "razor", "wasm", "wat", "webmanifest", "htaccess"] },
    { icon: "code", tone: "code", ext: ["rs", "py", "pyw", "pyi", "pyx", "js", "mjs", "cjs", "ts", "mts", "cts", "qml", "c", "h", "cc",
        "cpp", "cxx", "hpp", "hh", "hxx", "inl", "cs", "go", "lua", "java", "kt", "kts", "scala", "sc", "swift", "m", "mm", "rb",
        "php", "pl", "pm", "raku", "r", "jl", "dart", "ex", "exs", "erl", "hrl", "hs", "lhs", "ml", "mli", "fs", "fsx", "fsi", "clj",
        "cljs", "cljc", "edn", "lisp", "lsp", "el", "scm", "rkt", "vim", "asm", "s", "nasm", "f", "f90", "f95", "for", "pas", "pp",
        "d", "nim", "cr", "zig", "v", "sv", "svh", "vhd", "vhdl", "tcl", "groovy", "gvy", "gd", "gdscript", "cob", "cbl", "ada",
        "adb", "ads", "bas", "vb", "vbs", "apl", "pro", "sol", "move", "cairo", "vy", "odin", "hx", "elm", "purs", "re", "res",
        "coffee", "ls", "as", "mq4", "mq5", "au3", "ahk", "applescript", "scpt", "sml", "idr", "agda", "lean", "coq", "tla",
        "wren", "janet", "fnl", "moon", "tl", "luau", "nut", "gml", "sqf", "pwn", "inc", "st", "lgo", "bf", "p4"] },
    { icon: "shader", tone: "code", ext: ["glsl", "hlsl", "wgsl", "vert", "frag", "geom", "comp", "tesc", "tese", "metal", "fx", "fxh",
        "shader", "gdshader", "cg", "cginc", "spv", "slang", "osl", "mtlx"] },
    { icon: "data", tone: "code", ext: ["sql", "sqlite", "sqlite3", "db", "db3", "mdb", "accdb", "dbf", "prisma", "graphql", "gql",
        "proto", "thrift", "avsc", "avro", "parquet", "orc", "feather", "arrow", "hdf5", "h5", "nc4", "mat", "npy", "npz", "pkl",
        "pickle", "rdb", "dump", "bak", "frm", "ibd", "myd", "ldf", "kdb", "realm", "duckdb"] },
    { icon: "config", tone: "code", ext: ["json", "jsonc", "json5", "jsonl", "ndjson", "toml", "yaml", "yml", "xml", "xsd", "xsl",
        "xslt", "dtd", "kdl", "conf", "config", "ini", "cfg", "cnf", "env", "properties", "props", "plist", "reg", "desktop",
        "service", "timer", "socket", "mount", "automount", "target", "path", "slice", "rules", "network", "netdev", "link",
        "lock", "editorconfig", "nix", "hcl", "tf", "tfvars", "tfstate", "ron", "dhall", "rc", "theme", "tmtheme",
        "sublime-settings", "code-workspace", "prefs", "inf", "manifest", "gradle", "sbt", "cabal", "podspec", "gemspec",
        "csproj", "vcxproj", "sln", "pbxproj", "xcconfig", "cmake", "mk", "mak", "ninja", "bazel", "bzl", "buck", "gn", "gni",
        "am", "ac", "in", "m4", "pri", "qrc", "ui", "po", "pot", "mo", "strings", "resx", "arb", "ftl", "lang"] },
    { icon: "notebook", tone: "code", ext: ["ipynb", "rmd", "qmd", "nb", "wl", "mlx", "sage", "livemd", "org-roam"] },
    { icon: "diff", tone: "code", ext: ["diff", "patch", "rej", "orig", "bundle"] },
    { icon: "lib", tone: "system", ext: ["so", "dll", "dylib", "a", "lib", "o", "ko", "sys", "drv", "ocx", "class", "pyc", "pyo",
        "pyd", "beam", "rlib", "rmeta", "node", "elc", "luac", "pdb", "ilk", "exp", "la", "lo", "gch", "pch"] },

    { icon: "pdf", tone: "doc", ext: ["pdf", "xps", "oxps", "ps", "djvu", "djv"] },
    { icon: "book", tone: "doc", ext: ["epub", "mobi", "azw", "azw3", "kfx", "fb2", "lit", "cbz", "cbr", "cb7", "cbt", "chm", "ibooks"] },
    { icon: "doc", tone: "doc", ext: ["txt", "text", "nfo", "diz", "me", "1st", "man", "roff", "pod", "fountain", "opml"] },
    // Written in a markup: plain text that turns into a formatted page.
    { icon: "markup", tone: "doc", ext: ["md", "markdown", "mdx", "rst", "adoc", "asciidoc", "org", "tex", "ltx", "bib",
        "sty", "cls", "typ", "wiki", "textile"] },
    // Word processor documents.
    { icon: "word", tone: "doc", ext: ["doc", "docx", "docm", "dotx", "odt", "ott", "rtf", "pages", "wpd", "wps", "abw"] },
    { icon: "sheet", tone: "doc", ext: ["csv", "tsv", "psv", "xls", "xlsx", "xlsm", "xlsb", "xlt", "xltx", "ods", "ots", "numbers",
        "gnumeric", "dif", "slk", "qif", "ofx", "qfx", "gnucash", "ledger"] },
    { icon: "slides", tone: "doc", ext: ["ppt", "pptx", "pptm", "pps", "ppsx", "potx", "odp", "otp", "key", "sozi", "marp"] },
    { icon: "log", tone: "doc", ext: ["log", "out", "err", "trace", "journal", "audit", "stackdump", "dmp", "crash", "core"] },
    { icon: "font", tone: "doc", ext: ["ttf", "otf", "ttc", "woff", "woff2", "eot", "pfb", "pfa", "pfm", "afm", "bdf", "pcf", "psf",
        "fon", "fnt", "glyphs", "ufo", "sfd"] },
    { icon: "mail", tone: "doc", ext: ["eml", "msg", "mbox", "mbx", "pst", "ost", "emlx", "mht", "mhtml"] },
    { icon: "calendar", tone: "doc", ext: ["ics", "ical", "ifb", "vcs"] },
    { icon: "contact", tone: "doc", ext: ["vcf", "vcard", "ldif"] },
    { icon: "map", tone: "doc", ext: ["gpx", "kml", "kmz", "geojson", "topojson", "osm", "pbf", "shp", "shx", "mbtiles", "fit", "tcx",
        "gdb", "qgs", "qgz"] },
    { icon: "link", tone: "doc", ext: ["url", "webloc", "lnk", "website", "weblink"] },

    { icon: "game", tone: "media", ext: ["sav", "srm", "state", "nes", "sfc", "smc", "gb", "gbc", "gba", "nds", "3dsx", "cia", "n64",
        "z64", "gcm", "wbfs", "xci", "nsp", "pbp", "chd", "unity", "unitypackage", "prefab", "asset", "uasset", "umap",
        "uproject", "godot", "tscn", "tres", "pck", "rpgmvp", "rpa", "rpyc", "rpy", "love", "bsp", "vmf", "vmt", "vtf", "mdl",
        "vdf", "acf", "osu", "osz", "osk", "mcworld", "mcpack", "mcfunction", "schematic", "litematic", "nbt"] },

    { icon: "key", tone: "system", ext: ["pem", "crt", "cer", "der", "p12", "pfx", "p7b", "p7c", "csr", "jks", "keystore", "gpg",
        "pgp", "asc", "sig", "pub", "ppk", "ovpn", "wg", "kdbx", "agilekeychain", "opvault", "htpasswd", "netrc"] },
    { icon: "lock", tone: "system", ext: ["enc", "aes", "age", "vault", "luks", "veracrypt", "tc", "hc", "cpt", "axx", "crypt",
        "locked", "sops"] },
    { icon: "trash", tone: "system", ext: ["tmp", "temp", "swp", "swo", "swn", "old", "cache", "dummy", "junk", "ds_store"] }
];

// Files known by their whole name rather than their extension. The tag is
// what shows beside the icon, since these have no extension to show.
const NAMES = {
    "makefile": ["config", "code", "MAKE"], "gnumakefile": ["config", "code", "MAKE"], "cmakelists.txt": ["config", "code", "CMAKE"],
    "justfile": ["config", "code", "JUST"], "meson.build": ["config", "code", "MESON"], "build.ninja": ["config", "code", "NINJA"],
    "rakefile": ["config", "code", "RAKE"], "gemfile": ["config", "code", "GEM"], "procfile": ["config", "code", "PROC"],
    "vagrantfile": ["config", "code", "VAGR"], "brewfile": ["config", "code", "BREW"], "pkgbuild": ["package", "archive", "PKG"],
    "dockerfile": ["container", "code", "DOCK"], "containerfile": ["container", "code", "CONT"],
    "docker-compose.yml": ["container", "code", "COMP"], "docker-compose.yaml": ["container", "code", "COMP"],
    "compose.yml": ["container", "code", "COMP"], "compose.yaml": ["container", "code", "COMP"], ".dockerignore": ["container", "code", "DOCK"],
    "license": ["seal", "doc", "LIC"], "licence": ["seal", "doc", "LIC"], "license.md": ["seal", "doc", "LIC"],
    "license.txt": ["seal", "doc", "LIC"], "copying": ["seal", "doc", "LIC"], "unlicense": ["seal", "doc", "LIC"],
    "notice": ["seal", "doc", "NOTE"], "authors": ["contact", "doc", "AUTH"], "contributors": ["contact", "doc", "AUTH"],
    "codeowners": ["contact", "doc", "OWN"], "maintainers": ["contact", "doc", "AUTH"],
    "readme": ["info", "doc", "READ"], "readme.md": ["info", "doc", "READ"], "readme.txt": ["info", "doc", "READ"],
    "readme.rst": ["info", "doc", "READ"], "changelog": ["log", "doc", "CHNG"], "changelog.md": ["log", "doc", "CHNG"],
    "changes": ["log", "doc", "CHNG"], "history.md": ["log", "doc", "HIST"], "todo": ["list", "doc", "TODO"],
    "todo.md": ["list", "doc", "TODO"], "todo.txt": ["list", "doc", "TODO"],
    ".gitignore": ["git", "code", "GIT"], ".gitattributes": ["git", "code", "GIT"], ".gitmodules": ["git", "code", "GIT"],
    ".gitconfig": ["git", "code", "GIT"], ".gitkeep": ["git", "code", "GIT"], ".mailmap": ["git", "code", "GIT"],
    ".env": ["lock", "system", "ENV"], ".env.local": ["lock", "system", "ENV"], ".env.example": ["config", "code", "ENV"],
    ".npmrc": ["config", "code", "NPM"], ".nvmrc": ["config", "code", "NVM"], ".editorconfig": ["config", "code", "EDIT"],
    ".prettierrc": ["config", "code", "PRET"], ".eslintrc": ["config", "code", "LINT"], ".clang-format": ["config", "code", "FMT"],
    ".bashrc": ["script", "code", "BASH"], ".zshrc": ["script", "code", "ZSH"], ".profile": ["script", "code", "PROF"],
    ".bash_profile": ["script", "code", "BASH"], ".vimrc": ["config", "code", "VIM"], ".tmux.conf": ["config", "code", "TMUX"],
    ".xinitrc": ["script", "code", "X11"], ".inputrc": ["config", "code", "RL"], ".htaccess": ["web", "code", "HTA"],
    "package.json": ["package", "code", "NPM"], "package-lock.json": ["lock", "code", "NPM"], "yarn.lock": ["lock", "code", "YARN"],
    "pnpm-lock.yaml": ["lock", "code", "PNPM"], "cargo.toml": ["package", "code", "CARGO"], "cargo.lock": ["lock", "code", "CARGO"],
    "go.mod": ["package", "code", "GO"], "go.sum": ["lock", "code", "GO"], "requirements.txt": ["package", "code", "PIP"],
    "pyproject.toml": ["package", "code", "PY"], "setup.py": ["package", "code", "PY"], "pipfile": ["package", "code", "PIP"],
    "poetry.lock": ["lock", "code", "POET"], "uv.lock": ["lock", "code", "UV"], "composer.json": ["package", "code", "COMP"],
    "flake.nix": ["package", "code", "FLAKE"], "flake.lock": ["lock", "code", "FLAKE"], "manifest.json": ["config", "code", "MANI"],
    "tsconfig.json": ["config", "code", "TS"], "sdkconfig": ["chip", "maker", "IDF"], "platformio.ini": ["chip", "maker", "PIO"],
    "known_hosts": ["key", "system", "SSH"], "authorized_keys": ["key", "system", "SSH"], "id_rsa": ["key", "system", "SSH"],
    "id_ed25519": ["key", "system", "SSH"], "passwd": ["contact", "system", "USER"], "hosts": ["network", "system", "HOST"],
    "fstab": ["disk", "system", "FSTAB"], "crontab": ["calendar", "system", "CRON"]
};

const IMAGES = ["png", "jpg", "jpeg", "jpe", "webp", "gif", "svg", "bmp", "avif", "ico", "tiff", "tif"];

const BY_EXT = (function () {
    const index = {};
    for (const f of FAMILIES) {
        for (const e of f.ext) {
            if (index[e] === undefined)
                index[e] = f;
        }
    }
    return index;
})();

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
    const known = NAMES[name.toLowerCase()];
    if (known)
        return { icon: known[0], tone: known[1], tag: known[2] };
    return BY_EXT[suffix(name)] || null;
}

function icon(name, isDir) {
    if (isDir)
        return "folder";
    const f = family(name);
    return f ? f.icon : "file";
}

// folder, media, archive, maker, code, doc, system or plain.
function tone(name, isDir) {
    if (isDir)
        return "folder";
    const f = family(name);
    return f ? f.tone : "plain";
}

// The few letters shown beside the icon: the extension, or a short name for
// the files that are known by their whole name.
function tag(name) {
    const known = NAMES[name.toLowerCase()];
    if (known)
        return known[2];
    return suffix(name).slice(0, 5).toUpperCase();
}

function isImage(name) {
    return IMAGES.indexOf(suffix(name)) >= 0;
}

// Order names the way people read them: letters by locale, runs of digits by value.
function compare(a, b) {
    return compareKeys(sortKey(a), sortKey(b));
}

// A name cut into text and number runs, done once per name before a sort
// instead of once per comparison.
function sortKey(name) {
    // Case and accents do not order names: "Álbum" sits with "album".
    const plain = name.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const parts = plain.split(/(\d+)/);
    for (let i = 1; i < parts.length; i += 2)
        parts[i] = Number(parts[i]);
    return parts;
}

function compareKeys(left, right) {
    for (let i = 0; i < Math.min(left.length, right.length); i++) {
        if (left[i] === right[i])
            continue;
        const numeric = i % 2 === 1;
        const d = numeric ? left[i] - right[i] : (left[i] < right[i] ? -1 : 1);
        if (d !== 0)
            return d;
    }
    return left.length - right.length;
}

function plural(n, one, many) {
    return n + " " + (n === 1 ? one : many);
}
