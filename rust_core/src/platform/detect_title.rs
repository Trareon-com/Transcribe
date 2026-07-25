/// Get the title of the frontmost window on macOS using AppleScript.
/// Returns empty string if detection fails (graceful fallback).
pub fn detect_frontmost_window_title() -> String {
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("osascript")
            .args([
                "-e",
                r#"tell application "System Events" to get title of first window of (first process whose frontmost is true)"#,
            ])
            .output()
            .ok()
            .and_then(|o| {
                if o.status.success() {
                    String::from_utf8(o.stdout)
                        .ok()
                        .map(|s| s.trim().to_string())
                } else {
                    None
                }
            })
            .unwrap_or_default()
    }
    #[cfg(not(target_os = "macos"))]
    {
        String::new() // Not implemented on other platforms yet
    }
}
