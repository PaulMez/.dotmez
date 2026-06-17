# AI Task Workflow

A lightweight task tracker for AI coding agents, backed by `AI-Task.yml` at the repo root. Four slash commands manage it: `/task-add`, `/task-do`, `/task-list`, `/task-clean`. Available in both Claude Code (`AI Utilities/.claude/skills/`) and OpenCode (`AI Utilities/.config/opencode/commands/`) — the two stay in sync.

## The four commands

| Command | Purpose |
|---|---|
| `/task-add <description> [--recurring]` | Create or update a task. Reads the codebase to enrich the description with real file/component references. |
| `/task-do [task-ID] [--size S] [--priority P] [--dry-run]` | Implement a task. No args = auto-pick highest priority unblocked `ready` task. |
| `/task-list [--limit N\|--all] [--sort ...] [--order ...] [--recurring]` | Read-only overview, one line per task. |
| `/task-clean [--dry-run]` | Archive `done`/`cancelled` tasks into `Completed-AI-Task.yml`. |

## Typical flow

```
/task-add Fix flaky checkout e2e test
/task-list                      # see what's queued
/task-do                        # auto-picks highest priority, no unmet deps
/task-clean                     # periodically, to keep AI-Task.yml short
```

## Task fields

- `id` — `task-NN`, sequential
- `name` / `description` — description is enriched from codebase context, kept to ~2 sentences
- `status` — `ready` → `in-progress` → `done` (or `cancelled`); recurring tasks go `ready` → `in-progress` → `ready`
- `size` — `small` / `medium` / `large` (large tasks trigger a context-usage warning in `/task-do`)
- `priority` — `low` / `medium` / `high`
- `dependencies` — list of task IDs that must be `done` first
- `created_date` — stamped automatically
- `recurring` — `true` for repeatable audits/checks; if true, `/task-do` cycles it back to `ready` instead of `done` and stamps `last_run_date`

## Best practices

- **Let auto-pick drive day-to-day work.** Run `/task-do` with no args rather than always specifying an ID — it respects priority and dependency order for you.
- **Use `--dry-run` on anything you're unsure about**, especially `large` tasks, before committing to the full implementation.
- **Mark dependencies explicitly** when adding related tasks — `/task-add` checks existing tasks, but only links them if your description references the dependency clearly.
- **Use `--recurring` for audits, not features** — e.g. "check all nodes have e2e tests," "review recent merges for missing docs." One-off feature work should never be recurring.
- **Run `/task-clean` periodically**, not after every task — let `done` tasks accumulate a bit so `/task-list` history stays useful, then archive in a batch.
- **Don't hand-edit `AI-Task.yml`** unless necessary — the commands maintain status transitions and `last_run_date` consistently; manual edits risk invalid YAML or skipped state.
- **Keep descriptions specific** (file paths, component names) so a future `/task-do` run — possibly in a fresh context — has enough to act without re-deriving everything from scratch.
- **For recurring tasks left mid-cycle**, `/task-do` leaves status as `in-progress` rather than cycling back — re-run `/task-do <id>` to finish that cycle rather than starting a new one.
- **When updating skill logic**, change both `AI Utilities/.claude/skills/` and `AI Utilities/.config/opencode/commands/` to keep the two tool ecosystems consistent (per `CLAUDE.md`).
