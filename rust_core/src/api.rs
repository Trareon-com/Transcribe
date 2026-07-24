//! Public API surface exposed to Flutter via flutter_rust_bridge V2.
//!
//! This file stays FRB-compatible: no lifetimes in public signatures,
//! every fallible function returns `Result<T, TrascribeError>`.
//!
//! Skeleton only — implementations land module-by-module in Fase 1
//! (audio, vad, stt, dedupe, export, decode). flutter_rust_bridge
//! codegen wiring is deferred until the Flutter SDK is available.

use crate::error::TrascribeResult;

pub fn engine_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn health_check() -> TrascribeResult<bool> {
    Ok(true)
}
