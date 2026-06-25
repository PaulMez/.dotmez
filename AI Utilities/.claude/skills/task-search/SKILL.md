---
description: "Search tasks in AI-Task.yml by free-text query across all task fields."
allowed-tools: Read, Bash
argument-hint: "<query words> [--full]"
---

OUTPUT ONLY TASK ROWS. NO HEADERS, NO TIPS, NO EXTRA TEXT.
Row format (single line per task):
id | name | size | priority | status | recurring

Behavior:
- Query is all text in $ARGUMENTS excluding optional --full. If empty, output: No query provided.
- Read AI-Task.yml from repo root. If missing or empty, output:
  No AI-Task.yml found - nothing to list. Run /task-add first.
- Search is case-insensitive. Split query into tokens by whitespace.
- Build a searchable string for each task by concatenating:
  id, name, description, status, size, priority, dependencies, created_date,
  last_run_date, recurring, branch, worktree_path.
- A task matches if all tokens appear in the searchable string.
- Sort matches by created_date desc (newest first). If created_date missing, treat as oldest.
- Name truncation: default max 60 chars with "..." ASCII; --full disables truncation.
- Recurring column: "-" or "recurring (last run YYYY-MM-DD)" or "recurring (never run)".
- If status is review, append " (branch <branch>)" to the status value.
