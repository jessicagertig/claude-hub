# Plan Review — Round 5

**Branch:** `feature-ai-summaries-integrating-scoring-v4`
**Date:** 2026-06-15
**Verdict:** FAIL

---

## Files traced

- `/Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/plan.md`
- `/Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/SPEC.md`
- `/Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/reviews/REVIEW-ANGLES.md`
- `app/models/ai_job_application_summary.rb` (branch)
- `app/models/ai_job_application_summary_status.rb` (branch)
- `app/models/job_application.rb` (branch)
- `app/models/textract_result.rb` (branch)
- `app/interactors/create_ai_summary_generation.rb` (branch)
- `app/interactors/find_or_create_org_interviewer_invite.rb` (branch)
- `app/jobs/generate_ai_job_application_summary_job.rb` (branch)
- `app/jobs/bulk_generate_ai_summaries_job.rb` (branch)
- `spec/models/ai_job_application_summary_status_spec.rb` (branch)
- `spec/models/ai_job_application_summary_spec.rb` (branch)
- `spec/models/textract_result_ai_trigger_spec.rb` (branch)
- `spec/interactors/create_ai_credit_balance_transaction_spec.rb` (branch, pattern reference)
- `spec/support/ai_credits_test_helpers.rb` (branch)
- `db/schema.rb` (branch)
- `spec/rails_helper.rb` (branch)

---

## HIGH findings

### HIGH-1: Plan omits required `TextractResult` spec coverage (review-angles always-on)

The REVIEW-ANGLES "Required new test coverage" section explicitly requires:

> `TextractResult` model spec: `generate_ai_summary_with_credit_flow` calls the interactor before `generate_ai_summary`; does NOT call it when the early-return guard fires

The plan adds no such test. `spec/models/textract_result_ai_trigger_spec.rb` (verified on branch) only tests `queue_ai_summary_job` — it has no tests for `generate_ai_summary_with_credit_flow`. The plan's Task 7 adds only the interactor spec. The call to `job_application.find_or_create_ai_job_application_summary_status` in `generate_ai_summary_with_credit_flow` is untested by the plan.

This is a spec-coverage requirement explicitly stated in the REVIEW-ANGLES that the plan does not fulfill. The spec for the TextractResult method must verify both: (a) the interactor is called before `generate_ai_summary`, and (b) the early-return guard at line 68 skips the interactor call.

### HIGH-2: Plan omits required `JobApplication` spec coverage (review-angles always-on)

The REVIEW-ANGLES "Required new test coverage" section explicitly requires:

> `JobApplication` model spec or integration test: `enqueue_new_job_application` creates a status record with `status: :none`

The plan adds no such test. No existing spec tests `enqueue_new_job_application` (confirmed with `grep -rn "enqueue_new_job_application" -- 'spec/'` returning zero results). The plan's Task 7 adds only the interactor spec. The Trigger A path — `enqueue_new_job_application` → `find_or_create_ai_job_application_summary_status` — is untested by the plan.

This is a second spec-coverage requirement explicitly stated in the REVIEW-ANGLES that the plan does not fulfill.

---

## MED findings

### MED-1: Race condition at uniqueness constraint not addressed (review-angles angle-2)

The REVIEW-ANGLES angle-2 explicitly flags:

> **Race condition at uniqueness constraint:** The `AiJobApplicationSummaryStatus` table has a DB-level unique index on `job_application_id`. If two concurrent calls both hit Branch 3 simultaneously, the second `save` will fail. Verify the spec addresses or explicitly defers this. (If not addressed, the reviewer should flag it.)

The plan does not address the race condition and does not explicitly defer it. The spec (SPEC.md) also says nothing about concurrent access. The plan's new interactor uses `build` + `save` (not `find_or_create_by`), so a concurrent duplicate will raise `ActiveRecord::RecordNotUnique` from the DB constraint rather than being silently swallowed. The plan should either: (a) add `rescue ActiveRecord::RecordNotUnique` and reload the existing record, or (b) explicitly note this is deferred and document why it's acceptable.

---

## LOW findings

### LOW-1: Stale line number in SPEC.md and REVIEW-ANGLES (source accuracy angle)

The SPEC.md (modified files section) says the early return guard is at "line 67" of `textract_result.rb`. The REVIEW-ANGLES angle-1 also says "line 67." The actual branch file shows:
- Line 67: `latest = job_application.latest_ai_job_application_summary`
- Line 68: `return if latest&.status_succeeded? && !latest.stale?`

The plan (Task 3, Step 1) correctly says "after the early return guard at line 68" — so the PLAN has the correct line number. The SPEC.md and REVIEW-ANGLES have an off-by-one error that could confuse the implementing agent about exactly where to insert the new line. However, the plan itself is correct on this point, so the implementing agent following the plan will place the code correctly.

### LOW-2: SPEC.md line number for second `find_or_create_by` in `CreateAiSummaryGeneration` is off by two

SPEC.md says: "Delete both `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)` calls (lines 54 and 74)." The actual branch file shows the second `find_or_create_by` is at line 72 (not 74) — line 73 is `status_record.regenerating = false` and line 74 is `end`. The PLAN correctly identifies "lines 72-74" as the block to remove. The SPEC's "line 74" refers to the closing `end` of the block, not the `find_or_create_by` call itself. The plan will produce correct behavior, but the SPEC documentation is misleading.

---

## Verified correct

The following were verified against the branch and are accurate in the plan:

**File existence:**
- `app/interactors/find_or_create_org_interviewer_invite.rb` — exists on branch; confirms analog pattern
- `app/models/ai_job_application_summary.rb` — `after_commit :create_status_record, on: :create` at line 27, `create_status_record` method at lines 45-47. Plan is accurate.
- `app/models/ai_job_application_summary_status.rb` — enum `{none: 0, current: 1, regenerating: 2}, _prefix: true`. No boolean `regenerating` column. Plan is accurate.
- `db/schema.rb` — columns `score_percentage` (decimal), `headline` (string), `integrated_role_analysis` (text) confirmed. Plan column references are accurate.
- `app/interactors/create_ai_summary_generation.rb` — first `find_or_create_by` at line 54, second `find_or_create_by` at line 72 (with `status_record.regenerating = false` at 73, `end` at 74). Both plan tasks target the correct code.

**Code correctness:**
- Interactor `handle_existing` branch: accesses `status_record.ai_job_application_summary` (association, not column). Correct per spec Decision #5.
- `update_columns(status: 'regenerating')` pattern: follows existing `update_summary_status_record` precedent (`status: 'current'` with `update_columns`). Correct.
- `build` + explicit `save` pattern: matches analog `FindOrCreateOrgInterviewerInvite`. Correct.
- `context.fail!` on save failure: both Branch 2 and Branch 3 check return values. Correct per core critical rule #12.
- `context.ai_job_application_summary_status` set in all paths (Branch 1: set at end of `call`; Branch 2 update: set at end of `call`; Branch 3 create: returned and set). Correct.

**Line number accuracy in plan:**
- `enqueue_new_job_application` at line 151, plan says "around line 150." Accurate.
- `private` keyword at line 896. Plan says "the only `private` keyword is at line 896." Accurate.
- `after_commit :create_status_record, on: :create` at line 27. Plan says "line 27." Accurate.
- `create_status_record` method at lines 45-47. Plan says "lines 45-47." Accurate.
- First `find_or_create_by` at line 54. Plan says "line 54." Accurate.
- Second `find_or_create_by` block at lines 72-74. Plan says "lines 72-74." Accurate.
- Early return guard at line 68. Plan says "line 68." Accurate (spec says 67; plan is correct).

**Spec design:**
- Task 6 `validations` rewrite: removes `described_class.create!` (which would fail after Task 2's eager creation). Correct.
- Task 6 `defaults` rewrite: removes `described_class.create!` (same issue). Correct.
- Task 7 interactor spec `before { job_application.ai_job_application_summary_status&.destroy }` pattern: correctly destroys the eagerly-created record before "record does not exist" tests. Correct.
- `type: :interactor` with `config.infer_spec_type_from_file_location!`: pattern used by existing interactor specs in `spec/interactors/`. Correct.
- `AiCreditsTestHelpers` included globally (no type restriction) — `create_credit_test_job_application` available in interactor spec. Correct.

**Commit step:**
- All 7 file paths in Task 9's `git add` are the correct files the plan modifies. No file is staged that should not be; no file is omitted that is modified.

---

## Summary

Two HIGH findings: the plan omits test coverage that the REVIEW-ANGLES explicitly require — tests for `TextractResult#generate_ai_summary_with_credit_flow` calling the interactor (and not calling it when the early-return guard fires), and a test that `enqueue_new_job_application` creates a status record with `status: :none`. Both are in the "Required new test coverage" section of the always-on checks and cannot be waived without the spec explicitly documenting the omission.

The plan is otherwise structurally correct: line numbers verified, analog pattern followed, enum handling correct, save return values checked, callback removal complete, spec rewrites address the eager-creation conflict, commit step stages the right files.

**0 BLOCKER, 2 HIGH, 1 MED, 2 LOW → FAIL**
