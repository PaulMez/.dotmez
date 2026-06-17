---
description: "Implement a task from AI-Task.yml. Pass a task ID, or filter by size/priority, or leave blank to auto-pick the highest priority ready task with no unmet dependencies."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[task-ID] [--size small|medium|large] [--priority low|medium|high] [--dry-run]"
---

You are a task implementer for this project/git repo. When invoked with $ARGUMENTS, you will:

## Inputs (all optional)

| Input | Example | Effect |
|---|---|---|
| Task ID | `task-03` | Work on that specific task |
| `--size small` | `--size medium` | Filter to tasks of that size |
| `--priority high` | `--priority medium` | Filter to tasks of that priority |
| `--dry-run` | `--dry-run` | Show what you WOULD do, make no changes |
| _(blank)_ | | Auto-pick highest priority `ready` task with no unmet dependencies |

Multiple filters combine: `--size small --priority high` finds small + high priority tasks.

---

## Steps

1. **Read AI-Task.yml** from the repo root. If it does not exist, stop and say: "No AI-Task.yml found. Run /task-add first."

2. **Select the target task** based on $ARGUMENTS:
   - If a task ID like `task-03` is given → use that task. If not found, list available IDs and stop.
   - If filters like `--size` or `--priority` are given → filter tasks with `status: ready` matching all provided filters. If multiple match, pick the highest priority one (high > medium > low), then smallest size as tiebreaker. List all matches before proceeding.
   - If blank → from all `status: ready` tasks, find those whose `dependencies` are all `status: done`. Among those, pick highest priority (high > medium > low), then smallest size as tiebreaker.
   - If no eligible task is found, print a clear message explaining why (e.g. "No ready tasks with no unmet dependencies found") and list blocked tasks with what they're waiting on.

3. **Print a task summary** before doing anything:
   ```
   Task:        task-03
   Name:        Add login button
   Description: ...
   Size:        small
   Priority:    high
   Dependencies: none
   Recurring:   no
   ```
   If the task has `recurring: true`, show `Recurring:   yes (last run: 2026-06-10)` or `Recurring:   yes (never run)` if `last_run_date` is absent.

   If `--dry-run` is in $ARGUMENTS, stop here and describe what files you would change and how.

4. **Check size before starting large tasks** — if the selected task's `size` is `large`, print this reminder then immediately continue:
   ```
   ⚠ Large task: this may consume significant context. Consider /compact or /clear before re-running if you hit limits.
   ```
   Skip this step entirely for `small` and `medium` tasks.

5. **Mark task as in-progress** — immediately update the task's `status` to `in-progress` in AI-Task.yml so other agents know this task is being worked on. Do this before any codebase scanning or implementation.

6. **Scan the codebase** to understand context:
   - Use Glob to find files relevant to the task name/description
   - Use Grep to find existing symbols, components, or patterns to follow
   - Read the most relevant files before making changes

7. **Implement the task** — make the actual code changes using Edit or Write. Follow existing patterns and conventions in the codebase. Keep changes focused on what the task describes — don't refactor unrelated code.

8. **Update AI-Task.yml**:
   - If the task is **not** `recurring` (field absent or `false`): change `status` from `in-progress` to `done`. Do not modify any other fields.
   - If the task **is** `recurring: true`: change `status` from `in-progress` back to `ready` (instead of `done`), and set `last_run_date` to today's date (`date +%Y-%m-%d`). This puts the task back in the pool so it can be picked up again on a future run. Do not modify any other fields.

9. **Print a completion summary**. For a one-off task:
   ```
   ✓ Completed task-03
   Files changed: src/components/Auth.tsx, src/styles/auth.css
   Status updated: ready → in-progress → done
   ```
   For a recurring task:
   ```
   ✓ Completed recurring task-07 (cycle complete)
   Files changed: tests/e2e/checkout.spec.ts
   Status updated: ready → in-progress → ready (last_run_date: 2026-06-17)
   ```

---

## Rules
- Never mark a task `done` if you only partially completed it — use `in-progress` instead and explain what remains
- For a recurring task that you couldn't finish, leave it as `in-progress` (not `ready`) and explain what remains — only cycle it back to `ready` when the run is actually complete
- If a dependency task is not `done`, refuse to start and list what needs to happen first
- If `--dry-run` is passed, make zero file changes — only describe your plan
- Always read before editing — never overwrite a file without reading it first
- A recurring task never ends a cycle as `done` — it always cycles back to `ready` with an updated `last_run_date` so it can run again later (e.g. via `/loop` or manual re-invocation)
