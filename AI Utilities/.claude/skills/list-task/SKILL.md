---
description: "List tasks from AI-Task.yml. Default view is one line per task (id, name, size, priority, status); pass a sort option to reorder."
allowed-tools: Read, Bash
argument-hint: "[--sort created|priority|size|status] [--order asc|desc]"
---

You are a task lister for this project/git repo. When invoked with $ARGUMENTS, you will:

1. **Read AI-Task.yml** from the repo root. If it does not exist or has no tasks, print "No AI-Task.yml found — nothing to list. Run /add-task first." and stop.

2. **Determine sort field and order** from $ARGUMENTS:
   - `--sort created` → order by `created_date` (default `asc` = oldest first)
   - `--sort priority` → order by `priority` (default `desc` = `high` → `medium` → `low`)
   - `--sort size` → order by `size` (default `asc` = `small` → `medium` → `large`)
   - `--sort status` → group by `status` (default order: `in-progress`, `ready`, `done`, `cancelled`)
   - _(no `--sort`)_ → keep the order tasks appear in AI-Task.yml; `--order` is ignored in this case

   If `--order asc` or `--order desc` is also given, apply it on top of the chosen `--sort` field — `desc` reverses the default ordering above (for `--sort status`, `desc` reverses the group order to `cancelled`, `done`, `ready`, `in-progress`).

3. **Print one line per task** in this exact column format, aligned with padding:

   ```
   task-01  Make heading bigger              small   low     ready
   task-02  Revamp add-website flow          medium  high    in-progress
   task-03  Label sample D3 charts           small   low     done
   ```

   Columns: `id`, `name` (truncate to ~32 chars with `…` if longer), `size`, `priority`, `status`. Use consistent column widths across all rows.

4. **Print a one-line footer** with the total count and the sort applied, e.g.:
   ```
   3 task(s) — sorted by priority (desc)
   ```
   If no `--sort` was given, print `3 task(s) — unsorted (AI-Task.yml order)`.

5. **After printing the list**, offer the available sort options the user hasn't used, e.g.:
   ```
   Tip: re-run with --sort created | priority | size | status, optionally with --order asc | desc.
   ```

---

## Rules
- Read-only — never modify AI-Task.yml or Completed-AI-Task.yml
- Do not scan the codebase or enrich descriptions — this command is for a quick overview only
- If `$ARGUMENTS` includes an unrecognized `--sort` or `--order` value, list the valid options and fall back to AI-Task.yml's existing order
