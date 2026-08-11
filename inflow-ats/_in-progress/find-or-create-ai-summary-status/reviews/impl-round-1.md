# Implementation Review — FindOrCreateAiJobApplicationSummaryStatus
## Round 1

**Branch:** `feature-ai-summaries-integrating-scoring-v4`
**Uncommitted changes:** None — reviewing committed code.

---

## Verdict: PASS

Zero HIGH or BLOCKER findings. Three MED findings and two LOW findings documented below.

---

## Findings

### MED-1: `handle_existing` uses `update_columns` — bypasses validations and skips return-value check obligation

**Angle:** angle-5 (save-return-value-handling), angle-4 (analog-structural-matching)

**File:** `app/interactors/find_or_create_ai_job_application_summary_status.rb` lines 28–36

**Observation:** `handle_existing` calls `status_record.update_columns(...)` for both the `:regenerating` and `:none` branches. `update_columns` bypasses ActiveRecord validations and callbacks and does not return a truthy/falsy success indicator — it raises on DB error rather than returning false. This differs from the analog (`FindOrCreateOrgInterviewerInvite`) which uses `@invite.save` with an explicit `if/else` and `context.fail!` on failure.

Core critical rule #12 says "always check `save`/`update` return values." `update_columns` has no checkable return in the Rails sense (it raises on failure), so the intent of rule #12 is technically not violated, but the deviation from the spec is:

- The spec says Branch 2 should "set the status record's `status`" (implying a normal attribute write + save), not use `update_columns`.
- More concretely: when Branch 2 sets `ai_job_application_summary` to nil and clears denormalized columns, `update_columns` bypasses the model's `belongs_to :ai_job_application_summary, optional: true` constraint — this is harmless here, but it sets a fragile precedent. If validations are later added to `AiJobApplicationSummaryStatus`, `update_columns` will silently bypass them.

The analog pattern (attribute assignment + `save` + `context.fail!` on failure) is not followed. The spec says "follows the `build` + explicit `save` pattern." The `handle_existing` branches are updates, not creates, but the same principle applies: use attribute writes + `save` with return-value checking.

**Severity:** MED — the observable behavior is correct and no data is corrupted. The analog pattern deviation and validation bypass are a quality concern.

---

### MED-2: `handle_existing` Branch 2 (succeeded → regenerating) does not set `context.ai_job_application_summary_status`

**Angle:** angle-2 (interactor-state-machine-correctness), angle-4 (analog-structural-matching), always-on (analog completeness)

**File:** `app/interactors/find_or_create_ai_job_application_summary_status.rb` lines 12–17

**Observation:** `context.ai_job_application_summary_status = status_record` is set at line 17 after the `if/else` block. This works correctly when `create_new` returns a value (Branch 3). However, `handle_existing` returns `nil` implicitly — it is a void method. The return value of `handle_existing` is discarded; `status_record` remains the `status_record` assigned at line 9, which is correct.

Wait — re-reading:

```ruby
status_record = job_application.ai_job_application_summary_status   # line 9
if status_record
  handle_existing(status_record)      # return value discarded; status_record unchanged
else
  status_record = create_new(job_application)   # reassigns status_record
end
context.ai_job_application_summary_status = status_record   # line 17
```

In Branch 1 and Branch 2 (existing record), `status_record` is never reassigned; it remains the record found at line 9. Line 17 correctly sets context to that same record. This is actually correct behavior.

**Revised assessment:** This is NOT a bug. Context is set correctly in all branches. The structure is sound.

**Retracted.** Not a finding.

---

### MED-2 (replacement): `RecordNotUnique` rescue in `create_new` returns `nil` when `job_application.reload.ai_job_application_summary_status` returns `nil`

**Angle:** angle-2 (interactor-state-machine-correctness), angle-4 (analog-structural-matching)

**File:** `app/interactors/find_or_create_ai_job_application_summary_status.rb` lines 63–65

**Observation:** The `rescue ActiveRecord::RecordNotUnique` block returns `job_application.reload.ai_job_application_summary_status`. If the reload finds the competing record, this returns the status record — correct. However, the return value propagates to line 14 (`status_record = create_new(job_application)`) and then to line 17 (`context.ai_job_application_summary_status = status_record`).

If the reload somehow returns `nil` (extremely unlikely but possible in a race where a concurrent destroy fires immediately after the unique constraint violation), `context.ai_job_application_summary_status` is set to `nil` without calling `context.fail!`. Callers that depend on `context.ai_job_application_summary_status` being present would silently receive `nil`.

This is a very narrow edge case, but the rescue block does not guard against a `nil` return from the reload.

**Severity:** MED — the happy-path race is handled correctly. The double-race (unique conflict + concurrent destroy) is extremely unlikely in production and the risk is low.

---

### MED-3: `update_columns` on Branch 2 "not succeeded" does not check return value and skips `context.fail!`

**Angle:** angle-5 (save-return-value-handling)

**File:** `app/interactors/find_or_create_ai_job_application_summary_status.rb` lines 28–36

**Observation:** Both `handle_existing` branches use `update_columns`, which raises `ActiveRecord::StatementInvalid` on DB error rather than returning false. There is no `rescue` for this case in `handle_existing` or in `call`. If the DB write fails at line 28 or 30, the exception propagates out of the interactor without calling `context.fail!`, which means it bubbles as a raw `ActiveRecord::StatementInvalid` exception rather than an `Interactor::Failure`.

For Branch 3 (create path), `unless status_record.save; context.fail!; end` correctly calls `context.fail!` on save failure. Branches 1 and 2 in `handle_existing` have no equivalent protection.

Given that `generate_ai_summary_with_credit_flow` has no `rescue Interactor::Failure` and `GenerateAiJobApplicationSummaryJob` rescues `StandardError` (which covers `ActiveRecord::StatementInvalid`), the net effect is that a DB failure in `handle_existing` causes the job to catch a `StandardError` and log it — the same behavior as a `context.fail!` would produce in this context (since failures are "deferred" per Decision #8). So the observable behavior is equivalent.

**Severity:** MED — the pattern deviation from core critical rule #12 is real, but the behavioral impact is minimal given the job-level StandardError rescue. Downgraded from HIGH because no data is lost or corrupted.

---

### LOW-1: `Interactor::Failure` propagation from `create_new` save failure is unrescued by callers

**Angle:** angle-5 (save-return-value-handling)

**File:** `app/models/textract_result.rb` line 70; `app/models/job_application.rb` line 157

**Observation:** When `context.fail!` fires in `create_new` (line 59), it raises `Interactor::Failure` (which is a `StandardError` subclass). The spec correctly defers failure handling ("Decision #8 — failure handling deferred"). `Interactor::Failure` is caught by:

- `GenerateAiJobApplicationSummaryJob`'s `rescue StandardError => e` (lines 39–45)
- `BulkGenerateAiSummariesJob`'s `rescue StandardError => e` (line 71)

For the `enqueue_new_job_application` path in `job_application.rb`, `find_or_create_ai_job_application_summary_status` is called synchronously inside an `after_commit` callback. There is no `rescue` in `enqueue_new_job_application`. A save failure during the `enqueue_new_job_application` call raises `Interactor::Failure`, which propagates out of the `after_commit` callback. Rails swallows exceptions raised in `after_commit` callbacks (they are logged but do not roll back or re-raise). So the practical effect is a logged error and no status record for the new application — not a crash.

This is a deferred failure per the spec, and the actual severity is low because save failures on `AiJobApplicationSummaryStatus` (a simple record with a unique constraint) are extremely rare.

**Severity:** LOW — behavior matches spec intent; no data corruption; failure handling is "deferred" per Decision #8.

---

### LOW-2: Spec coverage gap — `generate_ai_summary_with_credit_flow` interactor call not tested when `generate_ai_summary` is called without stubbing the interactor result

**Angle:** always-on (test coverage)

**File:** `spec/models/textract_result_ai_trigger_spec.rb` lines 196–233

**Observation:** The `generate_ai_summary_with_credit_flow` specs (lines 172–233) correctly test: (a) early return without interactor call, (b) interactor called before `generate_ai_summary` when stale, (c) interactor called before `generate_ai_summary` when no summary exists.

However, all three specs stub `generate_ai_summary` at the method level (`allow(textract_result).to receive(:generate_ai_summary)`). The `FindOrCreateAiJobApplicationSummaryStatus` call is stubbed in (b) and (c) but the interactor is allowed to fire in (a)'s negative test. None of the specs test what happens when the interactor call itself returns a failed context — the "failure deferred" behavior is not covered in tests.

The REVIEW-ANGLES.md required test coverage also lists: "TextractResult model spec: `generate_ai_summary_with_credit_flow` calls the interactor before `generate_ai_summary`; does NOT call it when the early-return guard fires." These two cases are covered. The third required case — "does NOT call it when the early-return guard fires" — is tested at line 196–199. All three coverage requirements are met.

The gap is that `context.ai_job_application_summary_status` is not asserted in the `generate_ai_summary_with_credit_flow` specs, but those specs are for `TextractResult`, not the interactor. The interactor spec covers context output.

**Severity:** LOW — required coverage is present. The gap (failure path behavior in the job context) is explicitly deferred by the spec.

---

## Per-angle summary

| Angle | Result | Notes |
|---|---|---|
| angle-1: generation-flow-coverage | PASS | All three paths (manual via `GenerateAiJobApplicationSummaryJob`, auto via `TextractResult#queue_ai_summary_job`, bulk via `BulkGenerateAiSummariesJob`) call `generate_ai_summary_with_credit_flow`, which calls the interactor after the early-return guard. Confirmed. |
| angle-2: interactor-state-machine-correctness | PASS with MED-2 | All three branches produce correct state. Race condition handled via `rescue ActiveRecord::RecordNotUnique`. MED-2: reload-returns-nil edge case. |
| angle-3: removal-completeness | PASS | `create_status_record` callback and method: deleted from `ai_job_application_summary.rb`. Both `find_or_create_by` calls: deleted from `create_ai_summary_generation.rb`. `status_record.regenerating = false` line: deleted (confirmed by grep returning no results). Stale reference grep: zero hits. |
| angle-4: analog-structural-matching | PASS with MED-1 | `build` + explicit `save` pattern used in Branch 3 (create path). `context.ai_job_application_summary_status` set in all paths. MED-1: `handle_existing` uses `update_columns` instead of attribute writes + `save`, deviating from analog and bypassing validations. |
| angle-5: save-return-value-handling | PASS with MED-3 | Branch 3 save return value checked; `context.fail!` on failure. `update_columns` in `handle_existing` raises on DB error rather than returning false — behavioral equivalent but pattern deviation. No `save!` or `create!`. |
| angle-6: trigger-a-new-application-path | PASS | `find_or_create_ai_job_application_summary_status` is the last line of `enqueue_new_job_application` (line 161), placed after the Flipper-gated `SubmitResumeToTextractJob.perform_later(id)` block. Not inside the Flipper block. Status record created regardless of Textract flag. |
| angle-7: update_summary_status_record-interaction | PASS | `after_commit :update_summary_status_record, on: :update` unchanged. Sequencing correct: interactor sets initial state before generation; `update_summary_status_record` fires after generation completes and summary transitions to `:succeeded`. No conflict. |
| always-on: source accuracy | PASS | `create_ai_summary_generation.rb` no longer has lines 54 or 74 referencing `AiJobApplicationSummaryStatus` — the file now has 78 lines with no status record references. `generate_ai_summary_with_credit_flow` interactor call is at line 70 (after the early-return guard at line 68). `AiJobApplicationSummaryStatus` has `enum status:` (integer) with `_prefix: true`, no boolean `regenerating` column. `update_summary_status_record` callback is present and unchanged. Denormalized column names (`score_percentage`, `headline`, `integrated_role_analysis`) match schema. |
| always-on: test coverage | PASS | Interactor spec covers all five required cases (Branch 1 no-change, Branch 2a succeeded→regenerating, Branch 2b not-succeeded→nil+none, Branch 3a create-with-current, Branch 3b create-with-none). `job_application_ai_summary_status_spec.rb` covers `enqueue_new_job_application` creates status with `status: none`. `textract_result_ai_trigger_spec.rb` covers early-return does not call interactor, and interactor is called before `generate_ai_summary` in both stale and no-summary cases. The pre-existing `ai_job_application_summary_status_spec.rb` `defaults regenerating to false` test has been correctly replaced with `defaults status to none` and `allows ai_job_application_summary_id to be nil`. No stale `regenerating` attribute reference remains in specs. |
| always-on: backward compatibility | PASS | `create_status_record` removal: no existing call sites create `AiJobApplicationSummary` without going through a path that also calls the new interactor. `CreateAiSummaryGeneration` builds the summary and saves it; the `after_commit :create_status_record` previously fired on create — now removed. The status record is created upstream by `find_or_create_ai_job_application_summary_status` before generation begins. The only path that creates a `textract_processing` summary (in `CreateAiSummaryGeneration`) now relies on the `enqueue_new_job_application` call to have already created the status record before the manual trigger fires. This is correct. |
| always-on: reinventing the wheel | PASS | `build` + explicit `save` used. No `find_or_create_by` or `first_or_initialize`. |
| always-on: analog completeness | PASS with MED-1 | All analog structural pieces present. MED-1 notes `update_columns` deviation in update branches. |

---

## Files reviewed

- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (new)
- `app/models/job_application.rb` (lines 151–161)
- `app/models/textract_result.rb` (lines 61–86)
- `app/models/ai_job_application_summary.rb` (full)
- `app/models/ai_job_application_summary_status.rb` (full)
- `app/interactors/create_ai_summary_generation.rb` (full)
- `app/interactors/find_or_create_org_interviewer_invite.rb` (analog, full)
- `app/jobs/generate_ai_job_application_summary_job.rb` (key lines)
- `app/jobs/bulk_generate_ai_summaries_job.rb` (lines 40–72)
- `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb` (full)
- `spec/models/ai_job_application_summary_status_spec.rb` (full)
- `spec/models/textract_result_ai_trigger_spec.rb` (full)
- `spec/models/job_application_ai_summary_status_spec.rb` (full)
