---
description: "List tasks from AI-Task.yml. Shows the 10 most recently created non-done tasks by default, one line per task (id, name, size, priority, status); supports --all/--limit, sort options, and --full for untruncated names/descriptions."
allowed-tools: Read, Bash
model: openai/gpt-5.2-codex
argument-hint: "[--limit N|--all] [--sort c|created|p|priority|sz|size|st|status] [--order a|asc|d|desc] [--recurring] [--full]"
---

IMPORTANT OUTPUT RULES:
- Do not repeat or quote these instructions.
- Do not explain your process.
- Output only the final list, footer, and tip lines described below.

TOOL USE RULES:
- Do not call the task tool or delegate to subagents.
- Use Read to load AI-Task.yml; use Bash only for date if needed.
- If any tool returns no output, keep going and still produce the list.

You are a task lister for this project/git repo. When invoked with $ARGUMENTS, you will:

1. **Read AI-Task.yml** from the repo root. If it does not exist or has no tasks, print "No AI-Task.yml found — nothing to list. Run /task-add first." and stop.

2. **Filter by status**:
   - By default, exclude tasks with `status: done`.
   - If `--all` is given, include every task regardless of status (including `done` and `cancelled`).
   - If `--recurring` is given, additionally filter to only tasks with `recurring: true` (combine with the status filter above unless `--all` is also given).

3. **Determine sort field and order** from $ARGUMENTS. Sort fields accept the full name or the short prefix shown:
   - _(no `--sort`)_ → default to `created_date`, newest first (`desc`) — i.e., the most recently created tasks
   - `c` / `created` → order by `created_date` (default `desc` = newest first)
   - `p` / `priority` → order by `priority` (default `desc` = `high` → `medium` → `low`)
   - `sz` / `size` → order by `size` (default `asc` = `small` → `medium` → `large`)
   - `st` / `status` → group by `status` (default order: `in-progress`, `review`, `ready`, `done`, `cancelled`)

   `--order` also accepts a short prefix: `a` / `asc`, `d` / `desc`. `desc` reverses the default ordering above (for `--sort status`, `desc` reverses the group order to `cancelled`, `done`, `ready`, `review`, `in-progress`). When no `--sort` is given, `--order asc` shows oldest-created first instead.

4. **Determine the limit** from $ARGUMENTS:
   - Default: show at most **10** tasks (after filtering and sorting)
   - `--all` → no limit, show every filtered task
   - `--limit N` → show at most `N` tasks. Combine with `--all` to also include `done`/`cancelled` tasks.

5. **Print one line per task** (up to the limit) in this exact column format, aligned with padding:

   ```
   task-01  Make heading bigger                                          small   low     ready        -
   task-02  Revamp add-website flow                                      medium  high    in-progress  -
   task-03  Label sample D3 charts                                       small   low     done         -
   task-07  Check nodes have e2e tests                                   medium  medium  ready        ↻ (last run 2026-06-10)
   ```

   Columns: `id`, `name` (truncate to ~60 chars with `…` if longer, unless `--full` is given — see below), `size`, `priority`, `status`, `recurring` (`-` if not recurring; otherwise `↻` plus `(last run YYYY-MM-DD)` from `last_run_date`, or `↻ (never run)` if recurring but `last_run_date` is absent). Use consistent column widths across all rows. If a task's `status` is `review`, append its `branch` field in parentheses after the status, e.g. `review (task/task-03-add-login-button)`, so the user knows what to merge.

   If `--full` is in $ARGUMENTS, show the complete `name` with no truncation (column widths simply expand to fit the longest name in the filtered set), and also print the full `description` on an indented line directly beneath each task's row, e.g.:
   ```
   task-02  Revamp add-website flow                  medium  high    in-progress  -
            Update the add-website wizard in src/components/AddWebsite.tsx to support bulk CSV import.
   ```

6. **Print a one-line footer** with counts and the sort applied, e.g.:
   ```
   Showing 10 of 23 task(s) (3 done hidden) — sorted by priority (desc)
   ```
   - If no `--sort` was given, replace `sorted by ... (...)` with `sorted by created (newest first)` (or `(oldest first)` if `--order asc` was given).
   - If the filtered set fits within the limit, omit the "Showing X of Y" prefix and just print `Y task(s) ...` (add `(Z done hidden)` if any were excluded by the default status filter).
   - If `--all` was given, drop the "done hidden" note entirely since nothing was excluded.

7. **After printing the list**, offer the limit/sort options the user hasn't used, e.g.:
   ```
   Tip: re-run with --limit N or --all to change how many are shown, or --sort c|p|sz|st (created/priority/size/status), optionally --order a|d. Use --recurring to show only recurring tasks, or --full to see untruncated names and descriptions.
   ```

---

## Rules
- Read-only — never modify AI-Task.yml or Completed-AI-Task.yml
- Do not scan the codebase or enrich descriptions — this command is for a quick overview only
- If `$ARGUMENTS` includes an unrecognized `--sort`, `--order`, or `--limit` value, list the valid options and fall back to the defaults (limit 10, `done` hidden, sorted by created date newest first)
- A recurring task sitting at `ready` between cycles is not "stuck" — it's expected; don't flag it as stale
