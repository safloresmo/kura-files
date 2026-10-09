//! Read only answers: what a file is, what a folder holds, how to preview it.

use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io::Read;
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use crate::file_name;

const SEARCH_LIMIT: usize = 500;

fn home() -> PathBuf {
    PathBuf::from(env::var("HOME").unwrap_or_else(|_| "/".into()))
}

fn output_of(program: &str, args: &[&str], path: Option<&Path>) -> String {
    let mut command = Command::new(program);
    command.args(args);
    if let Some(path) = path {
        command.arg(path);
    }
    command
        .output()
        .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
        .unwrap_or_default()
}

fn mime(path: &Path) -> String {
    output_of("file", &["--brief", "--mime-type", "--dereference", "--"], Some(path))
}

fn seconds(time: std::io::Result<SystemTime>) -> u64 {
    time.ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// Look a numeric id up in /etc/passwd or /etc/group.
fn name_of(table: &str, id: u32) -> String {
    fs::read_to_string(table)
        .ok()
        .and_then(|text| {
            text.lines().find_map(|line| {
                let mut fields = line.split(':');
                let name = fields.next()?;
                (fields.nth(1)?.parse::<u32>().ok()? == id).then(|| name.to_string())
            })
        })
        .unwrap_or_else(|| id.to_string())
}

fn mode_text(mode: u32) -> String {
    let mut text = String::new();
    for shift in [6, 3, 0] {
        let bits = (mode >> shift) & 7;
        text.push(if bits & 4 != 0 { 'r' } else { '-' });
        text.push(if bits & 2 != 0 { 'w' } else { '-' });
        text.push(if bits & 1 != 0 { 'x' } else { '-' });
    }
    text
}

/// Total size and item count under a folder, giving up after a moment on huge trees.
fn measure(dir: &Path, started: Instant, size: &mut u64, items: &mut u64) -> bool {
    let Ok(entries) = fs::read_dir(dir) else { return true };
    for entry in entries.flatten() {
        if started.elapsed().as_millis() > 1500 {
            return false;
        }
        let Ok(meta) = entry.metadata() else { continue };
        *items += 1;
        if meta.is_dir() {
            if !measure(&entry.path(), started, size, items) {
                return false;
            }
        } else {
            *size += meta.len();
        }
    }
    true
}

pub fn info(path: &Path) -> Result<(), String> {
    let meta = path.symlink_metadata().map_err(|e| format!("No se pudo leer: {e}"))?;
    println!("name\t{}", file_name(path));
    println!("path\t{}", path.display());
    if meta.file_type().is_symlink() {
        if let Ok(target) = fs::read_link(path) {
            println!("link\t{}", target.display());
        }
    }
    if meta.is_dir() {
        println!("kind\tinode/directory");
        let (mut size, mut items) = (0, 0);
        let complete = measure(path, Instant::now(), &mut size, &mut items);
        println!("size\t{size}");
        println!("items\t{items}");
        println!("complete\t{complete}");
    } else {
        println!("kind\t{}", mime(path));
        println!("size\t{}", meta.len());
    }
    println!("modified\t{}", seconds(meta.modified()));
    println!("accessed\t{}", seconds(meta.accessed()));
    println!("created\t{}", seconds(meta.created()));
    let mode = meta.permissions().mode() & 0o7777;
    println!("mode\t{}\t{:o}", mode_text(mode), mode);
    println!("owner\t{}", name_of("/etc/passwd", meta.uid()));
    println!("group\t{}", name_of("/etc/group", meta.gid()));
    Ok(())
}

/// How many entries each sub folder holds.
pub fn counts(dir: &Path) -> Result<(), String> {
    let entries = fs::read_dir(dir).map_err(|e| format!("No se pudo leer: {e}"))?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let count = fs::read_dir(&path).map(|inner| inner.count()).unwrap_or(0);
            println!("{count}\t{}", path.display());
        }
    }
    Ok(())
}

pub fn search(dir: &Path, text: &str, hidden: bool) -> Result<(), String> {
    let needle = text.to_lowercase();
    let mut found = 0;
    let mut pending = vec![dir.to_path_buf()];
    while let Some(current) = pending.pop() {
        let Ok(entries) = fs::read_dir(&current) else { continue };
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().into_owned();
            if !hidden && name.starts_with('.') {
                continue;
            }
            let path = entry.path();
            let Ok(meta) = path.symlink_metadata() else { continue };
            if meta.is_dir() {
                pending.push(path.clone());
            }
            if name.to_lowercase().contains(&needle) {
                let shown = path.strip_prefix(dir).unwrap_or(&path);
                let kind = if meta.is_dir() { 'd' } else { 'f' };
                println!("{kind}\t{}\t{}\t{}", meta.len(), seconds(meta.modified()), shown.display());
                found += 1;
                if found >= SEARCH_LIMIT {
                    return Ok(());
                }
            }
        }
    }
    Ok(())
}

fn thumbnail(path: &Path) -> PathBuf {
    let mut hasher = DefaultHasher::new();
    path.canonicalize().unwrap_or_else(|_| path.to_path_buf()).hash(&mut hasher);
    path.metadata().map(|m| m.mtime()).unwrap_or(0).hash(&mut hasher);
    let cache = env::var("XDG_CACHE_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".cache"));
    cache.join("archivos/thumbs").join(format!("{:016x}.png", hasher.finish()))
}

fn made(thumb: &Path) -> bool {
    thumb.metadata().map(|m| m.len() > 0).unwrap_or(false)
}

/// The cached picture of a video or a PDF, made on first use.
fn render(path: &Path, pdf: bool) -> Option<PathBuf> {
    let thumb = thumbnail(path);
    if !made(&thumb) {
        let _ = fs::create_dir_all(thumb.parent().unwrap_or(Path::new("/")));
        if pdf {
            let _ = Command::new("pdftoppm")
                .args(["-png", "-singlefile", "-scale-to", "900", "-f", "1", "-l", "1", "--"])
                .arg(path)
                .arg(thumb.with_extension(""))
                .output();
        } else {
            let _ = Command::new("ffmpegthumbnailer")
                .arg("-i")
                .arg(path)
                .arg("-o")
                .arg(&thumb)
                .args(["-s", "720", "-t", "15%"])
                .output();
        }
    }
    made(&thumb).then_some(thumb)
}

/// Pictures for every video and PDF in a folder: `PATH<TAB>THUMBNAIL`, as each is ready.
pub fn thumbs(dir: &Path) -> Result<(), String> {
    const VIDEO: [&str; 6] = ["mp4", "mkv", "webm", "mov", "avi", "m4v"];
    let entries = fs::read_dir(dir).map_err(|e| format!("No se pudo leer: {e}"))?;
    for entry in entries.flatten() {
        let path = entry.path();
        let ext = path.extension().map(|e| e.to_string_lossy().to_lowercase()).unwrap_or_default();
        let pdf = ext == "pdf";
        if !path.is_file() || !(pdf || VIDEO.contains(&ext.as_str())) {
            continue;
        }
        if let Some(thumb) = render(&path, pdf) {
            println!("{}\t{}", path.display(), thumb.display());
        }
    }
    Ok(())
}

/// Where each network location is mounted: `URI<TAB>PATH`, the path empty when it is not.
pub fn remote(uris: &[String]) -> Result<(), String> {
    for uri in uris {
        let listing = Command::new("gio")
            .env("LC_ALL", "C")
            .args(["info", "-a", "standard::type"])
            .arg(uri)
            .output()
            .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
            .unwrap_or_default();
        let path = listing
            .lines()
            .find_map(|line| line.strip_prefix("local path: "))
            .unwrap_or("");
        println!("{uri}\t{path}");
    }
    Ok(())
}

/// First line says how to show the file: `image PATH`, `text` and the start of it, or `none`.
pub fn preview(path: &Path, bytes: usize) -> Result<(), String> {
    if !path.is_file() {
        println!("none");
        return Ok(());
    }
    let kind = mime(path);
    let textual = kind.starts_with("text/")
        || matches!(
            kind.as_str(),
            "application/json" | "application/toml" | "application/x-shellscript" | "application/xml" | "application/javascript"
        );
    if kind.starts_with("image/") {
        println!("image {}", path.display());
    } else if kind.starts_with("video/") || kind == "application/pdf" {
        match render(path, kind == "application/pdf") {
            Some(thumb) => println!("image {}", thumb.display()),
            None => println!("none"),
        }
    } else if textual {
        let mut buffer = Vec::new();
        fs::File::open(path)
            .and_then(|file| file.take(bytes as u64).read_to_end(&mut buffer))
            .map_err(|e| format!("No se pudo leer: {e}"))?;
        println!("text");
        print!("{}", String::from_utf8_lossy(&buffer));
    } else {
        println!("none");
    }
    Ok(())
}

fn data_dirs() -> Vec<PathBuf> {
    let user = env::var("XDG_DATA_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".local/share"));
    let system = env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".into());
    std::iter::once(user).chain(system.split(':').map(PathBuf::from)).collect()
}

/// The applications that open a file, the default one first: `DESKTOP_FILE<TAB>NAME`.
pub fn apps(path: &Path) -> Result<(), String> {
    // The desktop's own database goes by name as well as content, so a script
    // is text/x-python here rather than whatever its first bytes look like.
    let listing = Command::new("gio")
        .args(["info", "-a", "standard::content-type"])
        .arg(path)
        .output()
        .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
        .unwrap_or_default();
    let named = listing
        .lines()
        .find_map(|line| line.split_once("standard::content-type: ").map(|(_, kind)| kind.trim().to_string()))
        .unwrap_or_default();
    println!("type\t{named}");
    let mut kinds = vec![named];
    let sniffed = mime(path);
    if !kinds.contains(&sniffed) {
        kinds.push(sniffed);
    }
    if kinds.iter().any(|kind| kind.starts_with("text/")) && !kinds.iter().any(|kind| kind == "text/plain") {
        kinds.push("text/plain".into());
    }
    let mut ids = Vec::new();
    for kind in kinds.iter().filter(|kind| !kind.is_empty()) {
        let registered = Command::new("gio")
            .env("LC_ALL", "C")
            .args(["mime", kind])
            .output()
            .map(|o| o.stdout)
            .unwrap_or_default();
        for line in String::from_utf8_lossy(&registered).lines() {
            if let Some(id) = line.strip_prefix('\t') {
                ids.push(id.trim().to_string());
            } else if line.starts_with("Default application") {
                if let Some((_, id)) = line.rsplit_once(": ") {
                    ids.push(id.trim().to_string());
                }
            }
        }
    }
    let dirs = data_dirs();
    let mut seen: Vec<String> = Vec::new();
    for id in ids {
        if id.is_empty() || seen.contains(&id) {
            continue;
        }
        seen.push(id.clone());
        let Some(desktop) = dirs.iter().map(|d| d.join("applications").join(&id)).find(|p| p.is_file()) else { continue };
        let Ok(text) = fs::read_to_string(&desktop) else { continue };
        // Hidden launchers stay out of the list, unless one is the default.
        if seen.len() > 1 && text.lines().any(|line| line.trim() == "NoDisplay=true") {
            continue;
        }
        let name = text.lines().find_map(|line| line.strip_prefix("Name=")).unwrap_or(&id);
        println!("{}\t{name}", desktop.display());
    }
    Ok(())
}

fn encode(path: &str) -> String {
    let mut out = String::from("file://");
    for byte in path.bytes() {
        if byte.is_ascii_alphanumeric() || b"-._~/".contains(&byte) {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }
    out
}

fn decode(uri: &str) -> Option<String> {
    let raw = uri.strip_prefix("file://")?.as_bytes();
    let mut bytes = Vec::with_capacity(raw.len());
    let mut i = 0;
    while i < raw.len() {
        if raw[i] == b'%' && i + 2 < raw.len() {
            if let Ok(value) = u8::from_str_radix(std::str::from_utf8(&raw[i + 1..i + 3]).ok()?, 16) {
                bytes.push(value);
                i += 3;
                continue;
            }
        }
        bytes.push(raw[i]);
        i += 1;
    }
    String::from_utf8(bytes).ok()
}

/// The bookmark list GTK file managers share: `PATH<TAB>LABEL` per line.
pub fn bookmarks(action: &str, path: Option<&str>) -> Result<(), String> {
    let config = env::var("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".config"));
    let file = config.join("gtk-3.0/bookmarks");
    let text = fs::read_to_string(&file).unwrap_or_default();
    let lines: Vec<&str> = text.lines().filter(|line| !line.trim().is_empty()).collect();
    match (action, path) {
        ("list", _) => {
            for line in &lines {
                let (uri, label) = line.split_once(' ').unwrap_or((line, ""));
                if let Some(path) = decode(uri) {
                    let label = if label.is_empty() { file_name(Path::new(&path)) } else { label.to_string() };
                    println!("{path}\t{label}");
                }
            }
            Ok(())
        }
        ("add", Some(path)) | ("remove", Some(path)) => {
            let uri = encode(path);
            let mut kept: Vec<String> = lines
                .iter()
                .filter(|line| line.split(' ').next() != Some(uri.as_str()))
                .map(|line| line.to_string())
                .collect();
            if action == "add" {
                kept.push(uri);
            }
            let _ = fs::create_dir_all(file.parent().unwrap_or(Path::new("/")));
            let mut body = kept.join("\n");
            if !body.is_empty() {
                body.push('\n');
            }
            fs::write(&file, body).map_err(|e| format!("No se pudieron guardar los marcadores: {e}"))
        }
        _ => Err("uso: bookmarks list|add|remove [PATH]".into()),
    }
}
