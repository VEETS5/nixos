//! Git state for the config repo.

use crate::repo::capture;
use std::path::Path;

#[derive(Default, Clone)]
pub struct GitState {
    pub branch: String,
    pub head: String,
    pub upstream: Option<String>,
    pub ahead: u32,
    pub behind: u32,
    pub changes: Vec<String>,
    pub log: Vec<String>,
    pub remote_url: String,
}

pub fn read(dir: &Path) -> GitState {
    let g = |args: &[&str]| capture(dir, "git", args).unwrap_or_default();
    let mut s = GitState {
        branch: g(&["rev-parse", "--abbrev-ref", "HEAD"]).trim().into(),
        head: g(&["rev-parse", "HEAD"]).trim().into(),
        changes: g(&["status", "--porcelain"]).lines().map(String::from).collect(),
        log: g(&["log", "-20", "--format=%h  %s  (%cr)"]).lines().map(String::from).collect(),
        remote_url: g(&["remote", "get-url", "origin"]).trim().into(),
        ..Default::default()
    };
    let up = g(&["rev-parse", "--abbrev-ref", "@{u}"]).trim().to_string();
    if !up.is_empty() {
        let counts = g(&["rev-list", "--left-right", "--count", "HEAD...@{u}"]);
        let mut it = counts.split_whitespace().map(|n| n.parse().unwrap_or(0));
        s.ahead = it.next().unwrap_or(0);
        s.behind = it.next().unwrap_or(0);
        s.upstream = Some(up);
    }
    s
}

/// How many commits `rev` is behind HEAD, if `rev` is known to this repo.
pub fn commits_behind_head(dir: &Path, rev: &str) -> Option<u32> {
    capture(dir, "git", &["rev-list", "--count", &format!("{rev}..HEAD")]).ok()?.trim().parse().ok()
}
