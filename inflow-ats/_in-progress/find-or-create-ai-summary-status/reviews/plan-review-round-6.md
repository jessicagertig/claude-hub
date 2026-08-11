# Plan Review — Round 6

**Branch:** `feature-ai-summaries-integrating-scoring-v4`
**Date:** 2026-06-15
**Verdict:** PASS

---

## Files traced

- `/Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/plan.md`
- `/Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/SPEC.md`
- `/Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/reviews/REVIEW-ANGLES.md`
- `/Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/reviews/plan-review-round-5.md`
- `app/models/textract_result.rb` (branch) — `generate_ai_summary_with_credit_flow`, `queue_ai_summary_job`
- `app/models/ai_job_application_summary.rb` (branch) — `create_status_record` callback, `update_summary_status_record`
- `app/models/ai_job_application_summary_status.rb` (branch) — enum definition, validates
- `app/models/job_application.rb` (branch) — `enqueue_new_job_application`, `latest_ai_job_application_summary` has_one
- `app/interactors/create_ai_summary_generation.rb` (branch) — lines 54 and 72-74
- `app/interactors/find_or_create_org_interviewer_invite.rb` (branch) — analog
- `app/jobs/generate_ai_job_application_summary_job.rb` (branch)
- `app/jobs/bulk_generate_ai_summaries_job.rb` (branch)
- `spec/models/ai_job_application_summary_status_spec.rb` (branch)
- `spec/models/ai_job_application_summary_spec.rb` (branch)
- `spec/models/textract_result_ai_trigger_spec.rb` (branch)
- `spec/interactors/` directory listing (branch)
- `spec/support/ai_credits_test_helpers.rb` (branch)
- `app/models/organization.rb` (branch) — default settings, `auto_generate_ai_summaries_enabled`
- `app/models/job.rb` (branch) — `should_auto_generate_ai_summaries?`
- `db/schema.rb` (branch) — `ai_job_application_summary_statuses`, `ai_job_application_summaries`, `textract_results`

---

## Round 5 fixes verified

### HIGH-1 fix: Task 8 added

Task 8 adds `spec/models/textract_result_spec.rb` with three contexts covering `generate_ai_summary_with_credit_flow`:
- "when latest summary is succeeded and not stale" — verifies the interactor is NOT called (early return guard fires first)
- "when latest summary is stale" — verifies interactor is called before `generate_ai_summary`
- "when no summary exists" — verifies interactor is called before `generate_ai_summary`

This directly satisfies the REVIEW-ANGLES "Required new test coverage" requirement for `TextractResult`.

### HIGH-2 fix: Task 9 added

Task 9 adds `spec/models/job_application_spec.rb` with a test that creates a `job_application` via `create_credit_test_job_application` and immediately checks `job_application.ai_job_application_summary_status` is present with `status: 'none'`. This directly satisfies the REVIEW-ANGLES requirement for `enqueue_new_job_application` creating a status record.

### MED-1 fix: Race condition rescue added

The `create_new` private method in the Task 1 interactor code now wraps the `save` + `status_record` return inside a `rescue ActiveRecord::RecordNotUnique` block that returns `job_application.reload.ai_job_application_summary_status`. This handles the concurrent-insert race at the DB-level unique index. The MED is resolved.

---

## Full pass — no new HIGH or BLOCKER findings

### angle-1: generation-flow-coverage — PASS

All three generation paths converge on `generate_ai_summary_with_credit_flow`:
- Manual: `CreateAiSummaryGeneration` (Task 5 removes its two `find_or_create_by` calls) → enqueues `GenerateAiJobApplicationSummaryJob` → calls `generate_ai_summary_with_credit_flow`
- Auto: `TextractResult#queue_ai_summary_job` after commit → enqueues `GenerateAiJobApplicationSummaryJob` → calls `generate_ai_summary_with_credit_flow`
- Bulk: `BulkGenerateAiSummariesJob#each_iteration` → calls `generate_ai_summary_with_credit_flow` directly

Task 3 places the interactor call after the early return guard (`return if latest&.status_succeeded? && !latest.stale?` at line 68) and before `generate_ai_summary`. Verified: the guard is at line 68 on the branch. The Task 3 code placement is correct.

The `textract_processing` window concern (angle-1): after Task 2, `enqueue_new_job_application` creates the status record eagerly. When Textract later completes and `generate_ai_summary_with_credit_flow` fires (after Task 4 removes `create_status_record`), Branch 1 of the interactor fires (record exists, summary nil → no changes). No window exists where a `textract_processing` summary has no status record.

### angle-2: interactor-state-machine-correctness — PASS

All branches verified against the plan code:
- **Branch 1 (record exists, summary nil):** `handle_existing` returns immediately (bare `return unless summary`). `context.ai_job_application_summary_status = status_record` is set at the end of `call` in all paths. Correct.
- **Branch 2a (record exists, summary succeeded):** `update_columns(status: 'regenerating')` — return value checked via `unless ... context.fail!`. `ai_job_application_summary_id` is NOT cleared. Denormalized columns NOT cleared. Correct.
- **Branch 2b (record exists, summary not succeeded):** `update_columns(ai_job_application_summary_id: nil, status: 'none', score_percentage: nil, headline: nil, integrated_role_analysis: nil)` — return value checked via `unless ... context.fail!`. All denormalized columns cleared. Correct.
- **Branch 3a (no record, succeeded non-stale summary exists):** `build` + explicit `save` with `status: 'current'`, `ai_job_application_summary_id`, and all three denormalized columns set. Correct.
- **Branch 3b (no record, no succeeded summary):** `build` + `save` with `status: 'none'`, no denormalized columns set. Correct.
- **Race condition:** `rescue ActiveRecord::RecordNotUnique` returns `job_application.reload.ai_job_application_summary_status`. Correct.

The association-based check (`status_record.ai_job_application_summary`) is used throughout, not the ID column. Correct per spec Decision #5.

### angle-3: removal-completeness — PASS

Both `find_or_create_by` calls in `CreateAiSummaryGeneration` are targeted in Tasks 4 and 5:
- Line 54: single-line removal (Task 5 Step 1)
- Lines 72-74: three-line block removal including `status_record.regenerating = false` (Task 5 Step 2)

The `create_status_record` callback and method are removed in Task 4 (both the `after_commit` declaration at line 27 and the private method at lines 45-47).

Task 5 Step 3 includes a `grep` verification command for `create_status_record`, `find_or_create_by.*AiJobApplicationSummaryStatus`, and `.regenerating`. This catches any remaining references.

Task 6 rewrites `ai_job_application_summary_status_spec.rb`:
- `validations` test: removes `described_class.create!` (which would fail after Task 2's eager creation) and instead uses `described_class.new` to test the uniqueness validation against the eagerly-created record.
- `defaults` block: removes the broken `expect(status_record.regenerating).to eq(false)` test (which called `.regenerating` as a plain attribute — nonexistent; the model has `_prefix: true` so the predicate is `status_regenerating?`) and replaces it with `expect(status_record.status).to eq('none')`.

`ai_job_application_summary_spec.rb` has no direct test of `create_status_record` (verified on branch) — no updates required.

### angle-4: analog-structural-matching — PASS

The new interactor matches `FindOrCreateOrgInterviewerInvite`:
- Context input: `context.job_application` — single named input
- Find branch (record exists): sets `context.ai_job_application_summary_status` at end of `call`, makes no changes in Branch 1
- Build branch: `job_application.build_ai_job_application_summary_status` + explicit `save`
- `context.fail!` on save failure in Branch 2 and Branch 3
- Context output set in all non-error paths
- Wrapper method `JobApplication#find_or_create_ai_job_application_summary_status` is a one-liner

### angle-5: save-return-value-handling — PASS

- Branch 2 `update_columns(status: 'regenerating')`: `unless ... context.fail!` — checked
- Branch 2 (not succeeded) `update_columns(ai_job_application_summary_id: nil, ...)`: `unless ... context.fail!` — checked
- Branch 3 `status_record.save`: `unless status_record.save; context.fail!; end` — checked
- No `save!`, `update!`, or `create!` in the new interactor code

`context.fail!` raises `Interactor::Failure`, which will propagate through `generate_ai_summary_with_credit_flow` to the job (`GenerateAiJobApplicationSummaryJob`). The job has a `rescue StandardError` that updates the summary to `:failed` and broadcasts completion. `Interactor::Failure` inherits from `StandardError`, so the job's rescue block will catch it. The spec's Decision #8 ("failure handling deferred") is acceptable for the wrapper method; interactor failures propagate to the job's existing error handling.

### angle-6: trigger-a-new-application-path — PASS

`find_or_create_ai_job_application_summary_status` is the last line of `enqueue_new_job_application`, placed after the Flipper-gated `SubmitResumeToTextractJob` block (not inside it). Verified by the plan's Task 2 Step 2 code.

When `enqueue_new_job_application` fires (after commit on create), no `AiJobApplicationSummary` exists yet. The interactor takes Branch 3: no succeeded non-stale summary → creates with `status: :none`. This is the correct outcome for a new application.

The interactor call runs in `after_commit` context, so the `JobApplication` is already committed. The `build` + `save` for the status record is not inside a transaction being rolled back — safe.

### angle-7: update_summary_status_record-interaction — PASS

`update_summary_status_record` (the `after_commit :on :update` callback) is unchanged by this feature. It fires when an `AiJobApplicationSummary` transitions to `:succeeded` and updates the status record to `status: 'current'` with denormalized columns.

The lifecycle sequence works correctly:
1. `enqueue_new_job_application` → interactor creates status `status: :none`
2. `generate_ai_summary_with_credit_flow` → interactor fires (Branch 1: record exists, summary nil → no changes); then `generate_ai_summary` creates and processes the summary
3. `AiJobApplicationSummary` transitions to `:succeeded` → `update_summary_status_record` fires → sets `status: 'current'` and denormalized columns

No conflict: the interactor in step 2 does not set denormalized columns (Branch 1 makes no changes); `update_summary_status_record` sets them after generation succeeds.

### always-on checks: source accuracy — PASS

- `after_commit :create_status_record, on: :create` at line 27: confirmed on branch
- `create_status_record` method at lines 45-47: confirmed on branch
- First `find_or_create_by` at line 54 in `create_ai_summary_generation.rb`: confirmed on branch
- Second `find_or_create_by` block at lines 72-74: confirmed on branch (line 72: `AiJobApplicationSummaryStatus.find_or_create_by`, line 73: `status_record.regenerating = false`, line 74: `end`)
- Early return guard at line 68 in `textract_result.rb`: confirmed on branch (`return if latest&.status_succeeded? && !latest.stale?`)
- `AiJobApplicationSummaryStatus` enum: `{none: 0, current: 1, regenerating: 2}, _prefix: true` — no boolean `regenerating` column. Confirmed.
- Schema columns `score_percentage` (decimal), `headline` (string), `integrated_role_analysis` (text): confirmed in schema
- `update_summary_status_record` is the `after_commit on: :update` callback — NOT targeted for deletion. Confirmed: plan only removes `create_status_record`.
- `latest_ai_job_application_summary` is a `has_one` scoped to `order(created_at: :desc)` — not a method. The Task 8 spec creates summaries that will be returned by this association. Correct.

### always-on checks: test coverage — PASS

All three required test categories from REVIEW-ANGLES are now covered:
1. `FindOrCreateAiJobApplicationSummaryStatus` interactor spec (Task 7): Branch 1, 2a, 2b, 3a, 3b
2. `JobApplication` spec (Task 9): `enqueue_new_job_application` creates status with `status: :none`
3. `TextractResult` spec (Task 8): interactor called before `generate_ai_summary`; early-return guard skips interactor

### always-on checks: reinventing the wheel / pattern compliance — PASS

`build` + explicit `save` pattern used (not `find_or_create_by`). Context output set in all paths.

### always-on checks: backward compatibility — PASS

- `create_status_record` deletion: all `AiJobApplicationSummary` creation paths are covered. `CreateAiSummaryGeneration` creates summaries; its `find_or_create_by` calls (removed in Task 5) are superseded by the new interactor called upstream in `generate_ai_summary_with_credit_flow` (Task 3) and `enqueue_new_job_application` (Task 2). `AiJobApplicationAction::Orchestrate` creates summaries downstream of `generate_ai_summary_with_credit_flow` — by the time it runs, the status record already exists (created by `enqueue_new_job_application` or the interactor call in Task 3).
- `status_record.regenerating = false` block in `create_ai_summary_generation.rb`: this called a nonexistent boolean attribute on a model with `_prefix: true` enum. It was effectively a no-op or silently ignored. Task 5 removes it along with the surrounding `find_or_create_by` block. No behavior lost.
- `ai_job_application_summary_spec.rb`: no tests directly test `create_status_record` behavior (confirmed). No spec updates required.

### always-on checks: analog completeness — PASS

All structural pieces from `FindOrCreateOrgInterviewerInvite` have corresponding equivalents in the new interactor, as documented in the REVIEW-ANGLES table.

---

## LOW findings

### LOW-1: Task 11 Step 2 verify checklist omits two new spec files

The `git add` in Task 11 Step 1 correctly stages `spec/models/textract_result_spec.rb` and `spec/models/job_application_spec.rb`. However, the Step 2 verify checklist does not mention verifying these two files appear in `git diff --cached`. An implementer following the checklist would not confirm these new spec files are present in the staged diff. This cannot cause a code defect — the `git add` command is correct — but the verify checklist is incomplete.

Not a blocking defect. No code impact.

---

## Summary

Both HIGH findings from round 5 are resolved by Tasks 8 and 9. The MED race condition is resolved by the `rescue ActiveRecord::RecordNotUnique` in the interactor's `create_new` method. All angles pass on fresh inspection. No new HIGH or BLOCKER findings.

**0 BLOCKER, 0 HIGH, 0 MED, 1 LOW → PASS**
