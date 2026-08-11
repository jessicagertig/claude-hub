# CLAUDE.md Hardening Report

**Source:** this session's failures (W5 infrastructure over-reach; dropping out of the Phase 6 loop)
**Date:** 2026-06-23

## Rules Added to ~/claude-hub/inflow-ats/CLAUDE.md

- **#20 — Fixing a gap must not change shared infrastructure (enum values, columns, display-state semantics) without explicit owner approval.** — Motivated by W5/issue-3a: the fix added `failed:4` to the `AiJobApplicationSummaryStatus` enum and transitioned the row `current → failed`, destroying a user's prior succeeded review on a later regeneration failure. The 8-round spec review verified spec-compliance but never questioned whether the status enum *should* gain a failed value (it shouldn't — the enum exists to check for a succeeded review). Reverted entirely.

- **#21 — Stay in the LIFECYCLE phase loop; do not hand-fix review findings in the main thread.** — Motivated by the Phase 6 deviation: the orchestrator hand-patched review-flagged gaps instead of running the Phase 5↔6 fresh-sub-agent loop; Jessica redirected ("don't get out of the lifecycle").

## Existing Rules That Were Reinforced (no duplication added)

- **#10 (fix agents must not add code beyond defect scope)** and the global **"Spec-implementation mismatch is never MED"** / **"Fix agent code is unreviewed scope"** patterns are adjacent, but #20 is distinct: it targets the case where the SPEC ITSELF (not a rogue fix agent) directs an infrastructure change that no review round challenges because everyone checks "does the code match the spec," not "does the spec respect the existing infrastructure's purpose." That gap is the new lesson.

## Findings Skipped (one-offs, not patterns)

- The counter_culture decrement test that read a stale in-memory `job_record` count (a test-authoring slip, removed) — a one-off, not a recurring pattern.
- Transient API 500 that killed the Phase 6 round-2 agent — infrastructure flake, not a process lesson (the *response* to it is covered by #21).

## Process note for the orchestrator

The deepest defect this session (W5) was caught by the human, not by 8 spec-review rounds + a Phase-6 review — because adversarial review was pointed at spec-compliance, not at whether the spec's premise ("the status row needs a failed state") was sound. Future review angles for any feature that touches a shared enum/state should include an explicit "should this state exist at all / what is this enum FOR" challenge, not just "is it implemented correctly."
