//! Drawing.

use crate::app::{App, Focus, Popup, Tab, TABS};
use crate::git;
use crate::repo::{age, date};
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Color, Modifier, Style, Stylize};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Clear, List, ListItem, ListState, Paragraph, Wrap};
use ratatui::Frame;

const ACCENT: Color = Color::Cyan;

fn block(title: &str, focused: bool) -> Block<'static> {
    let b = Block::bordered().border_type(BorderType::Rounded).title(format!(" {title} "));
    if focused {
        b.border_style(Style::new().fg(ACCENT))
    } else {
        b.border_style(Style::new().fg(Color::DarkGray))
    }
}

fn hl() -> Style {
    Style::new().bg(ACCENT).fg(Color::Black).add_modifier(Modifier::BOLD)
}

pub fn draw(f: &mut Frame, app: &mut App) {
    let [head, body, status, keys] =
        Layout::vertical([Constraint::Length(1), Constraint::Min(3), Constraint::Length(1), Constraint::Length(1)])
            .areas(f.area());
    draw_header(f, app, head);
    match app.tab {
        Tab::Packages => draw_packages(f, app, body),
        Tab::Flake => draw_flake(f, app, body),
        Tab::System => draw_system(f, app, body),
        Tab::Git => draw_git(f, app, body),
    }
    let st = if app.status_err { Style::new().fg(Color::Red) } else { Style::new().fg(Color::Green) };
    f.render_widget(Paragraph::new(format!(" {}", app.status)).style(st), status);
    f.render_widget(Paragraph::new(format!(" {}", hints(app))).fg(Color::DarkGray), keys);
    draw_popup(f, app);
}

fn draw_header(f: &mut Frame, app: &App, area: Rect) {
    let mut spans = vec![Span::styled(" nixman ", Style::new().bg(ACCENT).fg(Color::Black).bold()), Span::raw(" ")];
    for (i, (t, name)) in TABS.iter().enumerate() {
        let s = format!(" {} {name} ", i + 1);
        spans.push(if *t == app.tab { Span::styled(s, Style::new().fg(ACCENT).bold().underlined()) } else { Span::raw(s) });
    }
    let g = &app.git;
    let mut right = format!("{}  ⎇ {}", app.repo.this_host, g.branch);
    if g.upstream.is_some() {
        right += &format!(" ↑{} ↓{}", g.ahead, g.behind);
    }
    if !g.changes.is_empty() {
        right += &format!("  ● {} uncommitted", g.changes.len());
    }
    let [l, r] = Layout::horizontal([Constraint::Min(0), Constraint::Length(right.chars().count() as u16 + 1)]).areas(area);
    f.render_widget(Paragraph::new(Line::from(spans)), l);
    let rs = if g.behind > 0 { Color::Yellow } else { Color::DarkGray };
    f.render_widget(Paragraph::new(right).fg(rs), r);
}

fn hints(app: &App) -> &'static str {
    match &app.popup {
        Popup::Search { .. } => "type to search · ↑↓ pick · Tab target list · Enter add · Esc cancel",
        Popup::Confirm { .. } => "y confirm · n/Esc cancel",
        Popup::Commit { .. } => "Enter commit · Esc cancel · Ctrl-U clear",
        Popup::Move { .. } => "↑↓ choose list · Enter move · Esc cancel",
        Popup::Help => "any key closes",
        Popup::None => match app.tab {
            Tab::Packages => "/ search · a add · d remove · m move · H switch host · ←→ focus · 1-4 tabs · ? help · q quit",
            Tab::Flake => "u update selected · U update all · ? help · q quit",
            Tab::System => "s switch · t test · B boot · b build+diff · R rollback · g gc · ? help",
            Tab::Git => "c commit · p push · P pull · f fetch · d diff · o open GitHub · ? help",
        },
    }
}

fn draw_packages(f: &mut Frame, app: &mut App, area: Rect) {
    let [left, right] = Layout::horizontal([Constraint::Length(30), Constraint::Min(20)]).areas(area);
    let items: Vec<ListItem> = app
        .lists
        .iter()
        .map(|lv| {
            let n = if lv.error.is_some() { "!".into() } else { lv.entries.len().to_string() };
            ListItem::new(format!("{:<22}{n:>4}", lv.list.label()))
        })
        .collect();
    let this = if app.view_host == app.repo.this_host { "this machine" } else { "other machine" };
    let title = format!("{} ({this})", app.view_host);
    let list = List::new(items).block(block(&title, app.focus == Focus::Lists)).highlight_style(hl());
    f.render_stateful_widget(list, left, &mut app.list_state);

    let lv = app.cur_list();
    let file = lv.list.file.strip_prefix(&app.repo.dir).unwrap_or(&lv.list.file).display().to_string();
    let title = format!("{} — {file}", lv.list.label());
    let focused = app.focus == Focus::Entries;
    if let Some(e) = &lv.error {
        let p = Paragraph::new(e.clone()).fg(Color::Red).wrap(Wrap { trim: false }).block(block(&title, focused));
        f.render_widget(p, right);
        return;
    }
    let mut items: Vec<ListItem> = lv
        .entries
        .iter()
        .map(|e| {
            let mut spans = vec![Span::raw(e.name.clone())];
            if let Some(c) = &e.comment {
                spans.push(Span::styled(format!("   # {c}"), Style::new().fg(Color::DarkGray)));
            }
            ListItem::new(Line::from(spans))
        })
        .collect();
    if lv.entries.is_empty() {
        items.push(ListItem::new("(empty — press a to add a package)").fg(Color::DarkGray));
    }
    for u in &lv.unmanaged {
        items.push(ListItem::new(format!("⋯ {u}")).style(Style::new().fg(Color::DarkGray).italic()));
    }
    let list = List::new(items).block(block(&title, focused)).highlight_style(if focused { hl() } else { Style::new().bold() });
    let mut st = app.entry_state.clone();
    if lv.entries.is_empty() {
        st.select(None);
    }
    f.render_stateful_widget(list, right, &mut st);
    *app.entry_state.offset_mut() = st.offset();
}

fn draw_flake(f: &mut Frame, app: &mut App, area: Rect) {
    let items: Vec<ListItem> = app
        .inputs
        .iter()
        .map(|i| {
            let old = crate::repo::days_ago(i.last_modified) > 30;
            ListItem::new(Line::from(vec![
                Span::styled(format!("{:<16}", i.name), Style::new().bold()),
                Span::raw(format!("{}  ", i.short_rev())),
                Span::raw(format!("{}  ", date(i.last_modified))),
                Span::styled(format!("{:<14}", age(i.last_modified)), Style::new().fg(if old { Color::Yellow } else { Color::Green })),
                Span::styled(i.source.clone(), Style::new().fg(Color::DarkGray)),
            ]))
        })
        .collect();
    let list = List::new(items).block(block("Flake inputs (flake.lock)", true)).highlight_style(hl());
    f.render_stateful_widget(list, area, &mut app.flake_state);
}

fn draw_system(f: &mut Frame, app: &mut App, area: Rect) {
    let [top, bottom] = Layout::vertical([Constraint::Length(6), Constraint::Min(3)]).areas(area);
    let cur = app.gens.iter().find(|g| g.current);
    let mut lines = vec![Line::from(vec![
        Span::raw("Machine  "),
        Span::styled(app.repo.this_host.clone(), Style::new().bold().fg(ACCENT)),
        Span::raw(if app.repo.host_known() { "" } else { "  (not in flake — rebuilds disabled)" }),
    ])];
    if let Some(g) = cur {
        lines.push(Line::raw(format!("Running  generation {} · NixOS {} · kernel {}", g.generation, g.nixos_version, g.kernel_version)));
        let rev = g.configuration_revision.as_str();
        let (txt, color) = if rev.is_empty() || rev == "Unknown" {
            ("built before revision tracking — next rebuild will record its commit".to_string(), Color::DarkGray)
        } else if let Some(clean) = rev.strip_suffix("-dirty") {
            (format!("built from {} plus uncommitted changes", &clean[..clean.len().min(7)]), Color::Yellow)
        } else if rev == app.git.head {
            (format!("built from {} — matches HEAD", &rev[..7.min(rev.len())]), Color::Green)
        } else {
            match git::commits_behind_head(&app.repo.dir, rev) {
                Some(n) => (format!("built from {} — {n} commit(s) behind HEAD, rebuild to catch up", &rev[..7.min(rev.len())]), Color::Yellow),
                None => (format!("built from {rev}, not in this repo's history"), Color::Yellow),
            }
        };
        lines.push(Line::from(vec![Span::raw("Config   "), Span::styled(txt, Style::new().fg(color))]));
    } else {
        lines.push(Line::raw("loading generations…").fg(Color::DarkGray));
    }
    if !app.git.changes.is_empty() {
        lines.push(Line::raw(format!("Repo     {} uncommitted change(s) will be included in a rebuild", app.git.changes.len())).fg(Color::Yellow));
    }
    f.render_widget(Paragraph::new(lines).block(block("System", false)), top);

    let items: Vec<ListItem> = app
        .gens
        .iter()
        .map(|g| {
            let rev = &g.configuration_revision;
            let rev = if rev.is_empty() || rev == "Unknown" { "-".to_string() } else { rev.chars().take(7).collect() };
            let mut l = Line::raw(format!("#{:<5} {}  NixOS {:<24} kernel {:<9} rev {rev}", g.generation, g.date, g.nixos_version, g.kernel_version));
            if g.current {
                l.push_span(Span::styled("  ← current", Style::new().fg(Color::Green).bold()));
            }
            ListItem::new(l)
        })
        .collect();
    let list = List::new(items).block(block("Generations", true)).highlight_style(hl());
    f.render_stateful_widget(list, bottom, &mut app.gen_state);
}

fn draw_git(f: &mut Frame, app: &mut App, area: Rect) {
    let [top, rest] = Layout::vertical([Constraint::Length(4), Constraint::Min(3)]).areas(area);
    let [left, right] = Layout::horizontal([Constraint::Percentage(45), Constraint::Percentage(55)]).areas(rest);
    let g = &app.git;
    let sync = match &g.upstream {
        None => "no upstream branch".to_string(),
        Some(u) if g.ahead == 0 && g.behind == 0 => format!("in sync with {u}"),
        Some(u) => format!("{} ahead, {} behind {u}", g.ahead, g.behind),
    };
    let fetching = if app.git_fetching { "  (fetching…)" } else { "" };
    let info = vec![
        Line::raw(format!("Branch   {}   {sync}{fetching}", g.branch)),
        Line::raw(format!("Remote   {}", g.remote_url)).fg(Color::DarkGray),
    ];
    f.render_widget(Paragraph::new(info).block(block("Repository", false)), top);

    let mut items: Vec<ListItem> = g.changes.iter().map(|c| ListItem::new(c.clone())).collect();
    if items.is_empty() {
        items.push(ListItem::new("working tree clean").fg(Color::DarkGray));
    }
    if !app.changes.is_empty() {
        items.push(ListItem::new(""));
        items.push(ListItem::new("This session:").bold());
        items.extend(app.changes.iter().map(|c| ListItem::new(format!("  {c}")).fg(ACCENT)));
    }
    f.render_widget(List::new(items).block(block("Changes", true)), left);
    let log: Vec<ListItem> = g.log.iter().map(|l| ListItem::new(l.clone())).collect();
    f.render_widget(List::new(log).block(block("Recent commits", false)), right);
}

fn centered(area: Rect, w: u16, h: u16) -> Rect {
    let w = w.min(area.width.saturating_sub(4));
    let h = h.min(area.height.saturating_sub(2));
    Rect { x: area.x + (area.width - w) / 2, y: area.y + (area.height - h) / 2, width: w, height: h }
}

fn draw_popup(f: &mut Frame, app: &App) {
    let area = f.area();
    match &app.popup {
        Popup::None => {}
        Popup::Help => {
            let r = centered(area, 72, 30);
            f.render_widget(Clear, r);
            f.render_widget(Paragraph::new(HELP).block(block("Help", true)), r);
        }
        Popup::Confirm { msg, .. } => {
            let r = centered(area, (msg.len() as u16 + 6).max(30), 5);
            f.render_widget(Clear, r);
            let p = Paragraph::new(vec![Line::raw(msg.clone()), Line::raw(""), Line::raw("y / n").fg(Color::DarkGray)]);
            f.render_widget(p.block(block("Confirm", true)), r);
        }
        Popup::Commit { input } => {
            let r = centered(area, 80, 3);
            f.render_widget(Clear, r);
            f.render_widget(Paragraph::new(format!("{input}▏")).block(block("Commit message", true)), r);
        }
        Popup::Move { name, from, sel } => {
            let r = centered(area, 40, app.lists.len() as u16 + 2);
            f.render_widget(Clear, r);
            let items: Vec<ListItem> = app
                .lists
                .iter()
                .enumerate()
                .map(|(i, lv)| ListItem::new(format!("{}{}", lv.list.label(), if i == *from { "  (current)" } else { "" })))
                .collect();
            let mut st = ListState::default().with_selected(Some(*sel));
            f.render_stateful_widget(List::new(items).block(block(&format!("Move {name} to"), true)).highlight_style(hl()), r, &mut st);
        }
        Popup::Search { input, results, sel, target } => {
            let r = centered(area, 100, area.height.saturating_sub(4));
            f.render_widget(Clear, r);
            let title = format!("Add package → {}", app.lists[*target].list.label());
            let b = block(&title, true);
            let inner = b.inner(r);
            f.render_widget(b, r);
            let [q, rest, detail] =
                Layout::vertical([Constraint::Length(2), Constraint::Min(1), Constraint::Length(5)]).areas(inner);
            f.render_widget(
                Paragraph::new(vec![Line::from(vec![Span::styled("search: ", Style::new().fg(ACCENT)), Span::raw(format!("{input}▏"))])]),
                q,
            );
            match &app.index {
                None => {
                    let msg = match &app.index_err {
                        Some(e) => format!("package index failed: {e}\n\nYou can still type an exact attribute (e.g. kdePackages.kate) and press Enter."),
                        None => "Building the package index for this nixpkgs revision (about a minute the first time)…\n\nYou can type an exact attribute and press Enter meanwhile.".into(),
                    };
                    f.render_widget(Paragraph::new(msg).fg(Color::DarkGray).wrap(Wrap { trim: false }), rest);
                }
                Some(idx) => {
                    let items: Vec<ListItem> = results
                        .iter()
                        .map(|&i| {
                            let p = &idx.pkgs[i];
                            let mark = if app.installed_in(&p.attr).is_some() {
                                Span::styled("✓ ", Style::new().fg(Color::Green).bold())
                            } else {
                                Span::raw("  ")
                            };
                            ListItem::new(Line::from(vec![
                                mark,
                                Span::styled(format!("{:<34}", trunc(&p.attr, 33)), Style::new().bold()),
                                Span::styled(format!("{:<14}", trunc(&p.version, 13)), Style::new().fg(Color::Green)),
                                Span::styled(p.description.clone(), Style::new().fg(Color::DarkGray)),
                            ]))
                        })
                        .collect();
                    if items.is_empty() && !input.is_empty() {
                        let p = Paragraph::new("No matches in the index. Packages in nested sets (kdePackages.*, python3Packages.*) aren't indexed — type the full attribute and press Enter to check and add it.")
                            .fg(Color::DarkGray)
                            .wrap(Wrap { trim: false });
                        f.render_widget(p, rest);
                    } else {
                        let mut st = ListState::default().with_selected(Some(*sel));
                        f.render_stateful_widget(List::new(items).highlight_style(hl()), rest, &mut st);
                        if let Some(p) = results.get(*sel).map(|&i| &idx.pkgs[i]) {
                            let status = match app.installed_in(&p.attr) {
                                Some(l) => Span::styled(format!("installed · {l}"), Style::new().fg(Color::Green)),
                                None => Span::styled(format!("Enter adds to {}", app.lists[*target].list.label()), Style::new().fg(Color::DarkGray)),
                            };
                            let desc = if p.description.is_empty() { "(no description)".to_string() } else { p.description.clone() };
                            let lines = vec![
                                Line::from(vec![Span::styled(format!("{}  {}   ", p.attr, p.version), Style::new().bold().fg(ACCENT)), status]),
                                Line::raw(desc),
                            ];
                            let b = Block::new().borders(ratatui::widgets::Borders::TOP).border_style(Style::new().fg(Color::DarkGray));
                            f.render_widget(Paragraph::new(lines).wrap(Wrap { trim: true }).block(b), detail);
                        }
                        if !results.is_empty() {
                            let count = format!("{} match{}", results.len(), if results.len() == 1 { "" } else { "es" });
                            f.render_widget(Paragraph::new(count).fg(Color::DarkGray).alignment(ratatui::layout::Alignment::Right), q);
                        }
                    }
                }
            }
        }
    }
}

const HELP: &str = "\
Global
  1-4 / Tab      switch tab            r   refresh + git fetch
  /              search nixpkgs (from any tab)
  ?              this help             q   quit

Packages
  ←→ / h l       focus lists / packages
  ↑↓ / j k       move
  a  /           search nixpkgs and add (Tab picks the target list)
  d              remove package        m   move to another list
  H              edit another host's lists (applies there after git sync)

Flake
  u / Enter      update selected input U   update all inputs

System  (always targets this machine only)
  b              build and show what would change
  s / t / B      build, show diff, then switch / test / boot
  R              roll back to previous generation
  g              delete generations older than 14 days + gc

Git
  c   commit (message pre-filled from this session's changes)
  p   push    P   pull --rebase    f   fetch
  d   full diff                     o   open repo on GitHub

Typical flow: add packages → s (switch) → 4 → c → p.
On the other machine: nixman → 4 → P → 3 → s.";

fn trunc(s: &str, n: usize) -> String {
    if s.chars().count() <= n { s.to_string() } else { s.chars().take(n - 1).collect::<String>() + "…" }
}
