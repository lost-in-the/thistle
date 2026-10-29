use crate::error::{CoreError, Result};
use std::{ffi::CString, fs::File, io::{Read, Write}, os::fd::{AsRawFd, FromRawFd}, path::{Component, Path}};

pub struct Dir { file: File }

fn name(value: &str) -> Result<CString> {
    if value.is_empty() || value == "." || value == ".." || value.contains('/') {
        return Err(CoreError::new("unsafe_path", "Invalid snapshot entry name"));
    }
    CString::new(value).map_err(|_| CoreError::new("unsafe_path", "NUL in snapshot entry"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::{symlink, PermissionsExt};

    #[test]
    fn physical_store_rejects_symlink_ancestors_leaves_and_special_files() {
        let temp = tempfile::tempdir().unwrap();
        let root = temp.path().canonicalize().unwrap();
        let store = Dir::open(&root.join("store"), true).unwrap();
        symlink(root.join("store"), root.join("alias")).unwrap();
        assert_eq!(Dir::open(&root.join("alias/new"), true).err().unwrap().code, "unsafe_path");
        assert!(!root.join("store/new").exists());
        store.write_new("original", b"captured").unwrap();
        symlink("original", root.join("store/link")).unwrap();
        assert_eq!(store.read("link", 100).unwrap_err().code, "unsafe_path");
        let fifo = name("fifo").unwrap();
        // SAFETY: live directory descriptor and a NUL-terminated child name.
        assert_eq!(unsafe { libc::mkfifoat(store.file.as_raw_fd(), fifo.as_ptr(), 0o600) }, 0);
        assert_eq!(store.read("fifo", 100).unwrap_err().code, "unsafe_path");
        assert_eq!(std::fs::metadata(root.join("store")).unwrap().permissions().mode() & 0o077, 0);
        assert_eq!(std::fs::metadata(root.join("store/original")).unwrap().permissions().mode() & 0o077, 0);
    }

    #[test]
    fn directory_sync_and_writer_lock_work_across_independent_opens() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().canonicalize().unwrap();
        let first = Dir::open(&path, false).unwrap();
        let second = Dir::open(&path, false).unwrap();
        let lock = first.lock().unwrap();
        assert_eq!(second.lock().unwrap_err().code, "busy");
        first.write_new("staged", b"complete").unwrap();
        first.rename("staged", &second, "published").unwrap();
        second.sync().unwrap();
        assert_eq!(second.read("published", 100).unwrap(), b"complete");
        drop(lock);
        second.lock().unwrap();
    }
}

impl Dir {
    pub fn open(path: &Path, create: bool) -> Result<Self> {
        if !cfg!(any(target_os = "linux", target_os = "macos")) {
            return Err(CoreError::new("unsupported_platform", "Snapshot storage requires Linux or macOS"));
        }
        let absolute = if path.is_absolute() { path.to_path_buf() } else { std::env::current_dir()?.join(path) };
        let mut current = Self { file: File::open("/")? };
        for part in absolute.components() {
            match part {
                Component::RootDir | Component::CurDir => {},
                Component::Normal(value) => {
                    let value = value.to_str().ok_or_else(|| CoreError::new("unsafe_path", "Non-UTF-8 directory component"))?;
                    current = current.child(value, create)?;
                }
                _ => return Err(CoreError::new("unsafe_path", "Parent traversal in snapshot directory")),
            }
        }
        Ok(current)
    }

    pub fn child(&self, value: &str, create: bool) -> Result<Self> {
        let value = name(value)?;
        if create {
            // SAFETY: directory descriptor is alive; CString is NUL terminated.
            let result = unsafe { libc::mkdirat(self.file.as_raw_fd(), value.as_ptr(), 0o700) };
            if result < 0 {
                let error = std::io::Error::last_os_error();
                if error.kind() != std::io::ErrorKind::AlreadyExists { return Err(error.into()); }
            }
        }
        let fd = unsafe { libc::openat(self.file.as_raw_fd(), value.as_ptr(), libc::O_RDONLY | libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC) };
        if fd < 0 { return Err(std::io::Error::last_os_error().into()); }
        Ok(Self { file: unsafe { File::from_raw_fd(fd) } })
    }

    pub fn file(&self, value: &str, flags: i32) -> Result<File> {
        let value = name(value)?;
        let fd = unsafe { libc::openat(self.file.as_raw_fd(), value.as_ptr(), flags | libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK, 0o600) };
        if fd < 0 { return Err(std::io::Error::last_os_error().into()); }
        let file = unsafe { File::from_raw_fd(fd) };
        if !file.metadata()?.is_file() { return Err(CoreError::new("unsafe_path", "Snapshot entry must be a regular file")); }
        Ok(file)
    }

    pub fn read(&self, value: &str, max: usize) -> Result<Vec<u8>> {
        let file = self.file(value, libc::O_RDONLY)?;
        if file.metadata()?.len() > max as u64 { return Err(CoreError::limit("Snapshot file exceeds byte limit")); }
        let mut bytes = Vec::new();
        file.take(max as u64 + 1).read_to_end(&mut bytes)?;
        if bytes.len() > max { return Err(CoreError::limit("Snapshot file exceeds byte limit")); }
        Ok(bytes)
    }

    pub fn write_new(&self, value: &str, bytes: &[u8]) -> Result<()> {
        let mut file = self.file(value, libc::O_WRONLY | libc::O_CREAT | libc::O_EXCL)?;
        file.write_all(bytes)?;
        file.sync_all()?;
        Ok(())
    }

    pub fn rename(&self, from: &str, destination: &Self, to: &str) -> Result<()> {
        let from = name(from)?;
        let to = name(to)?;
        let result = unsafe { libc::renameat(self.file.as_raw_fd(), from.as_ptr(), destination.file.as_raw_fd(), to.as_ptr()) };
        if result < 0 { return Err(std::io::Error::last_os_error().into()); }
        Ok(())
    }

    pub fn unlink(&self, value: &str, directory: bool) -> Result<()> {
        let value = name(value)?;
        let result = unsafe { libc::unlinkat(self.file.as_raw_fd(), value.as_ptr(), if directory { libc::AT_REMOVEDIR } else { 0 }) };
        if result < 0 {
            let error = std::io::Error::last_os_error();
            if error.kind() != std::io::ErrorKind::NotFound { return Err(error.into()); }
        }
        Ok(())
    }

    pub fn sync(&self) -> Result<()> { self.file.sync_all()?; Ok(()) }

    pub fn lock(&self) -> Result<File> {
        let file = self.file("writer.lock", libc::O_RDWR | libc::O_CREAT)?;
        let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
        if result < 0 { return Err(CoreError::new("busy", "Another snapshot writer is active")); }
        Ok(file)
    }
}
