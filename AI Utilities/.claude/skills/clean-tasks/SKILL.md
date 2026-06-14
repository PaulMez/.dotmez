---
description: "Archive done and cancelled tasks from AI-Task.yml into Completed-AI-Task.yml to keep the active task list tidy."
allowed-tools: Read, Write, Edit, Bash
argument-hint: "[--dry-run]"
---

You are a task archiver for this project/git repo. When invoked with $ARGUMENTS, you will:

1. **Check for AI-Task.yml** in the repo root using Read. If it does not exist, stop and say: "No AI-Task.yml found. Nothing to clean."

2. **Read AI-Task.yml** and identify all tasks with `status: done` or `status: cancelled`.

3. **Print a preview** of what will be archived:
   ```
   Tasks to archive:
     task-02  [done]      Revamp add-website flow
     task-03  [done]      Label sample D3 charts
     task-05  [cancelled] Some cancelled task
   
   Tasks remaining in AI-Task.yml: 3
   ```
   If no done/cancelled tasks exist, print "Nothing to archive — AI-Task.yml is already clean." and stop.

   If `--dry-run` is in $ARGUMENTS, stop here and make no changes.

4. **Read or create Completed-AI-Task.yml** in the repo root:
   - If it already exists, read it to get the existing completed tasks list.
   - If it does not exist, treat it as having an empty `completed_tasks: []` list.

5. **Append the archived tasks** to `Completed-AI-Task.yml` under the `completed_tasks` key, adding an `archived_date` field (today's date, YYYY-MM-DD via `date +%Y-%m-%d`) to each task. Preserve all existing entries already in the file.

   Format:
   ```yaml
   completed_tasks:
     - id: task-02
       name: Revamp add-website flow
       description: "..."
       status: done
       size: medium
       priority: low
       dependencies: []
       created_date: 2026-05-31
       archived_date: 2026-06-09
   ```

6. **Remove the archived tasks from AI-Task.yml** — rewrite the file keeping only tasks whose status is NOT `done` or `cancelled`. Preserve all other fields exactly as-is for remaining tasks.

7. **Print a completion summary**:
   ```
   Archived 5 task(s) → Completed-AI-Task.yml
   AI-Task.yml now has 3 active task(s)
   ```

---

## Rules
- Never archive tasks with status `ready`, `in-progress`, or `blocked` — only `done` and `cancelled`
- Never delete Completed-AI-Task.yml or overwrite existing entries in it — only append
- If `--dry-run` is passed, make zero file changes — only describe what would happen
- Always read before writing — never overwrite a file without reading it first
- Write valid YAML — quote strings containing colons or special characters
