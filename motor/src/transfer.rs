//! Copy and move, with progress and without ever landing on an existing name.

use std::fs::{self, File, FileTimes, Metadata};
use std::io::{self, Read, Write};
use std::os::unix::fs::{symlink, MetadataExt};
use std::path::{Path, PathBuf};
use std::process;
use std::time::{Duration, Instant};

use std::sync::atomic::Ordering;

use crate::{file_name, free_name, report, taken, STOP};

const CHUNK: usize = 1 << 20;

struct Progress {
    done: u64,
    total: u64,
    last: Instant,
}

impl Progress {
    fn add(&mut self, bytes: u64, name: &str) {
        self.done += bytes;
        if self.last.elapsed() >= Duration::from_millis(120) {
            self.last = Instant::now();
            println!("progress\t{}\t{}\t{name}", self.done, self.total);
        }
    }
}

/// `mode` is copy, move or drop; drop moves within a disk and copies across disks.
pub fn run(mode: &str, dest: &Path, sources: &[String]) -> Result<(), String> {
    if !dest.is_dir() {
        return Err(format!("El destino no es una carpeta: {}", dest.display()));
    }
    let real_dest = dest.canonicalize().map_err(|e| e.to_string())?;
    let dest_device = fs::metadata(dest).map(|m| m.dev()).unwrap_or(0);

    let mut jobs: Vec<(PathBuf, bool)> = Vec::new();
    let mut failed = false;
    for source in sources {
        let source = PathBuf::from(source);
        let Ok(meta) = source.symlink_metadata() else {
            eprintln!("No existe: {}", source.display());
            failed = true;
            continue;
        };
        let real = source.canonicalize().unwrap_or_else(|_| source.clone());
        if real_dest.starts_with(&real) {
            eprintln!("No se puede poner una carpeta dentro de sí misma: {}", source.display());
            failed = true;
            continue;
        }
        let moving = match mode {
            "move" => true,
            "drop" => meta.dev() == dest_device,
            _ => false,
        };
        if moving && real.parent() == Some(real_dest.as_path()) {
            continue;
        }
        jobs.push((source, moving));
    }

    let mut progress = Progress { done: 0, total: 0, last: Instant::now() };
    for (source, moving) in &jobs {
        let same_disk = source.symlink_metadata().map(|m| m.dev() == dest_device).unwrap_or(false);
        if !(*moving && same_disk) {
            progress.total += weigh(source);
        }
    }

    for (source, moving) in jobs {
        if STOP.load(Ordering::Relaxed) {
            eprintln!("Cancelado");
            return Err(String::new());
        }
        let name = free_name(dest, &file_name(&source));
        let target = dest.join(&name);
        let outcome = if moving { relocate(&source, &target, &mut progress) } else { duplicate(&source, &target, &mut progress) };
        match outcome {
            Ok(()) => report(if moving { "move" } else { "copy" }, &source, &target),
            Err(e) => {
                eprintln!("{}: {e}", source.display());
                failed = true;
            }
        }
    }
    if failed { Err(String::new()) } else { Ok(()) }
}

fn weigh(path: &Path) -> u64 {
    let Ok(meta) = path.symlink_metadata() else { return 0 };
    if meta.is_dir() {
        fs::read_dir(path)
            .map(|entries| entries.flatten().map(|e| weigh(&e.path())).sum())
            .unwrap_or(0)
    } else if meta.is_file() {
        meta.len()
    } else {
        0
    }
}

/// Copy under a hidden partial name first, so an interrupted copy never looks finished.
fn duplicate(source: &Path, target: &Path, progress: &mut Progress) -> io::Result<()> {
    let parent = target.parent().unwrap_or(Path::new("/"));
    let partial = parent.join(format!(".{}.parcial-{}", file_name(target), process::id()));
    let copied = copy_tree(source, &partial, progress).and_then(|()| {
        if taken(target) {
            return Err(io::Error::new(io::ErrorKind::AlreadyExists, "el destino apareció mientras se copiaba"));
        }
        fs::rename(&partial, target)
    });
    if copied.is_err() {
        let _ = if partial.is_dir() { fs::remove_dir_all(&partial) } else { fs::remove_file(&partial) };
    }
    copied
}

fn relocate(source: &Path, target: &Path, progress: &mut Progress) -> io::Result<()> {
    if taken(target) {
        return Err(io::Error::new(io::ErrorKind::AlreadyExists, "el destino ya existe"));
    }
    match fs::rename(source, target) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == io::ErrorKind::CrossesDevices => {
            duplicate(source, target, progress)?;
            if source.symlink_metadata()?.is_dir() {
                fs::remove_dir_all(source)
            } else {
                fs::remove_file(source)
            }
        }
        Err(e) => Err(e),
    }
}

fn copy_tree(source: &Path, target: &Path, progress: &mut Progress) -> io::Result<()> {
    if STOP.load(Ordering::Relaxed) {
        return Err(io::Error::new(io::ErrorKind::Interrupted, "cancelado"));
    }
    let meta = source.symlink_metadata()?;
    if meta.file_type().is_symlink() {
        symlink(fs::read_link(source)?, target)
    } else if meta.is_dir() {
        fs::create_dir(target)?;
        for entry in fs::read_dir(source)? {
            let entry = entry?;
            copy_tree(&entry.path(), &target.join(entry.file_name()), progress)?;
        }
        fs::set_permissions(target, meta.permissions())?;
        keep_times(target, &meta);
        Ok(())
    } else if meta.is_file() {
        copy_file(source, target, &meta, progress)
    } else {
        Err(io::Error::new(io::ErrorKind::Unsupported, "no es un archivo, una carpeta ni un enlace"))
    }
}

fn copy_file(source: &Path, target: &Path, meta: &Metadata, progress: &mut Progress) -> io::Result<()> {
    let name = file_name(source);
    let same_disk = target
        .parent()
        .and_then(|p| fs::metadata(p).ok())
        .map(|p| p.dev() == meta.dev())
        .unwrap_or(false);
    if same_disk || meta.len() < (8 * CHUNK) as u64 {
        // One call lets the kernel share the data on filesystems that can.
        fs::copy(source, target)?;
        progress.add(meta.len(), &name);
    } else {
        let mut input = File::open(source)?;
        let mut output = File::options().write(true).create_new(true).open(target)?;
        let mut buffer = vec![0u8; CHUNK];
        loop {
            if STOP.load(Ordering::Relaxed) {
                return Err(io::Error::new(io::ErrorKind::Interrupted, "cancelado"));
            }
            let read = input.read(&mut buffer)?;
            if read == 0 {
                break;
            }
            output.write_all(&buffer[..read])?;
            progress.add(read as u64, &name);
        }
        output.flush()?;
        fs::set_permissions(target, meta.permissions())?;
    }
    keep_times(target, meta);
    Ok(())
}

fn keep_times(target: &Path, meta: &Metadata) {
    let (Ok(modified), Ok(accessed)) = (meta.modified(), meta.accessed()) else { return };
    if let Ok(file) = File::open(target) {
        let _ = file.set_times(FileTimes::new().set_modified(modified).set_accessed(accessed));
    }
}
