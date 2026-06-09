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
./install_usuals.sh        # install common apt packages and tools
./zjstatus_install.sh      # install zellij status bar plugin
./install-claude-skills.sh    # sync ~/skills → ~/.claude/skills/
./install-opencode-commands.sh  # sync opencode commands → ~/.config/opencode/commands/
```

## Repo structure

| Path | Purpose |
|---|---|
| `configs/` | Shell configs deployed to `$HOME` (`.zshrc`, `.p10k.zsh`, `.bashrc`) |
| `ubuntuDesktop/` | Ubuntu-specific shell configs (`.zshrc`, `.p10k.zsh`, `.bashrc`) |
| `macos/` | macOS-specific shell configs + alias dump |
| `~/.claude/skills/` | Claude Code custom skills (`add-task`, `do-task`, `clean-tasks`) |
| `~/.config/opencode/commands/` | OpenCode slash commands (`add-task`, `do-task`) |
| `exa_demo/` | Demo files for the `exa` ls replacement |
| `Dockerfile` | Ubuntu 22.04 image with XFCE4, XRDP, and SSH for testing |

## AI task workflow (AI-Task.yml)

Tasks live in `AI-Task.yml` at the repo root. The skills/commands that manage them follow these conventions:

- **Statuses**: `ready` → `in-progress` → `done` (or `cancelled`)
- **Fields**: `id`, `name`, `description`, `status`, `size` (small/medium/large), `priority` (low/medium/high), `dependencies` (list of IDs), `created_date`
- `/add-task` — creates or updates a task, enriching the description from codebase context
- `/do-task` — picks and implements a task, auto-selecting highest-priority unblocked `ready` task if no ID given
- `/clean-tasks` — archives `done`/`cancelled` tasks from `AI-Task.yml` into `Completed-AI-Task.yml`

The Claude Code versions live in `~/.claude/skills/`; the OpenCode versions live in `~/.config/opencode/commands/`. When updating skill logic, update both locations to keep them in sync.

## Docker test environment

The container runs Ubuntu 22.04 with XFCE4 desktop, SSH (port 2222), and XRDP (port 3389). Root password is `pass123`. Connect via `ssh root@localhost -p 2222` or an RDP client at `localhost:3389`.
