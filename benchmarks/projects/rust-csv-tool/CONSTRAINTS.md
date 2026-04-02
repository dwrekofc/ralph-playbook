# Project Constraints

## App Description

A CLI tool that reads, transforms, filters, and outputs CSV data for data processing pipelines.

## Tech Stack

- **Language:** Rust
- **Runtime:** N/A
- **Framework:** None (CLI binary)

## UI

- **Type:** CLI
- **UI Framework:** N/A
- **Design System:** N/A

## Database

- **Type:** None
- **Product:** N/A

## Auth

- **Type:** None

## Deployment

- **Target:** Local binary

## Back-Pressure Commands

- **Build:** `cargo build`
- **Test:** `cargo test`
- **Lint:** `cargo clippy -- -D warnings`
- **Typecheck:** (built into cargo build)
- **Format:** `cargo fmt --check`

## Hard Requirements

- Use `clap` for argument parsing
- Use `serde` + `csv` crate for CSV handling
- Must compile on stable Rust
- No external network dependencies
