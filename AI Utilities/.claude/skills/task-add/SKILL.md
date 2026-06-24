---
description: "Add or update a task in AI-Task.yml. Reads the codebase to enrich the description automatically."
allowed-tools: Read, Write, Glob, Grep, Bash
argument-hint: "[task name or description] [--recurring]"
---

You are a task organiser for this project/git repo. When invoked with $ARGUMENTS, you will:

1. **Check for AI-Task.yml** in the repo root using Read. If it does not exist, create it with an empty tasks list:
   ```yaml
   tasks: []
   ```

2. **Read the existing AI-Task.yml** to understand current tasks and determine the next available ID (e.g. if the last is task-03, the next is task-04). If the file is empty or has no tasks, start at task-01.

3. **Scan the codebase** to enrich the task description:
   - Use Glob to find relevant files related to the task topic (e.g. `**/*.ts`, `**/*.tsx`, `src/**`)
   - Use Grep to find relevant symbols, component names, or file references mentioned in $ARGUMENTS
   - Use this context to write a clear, specific description that references actual file paths or component names where helpful

4. **Determine task fields** from $ARGUMENTS and codebase context:
   - `name`: concise title derived from $ARGUMENTS
   - `description`: enriched using codebase context — be specific (e.g. "Update the `<Heading>` component in `src/components/Heading.tsx` to increase font size from `text-2xl` to `text-4xl`")
   - `status`: always `ready` for new tasks
   - `size`: infer from scope — `small` (1 file, trivial change), `medium` (a few files), `large` (cross-cutting or complex)
   - `priority`: default `low` unless $ARGUMENTS implies urgency (words like "urgent", "blocking", "critical" → `high`; "soon", "next" → `medium`)
   - `dependencies`: check existing task names/IDs in AI-Task.yml — if $ARGUMENTS references something already tracked, list its ID; otherwise `[]`
   - `created_date`: today's date in YYYY-MM-DD format (use Bash: `date +%Y-%m-%d`)
   - `recurring`: `true` if `--recurring` is in $ARGUMENTS, or $ARGUMENTS clearly describes a periodic audit/check (e.g. "check all nodes have e2e tests", "review recent merges for docs updates", "run a security check") — otherwise `false`

5. **Append the new task** to AI-Task.yml following this exact template — preserve all existing tasks:

```yaml
tasks:
  - id: task-01
    name: Make heading bigger
    description: Update the <Heading> component in src/components/Heading.tsx to increase font size from text-2xl to text-4xl
    status: ready
    size: small
    priority: low
    dependencies: []
    created_date: 2024-01-20
    recurring: false
```

   For a recurring task, set `recurring: true`. Do not add a `last_run_date` field yet — `/task-do` adds and maintains it the first time the task completes a cycle.

```yaml
tasks:
  - id: task-02
    name: Check all nodes have an associated e2e test
    description: Scan src/nodes/** for node definitions and verify each has a matching test under tests/e2e/**; add missing tests.
    status: ready
    size: medium
    priority: medium
    dependencies: []
    created_date: 2026-06-17
    recurring: true
```

6. **Confirm** by printing a summary: the task ID, name, description, and whether it's recurring.

**Rules:**
- Never delete or modify existing tasks unless $ARGUMENTS explicitly says "update task-XX"
- If updating an existing task, change only the fields mentioned in $ARGUMENTS and update nothing else
- Keep descriptions under 2 sentences — specific and actionable
- Always write valid YAML — quote strings that contain colons or special characters
- A recurring task's description should be phrased as a repeatable check/audit (what to look for and what to do about it), since `/task-do` will run it again each time it cycles back to `ready`
