//! Reading and editing package lists inside .nix files.
//!
//! A managed list is `<attr> = with pkgs; [ ... ];`. Entries are lines holding a
//! single attribute path (optionally followed by a `# comment`). Anything else
//! inside the list (function calls, multi-line expressions) is preserved and
//! shown as "unmanaged", never touched.

use anyhow::{bail, Context, Result};
use std::path::{Path, PathBuf};

#[derive(Clone, Debug)]
pub struct PkgList {
    pub file: PathBuf,
    pub attr: String,
    /// None = shared by all hosts.
    pub host: Option<String>,
    pub home: bool,
}

impl PkgList {
    pub fn scope(&self) -> &str {
        self.host.as_deref().unwrap_or("all")
    }
    pub fn kind(&self) -> &str {
        if self.home { "home" } else { "system" }
    }
    pub fn label(&self) -> String {
        format!("{} · {}", if self.home { "Home" } else { "System" }, self.scope())
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Entry {
    pub name: String,
    pub comment: Option<String>,
    pub line: usize,
}

#[derive(Debug)]
pub struct Parsed {
    pub entries: Vec<Entry>,
    /// Lines inside the list that are not simple entries (0-based line numbers).
    pub unmanaged: Vec<(usize, String)>,
    pub close_line: usize,
}

fn is_attr_path(s: &str) -> bool {
    let mut chars = s.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    s.chars().all(|c| c.is_ascii_alphanumeric() || "_.'-".contains(c))
        && !s.ends_with('.')
        && !s.contains("..")
}

/// Split a list line into (attr, comment) if it is a simple entry.
fn parse_entry(line: &str) -> Option<(String, Option<String>)> {
    let t = line.trim();
    let (code, comment) = match t.find('#') {
        Some(i) => (t[..i].trim(), Some(t[i + 1..].trim().to_string())),
        None => (t, None),
    };
    if is_attr_path(code) && !matches!(code, "with" | "let" | "in" | "inherit") {
        Some((code.to_string(), comment.filter(|c| !c.is_empty())))
    } else {
        None
    }
}

#[derive(Clone, Copy, PartialEq)]
enum Str {
    None,
    Dq,
    Ind,
}

pub fn parse(text: &str, attr: &str) -> Result<Parsed> {
    let lines: Vec<&str> = text.lines().collect();
    let open_line = lines
        .iter()
        .position(|l| {
            let t = l.trim_start();
            t.strip_prefix(attr)
                .map(|rest| rest.trim_start().starts_with('=') && l.contains('['))
                .unwrap_or(false)
        })
        .with_context(|| format!("no `{attr} = ... [` list found"))?;

    let mut entries = Vec::new();
    let mut unmanaged = Vec::new();
    let (mut depth, mut paren) = (0i32, 0i32);
    let mut st = Str::None;
    let mut started = false;

    for (n, line) in lines.iter().enumerate().skip(open_line) {
        // State at the start of this line decides whether it can be an entry.
        if started && n > open_line && depth == 1 && paren == 0 && st == Str::None {
            let t = line.trim();
            if !t.is_empty() && !t.starts_with('#') && !t.starts_with(']') {
                match parse_entry(t) {
                    Some((name, comment)) => entries.push(Entry { name, comment, line: n }),
                    None => unmanaged.push((n, t.to_string())),
                }
            }
        }
        let b = line.as_bytes();
        let mut i = if n == open_line { line.find('[').unwrap() } else { 0 };
        while i < b.len() {
            let c = b[i];
            match st {
                Str::Dq => {
                    if c == b'\\' { i += 1 } else if c == b'"' { st = Str::None }
                }
                Str::Ind => {
                    if c == b'\'' && b.get(i + 1) == Some(&b'\'') {
                        // '''  and ''$ are escapes inside indented strings
                        if matches!(b.get(i + 2), Some(b'\'') | Some(b'$') | Some(b'\\')) {
                            i += 2;
                        } else {
                            st = Str::None;
                            i += 1;
                        }
                    }
                }
                Str::None => match c {
                    b'#' => break,
                    b'"' => st = Str::Dq,
                    b'\'' if b.get(i + 1) == Some(&b'\'') => { st = Str::Ind; i += 1 }
                    b'[' => { depth += 1; started = true }
                    b']' => {
                        depth -= 1;
                        if started && depth == 0 {
                            if n == open_line {
                                bail!("`{attr}` list is on one line; put `[` and `];` on separate lines");
                            }
                            return Ok(Parsed { entries, unmanaged, close_line: n });
                        }
                    }
                    b'(' | b'{' => paren += 1,
                    b')' | b'}' => paren -= 1,
                    _ => {}
                },
            }
            i += 1;
        }
    }
    bail!("unterminated `{attr}` list")
}

pub fn load(list: &PkgList) -> Result<Parsed> {
    let text = std::fs::read_to_string(&list.file)
        .with_context(|| format!("reading {}", list.file.display()))?;
    parse(&text, &list.attr).with_context(|| list.file.display().to_string())
}

fn write_atomic(path: &Path, text: &str) -> Result<()> {
    let tmp = path.with_extension("nixman-tmp");
    std::fs::write(&tmp, text)?;
    std::fs::rename(&tmp, path)?;
    Ok(())
}

pub fn insert_text(text: &str, attr: &str, name: &str) -> Result<String> {
    if !is_attr_path(name) {
        bail!("`{name}` is not a valid attribute path");
    }
    let p = parse(text, attr)?;
    if p.entries.iter().any(|e| e.name == name) {
        bail!("{name} is already in this list");
    }
    let lines: Vec<&str> = text.lines().collect();
    let indent: String = match p.entries.last() {
        Some(e) => lines[e.line].chars().take_while(|c| c.is_whitespace()).collect(),
        None => {
            let close: String = lines[p.close_line].chars().take_while(|c| c.is_whitespace()).collect();
            format!("{close}  ")
        }
    };
    let mut out: Vec<String> = lines.iter().map(|s| s.to_string()).collect();
    out.insert(p.close_line, format!("{indent}{name}"));
    Ok(join(out, text))
}

pub fn remove_text(text: &str, attr: &str, name: &str) -> Result<String> {
    let p = parse(text, attr)?;
    let e = p.entries.iter().find(|e| e.name == name).with_context(|| format!("{name} not in list"))?;
    let mut out: Vec<String> = text.lines().map(|s| s.to_string()).collect();
    out.remove(e.line);
    Ok(join(out, text))
}

fn join(lines: Vec<String>, original: &str) -> String {
    let mut s = lines.join("\n");
    if original.ends_with('\n') {
        s.push('\n');
    }
    s
}

pub fn insert(list: &PkgList, name: &str) -> Result<()> {
    let text = std::fs::read_to_string(&list.file)?;
    write_atomic(&list.file, &insert_text(&text, &list.attr, name)?)
}

pub fn remove(list: &PkgList, name: &str) -> Result<()> {
    let text = std::fs::read_to_string(&list.file)?;
    write_atomic(&list.file, &remove_text(&text, &list.attr, name)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SRC: &str = r#"{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    ethtool      # NIC diagnostics
    kdePackages.dolphin
    (writeShellScriptBin "x" ''
      exec ${gamescope}/bin/gamescope "$@" # not ] an entry
    '')
    # a comment line
    vim
  ];
  home.packages = with pkgs; [
  ];
}
"#;

    #[test]
    fn parses_entries_and_unmanaged() {
        let p = parse(SRC, "environment.systemPackages").unwrap();
        let names: Vec<_> = p.entries.iter().map(|e| e.name.as_str()).collect();
        assert_eq!(names, ["git", "ethtool", "kdePackages.dolphin", "vim"]);
        assert_eq!(p.entries[1].comment.as_deref(), Some("NIC diagnostics"));
        assert_eq!(p.unmanaged.len(), 1);
        assert_eq!(p.close_line, 11);
    }

    #[test]
    fn insert_and_remove_roundtrip() {
        let t = insert_text(SRC, "environment.systemPackages", "pince").unwrap();
        assert!(t.contains("    vim\n    pince\n  ];"));
        assert!(insert_text(&t, "environment.systemPackages", "pince").is_err());
        let back = remove_text(&t, "environment.systemPackages", "pince").unwrap();
        assert_eq!(back, SRC);
    }

    #[test]
    fn insert_into_empty_list() {
        let t = insert_text(SRC, "home.packages", "btop").unwrap();
        assert!(t.contains("home.packages = with pkgs; [\n    btop\n  ];"));
    }

    #[test]
    fn rejects_bad_names() {
        assert!(insert_text(SRC, "home.packages", "rm -rf").is_err());
        assert!(insert_text(SRC, "home.packages", "foo..bar").is_err());
    }

    #[test]
    fn attr_prefix_does_not_false_match() {
        let src = "home-manager.users.vito.home.packages = with pkgs; [\n  a\n];\nhome.packages = [\n  b\n];\n";
        let p = parse(src, "home.packages").unwrap();
        assert_eq!(p.entries[0].name, "b");
    }
}
