---
description: "Add or update a task in AI-Task.yml. Reads the codebase to enrich the description automatically."
allowed-tools: Read, Write, Glob, Grep, Bash
model: openai/gpt-5.2-codex
argument-hint: "[task name or description] [--recurring]"
---

OUTPUT ONLY ONE LINE.
Format:
Added <task-id> | <name> | recurring:<yes|no>

Behavior:
- Read AI-Task.yml from repo root; if missing, create with "tasks: []".
- Determine next id (task-01, task-02, ...).
- If $ARGUMENTS says "update task-XX", update only mentioned fields and output "Updated <task-id> | <name> | recurring:<yes|no>".
- For new tasks: set status ready; size inferred (small/medium/large); priority default low unless urgency words; dependencies from existing task references; created_date today (date +%Y-%m-%d); recurring true if --recurring or clearly periodic.
- Description: 1-2 sentences, specific, include file paths or symbols if found. Quote YAML strings with colons.
