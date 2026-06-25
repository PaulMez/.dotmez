---
description: "List tasks from AI-Task.yml. Shows the 10 most recently created non-done tasks by default, one line per task (id, name, size, priority, status); supports --all/--limit, sort options, and --full for untruncated names/descriptions."
allowed-tools: Read, Bash
model: openai/gpt-5.2-codex
argument-hint: "[--limit N|--all] [--sort c|created|p|priority|sz|size|st|status] [--order a|asc|d|desc] [--recurring] [--full]"
---

OUTPUT ONLY TASK ROWS. NO HEADERS, NO TIPS, NO EXTRA TEXT.
Row format (single line per task):
id | name | size | priority | status | recurring

Behavior:
- Read AI-Task.yml from repo root. If missing or empty, output:
  No AI-Task.yml found - nothing to list. Run /task-add first.
- Filter: default exclude status done. If --all, include all statuses. If --recurring, keep only recurring true (after status filter unless --all).
- Sort: default created_date desc. --sort c|created, p|priority (high>medium>low), sz|size (small>medium>large asc), st|status order (in-progress, review, ready, done, cancelled). --order a|asc or d|desc reverses.
- Limit: default 10. --limit N overrides. --all removes limit.
- Name truncation: default max 60 chars with "..." ASCII; --full disables truncation.
- Recurring column: "-" or "recurring (last run YYYY-MM-DD)" or "recurring (never run)".
- If status is review, append " (branch <branch>)" to the status value.
