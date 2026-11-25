//! Locating the flake, its hosts and the package lists, plus small process helpers.

use crate::lists::PkgList;
use anyhow::{bail, Context, Result};
use std::path::{Path, PathBuf};
use std::process::Command;

pub const USER: &str = "vito";

pub struct Repo {
    pub dir: PathBuf,
    pub hosts: Vec<String>,
    /// Hostname of the machine nixman runs on. Rebuilds only ever target this.
    pub this_host: String,
}

impl Repo {
    pub fn discover(dir: Option<PathBuf>) -> Result<Repo> {
        let dir = match dir.or_else(|| std::env::var_os("NIXMAN_FLAKE").map(PathBuf::from)) {
            Some(d) => d,
            None => home().join(".config/nixos"),
        };
        let dir = dir.canonicalize().with_context(|| format!("flake dir {}", dir.display()))?;
        if !dir.join("flake.nix").exists() {
            bail!("{} has no flake.nix", dir.display());
        }
        let mut hosts: Vec<String> = std::fs::read_dir(dir.join("hosts"))
            .context("reading hosts/")?
            .filter_map(|e| e.ok())
            .filter(|e| e.path().join("default.nix").exists())
            .filter_map(|e| e.file_name().into_string().ok())
            .collect();
        hosts.sort();
        let this_host = std::fs::read_to_string("/proc/sys/kernel/hostname")
            .context("reading hostname")?
            .trim()
            .to_string();
        Ok(Repo { dir, hosts, this_host })
    }

    pub fn host_known(&self) -> bool {
        self.hosts.contains(&self.this_host)
    }

    /// Lists that apply to `host`, shared ones first.
    pub fn lists_for(&self, host: &str) -> Vec<PkgList> {
        let host_file = self.dir.join("hosts").join(host).join("default.nix");
        vec![
            PkgList { file: self.dir.join("configuration.nix"), attr: "environment.systemPackages".into(), host: None, home: false },
            PkgList { file: self.dir.join("home/home.nix"), attr: "home.packages".into(), host: None, home: true },
            PkgList { file: host_file.clone(), attr: "environment.systemPackages".into(), host: Some(host.into()), home: false },
            PkgList { file: host_file, attr: format!("home-manager.users.{USER}.home.packages"), host: Some(host.into()), home: true },
        ]
    }
}

pub fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| "/".into())
}

pub fn cache_dir() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME").map(PathBuf::from).unwrap_or_else(|| home().join(".cache")).join("nixman")
}

/// Run a command, capture stdout; on failure return stderr as the error.
pub fn capture(dir: &Path, prog: &str, args: &[&str]) -> Result<String> {
    let out = Command::new(prog)
        .args(args)
        .current_dir(dir)
        .output()
        .with_context(|| format!("running {prog}"))?;
    if out.status.success() {
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    } else {
        let err = String::from_utf8_lossy(&out.stderr);
        let last = err.lines().rfind(|l| !l.trim().is_empty()).unwrap_or("failed");
        bail!("{prog} {}: {last}", args.first().unwrap_or(&""))
    }
}

pub fn on_path(prog: &str) -> bool {
    std::env::var_os("PATH")
        .map(|p| std::env::split_paths(&p).any(|d| d.join(prog).is_file()))
        .unwrap_or(false)
}

/// Days since epoch -> (y, m, d). Howard Hinnant's civil_from_days.
pub fn ymd(secs: i64) -> (i64, u32, u32) {
    let z = secs.div_euclid(86400) + 719468;
    let era = z.div_euclid(146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (yoe + era * 400 + (m <= 2) as i64, m, d)
}

pub fn date(secs: i64) -> String {
    let (y, m, d) = ymd(secs);
    format!("{y}-{m:02}-{d:02}")
}

pub fn age(secs: i64) -> String {
    match days_ago(secs) {
        d if d < 1 => "today".into(),
        1 => "1 day ago".into(),
        d if d < 60 => format!("{d} days ago"),
        d => format!("{} months ago", d / 30),
    }
}

pub fn days_ago(secs: i64) -> i64 {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    (now - secs) / 86400
}
