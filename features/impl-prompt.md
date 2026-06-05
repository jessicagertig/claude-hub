# Implementation

## File and Output Rules

- Create and use `/tmp` directories for throwaway work.
- Use the pipeline scratchpad for reference files only.
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

You have an approved, reviewed implementation plan. Your job is to execute it precisely.

1. **Read the plan.** Read the full plan file. If `reviews/plan-review.md` exists and contains a Reviewed Plan section, use that version — it has corrections applied. If `reviews/impl-round-*/FAILURE-REPORT.md` exists, read the most recent one first — it contains issues from the review agent that you must fix.

2. **Read conventions per step.** Check all conventions sources — the pipeline CLAUDE.md, the source repo's CLAUDE.md, any conventions directory, any reference repo, and existing codebase patterns. Read the relevant files before working each step. Don't read everything upfront — read what's relevant to each step as you reach it.

3. **Implement step by step.** Follow the plan's ordering. For each step:
   - Read the relevant convention files for that step
   - Study the pattern precedents cited in the plan
   - Write the code following existing codebase conventions
   - Verify your work matches the plan's description

4. **Minimize impact.** Choose the least disruptive approach that still follows best practices. Most feature additions should have a small, focused footprint.

5. **Self-review.** Review the implementation against the plan for gaps. Verify there are no other parts of the codebase that also need updates. Check that you followed conventions for every area you touched.

6. **Run tests.** Run the relevant test suites as appropriate for the tech stack. Do NOT modify existing tests unless the plan explicitly calls for it — existing tests are a source of truth.

7. **Validate CLAUDE.md compliance.** Read the pipeline CLAUDE.md and the global `~/.claude/CLAUDE.md`. Verify every applicable rule was followed in your implementation. Flag any violations you find in your summary.

8. **Summary.** Print a detailed summary **as text in the conversation** including:
   - Steps completed and files changed
   - Key decisions made during implementation
   - Deviations from the plan (if any) and why
   - Convention files read and how they shaped the implementation
   - CLAUDE.md compliance check results
   - Pitfalls, risks, or open questions
   - Which tests pass, which fail (if any)

## Working Directory Context

**You are running from the feature's working directory, NOT from inside the repository.**

Read `REPO-PATH` in the working directory to get the repo location. All repo access must use full paths.
