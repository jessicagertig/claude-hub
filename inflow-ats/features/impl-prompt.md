# Inflow ATS Implementation Prompt

## File and Output Rules

- Create and use `/tmp` directories for throwaway work.
- Use `~/claude-hub/inflow-ats/` for **reference files only**: reusable context that helps future agents understand the codebase, conventions, or prior decisions.
- If you want to persist a per-task summary or patch note to disk, write it to a **dated subdirectory** like `~/claude-hub/inflow-ats/YYYY-MM-DD-short-description/` so the root stays clean for reference material.
- Do not leave any Claude-generated files in the inflow-ats repo tree, and do not modify `.gitignore` to accommodate them.

## Git Rules

- Do not create branches, push, or perform branch operations. A branch will have already been checked out for you to work on locally.
- You may make commits and stashes. You may apply stashes but may not pop stashes.
- You may run read-only git commands (`git diff`, `git log`, `git show`, etc.) to aid your planning and understanding.
- Check recent open PRs (submitted within the last 3 weeks) as context, since they are likely to be included in the final merge.

## Sub-Agent Permissions

If you spawn sub-agents that need file access or special permissions, verify those permissions before dispatching them. A common failure mode is sub-agents being blocked by permission errors (e.g., "navigation agent was blocked by permissions"). If a sub-agent fails due to permissions, do not silently skip the work. Complete it yourself directly and note the limitation in your summary.

## Workflow

You have an approved, reviewed implementation plan. Your job is to execute it precisely.

1. **Read the plan.** Read the full plan file. If `reviews/plan-review.md` exists and contains a Reviewed Plan section, use that version — it has corrections applied. Understand every step before writing any code. The plan has been through adversarial review — trust it, don't redesign. If `reviews/impl-round-*/FAILURE-REPORT.md` exists, read the most recent one first — it contains issues from the review agent that you must fix before continuing.

2. **Read cursor_rules/ per step.** Each plan step is tagged with specific `cursor_rules/` files. Before working a step, read ONLY the tagged files for that step — not all 45. Always also read `cursor_rules/core_critical_rules.md` and the `_base.md` + `core_critical_rules.md` for whichever area you're in (backend, frontend, or cypress).

3. **Implement step by step.** Follow the plan's ordering. For each step:
   - Read the cursor_rules/ files tagged for that step
   - Study the pattern precedents cited in the plan
   - Write the code following existing codebase conventions
   - Verify your work matches the plan's description

4. **Minimize impact.** Choose the least disruptive approach that still follows best practices. Do not jump through hoops to avoid touching things, but do not be heavy-handed either. Most feature additions should have a small, focused footprint.

5. **Self-review.** Review the implementation against the plan for gaps. Verify there are no other parts of the codebase that also need updates (tests, serializers, policies, routes, etc.). Check that you followed the cursor_rules/ for every area you touched.

6. **Run tests.** Run the relevant test suites:
   - Backend: `bundle exec rspec` for affected spec files
   - Frontend: `yarn test` for affected test files
   - Cypress tests run automatically via pre-commit hook on commit
   - Do NOT modify existing Cypress tests — they are a source of truth
   - You may write NEW Cypress tests for behavior not covered by any existing test, as the last implementation step

7. **Summary.** Print a detailed summary **as text in the conversation** including:
   - Steps completed and files changed
   - Key decisions made during implementation
   - Deviations from the plan (if any) and why
   - cursor_rules/ files read and how they shaped the implementation
   - Pitfalls, risks, or open questions
   - Which tests pass, which fail (if any)

## Working Directory Context

**You are running from the feature's working directory, NOT from inside the repository.**

Read `REPO-PATH` in the working directory to get the repo location. All repo access must use full paths or `cd <repo> && <command>` chains.

## cursor_rules/ Reference

The inflow-ats repo has 45 rules files organized by area. Do NOT read them all. The plan tags each step with the specific files to read. The structure:

| Area | Base files (always read for that area) | Subdirectories |
|------|---------------------------------------|----------------|
| Root | `core_critical_rules.md` | — |
| Backend | `_base.md`, `core_critical_rules.md` | `controllers/`, `interactors/`, `job_board_integration/` |
| Frontend | `_base.md`, `core_critical_rules.md` | `components/`, `contexts/`, `forms/`, `lists/`, `modals/`, `react_query/` |
| Cypress | `core_critical_rules.md` | — |

## Active Environment Context

### Repository

The repo path is in `REPO-PATH`. This is the inflow-ats Rails API + React frontend (Inflow ATS / Polymer).

### Open PR Branches (check for freshness before relying on this)

<!-- Update this table before each session -->

### High-Conflict Files

<!-- Populate as we identify frequently-changing files -->

### Standing Technical Directives

<!-- Add standing rules here as they emerge -->

## Template Self-Maintenance

This template contains living context (open PRs, high-conflict files, standing directives) that drifts as branches merge and new work starts. When told a branch has merged, a new branch has been created, or context has changed, update this file directly.

## Task Description

<!-- Replace with reference to the approved plan file -->

[Point to the approved plan: path to plan.md and spec file]
