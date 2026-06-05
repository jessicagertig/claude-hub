# Setting Up a Feature for the Review Harness

## What you need

1. A spec file (wherever it currently lives)
2. The path to the worktree/repo for this feature

## Steps

```bash
# 1. Create the working directory
mkdir -p ~/claude-hub/inflow-ats/YYYY-MM-DD-feature-name/

# 2. Copy the spec
cp /path/to/your/spec ~/claude-hub/inflow-ats/YYYY-MM-DD-feature-name/SPEC.md

# 3. Write the repo path (the worktree this feature lives in)
echo '~/wrk/wrk-corp/inflow-ats.your-worktree/' > ~/claude-hub/inflow-ats/YYYY-MM-DD-feature-name/REPO-PATH
```

## Then run the flow

From the working directory, launch each phase with:

```
claude --append-system-prompt-file ~/claude-hub/inflow-ats/features/<prompt-file>.md
```

Phases in order:

| Phase | Prompt file | What it does |
|-------|-------------|-------------|
| 1 | `generate-review-angles-prompt.md` | Reads spec + codebase, writes `reviews/REVIEW-ANGLES.md`. **You review the angles before continuing.** |
| 2 | `spec-review-prompt.md` | Iterative adversarial spec review using the angles |
| 3 | `_base-template.md` | Writes implementation plan |
| 4 | `plan-review-prompt.md` | 2-pass plan fact-check |
| 5 | `impl-prompt.md` | Implements the plan |
| 6 | `impl-review-prompt.md` | Iterative adversarial impl review |
| 7 | `hardening-prompt.md` | Extracts lessons into CLAUDE.md |

Full details in `LIFECYCLE.md`.

## If an existing agent has the spec

Tell the agent:

> Print the full path to the spec file you wrote, and the full path to the worktree you're working in.

Then run the steps above with those paths.
