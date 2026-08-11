# Feature Harness — Manual Reference

Run individual phases manually when you want to drive the process yourself instead of letting the orchestrating agent handle it.

## Setup

```bash
# 1. Create the working directory under the relevant pipeline
mkdir -p ~/claude-hub/<pipeline>/feature-name-YYYY-MM-DD/

# 2. Write the repo path (the worktree or repo this feature lives in)
echo '/absolute/path/to/repo-or-worktree/' > ~/claude-hub/<pipeline>/feature-name-YYYY-MM-DD/REPO-PATH

# 3. If you already have a spec, copy it in
cp /path/to/your/spec ~/claude-hub/<pipeline>/feature-name-YYYY-MM-DD/SPEC.md
```

## Running phases individually

From the working directory, attach the relevant prompt file. Use the pipeline-specific version if it exists, otherwise use the generic one.

```bash
# Generic (any pipeline):
claude --append-system-prompt-file ~/claude-hub/features/<prompt-file>.md

# Pipeline-specific override (if it exists):
claude --append-system-prompt-file ~/claude-hub/<pipeline>/features/<prompt-file>.md
```

## Phase reference

| Phase | Prompt file | What it produces | Gate |
|-------|-------------|-----------------|------|
| 0 | `spec-writing-prompt.md` | `SPEC.md`, `REPO-PATH` | Both files exist |
| 1 | `generate-review-angles-prompt.md` | `reviews/REVIEW-ANGLES.md` | **You review the angles before continuing** |
| 2 | `spec-review-prompt.md` | `reviews/spec-round-N/`, `reviews/SPEC-REVIEW-COMPLETE.md` | READY FOR PLANNING |
| 3 | `_base-template.md` | `plan.md` | Plan file exists |
| 4 | `plan-review-prompt.md` | `reviews/plan-review.md` | APPROVED verdict |
| 5 | `impl-prompt.md` | Code changes in repo | Tests pass |
| 6 | `impl-review-prompt.md` | `reviews/impl-round-N/`, `reviews/IMPL-REVIEW-COMPLETE.md` | APPROVED verdict |
| 7 | `hardening-prompt.md` | `reviews/HARDENING-REPORT.md` | Report exists |

## Running the full orchestrated flow

Instead of running phases manually, let an orchestrating agent drive the whole thing:

```bash
cd ~/claude-hub/<pipeline>/feature-name-YYYY-MM-DD/
claude "Run the feature development harness. Read LIFECYCLE.md at ~/claude-hub/features/LIFECYCLE.md for the full flow."
```

The orchestrating agent will spawn sub-agents for each phase, check gates, and keep going. It stops only at the Phase 1 angle-approval gate and on escalation.

## If you have an existing spec from another session

Tell the agent:

> Print the full path to the spec file you wrote, and the full path to the worktree you're working in.

Then set up the working directory with those paths and start at Phase 1 (angle generation).

## Skipping phases

You can start at any phase as long as the prior gates are met. For example, if you already have a reviewed spec and want to jump to planning:
1. Ensure `SPEC.md`, `REPO-PATH`, `reviews/REVIEW-ANGLES.md`, and `reviews/SPEC-REVIEW-COMPLETE.md` exist in the working directory
2. Run Phase 3 directly
