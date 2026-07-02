---
description: "Implement a task from AI-Task.yml. Pass a task ID, or filter by size/priority, or leave blank to auto-pick the highest priority ready task with no unmet dependencies."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[task-ID] [--size small|medium|large] [--priority low|medium|high] [--dry-run] [--test] [--worktree]"
---

You are a task implementer for this project/git repo. When invoked with $ARGUMENTS, you will:

## Inputs (all optional)

| Input | Example | Effect |
|---|---|---|
| Task ID | `task-03` | Work on that specific task |
| `--size small` | `--size medium` | Filter to tasks of that size |
| `--priority high` | `--priority medium` | Filter to tasks of that priority |
| `--dry-run` | `--dry-run` | Show what you WOULD do, make no changes |
| `--test` | `--test` | Write test(s) covering the change and require them to pass before marking the task complete. **Off by default.** |
| `--worktree` | `--worktree` | Do the work on a new branch in a new git worktree instead of the current checkout; finish at `review` status instead of `done`/`ready`. **Off by default.** |
| _(blank)_ | | Auto-pick highest priority `ready` task with no unmet dependencies |

Multiple filters combine: `--size small --priority high` finds small + high priority tasks. `--test` and `--worktree` can be combined with each other and with any selection method.

---

## Steps

1. **Read AI-Task.yml** from the repo root. If it does not exist, stop and say: "No AI-Task.yml found. Run /task-add first."

2. **Select the target task** based on $ARGUMENTS:
   - If a task ID like `task-03`, `03`, or `3` is given → normalize to `task-XX` with zero padding and use that task. If not found, list available IDs and stop.
   - If filters like `--size` or `--priority` are given → filter tasks with `status: ready` matching all provided filters. If multiple match, pick the highest priority one (high > medium > low), then smallest size as tiebreaker. List all matches before proceeding.
   - If blank → from all `status: ready` tasks, find those whose `dependencies` are all `status: done`. Always prefer non-recurring tasks if any exist. If only recurring tasks are eligible, pick highest priority (high > medium > low), then oldest `last_run_date` (missing/never run first). Among non-recurring tasks, pick highest priority then smallest size as tiebreaker.
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
   Test:        no
   Worktree:    no
   ```
   If the task has `recurring: true`, show `Recurring:   yes (last run: 2026-06-10)` or `Recurring:   yes (never run)` if `last_run_date` is absent.
   Show `Test:        yes` if `--test` is in $ARGUMENTS, otherwise `no`.
   Show `Worktree:    yes` if `--worktree` is in $ARGUMENTS, otherwise `no`.

   If `--dry-run` is in $ARGUMENTS, stop here and describe what files you would change and how (including, if `--worktree` was passed, what branch/worktree path you would create, and if `--test` was passed, what test(s) you would add).

4. **Check size before starting large tasks** — if the selected task's `size` is `large`, print this reminder then immediately continue:
   ```
   ⚠ Large task: this may consume significant context. Consider /compact or /clear before re-running if you hit limits.
   ```
   Skip this step entirely for `small` and `medium` tasks.

5. **Mark task as in-progress** — immediately update the task's `status` to `in-progress` in AI-Task.yml (in the main checkout, even if `--worktree` is set — see step 6) so other agents know this task is being worked on. Do this before any codebase scanning or implementation.

6. **If `--worktree` is in $ARGUMENTS, create a branch and worktree before touching any code**:
   - Derive a branch name: `task/<task-id>-<slug>`, where `<slug>` is the task `name` lowercased with non-alphanumeric runs collapsed to single hyphens (e.g. `task/task-03-add-login-button`).
   - Derive a worktree path: `.worktrees/<task-id>` under the repo root.
   - Run `git worktree add -b <branch> .worktrees/<task-id>` from the repo root. If `.worktrees/` is not already in `.gitignore`, add it.
   - From this point on, do all codebase scanning, file edits, and test runs **inside that worktree directory** (e.g. `cd .worktrees/<task-id>` or prefix Bash commands with it), not in the main checkout. AI-Task.yml itself is still read/written in the **main checkout** — task tracking metadata is never committed to the feature branch.
   - If `git worktree add` fails (e.g. branch already exists), stop and report the error — do not fall back to working in the main checkout silently.

7. **Scan the codebase** to understand context:
   - Use Glob to find files relevant to the task name/description
   - Use Grep to find existing symbols, components, or patterns to follow
   - Read the most relevant files before making changes
   - (If `--worktree` is set, do this inside the worktree directory from step 6.)

8. **Implement the task** — make the actual code changes using Edit or Write. Follow existing patterns and conventions in the codebase. Keep changes focused on what the task describes — don't refactor unrelated code.

9. **If `--test` is in $ARGUMENTS, write and run tests before proceeding**:
   - Identify the project's existing test framework/convention (check `package.json` scripts, `Makefile`, presence of `pytest`/`jest`/`vitest`/etc., or existing test file naming patterns nearby).
   - Write test(s) that specifically cover the new behavior or fix, following existing test conventions and file locations.
   - Run the test suite (or the narrowest command that covers the new test(s)) and confirm it passes.
   - If tests fail, **do not proceed to step 10** — go back and fix the implementation or the test, then re-run. Only continue once the tests pass.
   - If the repo has no test framework/runner at all (e.g. this is a shell-script/config repo), say so explicitly, and instead describe and perform a concrete manual verification of the change (e.g. run the script, check output), reporting what you checked.

10. **Update AI-Task.yml** (always in the main checkout):
   - If `--worktree` was set: change `status` from `in-progress` to `review` (regardless of whether the task is recurring), and add/update two fields on the task: `branch: <branch-name>` and `worktree_path: .worktrees/<task-id>`. This applies even to recurring tasks — a task sitting at `review` is not yet eligible to cycle back to `ready` until the user merges and re-runs.
   - Else, if the task is **not** `recurring` (field absent or `false`): change `status` from `in-progress` to `done`. Do not modify any other fields.
   - Else, if the task **is** `recurring: true`: change `status` from `in-progress` back to `ready`, and set `last_run_date` to today's date (`date +%Y-%m-%d`). Do not modify any other fields.

11. **Print a completion summary**. For a one-off task:
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
   For a task run with `--test`, add a line: `Tests: tests/components/Auth.test.tsx (passing)`.
   For a task run with `--worktree`, add lines:
   ```
   Branch:   task/task-03-add-login-button
   Worktree: .worktrees/task-03
   Status updated: ready → in-progress → review
   (merge when ready: cd .worktrees/task-03 && git push, or merge the branch directly)
   ```

---

## Rules
- Never mark a task `done` if you only partially completed it — use `in-progress` instead and explain what remains
- For a recurring task that you couldn't finish, leave it as `in-progress` (not `ready`) and explain what remains — only cycle it back to `ready` when the run is actually complete
- If a dependency task is not `done`, refuse to start and list what needs to happen first
- If `--dry-run` is passed, make zero file changes — only describe your plan
- Always read before editing — never overwrite a file without reading it first
- A recurring task never ends a cycle as `done` — it always cycles back to `ready` with an updated `last_run_date` so it can run again later (e.g. via `/loop` or manual re-invocation) — unless `--worktree` was also used, in which case it ends at `review` instead, same as a one-off task
- `--test` and `--worktree` are both **off by default** — only engage their behavior when explicitly passed in $ARGUMENTS
- With `--test`, never mark the task `done`/`review`/`ready` if the tests don't pass — leave it `in-progress` and report exactly what failed
- With `--worktree`, never edit files in the main checkout — all implementation work happens inside the created worktree directory; only AI-Task.yml status/metadata is updated in the main checkout
- Never merge, push, or delete the worktree/branch yourself — `review` status means the user reviews and merges manually
