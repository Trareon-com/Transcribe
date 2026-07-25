//! Main power-user entrypoint.
//!
//! Usage: `trascribe --batch "*.mp3" --output ./transkrip/ --model models/ggml-tiny.bin`

mod cli_shared;

use clap::Parser;

use cli_shared::{run, Args};

fn main() {
    std::process::exit(run(Args::parse()));
}
