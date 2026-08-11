# Angle 3 — Job gating change, ExtractJobCriteriaJob signature, broadcast lifecycle — Round 2

All files in this angle (`job.rb` gating region, `extract_job_criteria_job.rb`, their specs) are byte-identical to the round-1-reviewed state except that `job.rb` also carries develop's unrelated `reset_ai_summaries_count` addition (:1189-1194) — different region, no interaction.

## Re-verified at HEAD

- **Gating (SPEC 4.1):** `extract_job_criteria_immediately(requesting_organization_user_id: nil)` guards `description.present?`, `in_progress`, `retrying` (no pending guard — DECISIONS-verbatim); `_if_needed` keeps only the `succeeded` guard (job.rb:730-746). Interdiff across the merge: byte-identical hunks. `auto_extract_job_criteria`/`extract_job_criteria` untouched (their `status_pending?` + Flipper semantics preserved; enqueue sites still single-arg).
- **Signature (flag 4, adjudicated):** `perform(ai_job_criteria_id, requesting_organization_user_id = nil)` — optional positional stands; old `[id]` payloads remain valid.
- **Three broadcast sites** (extract_job_criteria_job.rb): end-of-perform gated `if requesting_organization_user_id` (:23); `retry_on` exhaustion block after the failure write, args via `job.arguments.first`/`.second`, row-exists guard (:5-13); StandardError rescue after the failure write, gated on row AND requesting id (:27-35). Helper guard ladder (OrganizationUser → user → `reload` → terminal check → payload with conditional `errorMessage`) matches the analog's order; camelCase payload keys; `JOB_CRITERIA_EXTRACTION_COMPLETE` action (:39-63).
- `ai_job_criteria.reload` (:46) — SPEC-verbatim, plan R-1 gate-bound to the Phase 6.5 conventions pass. Noted, not counted (round directive; round-1 code-quality F1).
- Auto path (nil requesting id) never broadcasts: perform-end gated; rescue gated; exhaustion path calls the helper with `job.arguments.second` = nil → `OrganizationUser.find_by(id: nil)` → nil → return. Matches analog behavior.
- Specs (`extract_job_criteria_job_spec.rb`, `job_criteria_lifecycle_spec.rb`): unchanged since round 1, all passing in this round's suite run (140 examples; only the 9 pre-existing on_complete failures elsewhere).

## Merge interaction check

Develop's PR #3054 touched neither `extract_job_criteria_job.rb` nor the gating region of `job.rb` (develop diff for job.rb is only `reset_ai_summaries_count`). No resolution occurred in this angle's code paths.

## Findings

No issues found. (LOW carryover recorded in test-coverage.md: exhaustion-broadcast site still has no direct test — matches the adjudicated test plan.)
