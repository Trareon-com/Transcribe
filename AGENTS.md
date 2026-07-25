# Trascribe Agent Instructions

## Commit Rules
- NEVER add `Co-Authored-By: Claude` or any AI co-author trailers to commit messages
- Commit messages must only contain the actual human author
- Use conventional commits: feat:, fix:, docs:, refactor:, chore:, perf:

## Build & Test
- Run `cd rust_core && cargo test --lib` before any Rust commit
- Run `flutter analyze && flutter test` before any Dart commit
- Run `cd rust_core && cargo fmt` before any Rust commit
