//! Searchable index of nixpkgs, built once per locked nixpkgs revision.

use crate::repo::{cache_dir, capture};
use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::HashMap;
use std::path::Path;

#[derive(Deserialize)]
struct Raw {
    #[serde(default)]
    pname: String,
    #[serde(default)]
    version: String,
    #[serde(default)]
    description: String,
}

pub struct Pkg {
    pub attr: String,
    pub version: String,
    pub description: String,
    key: String,
    desc_lc: String,
}

pub struct Index {
    pub rev: String,
    pub pkgs: Vec<Pkg>,
}

pub fn load_or_build(flake_dir: &Path, rev: &str) -> Result<Index> {
    let path = cache_dir().join(format!("nixpkgs-{rev}.json"));
    let json = match std::fs::read_to_string(&path) {
        Ok(s) => s,
        Err(_) => {
            let s = capture(flake_dir, "nix", &["search", "--inputs-from", ".", "nixpkgs", "^", "--json"])
                .context("building package index")?;
            std::fs::create_dir_all(cache_dir())?;
            // Old indexes are dead weight once nixpkgs moves on.
            if let Ok(rd) = std::fs::read_dir(cache_dir()) {
                for e in rd.flatten() {
                    if e.file_name().to_string_lossy().starts_with("nixpkgs-") {
                        let _ = std::fs::remove_file(e.path());
                    }
                }
            }
            std::fs::write(&path, &s)?;
            s
        }
    };
    let raw: HashMap<String, Raw> = serde_json::from_str(&json).context("parsing package index")?;
    let mut pkgs: Vec<Pkg> = raw
        .into_iter()
        .map(|(k, r)| {
            let attr = k.splitn(3, '.').nth(2).unwrap_or(&k).to_string();
            let _ = r.pname;
            Pkg {
                key: attr.to_lowercase(),
                desc_lc: r.description.to_lowercase(),
                attr,
                version: r.version,
                description: r.description,
            }
        })
        .collect();
    pkgs.sort_by(|a, b| a.attr.cmp(&b.attr));
    Ok(Index { rev: rev.to_string(), pkgs })
}

impl Index {
    /// Rank: exact attr, attr prefix, attr substring, description substring.
    pub fn search(&self, query: &str, limit: usize) -> Vec<usize> {
        let q = query.trim().to_lowercase();
        if q.is_empty() {
            return vec![];
        }
        let mut hits: Vec<(u8, usize, usize)> = self
            .pkgs
            .iter()
            .enumerate()
            .filter_map(|(i, p)| {
                let rank = if p.key == q {
                    0
                } else if p.key.starts_with(&q) {
                    1
                } else if p.key.contains(&q) {
                    2
                } else if p.desc_lc.contains(&q) {
                    3
                } else {
                    return None;
                };
                Some((rank, p.attr.len(), i))
            })
            .collect();
        hits.sort();
        hits.into_iter().take(limit).map(|h| h.2).collect()
    }
}
