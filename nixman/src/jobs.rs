//! Jobs that take over the terminal (TUI suspended) so nix/git/sudo show their
//! real output and can prompt for passwords.

use crate::app::{App, Job, Mode};
use crate::repo::on_path;
use anyhow::{bail, Context, Result};
use std::io::{BufRead, Write};
use std::path::Path;
use std::process::Command;

const BOLD: &str = "\x1b[1m";
const CYAN: &str = "\x1b[36m";
const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const RESET: &str = "\x1b[0m";

fn sh(dir: &Path, prog: &str, args: &[&str]) -> Result<()> {
    println!("{BOLD}{CYAN}$ {prog} {}{RESET}", args.join(" "));
    let status = Command::new(prog).args(args).current_dir(dir).status().with_context(|| format!("running {prog}"))?;
    if !status.success() {
        bail!("{prog} exited with {status}");
    }
    Ok(())
}

fn ask(question: &str) -> bool {
    print!("{BOLD}{question} [y/N] {RESET}");
    let _ = std::io::stdout().flush();
    let mut line = String::new();
    let _ = std::io::stdin().lock().read_line(&mut line);
    matches!(line.trim(), "y" | "Y" | "yes")
}

pub fn wait_for_enter(ok: bool) {
    if ok {
        print!("\n{GREEN}{BOLD}✔ done{RESET} — press Enter to return to nixman ");
    } else {
        print!("\n{RED}{BOLD}✘ failed{RESET} — press Enter to return to nixman ");
    }
    let _ = std::io::stdout().flush();
    let mut s = String::new();
    let _ = std::io::stdin().lock().read_line(&mut s);
}

fn rebuild(app: &App, mode: Mode) -> Result<()> {
    let dir = &app.repo.dir;
    let host = &app.repo.this_host;
    // The one invariant that matters: only ever build and activate this
    // machine's own configuration.
    if !app.repo.host_known() {
        bail!("{host} is not a host in {}", dir.display());
    }
    if !app.git.changes.is_empty() {
        println!("note: building with {} uncommitted change(s)\n", app.git.changes.len());
    }
    sh(dir, "nixos-rebuild", &["build", "--flake", &format!(".#{host}")])?;
    let path = std::fs::canonicalize(dir.join("result")).context("resolving ./result")?;
    let name = path.file_name().unwrap_or_default().to_string_lossy();
    if !name.contains(&format!("-nixos-system-{host}-")) {
        bail!("built {name}, which is not a system for {host} — refusing to continue");
    }
    let path = path.to_string_lossy().to_string();
    println!();
    if on_path("nvd") {
        sh(dir, "nvd", &["diff", "/run/current-system", &path])?;
    } else {
        sh(dir, "nix", &["store", "diff-closures", "/run/current-system", &path])?;
    }
    if mode == Mode::Build {
        return Ok(());
    }
    println!();
    if !ask(&format!("Apply to {host} ({})?", mode.verb())) {
        bail!("not applied");
    }
    sh(dir, "sudo", &["nixos-rebuild", mode.verb(), "--store-path", &path])
}

pub fn run(app: &App, job: &Job) -> bool {
    let dir = &app.repo.dir;
    print!("\x1b[2J\x1b[H");
    println!("{BOLD}nixman · {job:?} · {}{RESET}\n", app.repo.this_host);
    let r = match job {
        Job::Rebuild(m) => rebuild(app, *m),
        Job::FlakeUpdate(inputs) => {
            let mut args = vec!["flake", "update"];
            args.extend(inputs.iter().map(String::as_str));
            sh(dir, "nix", &args)
        }
        Job::Push => sh(dir, "git", &["push"]),
        Job::Pull => sh(dir, "git", &["pull", "--rebase", "--autostash"]),
        Job::Diff => sh(dir, "git", &["diff", "HEAD"]),
        Job::Rollback => sh(dir, "sudo", &["nixos-rebuild", "switch", "--rollback"]),
        Job::Gc => sh(dir, "sudo", &["nix-collect-garbage", "--delete-older-than", "14d"])
            // Refresh the GRUB menu so deleted generations disappear from it.
            .and_then(|_| sh(dir, "sudo", &["/run/current-system/bin/switch-to-configuration", "boot"])),
    };
    if let Err(e) = &r {
        println!("\n{RED}{e:#}{RESET}");
    }
    r.is_ok()
}
