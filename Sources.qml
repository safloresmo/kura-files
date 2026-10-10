import QtQuick
import Quickshell
import Quickshell.Io
import "lib/format.js" as Fmt

// Everything the view learns from outside: disks, places, bookmarks, network
// mounts, the trash, folder counts and thumbnails. Each process writes what
// it finds into the application's properties.
Item {
    id: sources

    required property var app

    function reload() {
        counter.running = false;
        counter.command = [app.engine, "counts", app.path];
        counter.running = true;
        disk.running = false;
        disk.command = ["df", "-B1", "--output=fstype,avail", app.path];
        disk.running = true;
        blocks.running = true;
        marks.running = true;
        if (app.servers.length > 0) {
            mounts.running = false;
            mounts.command = [app.engine, "remote"].concat(app.servers.map(x => x.uri));
            mounts.running = true;
        }
        if (app.inTrash) {
            trashLister.running = false;
            trashLister.running = true;
        }
        if (app.grid) {
            painter.running = false;
            painter.command = [app.engine, "thumbs", app.path];
            painter.running = true;
        }
    }
    function loadTargets() {
        tailnet.running = true;
    }
    function loadRecent() {
        recents.running = true;
    }

    visible: false

    Process {
        id: mounts
        property string wanted: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut > 0 && line.length > cut + 1)
                        map[line.slice(0, cut)] = line.slice(cut + 1);
                }
                const fresh = Object.keys(map).find(uri => !app.remotes[uri]);
                const first = Object.keys(app.remotes).length === 0 && !mounts.wanted;
                app.remotes = map;
                if (mounts.wanted && map[mounts.wanted]) {
                    app.go(map[mounts.wanted]);
                    mounts.wanted = "";
                } else if (fresh && !first && app.notice.indexOf("CONECTADO") === 0)
                    app.go(map[fresh]);
            }
        }
    }
    Process {
        id: painter
        stdout: SplitParser {
            onRead: line => {
                const cut = line.indexOf("\t");
                if (cut <= 0)
                    return;
                const next = Object.assign({}, app.thumbs);
                next[line.slice(0, cut)] = line.slice(cut + 1);
                app.thumbs = next;
            }
        }
    }
    Process {
        id: marks
        running: true
        command: [app.engine, "bookmarks", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut > 0)
                        list.push({ path: line.slice(0, cut), name: line.slice(cut + 1) });
                }
                app.bookmarks = list;
            }
        }
    }
    Process {
        id: trashLister
        command: [app.engine, "trashed"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length !== 5)
                        continue;
                    list.push({
                        name: cols[4].slice(cols[4].lastIndexOf("/") + 1),
                        path: cols[4],
                        size: Number(cols[1]),
                        modified: new Date(cols[2]),
                        isDir: cols[0] === "d",
                        from: cols[3]
                    });
                }
                app.trashList = list;
                app.rebuild();
            }
        }
    }
    Process {
        id: tailnet
        running: true
        command: ["tailscale", "file", "cp", "--targets"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length >= 2 && cols[1])
                        list.push({ name: cols[1], online: !(cols[2] || "").startsWith("offline") });
                }
                list.sort((a, b) => (a.online === b.online ? a.name.localeCompare(b.name) : (a.online ? -1 : 1)));
                app.targets = list;
            }
        }
    }
    Process {
        id: counter
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                const flags = {};
                const changed = {};
                for (const line of text.split("\n")) {
                    const cut = line.indexOf("\t");
                    if (cut <= 0)
                        continue;
                    const what = line.slice(0, cut);
                    const where = line.slice(cut + 1);
                    if (what === "git")
                        changed[where.slice(2)] = where.charAt(0);
                    else if (what === "link" || what === "exec")
                        flags[where] = what;
                    else
                        map[where] = Number(what);
                }
                app.flags = flags;
                app.changed = changed;
                app.counts = map;
                app.countsReady = true;
            }
        }
        stderr: StdioCollector { id: counterErrors }
        // The engine fails only when it cannot read the folder at all: either
        // it is gone, and the view climbs to what is left, or it is off limits.
        onExited: code => {
            if (code !== 0 && /No such file/i.test(counterErrors.text))
                app.climbOut();
            else
                app.unreadable = code !== 0;
        }
    }
    Process {
        id: disk
        stdout: StdioCollector {
            onStreamFinished: {
                const row = text.trim().split("\n")[1];
                const cols = row ? row.trim().split(/\s+/) : [];
                app.space = cols.length !== 2 ? ""
                    : cols[0].indexOf("fuse.gvfsd") === 0 ? "EN RED"
                    : cols[0].toUpperCase() + " · " + Fmt.size(cols[1]).toUpperCase() + " LIBRES";
            }
        }
    }
    Process {
        id: userDirs
        running: true
        command: ["sh", "-c", "for k in DESKTOP DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS; do printf '%s\\t%s\\n' \"$k\" \"$(xdg-user-dir $k)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const known = {
                    DESKTOP: ["Escritorio", "desktop", "机上"],
                    DOCUMENTS: ["Documentos", "doc", "文書"],
                    DOWNLOAD: ["Descargas", "download", "受信"],
                    MUSIC: ["Música", "music", "音楽"],
                    PICTURES: ["Imágenes", "image", "画像"],
                    VIDEOS: ["Vídeos", "video", "動画"]
                };
                const list = [
                    { name: "Carpeta personal", path: app.home, icon: "home", seal: "自宅" },
                    { name: "Recientes", path: "", icon: "clock", seal: "最近", special: "recent" }
                ];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    const meta = known[cols[0]];
                    if (!meta || !cols[1] || cols[1] === app.home)
                        continue;
                    list.push({ name: meta[0], path: app.clean(cols[1]), icon: meta[1], seal: meta[2] });
                }
                list.push({ name: "Papelera", path: app.home + "/.local/share/Trash/files", icon: "trash", seal: "屑籠" });
                app.places = list;
            }
        }
    }
    Process {
        id: blocks
        running: true
        command: ["lsblk", "-J", "-b", "-o", "NAME,LABEL,MOUNTPOINTS,SIZE,FSUSE%,RM,HOTPLUG,TYPE,FSTYPE,PATH"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const skip = ["swap", "crypto_LUKS", "LVM2_member", "linux_raid_member"];
                const walk = nodes => {
                    for (const n of nodes || []) {
                        const points = (n.mountpoints || []).filter(m => m);
                        const at = points.find(m => m === "/" || m.indexOf("/run/media/") === 0 || m.indexOf("/mnt/") === 0 || m.indexOf("/media/") === 0);
                        const loose = n.rm === true || n.hotplug === true;
                        const name = n.label || Fmt.size(n.size) + " · " + n.name;
                        if (at) {
                            found.push({
                                name: at === "/" ? "Sistema" : name,
                                path: at,
                                dev: n.path,
                                used: parseInt(n["fsuse%"]) || 0,
                                removable: loose,
                                mounted: true
                            });
                        } else if (loose && points.length === 0 && n.fstype && skip.indexOf(n.fstype) < 0 && n.size >= 268435456) {
                            found.push({ name: name, path: "", dev: n.path, used: 0, removable: true, mounted: false });
                        }
                        walk(n.children);
                    }
                };
                try {
                    walk(JSON.parse(text).blockdevices);
                } catch (e) {
                    return;
                }
                found.sort((a, b) => (a.path === "/" ? -1 : b.path === "/" ? 1 : a.name.localeCompare(b.name)));
                app.devices = found;
            }
        }
    }
    Process {
        id: recents
        command: [app.engine, "recent"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!app.recent)
                    return;
                const list = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length < 4)
                        continue;
                    const full = cols.slice(3).join("\t");
                    list.push({
                        name: full.slice(full.lastIndexOf("/") + 1),
                        shown: app.shorten(full),
                        path: full,
                        size: Number(cols[1]),
                        modified: new Date(Number(cols[2]) * 1000),
                        isDir: cols[0] === "d"
                    });
                }
                app.found = list;
                app.rebuild();
            }
        }
    }
    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: blocks.running = true
    }
}
