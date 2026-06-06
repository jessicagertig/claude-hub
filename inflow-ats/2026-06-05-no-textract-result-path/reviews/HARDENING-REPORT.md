# CLAUDE.md Hardening Report

**Source:** All spec-round and impl-round findings
**Date:** 2026-06-05

## Rules Added to ~/claude-hub/inflow-ats/CLAUDE.md

None. All review rounds (2 spec, 1 impl) produced 0 BLOCKER and 0 HIGH findings. The 3 MED findings from the spec review were outside the spec's scope (pre-existing design gaps, not implementation failures). No recurring pattern was identified that warrants a new rule.

## Existing Rules That Were Violated

None. The implementation followed all existing rules:
- `return unless x` for guard clauses (CLAUDE.md Rule)
- `update_columns` for targeted attribute writes (pipeline CLAUDE.md Known Failure Pattern)
- No begin blocks (source repo CLAUDE.md Rule 1)
- `find_by` instead of `find` (cursor_rules/backend/background_jobs.md Rule 2)
- `ap` for logging (source repo CLAUDE.md)

## Findings Skipped (one-offs, not patterns)

### Spec review MEDs (outside scope, pre-existing gaps)
- async-timing F1: `SubmitResumeToTextract` AWS failure orphaning `textract_processing` summary. Pre-existing gap, not caused by this feature. Would require a new orphan-cleanup mechanism to fix.
- cascade-and-cleanup F3: Resume re-upload repurposing stale summary. Pre-existing ambiguity in the double-click protection logic. Not a pattern that applies to other features.
- notification-and-user-feedback F2: Missing persistent failure indication after page reload. Pre-existing UX gap. Would require a new status or audit trail to fix.

### Implementation note (not a failure, but worth noting)
The test database had a stale schema for `ai_job_application_summaries.textract_result_id` (NOT NULL constraint from before the in-place migration edit). This was resolved by rolling back and re-running the migration in the test env (`RAILS_ENV=test bundle exec rails db:migrate:down VERSION=... && db:migrate:up VERSION=...`). This is a consequence of editing migrations in place rather than creating change migrations — a known trade-off in this codebase during active development.
