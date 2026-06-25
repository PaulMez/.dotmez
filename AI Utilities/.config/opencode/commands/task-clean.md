---
description: "Archive done and cancelled tasks from AI-Task.yml into Completed-AI-Task.yml to keep the active task list tidy."
allowed-tools: Read, Write, Edit, Bash
model: openai/gpt-5.2-codex
argument-hint: "[--dry-run]"
---

OUTPUT ONLY ONE LINE.
Format:
Archived <count> task(s). Active now: <count>

Behavior:
- Read AI-Task.yml; if missing, output: No AI-Task.yml found. Nothing to clean.
- Identify tasks with status done or cancelled. If none, output: Nothing to archive - AI-Task.yml is already clean.
- If --dry-run, do not write; output: Dry run - would archive <count> task(s). Active would be: <count>
- Otherwise, append archived tasks to Completed-AI-Task.yml under completed_tasks with archived_date (date +%Y-%m-%d), preserving recurring and last_run_date.
- Remove archived tasks from AI-Task.yml.
