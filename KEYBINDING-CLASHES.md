# Keybinding Clashes Audit

Audit of keybinding collisions across the `.dotmez` setup on this machine.
Generated 2026-07-25. Last updated 2026-07-25 (LSP bindings + `default_mode` fix).

## ✅ Status: primary fix applied

`default_mode "locked"` is now set in `configs/zellij/config.kdl` and deployed to
`~/.config/zellij/config.kdl`. Zellij now starts **Locked**, binding nothing but
`Ctrl+g`, so every key below reaches the inner app. **This neutralises every 🔴 /
🟠 / 🟡 row in this document while locked.**

The tables below are therefore a record of what collides *when you unlock into
Normal mode with `Ctrl+g`* — not a list of things currently broken.

Caveat: this is a mode toggle, not a one-shot tmux prefix. `Ctrl+g` unlocks and
you stay unlocked until you press `Ctrl+g` again.

**Applies to new sessions only** — `default_mode` is read at session start, so any
zellij session already running keeps the old behaviour until restarted.

## How to read this

Keys are consumed by the **outermost layer that binds them**. The stack here is:

```
GNOME Terminal          ← grabs Ctrl+Shift+* only
  └── zellij            ← grabs ~9 bare Ctrl keys + most Alt keys  ⚠️ the aggressor
        └── zsh  OR  micro / helix / htop / ranger / ...
```

Anything zellij binds **never reaches** micro or zsh. That single fact explains
essentially every clash below, including the Ctrl+Q one that prompted this audit.

Confidence markers:

- **[verified]** — read directly from a config file on this machine
- **[default]** — the app's documented default; not overridden in any local config

---

## 1. Zellij: the keys it swallows

Source: `~/.config/zellij/config.kdl` **[verified]**, zellij 0.43.1. `keybinds`
does **not** use `clear-defaults=true`, so all default bindings are live.

`default_mode "locked"` is now set (`config.kdl:346`), so sessions start Locked
and none of the following fire until you press `Ctrl+g`. Before that change,
sessions started in Normal mode and every row below was active by default.

### Bare Ctrl keys (from `shared_except "locked"` + mode switches)

| Key | Zellij action | Config line |
|---|---|---|
| `Ctrl+q` | **Quit zellij entirely** | `config.kdl:181` |
| `Ctrl+g` | Switch to Locked mode | `config.kdl:180` |
| `Ctrl+p` | Switch to Pane mode | `config.kdl:199` |
| `Ctrl+n` | Switch to Resize mode | `config.kdl:202` |
| `Ctrl+s` | Switch to Scroll mode | `config.kdl:205` |
| `Ctrl+o` | Switch to Session mode | `config.kdl:208` |
| `Ctrl+t` | Switch to Tab mode | `config.kdl:211` |
| `Ctrl+h` | Switch to Move mode | `config.kdl:214` |
| `Ctrl+b` | Switch to Tmux mode | `config.kdl:217` |

### Alt keys

`Alt+f` `Alt+n` `Alt+[` `Alt+]` `Alt+h/j/k/l` `Alt+←/→/↑/↓` `Alt+=` `Alt++`
`Alt+-` `Alt+p` `Alt+Shift+p` — `config.kdl:182-193`

**Escape hatch that already exists:** `Ctrl+g` puts zellij in **Locked** mode,
where it passes *everything* through except `Ctrl+g` to unlock. This is the
built-in answer to every clash below — it's just manual.

---

## 2. micro ↔ zellij

micro 2.0.13, with the `filemanager` and `lsp` plugins installed via
`setup-micro.sh`. Local overrides in `~/.config/micro/bindings.json` **[verified]**:

```json
{ "Alt-/": "lua:comment.comment", "CtrlUnderscore": "lua:comment.comment" }
```

Everything else is micro **[default]**, plus the `lsp` plugin's own **[default]**
bindings (`Ctrl+Space`, `Alt+K/D/R/F`).

| Key | micro wants | zellij takes it for | Severity |
|---|---|---|---|
| `Ctrl+q` | Quit micro | **Quit zellij** | 🔴 Critical — kills the whole session, not the editor |
| `Ctrl+s` | **Save file** | Scroll mode | 🔴 Critical — cannot save |
| `Ctrl+o` | Open file | Session mode | 🟠 High |
| `Ctrl+n` | Find next | Resize mode | 🟠 High |
| `Ctrl+p` | Find previous | Pane mode | 🟠 High |
| `Ctrl+t` | New tab | Tab mode | 🟡 Medium |
| `Ctrl+b` | Shell mode | Tmux mode | 🟡 Medium |
| `Ctrl+g` | Toggle help | Locked mode | 🟡 Medium |
| `Ctrl+h` | Backspace | Move mode | 🟢 Low here — GNOME Terminal sends `^?` for Backspace, so the physical key still works |
| `Alt+/` | Comment (yours) | *free* | ✅ No clash |

### micro LSP plugin bindings

| Key | micro LSP wants | zellij takes it for | Severity |
|---|---|---|---|
| `Alt+F` | **Format** | `ToggleFloatingPanes` (`config.kdl:182`) | 🟠 High — and `lsp.formatOnSave` is on, so save-formatting still works |
| `Alt+K` | Hover docs | `MoveFocus Up` (`config.kdl:189`) | 🟠 High |
| `Alt+D` | Go to definition | *free* | ✅ No clash |
| `Alt+R` | Find references | *free* | ✅ No clash |
| `Ctrl+Space` | Autocomplete | *free* | ✅ No clash |

**Safe in micro (zellij does not bind these):** `Ctrl+e` command mode,
`Ctrl+f` find, `Ctrl+z` undo, `Ctrl+y` redo, `Ctrl+c/x/v` copy/cut/paste,
`Ctrl+a` select all, `Ctrl+d` duplicate line, `Ctrl+k` cut line, `Ctrl+l` goto
line, `Ctrl+w` next split, `Ctrl+r` toggle ruler, `Ctrl+_` comment.

> Note: micro's shortcut list printed by `setup-micro.sh` advertises `Ctrl+S`
> and `Ctrl+E` — `Ctrl+S` is a lie inside zellij.

---

## 3. zsh ↔ zellij

`~/.zshrc` **[verified]** — only two explicit `bindkey` lines (`:126-127`,
`Ctrl+↑`/`Ctrl+↓` → history search; no clash). Everything else is the zsh
**emacs keymap [default]**, plus oh-my-zsh with `zsh-syntax-highlighting`,
`zsh-autosuggestions`, `z`.

| Key | zsh line-editor action | zellij takes it for | Severity |
|---|---|---|---|
| `Ctrl+p` | Previous history | Pane mode | 🟠 High — very common muscle memory |
| `Ctrl+n` | Next history | Resize mode | 🟠 High |
| `Ctrl+s` | (forward-search / XOFF) | Scroll mode | 🟠 High |
| `Ctrl+q` | (push-line / XON) | **Quit zellij** | 🔴 Critical |
| `Ctrl+b` | Backward char | Tmux mode | 🟡 Medium |
| `Ctrl+t` | Transpose chars | Tab mode | 🟢 Low |
| `Ctrl+o` | Accept-line-and-down-history | Session mode | 🟢 Low |
| `Ctrl+g` | Send break / abort | Locked mode | 🟡 Medium |
| `Ctrl+h` | Backward-delete-char | Move mode | 🟢 Low — see micro note |

**Safe in zsh:** `Ctrl+r` reverse search, `Ctrl+a/e` line start/end, `Ctrl+u/k/w`
kill, `Ctrl+l` clear, `Ctrl+c`, `Ctrl+d`, `Ctrl+z`.

### ⚠️ Now-active: terminal flow control (XON/XOFF)

`~/.zshrc` has **no `stty -ixon`** **[verified]**. Outside zellij — or inside
zellij **Locked** mode — `Ctrl+s` freezes the terminal and `Ctrl+q` unfreezes it.

Normal mode used to mask this because zellij ate both keys first. **Now that
`default_mode "locked"` is set, that mask is gone by default**: a stray `Ctrl+s`
at a shell prompt will appear to hang the terminal. Adding `stty -ixon` went from
nice-to-have to worth doing.

### Latent: fzf

`fzf` is installed at `/usr/bin/fzf` but is **not** wired into zsh — it is not in
the oh-my-zsh `plugins` list and its key-bindings file is never sourced
**[verified]**. So `Ctrl+t` / `Ctrl+r` / `Alt+c` are *not* currently bound.
If you ever enable the standard fzf shell integration, `Ctrl+t` (file widget)
and `Alt+c` (cd widget) will land straight on top of zellij's Tab mode and
zellij's Alt block.

---

## 4. Other TUIs installed

Installed and on `PATH` **[verified]**: `micro` `hx` `zellij` `btop` `htop`
`oxker` `lazydocker` `ranger` `nano` `fzf`.

| App | Conflicting keys **[default]** | Notes |
|---|---|---|
| **helix** (`hx`) | `Ctrl+s`, `Ctrl+o`, `Ctrl+n`, `Ctrl+p`, `Ctrl+b`, `Ctrl+h` | Jumplist (`Ctrl+o`/`Ctrl+i`) and half/page scroll (`Ctrl+b`) are hit. Helix leans on `Space` menus, so damage is lower than micro. `~/.config/helix/` is **empty** — no local overrides exist yet. |
| **nano** | `Ctrl+o` (WriteOut), `Ctrl+s` (save), `Ctrl+t`, `Ctrl+p`, `Ctrl+n`, `Ctrl+b` | nano is *heavily* bare-Ctrl based — worst-hit app of the set. |
| **ranger** | `Ctrl+n`, `Ctrl+p`, `Ctrl+b`, `Ctrl+h` | Primary bindings are vim-style single letters, so mostly survives. |
| **htop** | — | F-keys + single letters. ✅ Clean. |
| **btop** | — | Esc/single letters. ✅ Clean. |
| **lazydocker** | `Ctrl+p` (rare) | Mostly single letters + Tab. Near-clean. |
| **oxker** | — | Single letters + Tab. ✅ Clean. |

---

## 5. Terminal layer (GNOME Terminal)

`org.gnome.Terminal.desktop` is the default terminal **[verified]**, `TERM=xterm-256color`.

GNOME Terminal binds **`Ctrl+Shift+*`** (`C`/`V` copy-paste, `T` new tab, `N` new
window, `W` close, `F` find) plus `Ctrl+PageUp/PageDown` and `Ctrl+±` zoom.

✅ **No clash with zellij or micro** — zellij binds bare `Ctrl` and `Alt`, GNOME
Terminal binds `Ctrl+Shift`. The two layers are cleanly separated. The only thing
to know is that copy/paste in a terminal is `Ctrl+Shift+C/V`, so micro's
`Ctrl+c`/`Ctrl+v` reach micro correctly.

---

## 6. Non-keybinding clashes found along the way

### 6a. `cc` alias disagreement

| Item | Repo says | Live `~/.zshrc` says |
|---|---|---|
| `alias cc` | `alias cc=claude` (`configs/.zshrc:70`, `ubuntuDesktop/.zshrc:20`) | `alias cc=clear` (`~/.zshrc:64`) |

**[verified]** — the repo and the live machine disagree about what `cc` does, and
`install_aliases.sh` only adds/updates aliases by name, so whichever ran last
wins silently. (`cc` also shadows the C compiler either way.)

### 6b. ⚠️ `install_zellij_config.sh` points at a stale clone

`install_zellij_config.sh:5` hardcodes `source_dir="$HOME/.dotmez/configs/zellij"`,
but **[verified]**:

- the working repo is at `~/gitrepo/.dotmez`
- `~/.dotmez` is a *separate, real directory* — a stale clone stuck at commit
  `3c11c07` from 24 Aug 2025 (not a symlink; `readlink -f` resolves to itself)
- `~/.dotmez/configs/zellij/` **does not exist** at that commit

So the script cannot work on this machine — it would `cp` a nonexistent file.
The `default_mode` change above was therefore deployed by copying directly from
`~/gitrepo/.dotmez/configs/zellij/config.kdl`, bypassing the script.

`copy_configs.sh` and `install_usuals.sh` should be checked for the same
`$HOME/.dotmez` assumption. Either delete/refresh the stale clone, symlink
`~/.dotmez` → `~/gitrepo/.dotmez`, or make the scripts resolve their own location.

---

## Options — remaining

**Done:** `default_mode "locked"` (was option 1/2 territory — it fixes micro, nano,
helix and zsh in one edit, at the cost of a modal `Ctrl+g`).

Still open:

1. **Rebind zellij off the bare-`Ctrl` keys** anyway — move mode switches behind a
   single `Ctrl+a`-style prefix. Only worth it if the Locked-mode toggle turns out
   to annoy you; it buys one-shot navigation instead of a mode flip.

2. **Rebind micro's `Alt+F` / `Alt+K`** (LSP format & hover) onto free keys, so
   they work even while unlocked. `Alt+D` / `Alt+R` / `Ctrl+Space` are already fine.

3. **Add `stty -ixon`** to `.zshrc`. Now *more* relevant, not less: in Locked mode
   `Ctrl+s` reaches the terminal, so the XON/XOFF freeze is live by default.

4. **Resolve the `cc` alias** disagreement (6a).

5. **Fix the `~/.dotmez` path bug** (6b) — highest practical priority, since it
   means the install scripts silently don't do what they claim.

Recommendation: **3 and 5** next. 3 is a one-liner and Locked mode has made the
freeze reachable; 5 is the difference between the install scripts working and not.
