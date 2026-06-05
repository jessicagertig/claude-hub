# Implementation Planning

## File and Output Rules

- Create and use `/tmp` directories for throwaway work.
- Use the pipeline scratchpad (e.g., `~/claude-hub/<pipeline>/`) for reference files only.
- Write your plan to the feature working directory.
- Do not leave any agent-generated files in the repo tree, and do not modify `.gitignore`.

## Git Rules

- Do not create branches, push, or perform branch operations. A branch will have already been checked out for you to work on locally.
- You may make commits and stashes. You may apply stashes but may not pop stashes.
- You may run read-only git commands (`git diff`, `git log`, `git show`, etc.).
- Check recent open PRs (submitted within the last 3 weeks) as context.

## Sub-Agent Permissions

If you spawn sub-agents that need file access or special permissions, verify those permissions before dispatching them. If a sub-agent fails due to permissions, do not silently skip the work. Complete it yourself directly and note the limitation.

## Context

Read the pipeline CLAUDE.md (found by going up from the working directory to the pipeline root). It tells you:
- The source repo path (also in `REPO-PATH`)
- The tech stack
- Where conventions live (conventions directory, reference repo, or just the CLAUDE.md)

## Workflow

### 1. Analyze the codebase

Study the relevant parts of the codebase for the proposed change. Read the pipeline CLAUDE.md for the tech stack and conventions sources (pipeline CLAUDE.md, source repo CLAUDE.md, conventions directory, reference repo, existing codebase patterns — whatever applies). Take your time here. Read broadly before narrowing.

### 2. Check for conflicts

Review open PR branches. Run `git diff main...<branch> --stat` for any that might overlap. Note conflicts or coordination needs.

### 3. Study existing patterns

For whatever this feature touches, find at least two existing examples in the codebase (or reference repo) that follow the same pattern — three or more is better. The examples must share specific structural traits, not just a surface resemblance. Document them in your plan as "pattern precedents."

### 4. Draft the implementation plan

Write `plan.md` in the working directory. The plan must open with this directive (copy it verbatim as a blockquote at the top of the plan, after the title):

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Structure the plan's tasks using checkbox syntax (`- [ ]`) so implementing agents can track progress. Each task should be a discrete, independently completable unit of work.

The plan must cover:

- **Summary:** One paragraph on what this feature does and why.
- **Pattern precedents:** Existing code you are modeling after, with file paths and line references.
- **Files to create or modify:** Full list with a sentence on what changes in each.
- **Changes by layer:** Group changes by the relevant layers of the stack (backend, frontend, data, infra, etc. — whatever applies to this project's architecture). Each layer's work is broken into numbered tasks with checkbox steps.
- **Validation and constraints:** What input validation is needed, where it goes, and why.
- **Test plan:** Which test files to update, what test cases to add, integration scenarios.
- **Risks and open questions:** Anything you are unsure about or that needs human judgment.
- **Estimated scope:** Rough count of files changed, new files, lines of code.
