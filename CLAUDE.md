# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal dotfiles repo (`~/.dotmez`) for managing shell configs, AI tool skills/commands, and environment setup scripts across Ubuntu and macOS. It also includes a Docker-based test environment for validating configs.

## Key commands

```bash
# Build and run the Docker test environment (Ubuntu 22.04 + XFCE4 desktop)
make build          # docker build
make run            # run with SSH (port 2222) + RDP (port 3389)
make run-without-rdp
make ssh            # SSH into container (after run)
make reset-docker   # stop + remove container, clear known_hosts entry
make retest         # reset-docker → run → sleep 3 → ssh

# Deploy dotfiles to the live system
./copy_configs.sh          # copy configs/ → $HOME (zshrc, p10k.zsh)
./backup_configs.sh        # snapshot $HOME dotfiles → configs/ with timestamp
./install_aliases.sh       # compare aliases in configs/.zshrc vs ~/.zshrc (--apply to sync)
./backup_app_configs.sh    # pull ~/.config/<app>/ configs back into configs/ (fresh, herdr)
./install_usuals.sh        # install common apt packages and tools (Debian/Ubuntu/Fedora/openSUSE)
./omarchy_install_usuals.sh  # Arch/Omarchy variant: pacman + yay, no side-loaded binaries
./zjstatus_install.sh      # install zellij status bar plugin
./omarchy_setup_fingerprint.sh  # wire an enrolled fingerprint into PAM (sudo/polkit/lock)
./omarchy_laptop_setup.sh       # apply display scaling + text sizing (--dry-run to preview)
./omarchy_install_branding.sh   # "mezarchy" branding: screensaver text, boot/login logo, idle timers, wallpapers (--dry-run, --all-themes)
./mezarchy_wallpapers.py [scene ...]  # regenerate the mezarchy wallpapers from SVG (--list, --out DIR, --svg); needs rsvg-convert
./mezarchy_bg.sh rotate on [MIN]      # systemd user timer cycling the wallpaper through ROTATE in mezarchy-bg.conf (default 15 min)
./mezarchy_bg.sh workspace on         # systemd user service giving each Hyprland workspace its own wallpaper (WORKSPACE map in the conf)
./mezarchy_bg.sh next|prev|random|set NAME|list|status   # one-shots; `rotate off` / `workspace off` remove the units

# Per-app config deployment (configs/<app>/ → ~/.config/<app>/, with backup)
./install_zellij_config.sh
./install_fresh_config.sh
./install_herdr_config.sh
"AI Utilities/install-claude-skills.sh"      # sync AI Utilities/.claude/skills/ → ~/.claude/skills/
"AI Utilities/install-opencode-commands.sh"  # sync AI Utilities/.config/opencode/commands/ → ~/.config/opencode/commands/
```

## Repo structure

| Path | Purpose |
|---|---|
| `configs/` | Shell configs deployed to `$HOME` (`.zshrc`, `.p10k.zsh`, `.bashrc`) |
| `configs/zellij/` | `config.kdl` → `~/.config/zellij/` |
| `configs/hypr/` | `monitors.lua` → `~/.config/hypr/` — per-output scales, `GDK_SCALE`, `QT_FONT_DPI` |
| `configs/fresh/` | `config.json` (JSONC) → `~/.config/fresh/` — [Fresh](https://getfresh.dev/) terminal IDE |
| `configs/herdr/` | `config.toml` → `~/.config/herdr/` — [Herdr](https://herdr.dev/) agent/session manager |
| `configs/omarchy/branding/` | `screensaver.txt`, `mezarchy-logo.png`, `backgrounds/*.png` → `~/.config/omarchy/branding/` — Omarchy "mezarchy" branding |
| `ubuntuDesktop/` | Ubuntu-specific shell configs (`.zshrc`, `.p10k.zsh`, `.bashrc`) |
| `macos/` | macOS-specific shell configs + alias dump |
| `AI Utilities/.claude/skills/` | Claude Code custom skills (`task-add`, `task-do`, `task-clean`, `task-list`) |
| `AI Utilities/.config/opencode/commands/` | OpenCode slash commands (`task-add`, `task-do`, `task-clean`, `task-list`) |
| `exa_demo/` | Demo files for the `exa` ls replacement |
| `Dockerfile` | Ubuntu 22.04 image with XFCE4, XRDP, and SSH for testing |

## AI task workflow (AI-Task.yml)

Tasks live in `AI-Task.yml` at the repo root. The skills/commands that manage them follow these conventions:

- **Statuses**: `ready` → `in-progress` → `done` (or `cancelled`). Recurring tasks cycle `ready` → `in-progress` → `ready` instead of ending at `done`. If `/task-do` is run with `--worktree`, a task ends at `review` instead of `done`/`ready` — work happened on a branch and is awaiting manual merge.
- **Fields**: `id`, `name`, `description`, `status`, `size` (small/medium/large), `priority` (low/medium/high), `dependencies` (list of IDs), `created_date`, `recurring` (bool, default false), `last_run_date` (set/updated by `/task-do` each time a recurring task completes a cycle), `branch`/`worktree_path` (set by `/task-do --worktree` once a task reaches `review`)
- `/task-add` — creates or updates a task, enriching the description from codebase context; pass `--recurring` to mark it as a repeatable audit/check
- `/task-do` — picks and implements a task, auto-selecting highest-priority unblocked `ready` task if no ID given; recurring tasks cycle back to `ready` (with `last_run_date` stamped) instead of becoming `done`. Two opt-in flags (both off by default): `--test` writes and runs test(s) covering the change, blocking completion until they pass; `--worktree` forces the work onto a new branch in a new git worktree (`.worktrees/<task-id>`) and leaves the task at `review` status with `branch`/`worktree_path` recorded, for manual merge later.
- `/task-clean` — archives `done`/`cancelled` tasks from `AI-Task.yml` into `Completed-AI-Task.yml`; recurring tasks waiting at `ready` are never archived, only if explicitly `cancelled` (or `done`); tasks at `review` are never archived either
- `/task-list` — lists tasks one per line (id, name, size, priority, status, recurring); supports `--sort created|priority|size|status`, `--order asc|desc`, and `--recurring` to show only recurring tasks

The Claude Code versions live in `AI Utilities/.claude/skills/`; the OpenCode versions live in `AI Utilities/.config/opencode/commands/`. When updating skill logic, update both locations to keep them in sync.

## Alias management

Aliases live inline in `configs/.zshrc` — that file is the source of truth. There is
no separate alias file. `install_aliases.sh` parses `alias name=...` lines out of the
repo copy and a target `.zshrc`, then sorts them into four buckets:

- **missing** — in the repo, not on the target → added by `--apply`
- **changed** — in both, definitions differ → target is overwritten by `--apply`
- **extra** — on the target, not in the repo → reported only, never removed
- **in sync** — identical

Default mode is `--check`: reports drift, writes nothing, exits 1 when out of sync
(so it works as a pre-commit gate). `--apply` backs the target up to
`<file>.bak.<timestamp>` first and inserts new aliases after the last existing alias
line, not at EOF. `--dest` is repeatable for comparing the `ubuntuDesktop/` and
`macos/` variants against `configs/`.

Comparison is deliberately file-based rather than against the live `alias` builtin —
the builtin would flood the "extra" bucket with oh-my-zsh plugin aliases (see
`macos/macosaliasall.txt`). The trade-off is that an alias defined ad-hoc in a running
shell is invisible to the script until it is written to a file.

Caveat when syncing to `macos/.zshrc`: the `ls`/`ll`/`lt`/`ltt` aliases in
`configs/.zshrc` reference `$LS_CMD`, which is set by the eza/exa detection block
earlier in that file. Copying them to a `.zshrc` without that block yields broken
aliases, so check before applying across variants.

## Omarchy branding ("mezarchy")

`omarchy_install_branding.sh` reproduces the custom branding applied to the live
Omarchy machine on 2026-09-14. Files live in `configs/omarchy/branding/` and mirror
`~/.config/omarchy/branding/` one-to-one, so `backup_app_configs.sh` pulls them back.

- **Screensaver** — `screensaver.txt` is the MEZARCHY block-letter art `omarchy-screensaver` renders via ttfx. Copied straight in.
- **Boot splash + login screen** — `mezarchy-logo.png` (920x190) is *not* copied into `/usr/share` by hand. The script calls `omarchy-plymouth-set '#1a1b26' '#ffffff' <logo>`, which rebuilds both the Plymouth theme and the SDDM theme atomically as root. Picking a theme's own unlock screen from the Omarchy menu (Style > Unlock) overwrites this; re-run the script to restore it. `omarchy-plymouth-reset` returns to stock.
- **Idle timers** — only `idle.screensaver` (120s, default 150) and `idle.lock` (300s) are patched in `~/.config/omarchy/shell.json` with jq; the rest of that file is left alone so Omarchy's bar defaults are not pinned by the repo. Never use `omarchy-refresh-shell` to reload it: in Omarchy, "refresh" means *reset to package defaults*. The script uses `omarchy-shell shell reloadConfig`.
- **Wallpapers** — Omarchy only lists user backgrounds per theme (`~/.config/omarchy/backgrounds/<theme>/`). The one real copy of each `backgrounds/*.png` goes under `branding/`, and each theme folder gets symlinks (all Omarchy pickers use `find -L`). Default is the current theme; `--all-themes` links every installed theme. The PNGs are generated by `mezarchy_wallpapers.py` (one seeded function per scene, SVG rendered with `rsvg-convert`); the "terminal kit" helpers (`block_logo`, `prompt`, `swatches`, `scanlines`, `logo_stack`) are what give the terminal/rain/skyline/circuit/horizon/panes scenes their shared pixel-logo look, so new variations should build on them. Adding a scene means: write the function, register it in `SCENES`, render, and add the PNG to the list in `backup_app_configs.sh` (the install script globs the directory, so it needs no change).
- **Swapping wallpapers** — `mezarchy_bg.sh` reads `~/.config/omarchy/branding/mezarchy-bg.conf` (repo: `configs/omarchy/branding/mezarchy-bg.conf`, a bash-sourced file with a `ROTATE` list, `ROTATE_MINUTES`, and a `WORKSPACE[id]=name` map). `rotate on` writes `~/.config/systemd/user/mezarchy-bg-rotate.{service,timer}`; `workspace on` writes `mezarchy-bg-workspace.service`, which listens on Hyprland's `.socket2.sock` via `socat` for `workspacev2`/`focusedmonv2` events. Turning one on turns the other off. Every change goes through `omarchy-theme-bg-set`, so Omarchy's reveal transition and its own switcher keep working. Omarchy's background plugin paints one image across all monitors, so per-workspace follows the last-focused monitor. The systemd user manager on Omarchy already has `HYPRLAND_INSTANCE_SIGNATURE`/`WAYLAND_DISPLAY` in its environment, which is why plain user units work. Note `hyprctl dispatch` on this Hyprland build takes Lua: `hyprctl dispatch 'hl.dsp.focus({ workspace = "3" })'`.

Both `omarchy_install_branding.sh` and `omarchy_setup_fingerprint.sh` need a real TTY for sudo.

## Docker test environment

The container runs Ubuntu 22.04 with XFCE4 desktop, SSH (port 2222), and XRDP (port 3389). Root password is `pass123`. Connect via `ssh root@localhost -p 2222` or an RDP client at `localhost:3389`.
