mod app;
mod flake;
mod git;
mod index;
mod jobs;
mod lists;
mod repo;
mod system;
mod ui;

use anyhow::{bail, Context, Result};
use crossterm::event::{self, Event, KeyEventKind};
use crossterm::terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen};
use crossterm::{cursor, execute};
use std::path::PathBuf;
use std::time::Duration;

const USAGE: &str = "\
nixman — manage this NixOS flake: packages, flake inputs, rebuilds, git

usage:
  nixman                         open the TUI
  nixman ls [--host H]           print package lists that apply to a host
  nixman add ATTR [--host H] [--home]
                                 add a package (default: shared system list)
  nixman rm ATTR [--host H] [--home]
                                 remove a package

options:
  --flake DIR    flake directory (default: $NIXMAN_FLAKE or ~/.config/nixos)
  --host H       target only host H instead of all hosts
  --home         use the home-manager list instead of the system list";

struct Args {
    cmd: Option<String>,
    attr: Option<String>,
    flake: Option<PathBuf>,
    host: Option<String>,
    home: bool,
}

fn parse_args() -> Result<Args> {
    let mut a = Args { cmd: None, attr: None, flake: None, host: None, home: false };
    let mut it = std::env::args().skip(1);
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                println!("{USAGE}");
                std::process::exit(0);
            }
            "--flake" => a.flake = Some(it.next().context("--flake needs a directory")?.into()),
            "--host" => a.host = Some(it.next().context("--host needs a name")?),
            "--home" => a.home = true,
            s if s.starts_with('-') => bail!("unknown option {s}\n\n{USAGE}"),
            s if a.cmd.is_none() => a.cmd = Some(s.into()),
            s if a.attr.is_none() => a.attr = Some(s.into()),
            s => bail!("unexpected argument {s}"),
        }
    }
    Ok(a)
}

fn cli(repo: &repo::Repo, a: &Args) -> Result<()> {
    let host = a.host.clone().unwrap_or_else(|| repo.this_host.clone());
    if !repo.hosts.contains(&host) {
        bail!("unknown host {host} (hosts: {})", repo.hosts.join(", "));
    }
    let all = repo.lists_for(&host);
    match a.cmd.as_deref() {
        Some("ls") => {
            for l in &all {
                let p = lists::load(l)?;
                println!("── {} ({})", l.label(), p.entries.len());
                for e in p.entries {
                    println!("   {}", e.name);
                }
            }
            Ok(())
        }
        Some(c @ ("add" | "rm")) => {
            let attr = a.attr.as_deref().context("missing package attribute")?;
            let target = all
                .iter()
                .find(|l| l.home == a.home && l.host.is_some() == a.host.is_some())
                .unwrap();
            if c == "rm" {
                lists::remove(target, attr)?;
                println!("removed {attr} from {}", target.label());
                return Ok(());
            }
            for l in &all {
                let overlaps = target.host.is_none() || l.host.is_none() || l.host == target.host;
                if overlaps && lists::load(l)?.entries.iter().any(|e| e.name == attr) {
                    bail!("{attr} is already in {}", l.label());
                }
            }
            repo::capture(&repo.dir, "nix", &["eval", "--inputs-from", ".", &format!("nixpkgs#{attr}.name"), "--raw"])
                .with_context(|| format!("{attr} not found in nixpkgs"))?;
            lists::insert(target, attr)?;
            println!("added {attr} to {}", target.label());
            Ok(())
        }
        Some(c) => bail!("unknown command {c}\n\n{USAGE}"),
        None => unreachable!(),
    }
}

fn suspend() -> Result<()> {
    disable_raw_mode()?;
    execute!(std::io::stdout(), LeaveAlternateScreen, cursor::Show)?;
    Ok(())
}

fn resume(term: &mut ratatui::DefaultTerminal) -> Result<()> {
    enable_raw_mode()?;
    execute!(std::io::stdout(), EnterAlternateScreen)?;
    term.clear()?;
    Ok(())
}

fn tui(repo: repo::Repo) -> Result<()> {
    // Ctrl-C while a job runs should stop the job, not nixman. A handler (unlike
    // SIG_IGN) is reset on exec, so children still get the default behaviour.
    let _ = ctrlc::set_handler(|| {});
    let mut app = app::App::new(repo);
    let mut term = ratatui::init();
    let result = (|| -> Result<()> {
        loop {
            while let Ok(msg) = app.rx.try_recv() {
                app.on_msg(msg);
            }
            term.draw(|f| ui::draw(f, &mut app))?;
            if !event::poll(Duration::from_millis(150))? {
                continue;
            }
            let Event::Key(k) = event::read()? else { continue };
            if k.kind != KeyEventKind::Press {
                continue;
            }
            match app.on_key(k) {
                app::Action::None => {}
                app::Action::Quit => return Ok(()),
                app::Action::Fg(job) => {
                    suspend()?;
                    let ok = jobs::run(&app, &job);
                    jobs::wait_for_enter(ok);
                    resume(&mut term)?;
                    app.after_job(&job, ok);
                }
            }
        }
    })();
    ratatui::restore();
    result
}

fn main() -> Result<()> {
    let args = parse_args()?;
    let repo = repo::Repo::discover(args.flake.clone())?;
    match args.cmd {
        None => tui(repo),
        Some(_) => cli(&repo, &args),
    }
}
