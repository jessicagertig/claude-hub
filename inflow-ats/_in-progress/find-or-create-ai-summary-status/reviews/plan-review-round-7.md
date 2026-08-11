# Plan Review — Round 7

**Branch:** `feature-ai-summaries-integrating-scoring-v4`
**Verdict:** PASS

0 HIGH+ findings. 1 MED, 1 LOW.

---

## Verification summary

Every file path, line number, code block, and behavioral claim in the plan was traced against the live branch. Summary of what was confirmed:

**File paths — all verified:**
- `app/interactors/find_or_create_org_interviewer_invite.rb` — exists, confirmed as analog
- `app/models/ai_job_application_summary_status.rb` — exists, enum `none: 0, current: 1, regenerating: 2` with `_prefix: true` confirmed
- `app/models/ai_job_application_summary.rb` — `after_commit :create_status_record, on: :create` at line 27; `create_status_record` method at lines 45-47 confirmed
- `app/interactors/create_ai_summary_generation.rb` — `AiJobApplicationSummaryStatus.find_or_create_by` at line 54 and lines 72-74 confirmed (83 total lines)
- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow` at line 61; early return guard `return if latest&.status_succeeded? && !latest.stale?` at line 68; `generate_ai_summary` at line 70 confirmed
- `app/models/job_application.rb` — `enqueue_new_job_application` at line 151; `private` keyword at line 896; method is public confirmed
- `spec/models/ai_job_application_summary_status_spec.rb` — `expect(status_record.regenerating).to eq(false)` at line 23 confirmed; both broken tests (`create!` in validations, `.regenerating` in defaults) confirmed present
- `spec/models/job_application_spec.rb` — does NOT exist on branch; plan correctly says "Create or modify"
- `spec/models/textract_result_spec.rb` — does NOT exist on branch; existing spec is `spec/models/textract_result_ai_trigger_spec.rb`; plan correctly says "or spec/models/textract_result_ai_trigger_spec.rb if that's where the existing generate tests live"
- `spec/interactors/` — directory exists with other interactor specs; `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb` does not yet exist

**Code blocks — verified:**
- Interactor code block matches the described behavior
- `enqueue_new_job_application` method body at lines 151-157 matches plan's Task 2 Step 2 target
- `generate_ai_summary_with_credit_flow` method body at lines 61-85 matches plan's Task 3 Step 1 description
- `AiJobApplicationSummary` callback and method at lines 27, 45-47 match plan's Task 4 deletion targets
- `CreateAiSummaryGeneration` blocks at lines 54 and 72-74 match plan's Task 5 deletion targets

**Schema — verified:**
- `ai_job_application_summary_statuses`: `status` is `t.integer default: 0` (not a boolean column); no `regenerating` column; `ai_job_application_summary_id` allows NULL; unique index on `job_application_id`; FK to `ai_job_application_summaries`
- `ai_job_application_summaries`: `stale` is `boolean default: false not null`

**After_commit in tests — verified:**
- `config.active_job.queue_adapter = :inline` in `config/environments/test.rb` — jobs run synchronously in tests
- `config.use_transactional_fixtures = true` in `spec/rails_helper.rb`
- Rails 6.1 fires `after_commit` within transactional tests (savepoint semantics)
- `create_credit_test_job_application` triggers `after_commit :enqueue_new_job_application` in tests
- Existing interactor specs (e.g., `create_ai_credit_balance_transaction_spec.rb`) use `create_credit_test_job_application` WITHOUT overriding the queue adapter and pass — confirms inline job execution via `handle_new_job_application` is safe in this codebase
- `auto_generate_ai_summaries_enabled` defaults to `false` for test orgs (no AI settings configured); `queue_ai_summary_job` returns early at `should_auto_generate_ai_summaries?` — no `GenerateAiJobApplicationSummaryJob` enqueued during textract result creation in new specs
- `textract_result_ai_trigger_spec.rb` overrides queue adapter to `:test` — existing tests unaffected by the new eager status record creation

**Race condition — verified:**
- `rescue ActiveRecord::RecordNotUnique` inside `create_new` correctly catches the uniqueness violation and falls back to `job_application.reload.ai_job_application_summary_status`; the rescued value is returned from `create_new` and assigned to `context.ai_job_application_summary_status` in `call()` — correct

**Interactor state machine — verified:**
- Branch 1 (exists, nil summary): `return unless summary` exits `handle_existing`; `context.ai_job_application_summary_status = status_record` still executes — correct
- Branch 2 succeeded: `update_columns(status: 'regenerating')` — 'regenerating' maps to integer 2 via Rails 6.1 enum type casting in `update_columns` (same mechanism as existing `update_summary_status_record` using `update_columns(status: 'current')`)
- Branch 2 non-succeeded: `update_columns(ai_job_application_summary_id: nil, ...)` — NULL allowed by schema ✓
- Branch 3 create: `job_application.build_ai_job_application_summary_status` + explicit `.save` matching the analog pattern ✓
- `context.ai_job_application_summary_status` set in all branches ✓

**Removal completeness — verified:**
All four existing references found by grep:
1. `app/models/ai_job_application_summary.rb:27` — Task 4 Step 1
2. `app/models/ai_job_application_summary.rb:45-47` — Task 4 Step 2
3. `app/interactors/create_ai_summary_generation.rb:54` — Task 5 Step 1
4. `app/interactors/create_ai_summary_generation.rb:72-74` — Task 5 Step 2 (includes `status_record.regenerating = false` at line 73)
5. `spec/models/ai_job_application_summary_status_spec.rb:23` — Task 6

**ai_job_application_summary_spec.rb — will not break:**
The existing `#destroy_previous_textract_results` test creates `AiJobApplicationSummary.create!` then calls `summary.update!(status: :succeeded)`. After the change: (1) `create_status_record` callback removed — no status record created from the summary. But the status record ALREADY EXISTS from `enqueue_new_job_application` firing on the job_application. (2) `update_summary_status_record` fires on the update and finds the status record, calling `update_columns(ai_job_application_summary_id: id, ...)` — valid FK. Test asserts `not_to raise_error` — still passes.

**Commit stage — verified:**
Stages 9 files. All are either new files (interactor, interactor spec, textract_result_spec, job_application_spec) or modified files. `spec/models/textract_result_ai_trigger_spec.rb` is correctly not staged (not modified). Correct.

---

## Findings

### MED-1: `update_columns` never returns false — `context.fail!` guard is dead code

**Location:** `FindOrCreateAiJobApplicationSummaryStatus`, `handle_existing` method, both `unless` blocks

**The issue:** Both `unless status_record.update_columns(...)` blocks assume `update_columns` can return a falsy value to trigger `context.fail!`. In Rails 6.1, `update_columns` returns an integer (the count of rows updated from the underlying `update_all` call — always 1 for a single-record update) or raises `ActiveRecord::ActiveRecordError` on failure. It NEVER returns `false`. In Ruby, `0` and `1` are both truthy. So `unless 1` and `unless 0` are both `false`, meaning `context.fail!` is unreachable via this guard.

If `update_columns` fails, it raises — which propagates up through `call()` as an unhandled exception, not a clean `context.fail!`. The analog (`FindOrCreateOrgInterviewerInvite`) uses `@invite.save` which genuinely returns `true`/`false`.

**Why it matters:** Review angle-5 (save-return-value-handling) explicitly requires checking the return value of every `save`/`update` call, per core critical rule #12. The check as written does not satisfy that requirement for `update_columns`. If a reviewer or implementer traces the code and expects `context.fail!` to fire on update failure, they will be wrong.

**Severity:** MED — not a behavioral regression against the CURRENT codebase (update_columns failures would raise anyway), but spec non-compliant per angle-5 and the analog pattern.

**Fix options:** (a) Replace `update_columns` with `update` (which does return true/false and goes through type casting) and keep the `unless` guard. (b) Remove the dead `unless...context.fail!` wrapper and accept that `update_columns` raises on error, documenting that the raise propagates. Option (a) maintains the spec's stated intent and matches the analog more closely; option (b) is simpler but abandons the spec's return-value-check requirement.

---

### LOW-1: Task 5 Step 3 grep pattern has reversed operand order

**Location:** Task 5, Step 3 verification command

**The issue:** The grep pattern is:
```
"create_status_record\|find_or_create_by.*AiJobApplicationSummaryStatus\|\.regenerating"
```
The pattern `find_or_create_by.*AiJobApplicationSummaryStatus` looks for `find_or_create_by` followed by `AiJobApplicationSummaryStatus` on the same line. But the actual code pattern is `AiJobApplicationSummaryStatus.find_or_create_by(...)` — the class name comes FIRST. The pattern would not match any of the three references being deleted if any were missed.

**Why it matters:** The grep is a verification step run AFTER deletion to confirm zero remaining references. If one of the four deletion steps was accidentally skipped, this grep would return empty anyway (because `create_status_record` catches the model references, and `find_or_create_by.*AiJobApplicationSummaryStatus` would fail to match the interactor references). The practical risk is low because the plan explicitly addresses all 4 references.

**Severity:** LOW — incorrect pattern that could mask a missed deletion, but with only 4 identified references all explicitly addressed in Tasks 4-5, the risk is minimal.

---

## Non-issues investigated

**Spec says "line 67" for early return guard; actual is line 68.** Plan correctly uses line 68. Spec had a minor inaccuracy; plan is right. Not a plan defect.

**Spec says "lines 54 and 74" for `create_ai_summary_generation.rb` deletions.** Line 74 is the closing `end` of the block that starts at line 72. Plan correctly says "lines 72-74" for the second deletion. Not a plan defect.

**Task 9 (`job_application_spec.rb`) does not include `ActiveJob::TestHelper` or override the queue adapter.** Safe: `handle_new_job_application` (called via inline `NewJobApplicationJob`) runs in other credit test specs without issue. The test does not assert on job enqueueing, only on the status record.

**`update_columns` type-casting for string enum values.** `update_columns(status: 'regenerating')` works correctly in Rails 6.1 because `update_columns` goes through type casting, and the enum type caster maps `'regenerating'` to integer `2`. The existing `update_summary_status_record` uses `update_columns(status: 'current')` with the same mechanism — confirmed working.

**Task 8 textract_result spec could trigger `queue_ai_summary_job`.** Not an issue: `create_credit_test_organization` does not enable `auto_generate_ai_summaries_enabled` (helper stubs `create_ai_credit_state_if_needed`; default is `false`). `queue_ai_summary_job` returns early at `should_auto_generate_ai_summaries?`. No job enqueued.

**Eagerly-created status record in the `'succeeded non-stale summary exists'` interactor spec context.** RSpec `before` block (which destroys the status record) runs before the inner `let!` (which creates the summary). So: (1) outer before destroys status record, (2) inner let! creates summary (no `create_status_record` callback since it's removed), (3) interactor is called with no status record and a succeeded non-stale summary → Branch 3 creates with `status: :current`. Correct.
