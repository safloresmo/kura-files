//! File operations behind the file manager.
//!
//! Every command reports on stdout, one tab separated line per fact:
//!   done KIND SRC DEST     an item finished (KIND is copy, move or new)
//!   progress DONE TOTAL NAME
//! Errors go to stderr and make the exit code non zero. Nothing here
//! overwrites: a taken name gets a numbered sibling instead.

mod describe;
mod transfer;

use std::env;
use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{exit, Command};

const USAGE: &str = "\
archivos-motor copy|move|drop [--replace|--skip] DEST SRC...
archivos-motor conflicts DEST SRC...
archivos-motor rename SRC NAME
archivos-motor mkdir|touch DIR NAME
archivos-motor trash SRC...
archivos-motor delete SRC...
archivos-motor untrash ORIGINAL...
archivos-motor restore NAME...
archivos-motor revert (copy|move|new SRC DEST)...
archivos-motor extract ARCHIVE
archivos-motor compress zip|tar.gz|tar.xz|7z SRC...
archivos-motor info PATH
archivos-motor counts DIR
archivos-motor search DIR TEXT [hidden]
archivos-motor preview PATH [BYTES]
archivos-motor apps PATH
archivos-motor bookmarks list|add|remove [PATH]
archivos-motor thumbs DIR
archivos-motor recent
archivos-motor remote URI...";

extern "C" {
    fn signal(signum: i32, handler: usize) -> usize;
}

/// Set when the manager cancels: a copy stops at the next chunk and cleans up.
pub static STOP: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

extern "C" fn on_terminate(_: i32) {
    STOP.store(true, std::sync::atomic::Ordering::Relaxed);
}

fn main() {
    // Die quietly when the reader goes away, instead of panicking on a closed pipe.
    unsafe {
        signal(13, 0);
        signal(15, on_terminate as extern "C" fn(i32) as usize);
    }
    let args: Vec<String> = env::args().skip(1).collect();
    let Some((command, rest)) = args.split_first() else {
        eprintln!("{USAGE}");
        exit(2);
    };
    let result = match (command.as_str(), rest) {
        ("copy" | "move" | "drop", [policy, dest, sources @ ..])
            if (policy == "--replace" || policy == "--skip") && !sources.is_empty() =>
        {
            transfer::run(command, Path::new(dest), sources, policy)
        }
        ("copy" | "move" | "drop", [dest, sources @ ..]) if !sources.is_empty() => {
            transfer::run(command, Path::new(dest), sources, "")
        }
        ("conflicts", [dest, sources @ ..]) if !sources.is_empty() => {
            transfer::conflicts(Path::new(dest), sources);
            Ok(())
        }
        ("rename", [source, name]) => rename(Path::new(source), name),
        ("mkdir", [dir, name]) => create(Path::new(dir), name, true),
        ("touch", [dir, name]) => create(Path::new(dir), name, false),
        ("trash", sources) if !sources.is_empty() => trash(sources),
        ("untrash", originals) if !originals.is_empty() => untrash(originals),
        ("restore", names) if !names.is_empty() => restore(names),
        ("delete", sources) if !sources.is_empty() => delete(sources),
        ("thumbs", [dir]) => describe::thumbs(Path::new(dir)),
        ("recent", []) => describe::recent(),
        ("remote", uris) if !uris.is_empty() => describe::remote(uris),
        ("revert", triples) if !triples.is_empty() && triples.len() % 3 == 0 => revert(triples),
        ("extract", [archive]) => extract(Path::new(archive)),
        ("compress", [format, sources @ ..]) if !sources.is_empty() => compress(format, sources),
        ("info", [path]) => describe::info(Path::new(path)),
        ("counts", [dir]) => describe::counts(Path::new(dir)),
        ("search", [dir, text]) => describe::search(Path::new(dir), text, false),
        ("search", [dir, text, _]) => describe::search(Path::new(dir), text, true),
        ("preview", [path]) => describe::preview(Path::new(path), 4000),
        ("preview", [path, bytes]) => describe::preview(Path::new(path), bytes.parse().unwrap_or(4000)),
        ("apps", [path]) => describe::apps(Path::new(path)),
        ("bookmarks", [action, rest @ ..]) => describe::bookmarks(action, rest.first().map(String::as_str)),
        _ => {
            eprintln!("{USAGE}");
            exit(2);
        }
    };
    if let Err(message) = result {
        if !message.is_empty() {
            eprintln!("{message}");
        }
        exit(1);
    }
}

/// Whether anything, a dangling link included, already has this name.
pub fn taken(path: &Path) -> bool {
    path.symlink_metadata().is_ok()
}

/// `name`, or `stem (2).ext` and up while the name is taken in `dir`.
pub fn free_name(dir: &Path, name: &str) -> String {
    if !taken(&dir.join(name)) {
        return name.to_string();
    }
    let (stem, ext) = match name.rfind('.') {
        Some(dot) if dot > 0 => (&name[..dot], &name[dot..]),
        _ => (name, ""),
    };
    let mut n = 2;
    loop {
        let candidate = format!("{stem} ({n}){ext}");
        if !taken(&dir.join(&candidate)) {
            return candidate;
        }
        n += 1;
    }
}

pub fn valid_name(name: &str) -> bool {
    !name.is_empty() && name != "." && name != ".." && !name.contains('/')
}

pub fn file_name(path: &Path) -> String {
    path.file_name().unwrap_or(OsStr::new("")).to_string_lossy().into_owned()
}

pub fn report(kind: &str, source: &Path, dest: &Path) {
    println!("done\t{kind}\t{}\t{}", source.display(), dest.display());
}

fn rename(source: &Path, name: &str) -> Result<(), String> {
    if !valid_name(name) {
        return Err(format!("Nombre no válido: {name}"));
    }
    let dest = source.parent().unwrap_or(Path::new("/")).join(name);
    if dest == source {
        return Ok(());
    }
    if taken(&dest) {
        return Err(format!("Ya existe: {name}"));
    }
    fs::rename(source, &dest).map_err(|e| format!("No se pudo renombrar: {e}"))?;
    report("move", source, &dest);
    Ok(())
}

fn create(dir: &Path, name: &str, folder: bool) -> Result<(), String> {
    if !valid_name(name) {
        return Err(format!("Nombre no válido: {name}"));
    }
    if !dir.is_dir() {
        return Err(format!("No es una carpeta: {}", dir.display()));
    }
    let dest = dir.join(free_name(dir, name));
    let made = if folder {
        fs::create_dir(&dest)
    } else {
        fs::OpenOptions::new().write(true).create_new(true).open(&dest).map(|_| ())
    };
    made.map_err(|e| format!("No se pudo crear: {e}"))?;
    report("new", dir, &dest);
    Ok(())
}

pub fn trash(sources: &[String]) -> Result<(), String> {
    let status = Command::new("gio").arg("trash").arg("--").args(sources).status();
    match status {
        Ok(code) if code.success() => Ok(()),
        Ok(_) => Err(String::new()),
        Err(e) => Err(format!("No se pudo usar la papelera: {e}")),
    }
}

/// Remove for good. The manager asks before calling this.
fn delete(sources: &[String]) -> Result<(), String> {
    let mut failed = false;
    for source in sources {
        let path = Path::new(source);
        let removed = match path.symlink_metadata() {
            Ok(meta) if meta.is_dir() => fs::remove_dir_all(path),
            Ok(_) => fs::remove_file(path),
            Err(e) => Err(e),
        };
        if let Err(e) = removed {
            eprintln!("{source}: {e}");
            failed = true;
        }
    }
    if failed { Err(String::new()) } else { Ok(()) }
}

fn home_trash() -> PathBuf {
    env::var("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(env::var("HOME").unwrap_or_default()).join(".local/share"))
        .join("Trash")
}

/// Where a trashed item came from and when it was deleted, read from its record.
fn trash_record(name: &str) -> Option<(String, String)> {
    let text = fs::read_to_string(home_trash().join("info").join(format!("{name}.trashinfo"))).ok()?;
    let field = |key: &str| text.lines().find_map(|line| line.strip_prefix(key)).map(str::to_string);
    Some((describe::unescape(&field("Path=")?)?, field("DeletionDate=").unwrap_or_default()))
}

/// Put one item of the home trash back where it was, never over something else.
fn restore_entry(name: &str) -> Result<(), String> {
    let trash = home_trash();
    let (original, _) = trash_record(name).ok_or_else(|| format!("No está en la papelera: {name}"))?;
    let original = PathBuf::from(original);
    if taken(&original) {
        return Err(format!("Ya existe: {}", original.display()));
    }
    if let Some(parent) = original.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("No se pudo crear la carpeta: {e}"))?;
    }
    fs::rename(trash.join("files").join(name), &original).map_err(|e| format!("No se pudo restaurar: {e}"))?;
    let _ = fs::remove_file(trash.join("info").join(format!("{name}.trashinfo")));
    report("move", &trash.join("files").join(name), &original);
    Ok(())
}

/// Restore items of the home trash by the name they have inside it.
fn restore(names: &[String]) -> Result<(), String> {
    let mut failed = false;
    for name in names {
        if let Err(message) = restore_entry(name) {
            eprintln!("{message}");
            failed = true;
        }
    }
    if failed { Err(String::new()) } else { Ok(()) }
}

/// Bring back from the trash the newest entry that came from each original path.
fn untrash(originals: &[String]) -> Result<(), String> {
    let names: Vec<String> = fs::read_dir(home_trash().join("info"))
        .map(|entries| {
            entries
                .flatten()
                .filter_map(|e| e.file_name().to_string_lossy().strip_suffix(".trashinfo").map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    let mut failed = false;
    for original in originals {
        let newest = names
            .iter()
            .filter_map(|name| trash_record(name).map(|(path, date)| (name, path, date)))
            .filter(|(_, path, _)| path == original)
            .max_by(|a, b| a.2.cmp(&b.2));
        let outcome = match newest {
            Some((name, _, _)) => restore_entry(name),
            None => Err(format!("No está en la papelera: {original}")),
        };
        if let Err(message) = outcome {
            eprintln!("{message}");
            failed = true;
        }
    }
    if failed { Err(String::new()) } else { Ok(()) }
}

/// Undo earlier results: a copy or a new item goes to the trash, a move goes back.
fn revert(triples: &[String]) -> Result<(), String> {
    let mut failed = false;
    for triple in triples.chunks(3) {
        let (kind, source, dest) = (triple[0].as_str(), Path::new(&triple[1]), Path::new(&triple[2]));
        let outcome = match kind {
            "copy" | "new" => trash(&[triple[2].clone()]),
            "move" if taken(source) => Err(format!("Ya existe: {}", source.display())),
            "move" => fs::rename(dest, source).map_err(|e| format!("No se pudo devolver: {e}")),
            _ => Err(format!("No sé deshacer: {kind}")),
        };
        if let Err(message) = outcome {
            if !message.is_empty() {
                eprintln!("{message}");
            }
            failed = true;
        }
    }
    if failed { Err(String::new()) } else { Ok(()) }
}

fn archive_stem(name: &str) -> &str {
    for ext in [".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tgz"] {
        if let Some(stem) = name.strip_suffix(ext) {
            return stem;
        }
    }
    match name.rfind('.') {
        Some(dot) if dot > 0 => &name[..dot],
        _ => name,
    }
}

/// Unpack into a new folder beside the archive, so nothing lands on existing files.
fn extract(archive: &Path) -> Result<(), String> {
    if !archive.is_file() {
        return Err(format!("No es un archivo: {}", archive.display()));
    }
    let parent = archive.parent().unwrap_or(Path::new("/"));
    let name = file_name(archive);
    let target = parent.join(free_name(parent, archive_stem(&name)));
    fs::create_dir(&target).map_err(|e| format!("No se pudo crear la carpeta: {e}"))?;
    let mut done = Command::new("bsdtar")
        .arg("-xf")
        .arg(archive)
        .arg("-C")
        .arg(&target)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if !done && name.to_lowercase().ends_with(".rar") {
        let mut into = target.clone().into_os_string();
        into.push("/");
        done = Command::new("unrar")
            .args(["x", "-o-", "-idq"])
            .arg(archive)
            .arg(into)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
    }
    if !done {
        let _ = fs::remove_dir(&target);
        return Err(format!("No se pudo extraer: {name}"));
    }
    report("new", archive, &target);
    Ok(())
}

fn compress(format: &str, sources: &[String]) -> Result<(), String> {
    let flags: &[&str] = match format {
        "zip" | "tar.gz" | "tar.xz" => &["-a"],
        "7z" => &["--format=7zip"],
        _ => return Err(format!("Formato desconocido: {format}")),
    };
    let first = PathBuf::from(&sources[0]);
    let parent = first.parent().unwrap_or(Path::new("/")).to_path_buf();
    let mut names = Vec::new();
    for source in sources {
        let path = Path::new(source);
        if path.parent() != Some(parent.as_path()) || !taken(path) {
            return Err("Todo lo que se comprime tiene que estar en la misma carpeta.".into());
        }
        names.push(file_name(path));
    }
    let base = if sources.len() == 1 { archive_stem(&names[0]).to_string() } else { "Archivo".to_string() };
    let dest = parent.join(free_name(&parent, &format!("{base}.{format}")));
    let done = Command::new("bsdtar")
        .args(flags)
        .arg("-cf")
        .arg(&dest)
        .arg("-C")
        .arg(&parent)
        .arg("--")
        .args(&names)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if !done {
        let _ = fs::remove_file(&dest);
        return Err("No se pudo comprimir.".into());
    }
    report("new", &parent, &dest);
    Ok(())
}
