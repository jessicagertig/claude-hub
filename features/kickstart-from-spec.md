# Kickstart Feature Harness from Existing Spec

You have an existing spec that was written outside the harness (e.g., in a superpowers session, a docs/ subdirectory, or another conversation). Your job: set up the working directory and start the harness from Phase 1.

## What you need from the user

1. **Spec location** — where the existing spec file is (full path)
2. **Pipeline** — which pipeline this is for (e.g., `inflow-ats`)
3. **Worktree or repo path** — where the source code lives (e.g., `/Users/jessica/wrk/wrk-corp/inflow-ats.messaging-improvements/`)
4. **Feature slug** — short kebab-case name for the working directory (e.g., `email-subjects-phase-1`)
5. **Spec filename** (optional) — what to name the spec in the working directory. Defaults to `SPEC.md`.

If the user didn't provide all of these, ask for the missing pieces before proceeding.

## Setup steps

1. Create the working directory: `~/claude-hub/<pipeline>/YYYY-MM-DD-<slug>/`
2. Copy the spec to the working directory with the specified name (default `SPEC.md`)
3. Write `REPO-PATH` with the worktree/repo path (one line, absolute path, trailing slash)
4. Verify the worktree/repo exists and is accessible
5. **Scan the spec's source directory** for related artifacts — investigation notes, decision logs, resource docs, analysis files, anything that informed the spec. Copy anything significant to the working directory so the harness agents have full context. List what you found and copied so the user can confirm nothing's missing.

## Then start the harness

Read `~/claude-hub/features/LIFECYCLE.md` for the full flow. Phase 0 (spec writing) is already done — skip it. Start at **Phase 1: Generate Review Angles**.

Drive the flow from Phase 1 onward. You are the orchestrating agent.
