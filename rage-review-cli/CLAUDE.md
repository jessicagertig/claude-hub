# rage-review-cli — Pipeline Scratchpad

**Source repo:** `/Users/jessica/wrk/review-cli`
**Status:** Reference + occasional feature work. **Heavy to run** — running the full review takes a long time, so default is read-only / feature-design work, not invocation.

## Context

This tool consumes Jessica's `cursor_rules/` (from inflow-ats) and applies them as a review pass. Output directories appear inside inflow-ats worktrees as `.rage-review-cli/`. We may decide to either incorporate ideas from this tool into other workflows, or run it on specific branches when worth the time cost.

## Scratchpad contents

(To be filled in. Likely candidates: feature design for the CLI itself, evaluations of whether to run it on a given branch.)

## In-progress working artifacts

Pipeline-specific working artifacts that need durable file storage during a session — feature design drafts for the CLI itself, evaluations of whether to run it on a given branch, in-flight investigation notes — live in `~/claude-hub/rage-review-cli/_in-progress/<artifact-name>/`, with each work item getting its own per-item subdirectory.

These artifacts do NOT live in the hub-root `~/claude-hub/_in-progress/`. That location is reserved for hub-level and cross-pipeline working artifacts (see the hub root `CLAUDE.md` for the full convention).

The user retains complete control over `_in-progress/` contents: graduate artifacts to their permanent location by moving them, or delete entire `_in-progress/` subdirectories without affecting anything outside.

## Pipeline-specific rules

(Empty placeholder.)
