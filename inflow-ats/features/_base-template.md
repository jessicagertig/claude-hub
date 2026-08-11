# Inflow ATS Plan Prompt

## File and Output Rules

- Create and use `/tmp` directories for throwaway work.
- Use `~/claude-hub/inflow-ats/` for **reference files only**: reusable context that helps future agents understand the codebase, conventions, or prior decisions.
- If you want to persist a per-task summary or patch note to disk, write it to a **dated subdirectory** like `~/claude-hub/inflow-ats/short-description-YYYY-MM-DD/` so the root stays clean for reference material.
- Do not leave any Claude-generated files in the inflow-ats repo tree, and do not modify `.gitignore` to accommodate them.

## Git Rules

- Do not create branches, push, or perform branch operations. A branch will have already been checked out for you to work on locally.
- You may make commits and stashes. You may apply stashes but may not pop stashes.
- You may run read-only git commands (`git diff`, `git log`, `git show`, etc.) to aid your planning and understanding.
- Check recent open PRs (submitted within the last 3 weeks) as context, since they are likely to be included in the final merge.

## Sub-Agent Permissions

If you spawn sub-agents that need file access or special permissions, verify those permissions before dispatching them. A common failure mode is sub-agents being blocked by permission errors (e.g., "navigation agent was blocked by permissions"). If a sub-agent fails due to permissions, do not silently skip the work. Complete it yourself directly and note the limitation in your summary.

## Workflow (Planning Phase Only)

**This is a planning-only session. Do NOT write implementation code.**

Your job is to produce a detailed implementation plan that a review agent will fact-check and verify before execution begins.

Before drafting any plan, it is critical that you analyze existing patterns, conventions, naming, and structure throughout the codebase. No decision should be made haphazardly. Name and structure things based on existing repo conventions, and if no convention exists, defer to industry best practice. Cite specific examples from the codebase when justifying a pattern choice.

1. **Analyze the codebase.** Study the relevant models, controllers, services, React components, hooks, and other structures you will need to understand for the proposed change. Take your time here. Read broadly before narrowing.

2. **Check for conflicts.** Review the open PR branches listed below. Run `git diff main...<branch> --stat` for any that might overlap. Note conflicts or coordination needs.

3. **Study existing patterns.** For whatever this feature touches, find at least two existing examples in the codebase that follow the same pattern — three or more is more desirable. The examples must share specific structural traits, not just a surface resemblance. Document them in your plan as "pattern precedents."

4. **Draft the implementation plan.** The plan must open with this directive (copy it verbatim as a blockquote at the top of the plan, after the title):

   > **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

   Structure the plan's tasks using checkbox syntax (`- [ ]`) at every level of granularity so implementing agents can track progress. Use hierarchical numbering (e.g., C.1, C.1.1, C.1.2) for nested sub-tasks. Every actionable item gets its own checkbox — do not collapse multiple distinct actions into a single checkbox line. Preserve the full description for each task; checkboxes are prefixes, not replacements for detail.

   The plan must cover:
   - **Summary:** One paragraph on what this feature does and why.
   - **Pattern precedents:** Existing code you are modeling after, with file paths and line references.
   - **Files to create or modify:** Full list with a sentence on what changes in each.
   - **Backend changes:** Models, controllers, services, serializers, policies, routes, jobs. Tag each step with the specific `cursor_rules/backend/` files the implementation agent should read before working that step. Break into numbered tasks with checkbox steps.
   - **Frontend changes:** React components, hooks, queries, context, styling. Tag each step with the specific `cursor_rules/frontend/` files the implementation agent should read before working that step. Break into numbered tasks with checkbox steps.
   - **Validation and constraints:** What input validation is needed, where it goes, and why.
   - **Test plan:** Which RSpec files to update and what test cases to add. Which existing Cypress tests cover the affected workflows (these must not be modified — they are a source of truth). Any NEW Cypress tests needed for behavior not covered by existing tests (last implementation step). Tag Cypress steps with the specific `cursor_rules/cypress/` files to read.
   - **Documentation impact:** What docs pages need creation or updates.
   - **Risks and open questions:** Anything you are unsure about or that could go either way.
   - **Estimated scope:** Rough count of files changed, new files, lines of code.

5. **Write the plan to disk.** Save the plan as `plan.md` in the working directory. The plan must be fully self-contained so a separate agent can read it cold and implement from it.

6. **Print the plan in conversation.** After writing to disk, also print the full plan in the conversation.

**Do NOT proceed to implementation. Do NOT write feature code. Do NOT create branches or commits. Planning only.**

## Working Directory Context

**You are running from the feature's working directory, NOT from inside the repository.**

Read `REPO-PATH` in the working directory to get the repo location. All repo access must use full paths or `cd <repo> && <command>` chains.

## Active Environment Context

### Repository

The repo path is in `REPO-PATH`. This is the inflow-ats Rails API + React frontend (Inflow ATS / Polymer).

### Open PR Branches (check for freshness before relying on this)

These branches are actively in flight and expected to merge soon. Your changes **must not conflict** with them. If your work touches the same files, read the branch diffs first.

<!-- Update this table before each planning session -->

### High-Conflict Files

<!-- Populate as we identify frequently-changing files -->

### Standing Technical Directives

<!-- Add standing rules here as they emerge -->

## Template Self-Maintenance

This template contains living context (open PRs, high-conflict files, standing directives) that drifts as branches merge and new work starts. When told a branch has merged, a new branch has been created, or context has changed, update this file directly.

## Task Description

<!-- Replace everything below this line with your specific feature request -->

[Describe the feature here. Include:]
- What the feature does and why
- Which parts of the stack it touches (backend, frontend, both)
- Any constraints or requirements
- Any existing patterns to follow
