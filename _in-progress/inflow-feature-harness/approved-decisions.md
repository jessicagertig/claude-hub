# Approved Decisions — Inflow Feature Harness

## D1 — Working directory

This brainstorm's artifacts (`approved-decisions.md` and the spec) live at `~/claude-hub/_in-progress/inflow-feature-harness/` — hub-level, not under `inflow-ats/`

## D2 — Spec-writing skills

Spec phase uses `brainstorming-plus` and `decision-capture` — Jessica's custom skills

## D3 — Sub-project decomposition

The inflow feature harness is too large for a single spec. Decompose it into independent sub-projects, each getting its own spec → plan → implementation cycle. The sub-project list and build order are the next thing to decide.

## D4 — Artifact conventions are not a standalone sub-project

Each sub-project includes its own artifact conventions as part of its design — what files it produces, naming, and where they go. These accumulate across sub-projects rather than being designed upfront or after the fact.

## D5 — Plan prompt: File and Output Rules

- Create and use `/tmp` directories for throwaway work.
- Use `~/claude-hub/inflow-ats/` for **reference files only**: reusable context that helps future agents understand the codebase, conventions, or prior decisions.
- If you want to persist a per-task summary or patch note to disk, write it to a **dated subdirectory** like `~/claude-hub/inflow-ats/YYYY-MM-DD-short-description/` so the root stays clean for reference material.
- Do not leave any Claude-generated files in the inflow-ats repo tree, and do not modify `.gitignore` to accommodate them.

## D6 — Plan prompt: Git Rules

- Do not create branches, push, or perform branch operations. Jessica will have already checked out a branch for you to work on locally.
- You may make commits and stashes. You may apply stashes but may not pop stashes.
- You may run read-only git commands (`git diff`, `git log`, `git show`, etc.) to aid your planning and understanding.
- Check recent open PRs (submitted within the last 3 weeks) as context, since they are likely to be included in the final merge.

## D7 — Plan prompt: Sub-Agent Permissions

If you spawn sub-agents that need file access or special permissions, verify those permissions before dispatching them. A common failure mode is sub-agents being blocked by permission errors (e.g., "navigation agent was blocked by permissions"). If a sub-agent fails due to permissions, do not silently skip the work. Complete it yourself directly and note the limitation in your summary.

## D8 — Plan prompt: Workflow steps 1-3

1. **Analyze the codebase.** Study the relevant models, controllers, services, React components, hooks, and other structures you will need to understand for the proposed change. Take your time here. Read broadly before narrowing.

2. **Check for conflicts.** Review the open PR branches listed below. Run `git diff main...<branch> --stat` for any that might overlap. Note conflicts or coordination needs.

3. **Study existing patterns.** For whatever this feature touches, find at least two existing examples in the codebase that follow the same pattern — three or more is more desirable. The examples must share specific structural traits, not just a surface resemblance. Document them in your plan as "pattern precedents."

## D9 — Plan prompt: Workflow step 4

4. **Draft the implementation plan.** Write a structured plan covering:
   - **Summary:** One paragraph on what this feature does and why.
   - **Pattern precedents:** Existing code you are modeling after, with file paths and line references.
   - **Files to create or modify:** Full list with a sentence on what changes in each.
   - **Backend changes:** Models, controllers, services, serializers, policies, routes, jobs.
   - **Frontend changes:** React components, hooks, queries, context, styling.
   - **Validation and constraints:** What input validation is needed, where it goes, and why.
   - **Test plan:** Which test files to update, what test cases to add, Cypress scenarios.
   - **Documentation impact:** What docs pages need creation or updates.
   - **Risks and open questions:** Anything you are unsure about or that needs human judgment.
   - **Estimated scope:** Rough count of files changed, new files, lines of code.
