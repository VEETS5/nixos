//! Flake inputs as recorded in flake.lock.

use anyhow::{Context, Result};
use serde_json::Value;
use std::path::Path;

#[derive(Clone, Debug, PartialEq)]
pub struct Input {
    pub name: String,
    pub source: String,
    pub rev: String,
    pub last_modified: i64,
}

impl Input {
    pub fn short_rev(&self) -> &str {
        &self.rev[..self.rev.len().min(7)]
    }
}

pub fn read(dir: &Path) -> Result<Vec<Input>> {
    let text = std::fs::read_to_string(dir.join("flake.lock")).context("reading flake.lock")?;
    let lock: Value = serde_json::from_str(&text)?;
    let nodes = &lock["nodes"];
    let root = lock["root"].as_str().unwrap_or("root");
    let mut out = Vec::new();
    if let Some(inputs) = nodes[root]["inputs"].as_object() {
        for (name, target) in inputs {
            // Root inputs are node names; a list means "follows", which has no lock of its own.
            let Some(node) = target.as_str() else { continue };
            let n = &nodes[node];
            let o = &n["original"];
            let source = match (o["owner"].as_str(), o["repo"].as_str()) {
                (Some(ow), Some(re)) => {
                    let r = o["ref"].as_str().map(|r| format!("/{r}")).unwrap_or_default();
                    format!("{}:{ow}/{re}{r}", o["type"].as_str().unwrap_or("?"))
                }
                _ => o["url"].as_str().unwrap_or("?").to_string(),
            };
            out.push(Input {
                name: name.clone(),
                source,
                rev: n["locked"]["rev"].as_str().unwrap_or("").to_string(),
                last_modified: n["locked"]["lastModified"].as_i64().unwrap_or(0),
            });
        }
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}

pub fn nixpkgs_rev(inputs: &[Input]) -> Option<String> {
    inputs.iter().find(|i| i.name == "nixpkgs").map(|i| i.rev.clone())
}
