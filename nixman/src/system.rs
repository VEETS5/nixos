//! NixOS generations of the running machine.

use crate::repo::capture;
use anyhow::Result;
use serde::Deserialize;
use std::path::Path;

#[derive(Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Generation {
    pub generation: u32,
    pub date: String,
    pub nixos_version: String,
    pub kernel_version: String,
    #[serde(default)]
    pub configuration_revision: String,
    pub current: bool,
}

pub fn generations(dir: &Path) -> Result<Vec<Generation>> {
    let out = capture(dir, "nixos-rebuild", &["list-generations", "--json"])?;
    Ok(serde_json::from_str(&out)?)
}
