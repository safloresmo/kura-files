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
const ACTION_PATHS: usize = 30;
const INDEX_SECONDS: u64 = 6 * 60 * 60;
const INDEX_SKIP: &str = ".git .cache node_modules target";
/// The action id that stands for a whole script, not a section of a menu.
const SCRIPT: &str = "@script";
const INSIDE_BYTES: u64 = 2 * 1024 * 1024;
const INSIDE_SECONDS: u64 = 20;
const INSIDE_SKIP: [&str; 5] = ["node_modules", "target", "__pycache__", "venv", "build"];

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

fn clock(seconds: f64) -> String {
    let total = seconds.round() as u64;
    if total >= 3600 {
        format!("{}:{:02}:{:02}", total / 3600, total % 3600 / 60, total % 60)
    } else {
        format!("{}:{:02}", total / 60, total % 60)
    }
}

/// The few things worth knowing at a glance beyond size and date, by kind of
/// file: `LABEL<TAB>VALUE` per line. Slow or missing tools just add nothing.
pub fn facts(path: &Path) -> Result<(), String> {
    if path.is_dir() {
        if path.join(".git").exists() {
            let branch = Command::new("git")
                .arg("-C")
                .arg(path)
                .args(["rev-parse", "--abbrev-ref", "HEAD"])
                .output()
                .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
                .unwrap_or_default();
            let changes = Command::new("git")
                .arg("-C")
                .arg(path)
                .args(["status", "--porcelain"])
                .output()
                .map(|out| String::from_utf8_lossy(&out.stdout).lines().count())
                .unwrap_or(0);
            if !branch.is_empty() {
                let state = match changes {
                    0 => "al día".to_string(),
                    1 => "1 cambio".to_string(),
                    n => format!("{n} cambios"),
                };
                println!("Repositorio\t{branch} · {state}");
            }
        }
        return Ok(());
    }
    let kind = mime(path);
    if kind.starts_with("image/") {
        let mut first = path.as_os_str().to_os_string();
        first.push("[0]");
        let size = Command::new("identify")
            .args(["-format", "%w × %h"])
            .arg(first)
            .output()
            .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
            .unwrap_or_default();
        if !size.is_empty() {
            println!("Dimensiones\t{size} px");
        }
    } else if kind.starts_with("video/") || kind.starts_with("audio/") {
        let probe = Command::new("ffprobe")
            .args(["-v", "error", "-show_entries", "format=duration:stream=width,height", "-of", "default=noprint_wrappers=1"])
            .arg(path)
            .output()
            .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
            .unwrap_or_default();
        let field = |key: &str| probe.lines().find_map(|line| line.strip_prefix(key)).and_then(|v| v.parse::<f64>().ok());
        if let (Some(w), Some(h)) = (field("width="), field("height=")) {
            println!("Dimensiones\t{} × {} px", w as u64, h as u64);
        }
        if let Some(duration) = field("duration=") {
            println!("Duración\t{}", clock(duration));
        }
    } else if kind == "application/pdf" {
        let pages = Command::new("pdfinfo")
            .arg(path)
            .output()
            .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
            .unwrap_or_default();
        if let Some(count) = pages.lines().find_map(|line| line.strip_prefix("Pages:")) {
            println!("Páginas\t{}", count.trim());
        }
    } else if kind.starts_with("text/") && path.metadata().map(|m| m.len() < 4_000_000).unwrap_or(false) {
        if let Ok(text) = fs::read(path) {
            println!("Líneas\t{}", text.iter().filter(|&&byte| byte == b'\n').count());
        }
    }
    Ok(())
}

/// Inside a git work tree, say which entries of `dir` hold changes:
/// `git<TAB>LETTER<TAB>PATH`, the letter being `?` for new, `M` for the rest.
fn git_marks(dir: &Path) {
    let run = |args: &[&str]| {
        Command::new("git")
            .arg("-C")
            .arg(dir)
            .args(args)
            .output()
            .ok()
            .filter(|out| out.status.success())
            .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
    };
    let Some(top) = run(&["rev-parse", "--show-toplevel"]) else { return };
    let top = PathBuf::from(top.trim());
    let Some(status) = run(&["status", "--porcelain", "--", "."]) else { return };
    let Ok(here) = dir.canonicalize() else { return };
    let mut seen: Vec<(PathBuf, char)> = Vec::new();
    for line in status.lines().filter(|line| line.len() > 3) {
        let letter = if line.starts_with("??") { '?' } else { 'M' };
        let changed = line[3..].rsplit(" -> ").next().unwrap_or("").trim_matches('"');
        let Ok(inside) = top.join(changed).strip_prefix(&here).map(Path::to_path_buf) else { continue };
        let Some(first) = inside.components().next() else { continue };
        let entry = dir.join(first.as_os_str());
        match seen.iter_mut().find(|(path, _)| path == &entry) {
            Some((_, kept)) if letter == 'M' => *kept = 'M',
            Some(_) => {}
            None => seen.push((entry, letter)),
        }
    }
    for (entry, letter) in seen {
        println!("git\t{letter}\t{}", entry.display());
    }
}

/// What a listing cannot tell by name: `COUNT<TAB>PATH` for how many entries
/// a sub folder holds, `link<TAB>PATH` for a symbolic link and `exec<TAB>PATH`
/// for a file that can be run.
pub fn counts(dir: &Path) -> Result<(), String> {
    let entries = fs::read_dir(dir).map_err(|e| format!("No se pudo leer: {e}"))?;
    git_marks(dir);
    for entry in entries.flatten() {
        let path = entry.path();
        let Ok(meta) = path.symlink_metadata() else { continue };
        if meta.file_type().is_symlink() {
            println!("link\t{}", path.display());
        }
        if path.is_dir() {
            let count = fs::read_dir(&path).map(|inner| inner.count()).unwrap_or(0);
            println!("{count}\t{}", path.display());
        } else if meta.is_file() && meta.permissions().mode() & 0o111 != 0 {
            println!("exec\t{}", path.display());
        }
    }
    Ok(())
}

/// What a folder holds, one line each as a search gives them, names only.
pub fn list(dir: &Path, hidden: bool) -> Result<(), String> {
    let entries = fs::read_dir(dir).map_err(|e| format!("No se pudo leer: {e}"))?;
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !hidden && name.starts_with('.') {
            continue;
        }
        let Ok(meta) = entry.path().metadata().or_else(|_| entry.path().symlink_metadata()) else { continue };
        let kind = if meta.is_dir() { 'd' } else { 'f' };
        println!("{kind}\t{}\t{}\t{name}", meta.len(), seconds(meta.modified()));
    }
    Ok(())
}

/// Where an account in the cloud shows up as a folder while it is connected.
fn cloud_dir(name: &str) -> PathBuf {
    let runtime = env::var("XDG_RUNTIME_DIR").map(PathBuf::from).unwrap_or_else(|_| home().join(".cache"));
    runtime.join("archivos/nube").join(name)
}

fn mounted_at(dir: &Path) -> bool {
    let wanted = dir.to_string_lossy();
    fs::read_to_string("/proc/self/mounts")
        .map(|text| text.lines().any(|line| line.split(' ').nth(1) == Some(wanted.as_ref())))
        .unwrap_or(false)
}

/// The accounts rclone knows: `NAME  KIND  FOLDER  CONNECTED` per line.
pub fn clouds() -> Result<(), String> {
    let listing = output_of("rclone", &["listremotes", "--long"], None);
    for line in listing.lines() {
        let Some((name, kind)) = line.split_once(':') else { continue };
        let name = name.trim();
        if name.is_empty() || !crate::valid_name(name) {
            continue;
        }
        let dir = cloud_dir(name);
        println!("{name}\t{}\t{}\t{}", kind.trim(), dir.display(), u8::from(mounted_at(&dir)));
    }
    Ok(())
}

/// Bring an account in as a folder. Prints the folder once it answers.
pub fn cloud_mount(name: &str) -> Result<(), String> {
    if !crate::valid_name(name) {
        return Err(format!("Nombre no válido: {name}"));
    }
    let dir = cloud_dir(name);
    if !mounted_at(&dir) {
        fs::create_dir_all(&dir).map_err(|e| format!("No se pudo crear la carpeta: {e}"))?;
        let out = Command::new("rclone")
            .arg("mount")
            .arg(format!("{name}:"))
            .arg(&dir)
            .args(["--daemon", "--vfs-cache-mode", "writes", "--dir-cache-time", "30s", "--daemon-wait", "20s"])
            .output()
            .map_err(|_| "Hace falta rclone".to_string())?;
        if !out.status.success() {
            let why = String::from_utf8_lossy(&out.stderr);
            return Err(format!("No se pudo conectar: {}", why.lines().last().unwrap_or("").trim()));
        }
    }
    println!("{}", dir.display());
    Ok(())
}

/// Let an account go. Nothing is lost: what was being written is finished first.
pub fn cloud_unmount(name: &str) -> Result<(), String> {
    let dir = cloud_dir(name);
    if !crate::valid_name(name) || !mounted_at(&dir) {
        return Ok(());
    }
    let done = ["fusermount3", "fusermount"].iter().any(|tool| {
        Command::new(tool).arg("-u").arg(&dir).status().map(|status| status.success()).unwrap_or(false)
    });
    if done { Ok(()) } else { Err("No se pudo desconectar: está en uso".to_string()) }
}

/// The themes or the languages on offer, the user's own first:
/// `FILE-NAME  SHOWN-NAME` per line. `kind` is the folder they live in.
pub fn catalogue(kind: &str, given: &Path) -> Result<(), String> {
    let config = env::var("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".config"));
    let mut seen: Vec<String> = Vec::new();
    for dir in [config.join("archivos").join(kind), given.to_path_buf()] {
        let mut files: Vec<PathBuf> = fs::read_dir(&dir).into_iter().flatten().flatten().map(|entry| entry.path()).collect();
        files.sort();
        for file in files {
            let Some(key) = file_name(&file).strip_suffix(".json").map(str::to_string) else { continue };
            if key.is_empty() || key.starts_with('.') || seen.contains(&key) {
                continue;
            }
            // The name the file gives itself, read without taking the file apart.
            let text = fs::read_to_string(&file).unwrap_or_default();
            let shown = text
                .split("\"name\"")
                .nth(1)
                .and_then(|rest| rest.split('"').nth(1))
                .filter(|name| !name.is_empty() && !name.contains(['\t', '\n']))
                .unwrap_or(&key)
                .to_string();
            println!("{key}\t{shown}");
            seen.push(key);
        }
    }
    Ok(())
}

/// The same line a search gives, for each of the paths that still exists.
pub fn stat(paths: &[String]) -> Result<(), String> {
    for path in paths {
        let Ok(meta) = Path::new(path).symlink_metadata() else { continue };
        let kind = if meta.is_dir() { 'd' } else { 'f' };
        println!("{kind}\t{}\t{}\t{path}", meta.len(), seconds(meta.modified()));
    }
    Ok(())
}

fn index_file() -> PathBuf {
    let cache = env::var("XDG_CACHE_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".cache"));
    cache.join("archivos/indice.db")
}

/// Write the index of every name under the home folder that `everywhere` reads.
pub fn index() -> Result<(), String> {
    let file = index_file();
    if let Some(dir) = file.parent() {
        fs::create_dir_all(dir).map_err(|e| format!("No se pudo crear la carpeta: {e}"))?;
    }
    let done = Command::new("updatedb")
        .args(["-l", "0", "--prunenames", INDEX_SKIP, "-U"])
        .arg(home())
        .arg("-o")
        .arg(&file)
        .status()
        .map(|status| status.success())
        .unwrap_or(false);
    if done { Ok(()) } else { Err("No se pudo hacer el índice: hace falta plocate".to_string()) }
}

/// Find names anywhere under the home folder, at once, from the index. An
/// index that is missing or hours old is made again first.
pub fn everywhere(text: &str, hidden: bool) -> Result<(), String> {
    let file = index_file();
    let fresh = file
        .metadata()
        .and_then(|meta| meta.modified())
        .ok()
        .and_then(|time| time.elapsed().ok())
        .is_some_and(|age| age.as_secs() < INDEX_SECONDS);
    if !fresh {
        index()?;
    }
    let out = Command::new("plocate")
        .arg("-d")
        .arg(&file)
        .args(["-i", "-b", "-l", "4000", "--"])
        .arg(text)
        .output()
        .map_err(|e| format!("No se pudo buscar: {e}"))?;
    let base = home();
    let mut found = 0;
    for path in String::from_utf8_lossy(&out.stdout).lines() {
        let inner = Path::new(path).strip_prefix(&base).unwrap_or(Path::new(path));
        if !hidden && inner.components().any(|part| part.as_os_str().to_string_lossy().starts_with('.')) {
            continue;
        }
        // The index may be hours old: what is gone is left out.
        let Ok(meta) = Path::new(path).symlink_metadata() else { continue };
        let kind = if meta.is_dir() { 'd' } else { 'f' };
        println!("{kind}\t{}\t{}\t{path}", meta.len(), seconds(meta.modified()));
        found += 1;
        if found >= SEARCH_LIMIT {
            break;
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

/// Whether a text file holds `needle` (already lowercase). Big and binary files are skipped.
fn holds(path: &Path, size: u64, needle: &str) -> bool {
    if size == 0 || size > INSIDE_BYTES {
        return false;
    }
    let Ok(bytes) = fs::read(path) else { return false };
    if bytes.iter().take(2048).any(|b| *b == 0) {
        return false;
    }
    String::from_utf8_lossy(&bytes).to_lowercase().contains(needle)
}

/// Like `search`, but looks at what the files say instead of their names.
pub fn inside(dir: &Path, text: &str, hidden: bool) -> Result<(), String> {
    let needle = text.to_lowercase();
    let started = Instant::now();
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
                if !INSIDE_SKIP.contains(&name.as_str()) {
                    pending.push(path);
                }
                continue;
            }
            if !meta.is_file() || !holds(&path, meta.len(), &needle) {
                continue;
            }
            let shown = path.strip_prefix(dir).unwrap_or(&path);
            println!("f\t{}\t{}\t{}", meta.len(), seconds(meta.modified()), shown.display());
            found += 1;
            if found >= SEARCH_LIMIT || started.elapsed().as_secs() >= INSIDE_SECONDS {
                return Ok(());
            }
        }
        if started.elapsed().as_secs() >= INSIDE_SECONDS {
            break;
        }
    }
    Ok(())
}

/// The SHA-256 of a file, as `sha256sum` works it out.
pub fn sum(path: &Path) -> Result<(), String> {
    if !path.is_file() {
        return Err(format!("No es un archivo: {}", path.display()));
    }
    let out = output_of("sha256sum", &["--"], Some(path));
    match out.split_whitespace().next() {
        Some(digest) if digest.len() == 64 => {
            println!("{digest}");
            Ok(())
        }
        _ => Err("No se pudo calcular la suma".to_string()),
    }
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

/// Where service menus live: the ones other file managers install, and our own.
fn menu_dirs() -> Vec<PathBuf> {
    let config = env::var("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".config"));
    let mut dirs = vec![config.join("archivos/acciones")];
    for data in data_dirs() {
        dirs.push(data.join("kio/servicemenus"));
        dirs.push(data.join("kservices5/ServiceMenus"));
    }
    // An installed pack may bring service menus of its own, at its top or one folder down.
    for pack in packs() {
        dirs.push(pack.clone());
        for entry in fs::read_dir(&pack).into_iter().flatten().flatten() {
            let path = entry.path();
            if path.is_dir() && !file_name(&path).starts_with('.') {
                dirs.push(path);
            }
        }
    }
    dirs
}

/// Where packs of actions fetched from a repository are kept.
fn pack_root() -> PathBuf {
    data_dirs().remove(0).join("archivos/acciones")
}

fn packs() -> Vec<PathBuf> {
    let mut found: Vec<PathBuf> = fs::read_dir(pack_root())
        .into_iter()
        .flatten()
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.is_dir() && !file_name(path).starts_with('.'))
        .collect();
    found.sort();
    found
}

/// Every script on offer: the ones Nautilus keeps, and each pack's own.
fn all_scripts() -> Vec<(PathBuf, String)> {
    let mut found = Vec::new();
    scripts_in(&script_root(), "", &mut found);
    for pack in packs() {
        let name = file_name(&pack);
        // Only what sits at the top of a pack is meant to be run by hand.
        for entry in fs::read_dir(&pack).into_iter().flatten().flatten() {
            let path = entry.path();
            let file = file_name(&path);
            let runnable = path.is_file() && path.metadata().is_ok_and(|meta| meta.permissions().mode() & 0o111 != 0);
            if runnable && !file.starts_with('.') && !file.starts_with("install") && !file.ends_with(".desktop") {
                found.push((path, name.clone()));
            }
        }
    }
    found.sort();
    found
}

/// The address a pack was fetched from.
fn origin_of(pack: &Path) -> String {
    Command::new("git")
        .arg("-C")
        .arg(pack)
        .args(["config", "--get", "remote.origin.url"])
        .output()
        .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
        .unwrap_or_default()
}

/// The installed packs: `NAME  ADDRESS  SCRIPTS` per line.
pub fn pack_list() -> Result<(), String> {
    let scripts = all_scripts();
    for pack in packs() {
        let count = scripts.iter().filter(|(path, _)| path.starts_with(&pack)).count();
        println!("{}\t{}\t{count}", file_name(&pack), origin_of(&pack));
    }
    Ok(())
}

/// Fetch a pack of actions from a git repository, or bring it up to date.
pub fn pack_add(address: &str) -> Result<(), String> {
    let address = address.trim().trim_end_matches('/');
    if !(address.starts_with("https://") || address.starts_with("file:///")) || address.contains(char::is_whitespace) {
        return Err("La dirección tiene que empezar por https://".to_string());
    }
    let name = address.rsplit('/').next().unwrap_or("").trim_end_matches(".git").to_string();
    if !crate::valid_name(&name) || name.starts_with('.') {
        return Err(format!("No sirve como nombre: {name}"));
    }
    let root = pack_root();
    fs::create_dir_all(&root).map_err(|e| format!("No se pudo crear la carpeta: {e}"))?;
    let target = root.join(&name);
    let mut git = Command::new("git");
    // A private repository must fail, not sit waiting for a name and a password.
    git.env("GIT_ASKPASS", "true").stdin(std::process::Stdio::null());
    if target.is_dir() {
        git.arg("-C").arg(&target).args(["pull", "--quiet", "--ff-only"]);
    } else {
        git.args(["clone", "--quiet", "--depth", "1", address]).arg(&target);
    }
    let out = git.output().map_err(|e| format!("No se pudo usar git: {e}"))?;
    if !out.status.success() {
        let why = String::from_utf8_lossy(&out.stderr);
        return Err(format!("No se pudo traer: {}", why.lines().last().unwrap_or("").trim()));
    }
    println!("{name}");
    Ok(())
}

/// Forget a pack: its folder goes away.
pub fn pack_remove(name: &str) -> Result<(), String> {
    let target = pack_root().join(name);
    if !crate::valid_name(name) || name.starts_with('.') || !target.is_dir() {
        return Err(format!("No está instalado: {name}"));
    }
    fs::remove_dir_all(&target).map_err(|e| format!("No se pudo quitar: {e}"))
}

/// Where Nautilus keeps its scripts: plain programs run on the selection.
fn script_root() -> PathBuf {
    data_dirs().remove(0).join("nautilus/scripts")
}

/// Every runnable script under a folder, with the subfolder it sits in.
fn scripts_in(dir: &Path, group: &str, found: &mut Vec<(PathBuf, String)>) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    let mut paths: Vec<PathBuf> = entries.flatten().map(|entry| entry.path()).collect();
    paths.sort();
    for path in paths {
        let name = file_name(&path);
        if name.starts_with('.') {
            continue;
        }
        if path.is_dir() {
            scripts_in(&path, &name, found);
        } else if path.metadata().is_ok_and(|meta| meta.permissions().mode() & 0o111 != 0) {
            found.push((path, group.to_string()));
        }
    }
}

/// The kinds a path answers to, most specific first.
fn kinds_of(path: &Path) -> Vec<String> {
    if path.is_dir() {
        return vec!["inode/directory".into()];
    }
    let listing = output_of("gio", &["info", "-a", "standard::content-type"], Some(path));
    let named = listing
        .lines()
        .find_map(|line| line.split_once("standard::content-type: ").map(|(_, kind)| kind.trim().to_string()))
        .unwrap_or_default();
    let mut kinds = vec![named, mime(path)];
    if kinds.iter().any(|kind| kind.starts_with("text/")) {
        kinds.push("text/plain".into());
    }
    kinds.retain(|kind| !kind.is_empty());
    kinds
}

/// Whether a menu's MimeType pattern takes a path of these kinds.
fn takes(pattern: &str, kinds: &[String]) -> bool {
    let folder = kinds.iter().any(|kind| kind == "inode/directory");
    match pattern {
        "all/all" | "*/*" => true,
        "all/allfiles" | "application/octet-stream" => !folder,
        _ => kinds.iter().any(|kind| match pattern.strip_suffix("/*") {
            Some(group) => kind.split('/').next() == Some(group),
            None => kind == pattern,
        }),
    }
}

/// A key of one section of a desktop file, in Spanish when it has it.
fn key_of(text: &str, section: &str, key: &str) -> Option<String> {
    let mut inside = false;
    let (mut plain, mut local) = (None, None);
    for line in text.lines().map(str::trim) {
        if line.starts_with('[') {
            inside = line == format!("[{section}]");
        } else if inside {
            if let Some((name, value)) = line.split_once('=') {
                if name.trim() == key {
                    plain = Some(value.trim().to_string());
                } else if name.trim() == format!("{key}[es]") {
                    local = Some(value.trim().to_string());
                }
            }
        }
    }
    local.or(plain)
}

/// The service menu actions that apply to every one of the paths:
/// `FILE  ID  SUBMENU  NAME` per line.
pub fn actions(paths: &[String]) -> Result<(), String> {
    let kinds: Vec<Vec<String>> = paths.iter().take(ACTION_PATHS).map(|path| kinds_of(Path::new(path))).collect();
    let mut seen: Vec<String> = Vec::new();
    for dir in menu_dirs() {
        let Ok(entries) = fs::read_dir(&dir) else { continue };
        let mut files: Vec<PathBuf> = entries.flatten().map(|entry| entry.path()).collect();
        files.sort();
        for file in files {
            let name = file_name(&file);
            if !name.ends_with(".desktop") || seen.contains(&name) {
                continue;
            }
            seen.push(name);
            let Ok(text) = fs::read_to_string(&file) else { continue };
            let main = "Desktop Entry";
            let patterns = key_of(&text, main, "MimeType").unwrap_or_default();
            let fits = kinds
                .iter()
                .all(|kinds| patterns.split(';').any(|pattern| !pattern.is_empty() && takes(pattern.trim(), kinds)));
            if !fits {
                continue;
            }
            let submenu = key_of(&text, main, "X-KDE-Submenu").unwrap_or_default();
            for id in key_of(&text, main, "Actions").unwrap_or_default().split(';').filter(|id| !id.is_empty()) {
                let section = format!("Desktop Action {id}");
                let (Some(label), Some(_)) = (key_of(&text, &section, "Name"), key_of(&text, &section, "Exec")) else { continue };
                println!("{}\t{id}\t{submenu}\t{label}", file.display());
            }
        }
    }
    for (script, group) in all_scripts() {
        println!("{}\t{SCRIPT}\t{group}\t{}", script.display(), file_name(&script));
    }
    Ok(())
}

/// How many service menus there are at all, so the window knows whether to offer them.
pub fn menus() -> Result<(), String> {
    let menus = menu_dirs()
        .iter()
        .filter_map(|dir| fs::read_dir(dir).ok())
        .flat_map(|entries| entries.flatten())
        .filter(|entry| entry.file_name().to_string_lossy().ends_with(".desktop"))
        .count();
    println!("{}", menus + all_scripts().len());
    Ok(())
}

fn quoted(text: &str) -> String {
    format!("'{}'", text.replace('\'', "'\\''"))
}

/// An Exec line with its field codes filled in, ready for the shell.
pub fn filled(exec: &str, paths: &[String]) -> String {
    let first = paths.first().map(String::as_str).unwrap_or("");
    let all = paths.iter().map(|path| quoted(path)).collect::<Vec<_>>().join(" ");
    let mut out = String::new();
    let mut chars = exec.chars();
    while let Some(c) = chars.next() {
        if c != '%' {
            out.push(c);
            continue;
        }
        match chars.next() {
            Some('f' | 'u') => out.push_str(&quoted(first)),
            Some('F' | 'U') => out.push_str(&all),
            Some('d') => out.push_str(&quoted(&Path::new(first).parent().unwrap_or(Path::new("/")).to_string_lossy())),
            Some('n') => out.push_str(&quoted(&file_name(Path::new(first)))),
            Some('%') => out.push('%'),
            _ => {}
        }
    }
    out
}

/// Run one action of a service menu on the paths, without waiting for it.
pub fn act(file: &Path, id: &str, paths: &[String]) -> Result<(), String> {
    let folder = Path::new(paths.first().map(String::as_str).unwrap_or("/")).parent().unwrap_or(Path::new("/"));
    if id == SCRIPT {
        if !all_scripts().iter().any(|(script, _)| script == file) {
            return Err(format!("No es un script: {}", file.display()));
        }
        // Scripts get the selection as arguments and, as Nautilus does, in the environment.
        return Command::new(file)
            .args(paths)
            .env("NAUTILUS_SCRIPT_SELECTED_FILE_PATHS", paths.iter().map(|path| format!("{path}\n")).collect::<String>())
            .env("NAUTILUS_SCRIPT_CURRENT_URI", encode(&folder.to_string_lossy()))
            .current_dir(folder)
            .spawn()
            .map(|_| ())
            .map_err(|e| format!("No se pudo lanzar: {e}"));
    }
    if !menu_dirs().iter().any(|dir| file.parent() == Some(dir.as_path())) {
        return Err(format!("No es un menú de servicio: {}", file.display()));
    }
    let text = fs::read_to_string(file).map_err(|e| format!("No se pudo leer: {e}"))?;
    let exec = key_of(&text, &format!("Desktop Action {id}"), "Exec").ok_or_else(|| format!("No existe la acción: {id}"))?;
    Command::new("sh")
        .arg("-c")
        .arg(filled(&exec, paths))
        .current_dir(folder)
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("No se pudo lanzar: {e}"))
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
    unescape(uri.strip_prefix("file://")?)
}

/// Turn %XX escapes back into the bytes they stand for.
pub fn unescape(text: &str) -> Option<String> {
    let raw = text.as_bytes();
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

/// Finish a half typed path the way a shell does: print the longest path every
/// matching folder shares, ending in a slash once only one is left.
pub fn complete(text: &str) -> Result<(), String> {
    let (dir, partial) = match text.rfind('/') {
        Some(cut) => (&text[..=cut], &text[cut + 1..]),
        None => return Ok(()),
    };
    let entries = fs::read_dir(dir).map_err(|e| format!("No se pudo leer: {e}"))?;
    let mut names: Vec<String> = entries
        .flatten()
        .filter(|entry| entry.path().is_dir())
        .map(|entry| entry.file_name().to_string_lossy().into_owned())
        .filter(|name| partial.starts_with('.') || !name.starts_with('.'))
        .collect();
    let exact: Vec<String> = names.iter().filter(|name| name.starts_with(partial)).cloned().collect();
    if exact.is_empty() {
        let lower = partial.to_lowercase();
        names.retain(|name| name.to_lowercase().starts_with(&lower));
    } else {
        names = exact;
    }
    let Some(first) = names.first() else { return Ok(()) };
    if names.len() == 1 {
        println!("{dir}{first}/");
        return Ok(());
    }
    let mut shared = first.chars().count();
    for name in &names[1..] {
        shared = shared.min(first.chars().zip(name.chars()).take_while(|(a, b)| a.to_lowercase().eq(b.to_lowercase())).count());
    }
    let prefix: String = first.chars().take(shared).collect();
    if prefix.chars().count() > partial.chars().count() {
        println!("{dir}{prefix}");
    }
    Ok(())
}

fn attribute<'a>(tag: &'a str, name: &str) -> Option<&'a str> {
    let start = tag.find(&format!("{name}=\""))? + name.len() + 2;
    let end = tag[start..].find('"')? + start;
    Some(&tag[start..end])
}

/// What was opened lately, newest first, from the list desktop apps keep:
/// the same `KIND SIZE MODIFIED PATH` lines a search gives.
pub fn recent() -> Result<(), String> {
    let data = env::var("XDG_DATA_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".local/share"));
    let text = fs::read_to_string(data.join("recently-used.xbel")).unwrap_or_default();
    let mut entries: Vec<(&str, String)> = text
        .split("<bookmark ")
        .skip(1)
        .filter_map(|tag| {
            let tag = &tag[..tag.find('>')?];
            Some((attribute(tag, "modified")?, decode(attribute(tag, "href")?)?))
        })
        .collect();
    entries.sort_by(|a, b| b.0.cmp(a.0));
    let mut shown = 0;
    for (_, path) in entries {
        let Ok(meta) = fs::metadata(&path) else { continue };
        let kind = if meta.is_dir() { 'd' } else { 'f' };
        println!("{kind}\t{}\t{}\t{path}", meta.len(), seconds(meta.modified()));
        shown += 1;
        if shown >= 60 {
            break;
        }
    }
    Ok(())
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
