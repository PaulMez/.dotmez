---
description: "Implement a task from AI-Task.yml. Pass a task ID, or filter by size/priority, or leave blank to auto-pick the highest priority ready task with no unmet dependencies."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: openai/gpt-5.2-codex
argument-hint: "[task-ID] [--size small|medium|large] [--priority low|medium|high] [--dry-run] [--test] [--worktree]"
---

OUTPUT ONLY SUMMARY LINES.

Behavior:
- Read AI-Task.yml; if missing, output: No AI-Task.yml found. Run /task-add first.
- Select task by id or filters; if none, output: No eligible task found.
- When no task id is supplied, do not select recurring tasks unless there are no non-recurring eligible tasks.
- If --dry-run, output: Dry run - would work on <task-id>.
- Mark task in-progress before work. If --worktree, create worktree and do code changes there.
- Implement task. If --test, write and run tests, and do not finish unless passing.
- Update AI-Task.yml: review for --worktree; done for one-off; ready + last_run_date for recurring.

Output lines (examples):
Completed task-03
Files changed: a, b
Status: ready -> in-progress -> done
Tests: <path> (passing)
Worktree: .worktrees/task-03 (branch task/task-03-...)
