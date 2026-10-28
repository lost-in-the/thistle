use serde::Serialize;
use std::{fmt, io};

#[derive(Debug, Serialize)]
pub struct CoreError {
    pub code: &'static str,
    pub message: String,
}

pub type Result<T> = std::result::Result<T, CoreError>;

impl CoreError {
    pub fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self { code, message: message.into() }
    }
    pub fn input(message: impl Into<String>) -> Self { Self::new("invalid_input", message) }
    pub fn snapshot(message: impl Into<String>) -> Self { Self::new("invalid_snapshot", message) }
    pub fn limit(message: impl Into<String>) -> Self { Self::new("limit_exceeded", message) }
}

impl fmt::Display for CoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result { write!(f, "{}: {}", self.code, self.message) }
}
impl std::error::Error for CoreError {}
impl From<io::Error> for CoreError {
    fn from(error: io::Error) -> Self {
        let code = match error.raw_os_error() {
            Some(libc::ELOOP) | Some(libc::ENOTDIR) => "unsafe_path",
            _ if error.kind() == io::ErrorKind::NotFound => "not_found",
            _ => "io_error",
        };
        Self::new(code, error.to_string())
    }
}
impl From<serde_json::Error> for CoreError {
    fn from(error: serde_json::Error) -> Self { Self::input(format!("Invalid JSON: {error}")) }
}
