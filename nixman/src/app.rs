//! Application state and key handling. Drawing lives in ui.rs, long-running
//! terminal jobs (rebuilds, pushes, ...) in jobs.rs.

use crate::flake::{self, Input};
use crate::git::{self, GitState};
use crate::index::{self, Index};
use crate::lists::{self, Entry, PkgList};
use crate::repo::{capture, Repo};
use crate::system::{self, Generation};
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::widgets::ListState;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::thread;

#[derive(Clone, Copy, PartialEq)]
pub enum Tab {
    Packages,
    Flake,
    System,
    Git,
}
pub const TABS: [(Tab, &str); 4] =
    [(Tab::Packages, "Packages"), (Tab::Flake, "Flake"), (Tab::System, "System"), (Tab::Git, "Git")];

#[derive(Clone, Copy, PartialEq)]
pub enum Focus {
    Lists,
    Entries,
}

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Mode {
    Build,
    Test,
    Switch,
    Boot,
}
impl Mode {
    pub fn verb(self) -> &'static str {
        match self {
            Mode::Build => "build",
            Mode::Test => "test",
            Mode::Switch => "switch",
            Mode::Boot => "boot",
        }
    }
}

#[derive(Clone, Debug)]
pub enum Job {
    Rebuild(Mode),
    FlakeUpdate(Vec<String>),
    Push,
    Pull,
    Diff,
    Rollback,
    Gc,
}

pub enum Confirmed {
    Remove { list: usize, name: String },
    Job(Job),
}

pub enum Popup {
    None,
    Help,
    Search { input: String, results: Vec<usize>, sel: usize, target: usize },
    Confirm { msg: String, on_yes: Confirmed },
    Commit { input: String },
    Move { name: String, from: usize, sel: usize },
}

pub enum Msg {
    Index(Result<Index, String>),
    Fetched(Result<(), String>),
    Validated { attr: String, target: usize, result: Result<(), String> },
    Gens(Result<Vec<Generation>, String>),
    Info(Result<String, String>),
}

pub enum Action {
    None,
    Quit,
    Fg(Job),
}

pub struct ListView {
    pub list: PkgList,
    pub entries: Vec<Entry>,
    pub unmanaged: Vec<String>,
    pub error: Option<String>,
}

pub struct App {
    pub repo: Repo,
    pub tab: Tab,
    pub focus: Focus,
    pub view_host: String,
    pub lists: Vec<ListView>,
    pub list_state: ListState,
    pub entry_state: ListState,
    pub inputs: Vec<Input>,
    pub flake_state: ListState,
    pub gens: Vec<Generation>,
    pub gen_state: ListState,
    pub git: GitState,
    pub git_fetching: bool,
    pub index: Option<Index>,
    pub index_building: bool,
    pub index_err: Option<String>,
    pub popup: Popup,
    pub status: String,
    pub status_err: bool,
    /// What changed this session; becomes the suggested commit message.
    pub changes: Vec<String>,
    /// flake.lock inputs before the last update, to describe what moved.
    pub inputs_before: Option<Vec<Input>>,
    tx: Sender<Msg>,
    pub rx: Receiver<Msg>,
}

fn sel(state: &ListState) -> usize {
    state.selected().unwrap_or(0)
}

fn step(state: &mut ListState, len: usize, delta: i32) {
    if len == 0 {
        state.select(None);
        return;
    }
    let cur = state.selected().unwrap_or(0) as i32;
    state.select(Some((cur + delta).clamp(0, len as i32 - 1) as usize));
}

impl App {
    pub fn new(repo: Repo) -> App {
        let (tx, rx) = channel();
        let view_host = if repo.host_known() {
            repo.this_host.clone()
        } else {
            repo.hosts.first().cloned().unwrap_or_default()
        };
        let mut app = App {
            repo,
            tab: Tab::Packages,
            focus: Focus::Lists,
            view_host,
            lists: vec![],
            list_state: ListState::default().with_selected(Some(0)),
            entry_state: ListState::default().with_selected(Some(0)),
            inputs: vec![],
            flake_state: ListState::default().with_selected(Some(0)),
            gens: vec![],
            gen_state: ListState::default().with_selected(Some(0)),
            git: GitState::default(),
            git_fetching: false,
            index: None,
            index_building: false,
            index_err: None,
            popup: Popup::None,
            status: String::new(),
            status_err: false,
            changes: vec![],
            inputs_before: None,
            tx,
            rx,
        };
        app.refresh();
        app.fetch();
        app.ensure_index();
        if !app.repo.host_known() {
            app.err(format!(
                "this machine ({}) has no hosts/{0}/ — rebuilds are disabled",
                app.repo.this_host
            ));
        } else {
            app.info("? for help");
        }
        app
    }

    pub fn info(&mut self, s: impl Into<String>) {
        self.status = s.into();
        self.status_err = false;
    }
    pub fn err(&mut self, s: impl Into<String>) {
        self.status = s.into();
        self.status_err = true;
    }

    // ── loading ──────────────────────────────────────────────────────────────

    pub fn refresh(&mut self) {
        self.reload_lists();
        match flake::read(&self.repo.dir) {
            Ok(i) => self.inputs = i,
            Err(e) => self.err(format!("{e:#}")),
        }
        self.git = git::read(&self.repo.dir);
        self.load_generations();
    }

    pub fn reload_lists(&mut self) {
        self.lists = self
            .repo
            .lists_for(&self.view_host)
            .into_iter()
            .map(|list| match lists::load(&list) {
                Ok(p) => ListView {
                    list,
                    entries: p.entries,
                    unmanaged: p.unmanaged.into_iter().map(|u| u.1).collect(),
                    error: None,
                },
                Err(e) => ListView { list, entries: vec![], unmanaged: vec![], error: Some(format!("{e:#}")) },
            })
            .collect();
        let n = self.cur_list().entries.len();
        if sel(&self.entry_state) >= n {
            self.entry_state.select(if n == 0 { None } else { Some(n - 1) });
        } else if self.entry_state.selected().is_none() && n > 0 {
            self.entry_state.select(Some(0));
        }
    }

    fn load_generations(&mut self) {
        let tx = self.tx.clone();
        let dir = self.repo.dir.clone();
        thread::spawn(move || {
            let _ = tx.send(Msg::Gens(system::generations(&dir).map_err(|e| format!("{e:#}"))));
        });
    }

    pub fn fetch(&mut self) {
        if self.git_fetching || self.git.upstream.is_none() {
            return;
        }
        self.git_fetching = true;
        let tx = self.tx.clone();
        let dir = self.repo.dir.clone();
        thread::spawn(move || {
            let r = capture(&dir, "git", &["fetch", "--quiet"]).map(|_| ()).map_err(|e| format!("{e:#}"));
            let _ = tx.send(Msg::Fetched(r));
        });
    }

    pub fn ensure_index(&mut self) {
        let Some(rev) = flake::nixpkgs_rev(&self.inputs) else { return };
        if self.index_building || self.index.as_ref().is_some_and(|i| i.rev == rev) {
            return;
        }
        self.index_building = true;
        self.index_err = None;
        let tx = self.tx.clone();
        let dir = self.repo.dir.clone();
        thread::spawn(move || {
            let _ = tx.send(Msg::Index(index::load_or_build(&dir, &rev).map_err(|e| format!("{e:#}"))));
        });
    }

    pub fn on_msg(&mut self, msg: Msg) {
        match msg {
            Msg::Index(r) => {
                self.index_building = false;
                match r {
                    Ok(i) => self.index = Some(i),
                    Err(e) => self.index_err = Some(e),
                }
                self.rerun_search();
            }
            Msg::Fetched(r) => {
                self.git_fetching = false;
                match r {
                    Ok(()) => {
                        self.git = git::read(&self.repo.dir);
                        if self.git.behind > 0 {
                            self.err(format!(
                                "origin has {} new commit(s) — pull (Git tab, P) before editing",
                                self.git.behind
                            ));
                        }
                    }
                    Err(e) => self.err(format!("fetch failed: {e}")),
                }
            }
            Msg::Validated { attr, target, result } => match result {
                Ok(()) => self.add(target, &attr),
                Err(e) => self.err(format!("{attr}: not found in nixpkgs ({e})")),
            },
            Msg::Gens(r) => match r {
                Ok(g) => {
                    self.gens = g;
                    step(&mut self.gen_state, self.gens.len(), 0);
                }
                Err(e) => self.err(format!("generations: {e}")),
            },
            Msg::Info(r) => match r {
                Ok(s) => self.info(s),
                Err(e) => self.err(e),
            },
        }
    }

    // ── package edits ────────────────────────────────────────────────────────

    pub fn cur_list(&self) -> &ListView {
        &self.lists[sel(&self.list_state).min(self.lists.len() - 1)]
    }

    fn change_label(list: &PkgList) -> String {
        format!("{} {}", list.scope(), list.kind())
    }

    /// Lists on the same host(s) as `target` that would also install a package.
    fn conflict(&self, target: usize, attr: &str, ignore: Option<usize>) -> Option<String> {
        let t = &self.lists[target].list;
        self.lists.iter().enumerate().find_map(|(i, lv)| {
            let overlaps = t.host.is_none() || lv.list.host.is_none() || lv.list.host == t.host;
            (Some(i) != ignore && overlaps && lv.entries.iter().any(|e| e.name == attr)).then(|| lv.list.label())
        })
    }

    pub fn add(&mut self, target: usize, attr: &str) {
        if let Some(where_) = self.conflict(target, attr, None) {
            return self.err(format!("{attr} is already in {where_}"));
        }
        let list = self.lists[target].list.clone();
        match lists::insert(&list, attr) {
            Ok(()) => {
                self.changes.push(format!("add {attr} ({})", Self::change_label(&list)));
                self.info(format!("added {attr} to {} — rebuild on System tab to apply", list.label()));
                self.list_state.select(Some(target));
                self.focus = Focus::Entries;
                self.reload_lists();
                let i = self.cur_list().entries.iter().position(|e| e.name == attr);
                self.entry_state.select(i);
                self.git = git::read(&self.repo.dir);
            }
            Err(e) => self.err(format!("{e:#}")),
        }
    }

    fn remove(&mut self, li: usize, name: &str) {
        let list = self.lists[li].list.clone();
        match lists::remove(&list, name) {
            Ok(()) => {
                self.changes.push(format!("remove {name} ({})", Self::change_label(&list)));
                self.info(format!("removed {name} from {}", list.label()));
                self.reload_lists();
                self.git = git::read(&self.repo.dir);
            }
            Err(e) => self.err(format!("{e:#}")),
        }
    }

    fn move_to(&mut self, name: &str, from: usize, to: usize) {
        if from == to {
            return;
        }
        if let Some(w) = self.conflict(to, name, Some(from)) {
            return self.err(format!("{name} is already in {w}"));
        }
        let (src, dst) = (self.lists[from].list.clone(), self.lists[to].list.clone());
        let r = lists::insert(&dst, name).and_then(|_| lists::remove(&src, name));
        match r {
            Ok(()) => {
                self.changes.push(format!(
                    "move {name} ({} → {})",
                    Self::change_label(&src),
                    Self::change_label(&dst)
                ));
                self.info(format!("moved {name} to {}", dst.label()));
                self.list_state.select(Some(to));
                self.reload_lists();
                let i = self.cur_list().entries.iter().position(|e| e.name == name);
                self.entry_state.select(i);
                self.git = git::read(&self.repo.dir);
            }
            Err(e) => {
                self.reload_lists();
                self.err(format!("{e:#}"))
            }
        }
    }

    fn validate_then_add(&mut self, target: usize, attr: String) {
        self.info(format!("checking that {attr} exists in nixpkgs…"));
        let tx = self.tx.clone();
        let dir = self.repo.dir.clone();
        thread::spawn(move || {
            let installable = format!("nixpkgs#{attr}.name");
            let result = capture(&dir, "nix", &["eval", "--inputs-from", ".", &installable, "--raw"])
                .map(|_| ())
                .map_err(|e| format!("{e:#}"));
            let _ = tx.send(Msg::Validated { attr, target, result });
        });
    }

    pub fn open_search(&mut self) {
        self.ensure_index();
        self.popup = Popup::Search { input: String::new(), results: vec![], sel: 0, target: sel(&self.list_state) };
    }

    /// Label of the list (for the host being viewed) that already has `attr`.
    pub fn installed_in(&self, attr: &str) -> Option<String> {
        self.lists.iter().find(|lv| lv.entries.iter().any(|e| e.name == attr)).map(|lv| lv.list.label())
    }

    fn rerun_search(&mut self) {
        if let (Popup::Search { input, results, sel, .. }, Some(idx)) = (&mut self.popup, &self.index) {
            *results = idx.search(input, 200);
            *sel = (*sel).min(results.len().saturating_sub(1));
        }
    }

    // ── after foreground jobs ────────────────────────────────────────────────

    pub fn after_job(&mut self, job: &Job, ok: bool) {
        let before = self.inputs_before.take();
        self.refresh();
        if let (Job::FlakeUpdate(_), Some(before), true) = (job, before, ok) {
            let moved: Vec<String> = self
                .inputs
                .iter()
                .filter(|n| before.iter().any(|b| b.name == n.name && b.rev != n.rev))
                .map(|n| n.name.clone())
                .collect();
            if moved.is_empty() {
                self.info("flake inputs already up to date");
            } else {
                self.changes.push(format!("update {}", moved.join(", ")));
                self.info(format!("updated {} — rebuild to apply", moved.join(", ")));
                self.ensure_index();
            }
            return;
        }
        if ok {
            self.info(format!("{job:?} finished"));
        } else {
            self.err(format!("{job:?} failed — see output above it"));
        }
    }

    // ── keys ─────────────────────────────────────────────────────────────────

    pub fn on_key(&mut self, k: KeyEvent) -> Action {
        if k.modifiers.contains(KeyModifiers::CONTROL) && k.code == KeyCode::Char('c') {
            return Action::Quit;
        }
        if !matches!(self.popup, Popup::None) {
            return self.on_popup_key(k);
        }
        match k.code {
            KeyCode::Char('q') => return Action::Quit,
            KeyCode::Char('?') => self.popup = Popup::Help,
            KeyCode::Char('/') => self.open_search(),
            KeyCode::Char(c @ '1'..='4') => self.tab = TABS[c as usize - '1' as usize].0,
            KeyCode::Tab => {
                let i = TABS.iter().position(|t| t.0 == self.tab).unwrap();
                self.tab = TABS[(i + 1) % TABS.len()].0;
            }
            KeyCode::BackTab => {
                let i = TABS.iter().position(|t| t.0 == self.tab).unwrap();
                self.tab = TABS[(i + TABS.len() - 1) % TABS.len()].0;
            }
            KeyCode::Char('r') => {
                self.refresh();
                self.fetch();
                self.info("refreshed");
            }
            _ => {
                return match self.tab {
                    Tab::Packages => self.packages_key(k),
                    Tab::Flake => self.flake_key(k),
                    Tab::System => self.system_key(k),
                    Tab::Git => self.git_key(k),
                }
            }
        }
        Action::None
    }

    fn dir_key(k: &KeyEvent) -> Option<i32> {
        match k.code {
            KeyCode::Up | KeyCode::Char('k') => Some(-1),
            KeyCode::Down | KeyCode::Char('j') => Some(1),
            KeyCode::PageUp => Some(-10),
            KeyCode::PageDown => Some(10),
            _ => None,
        }
    }

    fn packages_key(&mut self, k: KeyEvent) -> Action {
        if let Some(d) = Self::dir_key(&k) {
            match self.focus {
                Focus::Lists => {
                    step(&mut self.list_state, self.lists.len(), d);
                    self.entry_state.select(Some(0));
                    self.reload_lists();
                }
                Focus::Entries => {
                    let n = self.cur_list().entries.len();
                    step(&mut self.entry_state, n, d)
                }
            }
            return Action::None;
        }
        match k.code {
            KeyCode::Left | KeyCode::Char('h') => self.focus = Focus::Lists,
            KeyCode::Right | KeyCode::Char('l') | KeyCode::Enter => self.focus = Focus::Entries,
            KeyCode::Char('H') => {
                let hosts = &self.repo.hosts;
                if let Some(i) = hosts.iter().position(|h| *h == self.view_host) {
                    self.view_host = hosts[(i + 1) % hosts.len()].clone();
                    self.reload_lists();
                    let note = if self.view_host == self.repo.this_host { " (this machine)" } else { " — edits sync via git" };
                    self.info(format!("editing lists for {}{note}", self.view_host));
                }
            }
            KeyCode::Char('a') => self.open_search(),
            KeyCode::Char('d') | KeyCode::Char('x') | KeyCode::Delete if self.focus == Focus::Entries => {
                let li = sel(&self.list_state);
                if let Some(e) = self.cur_list().entries.get(sel(&self.entry_state)) {
                    let msg = format!("Remove {} from {}?", e.name, self.cur_list().list.label());
                    self.popup = Popup::Confirm { msg, on_yes: Confirmed::Remove { list: li, name: e.name.clone() } };
                }
            }
            KeyCode::Char('m') if self.focus == Focus::Entries => {
                let from = sel(&self.list_state);
                if let Some(e) = self.cur_list().entries.get(sel(&self.entry_state)) {
                    self.popup = Popup::Move { name: e.name.clone(), from, sel: from };
                }
            }
            _ => {}
        }
        Action::None
    }

    fn flake_key(&mut self, k: KeyEvent) -> Action {
        if let Some(d) = Self::dir_key(&k) {
            step(&mut self.flake_state, self.inputs.len(), d);
            return Action::None;
        }
        match k.code {
            KeyCode::Char('u') | KeyCode::Enter => {
                if let Some(i) = self.inputs.get(sel(&self.flake_state)) {
                    self.inputs_before = Some(self.inputs.clone());
                    return Action::Fg(Job::FlakeUpdate(vec![i.name.clone()]));
                }
            }
            KeyCode::Char('U') => {
                self.inputs_before = Some(self.inputs.clone());
                return Action::Fg(Job::FlakeUpdate(vec![]));
            }
            _ => {}
        }
        Action::None
    }

    fn system_key(&mut self, k: KeyEvent) -> Action {
        if let Some(d) = Self::dir_key(&k) {
            step(&mut self.gen_state, self.gens.len(), d);
            return Action::None;
        }
        let mode = match k.code {
            KeyCode::Char('b') => Some(Mode::Build),
            KeyCode::Char('t') => Some(Mode::Test),
            KeyCode::Char('s') => Some(Mode::Switch),
            KeyCode::Char('B') => Some(Mode::Boot),
            _ => None,
        };
        if let Some(m) = mode {
            if !self.repo.host_known() {
                self.err(format!("{} is not a host in this flake — refusing to rebuild", self.repo.this_host));
                return Action::None;
            }
            return Action::Fg(Job::Rebuild(m));
        }
        match k.code {
            KeyCode::Char('R') => {
                self.popup = Popup::Confirm {
                    msg: format!("Roll {} back to the previous generation?", self.repo.this_host),
                    on_yes: Confirmed::Job(Job::Rollback),
                }
            }
            KeyCode::Char('g') => {
                self.popup = Popup::Confirm {
                    msg: "Delete generations older than 14 days and collect garbage?".into(),
                    on_yes: Confirmed::Job(Job::Gc),
                }
            }
            _ => {}
        }
        Action::None
    }

    pub fn suggested_commit(&self) -> String {
        match self.changes.len() {
            0 => String::new(),
            1 => self.changes[0].clone(),
            _ => self.changes.join("; "),
        }
    }

    fn git_key(&mut self, k: KeyEvent) -> Action {
        match k.code {
            KeyCode::Char('c') => {
                if self.git.changes.is_empty() {
                    self.info("nothing to commit");
                } else {
                    self.popup = Popup::Commit { input: self.suggested_commit() };
                }
            }
            KeyCode::Char('p') => {
                if self.git.behind > 0 {
                    self.err("origin has commits you don't — pull (P) first");
                } else {
                    return Action::Fg(Job::Push);
                }
            }
            KeyCode::Char('P') => return Action::Fg(Job::Pull),
            KeyCode::Char('d') => return Action::Fg(Job::Diff),
            KeyCode::Char('f') => {
                self.fetch();
                self.info("fetching…");
            }
            KeyCode::Char('o') => {
                let tx = self.tx.clone();
                let dir = self.repo.dir.clone();
                thread::spawn(move || {
                    let r = capture(&dir, "gh", &["repo", "view", "--web"])
                        .map(|_| "opened repo in browser".to_string())
                        .map_err(|e| format!("{e:#}"));
                    let _ = tx.send(Msg::Info(r));
                });
            }
            _ => {}
        }
        Action::None
    }

    fn commit(&mut self, msg: &str) {
        let dir = &self.repo.dir;
        let r = capture(dir, "git", &["add", "-A"]).and_then(|_| capture(dir, "git", &["commit", "-q", "-m", msg]));
        match r {
            Ok(_) => {
                self.changes.clear();
                self.git = git::read(dir);
                self.info(format!("committed: {msg} — push with p"));
            }
            Err(e) => self.err(format!("{e:#}")),
        }
    }

    fn on_popup_key(&mut self, k: KeyEvent) -> Action {
        let popup = std::mem::replace(&mut self.popup, Popup::None);
        match popup {
            Popup::None => {}
            Popup::Help => {} // any key closes
            Popup::Confirm { msg, on_yes } => match k.code {
                KeyCode::Char('y') | KeyCode::Char('Y') => match on_yes {
                    Confirmed::Remove { list, name } => self.remove(list, &name),
                    Confirmed::Job(j) => return Action::Fg(j),
                },
                KeyCode::Char('n') | KeyCode::Esc => {}
                _ => self.popup = Popup::Confirm { msg, on_yes },
            },
            Popup::Commit { mut input } => match k.code {
                KeyCode::Esc => {}
                KeyCode::Enter if !input.trim().is_empty() => self.commit(input.trim()),
                _ => {
                    edit_text(&mut input, &k);
                    self.popup = Popup::Commit { input };
                }
            },
            Popup::Move { name, from, mut sel } => match k.code {
                KeyCode::Esc => {}
                KeyCode::Enter => self.move_to(&name, from, sel),
                _ => {
                    if let Some(d) = Self::dir_key(&k) {
                        sel = (sel as i32 + d).clamp(0, self.lists.len() as i32 - 1) as usize;
                    }
                    self.popup = Popup::Move { name, from, sel };
                }
            },
            Popup::Search { mut input, results, sel, mut target } => {
                match k.code {
                    KeyCode::Esc => return Action::None,
                    KeyCode::Enter => {
                        let picked = results.get(sel).and_then(|&i| self.index.as_ref().map(|x| x.pkgs[i].attr.clone()));
                        match picked {
                            Some(attr) => self.add(target, &attr),
                            None if !input.trim().is_empty() => self.validate_then_add(target, input.trim().to_string()),
                            None => {}
                        }
                        return Action::None;
                    }
                    KeyCode::Tab => target = (target + 1) % self.lists.len(),
                    KeyCode::BackTab => target = (target + self.lists.len() - 1) % self.lists.len(),
                    KeyCode::Up | KeyCode::Down | KeyCode::PageUp | KeyCode::PageDown => {
                        let d = match k.code {
                            KeyCode::Up => -1,
                            KeyCode::Down => 1,
                            KeyCode::PageUp => -10,
                            _ => 10,
                        };
                        let s = (sel as i32 + d).clamp(0, results.len().saturating_sub(1) as i32) as usize;
                        self.popup = Popup::Search { input, results, sel: s, target };
                        return Action::None;
                    }
                    _ => edit_text(&mut input, &k),
                }
                self.popup = Popup::Search { input, results, sel: 0, target };
                self.rerun_search();
            }
        }
        Action::None
    }
}

fn edit_text(s: &mut String, k: &KeyEvent) {
    match k.code {
        KeyCode::Backspace => {
            s.pop();
        }
        KeyCode::Char('u') if k.modifiers.contains(KeyModifiers::CONTROL) => s.clear(),
        KeyCode::Char('w') if k.modifiers.contains(KeyModifiers::CONTROL) => {
            let t = s.trim_end().rfind(' ').map(|i| i + 1).unwrap_or(0);
            s.truncate(t);
        }
        KeyCode::Char(c) => s.push(c),
        _ => {}
    }
}
