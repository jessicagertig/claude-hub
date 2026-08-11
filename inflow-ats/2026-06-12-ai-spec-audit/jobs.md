# Job & Webhook Specs Audit — Round 2 (5 files)

**Branch:** `UI-polishes` | **Date:** 2026-06-18
**Totals:** 23 findings (5 BLOCKER, 10 HIGH, 8 MED), 2 convention issues, 0 clean specs

## Files

| # | File | Findings | Status |
|---|------|----------|--------|
| 1 | `bulk_generate_ai_summaries_job_spec.rb` | 1H, 4M | HIGH |
| 2 | `extract_job_criteria_job_spec.rb` | 3H, 1M | HIGH |
| 3 | `generate_ai_job_application_summary_job_spec.rb` | 2B, 2H, 2M, 2C | BLOCKER |
| 4 | `get_resume_text_from_textract_job_spec.rb` | 2B, 2H | BLOCKER |
| 5 | `stripe_webhook_handler_ai_credits_spec.rb` | 1B, 2H, 1M | BLOCKER |

## Findings

### `bulk_generate_ai_summaries_job_spec.rb`

**Code under test:** `app/jobs/bulk_generate_ai_summaries_job.rb`
**File chain:** spec/jobs/bulk_generate_ai_summaries_job_spec.rb -> app/jobs/bulk_generate_ai_summaries_job.rb -> app/interactors/validate_ai_summary_generation.rb -> app/interactors/create_bulk_ai_summary_generation.rb -> app/models/bulk_ai_summary_job_application.rb -> app/models/textract_result.rb (generate_ai_summary_with_credit_flow) -> app/mailers/bulk_job_application_ai_summary_result_mailer.rb -> app/channels/global_channel.rb -> spec/support/ai_credits_test_helpers.rb

**Summary:** The spec file is well-structured and covers the primary happy paths, deferred path, short-circuit path, retry/discard behavior, on_complete broadcasting, mailer delivery chains (correctly verifying .deliver_later per Known Failure Pattern #4), and the all-failed notification path. The test helpers create realistic DB records, and stubs match the real method signatures. No ghost tests were found -- all tests exercise real production code paths and would fail if the production code were removed. However, there are coverage gaps: the validation failure path (result.success? returning false) in each_iteration has no test (HIGH), the short-circuit test omits verification of the claim row status update to :done, and the update_remaining_statuses_to_failed DB side-effect in discard_on/retry_on blocks is never verified. Several defensive guard clauses (job_application not found, user not found, empty bulk statuses) are also untested. No convention violations were found -- the spec uses bang methods appropriately per the test code exception, and follows the codebase patterns.

**F1 [MED] [Prong 2: tests what it claims] Short-circuit test does not verify the positive side-effect (claim row updated to done)**
- Location: `spec/jobs/bulk_generate_ai_summaries_job_spec.rb:72-86`
- The 'short-circuits if a completed summary already exists' test only asserts the negative (generate_ai_summary_with_credit_flow is not called). It does not verify that the claim row's status is updated to :done, which is the other half of the short-circuit logic at line 54 of the production code. The test correctly detects absence of the pipeline call, but misses verifying that the claim row transitions to :done -- a meaningful business outcome of the short-circuit path.
- Evidence: Production code at app/jobs/bulk_generate_ai_summaries_job.rb:54 does `job_application_bulk_job_status.update_columns(status: :done)` inside the `if summary_already_processed` block. The spec at line 85 calls `each_iteration` but never asserts `expect(claim_row.reload.status).to eq('done')` like the happy-path test does at line 52. If the `update_columns(status: :done)` line were deleted from production, this test would still pass.

**F2 [HIGH] [Prong 3: drift] No test for validation failure path (result.success? returns false)**
- Location: `spec/jobs/bulk_generate_ai_summaries_job_spec.rb:39-86`
- The production each_iteration at line 61 has `return unless result.success?` after calling ValidateAiSummaryGeneration. When validation fails (e.g., no credits, no resume, no job description, flipper disabled), the iteration silently returns. The spec has zero coverage for this branch. This is a significant path in production because it governs whether applicants with precondition failures are silently skipped or properly handled. The claim row remains at :processing status when validation fails, which means update_remaining_statuses_to_failed would later flip it to :failed -- a behavior not tested anywhere.
- Evidence: Production code at app/jobs/bulk_generate_ai_summaries_job.rb:59-61 calls ValidateAiSummaryGeneration.call and returns early on failure. ValidateAiSummaryGeneration has 5 distinct failure modes (nil job_application, nil organization, flipper disabled, no resume, no credits, no job description). The spec stubs ValidateAiSummaryGeneration.call to always return success in all three each_iteration tests. No test exercises the failure branch.

**F3 [MED] [Prong 3: drift] update_remaining_statuses_to_failed side-effect never verified in DB**
- Location: `spec/jobs/bulk_generate_ai_summaries_job_spec.rb:89-143`
- The discard_on and retry_on blocks both call update_remaining_statuses_to_failed(payload) (production lines 14, 19), which updates all remaining :processing rows to :failed in the database. No test verifies this DB state change. The before block stubs the mailer and GlobalChannel to prevent side effects, but update_remaining_statuses_to_failed runs a real DB query. The spec only tests that the job is or is not re-enqueued, and separately tests notify_failure -- but the status update to :failed is never asserted.
- Evidence: Production code at app/jobs/bulk_generate_ai_summaries_job.rb:175-181 runs BulkAiSummaryJobApplication.where(bulk_job_id: ..., status: :processing).update_all(status: 'failed', ...). The retry_on test (line 104) only asserts have_enqueued_job. The discard_on test (line 112) only asserts not_to have_enqueued_job. Neither checks claim_row.reload.status after the handler runs.

**F4 [MED] [Prong 3: drift] No test for job_application not found guard (return unless job_application)**
- Location: `spec/jobs/bulk_generate_ai_summaries_job_spec.rb:39-86`
- Production each_iteration line 33 has `return unless job_application` after `JobApplication.find_by(id: job_application_id)`. If the job application was deleted between enqueue and execution, the iteration silently returns. No spec tests this path. While this is a defensive guard, the spec claims to test each_iteration behavior but does not cover this early-return.
- Evidence: Production code at app/jobs/bulk_generate_ai_summaries_job.rb:32-33: `job_application = JobApplication.find_by(id: job_application_id); return unless job_application`. No spec passes a non-existent job_application_id to each_iteration.

**F5 [MED] [Prong 3: drift] No test for on_complete early returns (user not found, empty bulk_job_statuses)**
- Location: `spec/jobs/bulk_generate_ai_summaries_job_spec.rb:146-258`
- Production on_complete has two early-return guards at lines 98 and 101: `return unless user` and `return if bulk_job_statuses.empty?`. Neither is tested. If the user was deleted between enqueue and completion, on_complete silently returns without broadcasting or emailing. No spec covers this defensive behavior.
- Evidence: Production code at app/jobs/bulk_generate_ai_summaries_job.rb:97-101 has two guard clauses. All on_complete tests set up valid users and non-empty bulk_job_statuses. No test exercises the guard clause paths.

---

### `extract_job_criteria_job_spec.rb`

**Code under test:** `app/jobs/extract_job_criteria_job.rb`
**File chain:** spec/jobs/extract_job_criteria_job_spec.rb -> app/jobs/extract_job_criteria_job.rb -> app/services/ai_job_application_action/scoring/extract_criteria.rb -> app/models/ai_job_criteria.rb -> app/errors/custom_error_ai_summary.rb; spec/support/ai_credits_test_helpers.rb (test helpers)

**Summary:** The spec for ExtractJobCriteriaJob covers only two paths: the not-found guard clause and the happy-path delegation to ExtractCriteria. The production job has substantial error-handling logic that is entirely untested: (1) a retry_on exhaustion block that marks AiJobCriteria as :failed after 3 retries, (2) a rescue CustomErrorAiSummary block that re-raises to trigger retries, and (3) a rescue StandardError block that marks the record as :failed for terminal errors. All three are HIGH drift findings because these error paths are the job's primary value-add over a direct service call -- the job exists to provide retry semantics and status tracking on failure. The existing "returns silently" test has a weak assertion (only not_to raise_error) but is not a ghost, since removing the guard clause would cause the test to fail via NoMethodError. No convention issues found.

**F1 [HIGH] [Prong 3: drift] retry_on exhaustion block has no spec coverage**
- Location: `app/jobs/extract_job_criteria_job.rb:5-10`
- The job declares retry_on CustomErrorAiSummary with an exhaustion block (lines 5-10) that finds the AiJobCriteria record, updates its status to :failed, and sets error_message. This is a critical error-handling path: when the AI service fails 3 times, this block is the only thing that marks the record as failed and records why. The spec has no test for this path.
- Evidence: Production code (lines 5-10): retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3 do |job, error| ... ai_job_criteria&.update_columns(status: :failed, error_message: error&.message) end. The spec has two tests: 'returns silently' (not-found guard) and 'delegates to ExtractCriteria service' (happy path). Neither exercises the exhaustion block. A test would need to simulate 3 failed retries raising CustomErrorAiSummary and verify the record ends up with status: :failed and the error message is persisted.

**F2 [HIGH] [Prong 3: drift] rescue CustomErrorAiSummary re-raise path has no spec coverage**
- Location: `app/jobs/extract_job_criteria_job.rb:19-21`
- The perform method catches CustomErrorAiSummary (lines 19-21), logs it with ap, and re-raises to trigger retry_on. This is the mechanism that connects the service's retryable failures to the job's retry logic. The spec does not test that CustomErrorAiSummary errors propagate out of perform (which is what triggers retry_on). If someone accidentally removed the 'raise' on line 21, the error would be silently swallowed and retries would never happen.
- Evidence: Production code (lines 19-21): rescue CustomErrorAiSummary => e / ap '[ExtractJobCriteriaJob] CustomErrorAiSummary -- retrying' / ap e / raise. The spec's 'delegates to ExtractCriteria service' test stubs ExtractCriteria to do nothing (service_double receives :extract with no error). No test verifies that when ExtractCriteria raises CustomErrorAiSummary, the job re-raises it.

**F3 [HIGH] [Prong 3: drift] rescue StandardError terminal error handler has no spec coverage**
- Location: `app/jobs/extract_job_criteria_job.rb:23-28`
- The perform method catches StandardError (lines 23-28), logs the error, looks up the AiJobCriteria record fresh, and marks it as failed with the error message. This is the terminal error path for non-retryable failures. The spec has no test for this path. If this rescue block were removed, non-retryable errors would bubble up unhandled and the AiJobCriteria record would be left in an inconsistent state (no status update to :failed).
- Evidence: Production code (lines 23-28): rescue StandardError => e / Rails.logger.error ... / ap ... / ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria_id) / ai_job_criteria&.update_columns(status: :failed, error_message: e&.message). The spec has no test case that causes the service to raise a StandardError and then verifies that the AiJobCriteria record is updated to :failed.

**F4 [MED] [Prong 2: tests what it claims] Weak assertion for 'returns silently' -- only checks no error, not actual behavior**
- Location: `spec/jobs/extract_job_criteria_job_spec.rb:13-16`
- The test 'returns silently' (lines 13-16) when ai_job_criteria is not found only asserts not_to raise_error. While this does exercise the guard clause (removing it would cause NoMethodError on nil.id), the test does not verify the claimed 'silently' behavior -- it does not assert that ExtractCriteria was NOT instantiated. A more robust test would use expect(AiJobApplicationAction::Scoring::ExtractCriteria).not_to receive(:new) to confirm the service was never called.
- Evidence: Spec (lines 13-16): expect { described_class.perform_now(99_999_999) }.not_to raise_error. This passes whenever perform_now does not raise -- even if it does significant work. The context says 'when ai_job_criteria is not found' and the it says 'returns silently', but the test only verifies no exception, not that no work was done.

---

### `generate_ai_job_application_summary_job_spec.rb`

**Code under test:** `app/jobs/generate_ai_job_application_summary_job.rb`
**File chain:** spec/jobs/generate_ai_job_application_summary_job_spec.rb -> app/jobs/generate_ai_job_application_summary_job.rb -> app/models/textract_result.rb (generate_ai_summary_with_credit_flow, generate_ai_summary) -> app/services/ai_job_application_action/orchestrate.rb -> app/services/ai_job_application_action/summary/generate.rb | app/interactors/create_ai_credit_balance_transaction.rb -> app/models/ai_credit_balance_transaction.rb (counter_culture) | app/models/organization_ai_credit_balance.rb | app/channels/global_channel.rb | app/errors/custom_error_ai_summary.rb

**Summary:** The spec has two BLOCKER findings. First, the 'when org has zero credits' test (line 33-42) is a ghost test: it asserts that credits don't change, but credits don't change because the un-stubbed pipeline creates no summary (the orchestrator returns early when no AiJobApplicationSummary exists), not because of any zero-credits protection. Deleting all credit-consumption code would not change this test's outcome. Second, the 'when textract_result is not found' test (line 45-50) is a near-ghost that only asserts not_to raise_error without verifying any positive behavior. There are two HIGH drift findings: neither the retry_on CustomErrorAiSummary exhaustion block (job lines 13-22) nor the CustomErrorAiSummary re-raise path (job lines 35-38) have any test coverage, leaving critical error-recovery and retry logic unverified. Two MED findings cover dead Flipper.enable code that misleadingly suggests Flipper gating is tested, and a subtle callback-ordering dependency in the TextractResult let! creation. The credit consumption happy path (lines 53-90), failure path (lines 92-127), addon-only path (lines 129-149), and broadcast tests (lines 152-206) are sound and genuinely exercise their claimed code paths.

**F1 [BLOCKER] [Prong 1: works] Ghost test: zero-credits test passes because pipeline is a no-op, not because of any zero-credits protection**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:33-42`
- The 'when org has zero credits' context (lines 33-42) sets credits to 0 and asserts that credits don't change after calling perform_now. However, no stub is placed on generate_ai_summary, so the real pipeline code runs. The real AiJobApplicationAction::Orchestrate (line 15-16) returns early because no AiJobApplicationSummary record exists for the job_application. Since no summary is ever created, generate_ai_summary_with_credit_flow returns at line 82 (return unless ai_job_application_summary&.status_succeeded?) before reaching credit consumption. The assertion passes because the pipeline does nothing, not because zero-credits prevents consumption. If you deleted all credit-consumption code from production, this test would still pass identically.
- Evidence: Spec line 38-41: asserts not_to change total_credits_remaining. Code under test: TextractResult#generate_ai_summary (line 110) calls AiJobApplicationAction::Orchestrate. Orchestrate (line 15-16) does @ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first; return unless @ai_job_application_summary -- returns nil because no summary exists. Back in generate_ai_summary_with_credit_flow (line 77-82), ai_job_application_summary is nil, so it returns before reaching CreateAiCreditBalanceTransaction.call at line 84. Credits never change because the pipeline never creates a summary, not because of any zero-credits guard.

**F2 [BLOCKER] [Prong 1: works] Near-ghost test: textract_result not found test only asserts not_to raise_error**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:45-50`
- The 'when textract_result is not found' test (lines 45-50) calls perform_now with a nonexistent ID and asserts only not_to raise_error. This verifies that the guard clause (return unless textract_result at line 30 of the job) prevents a crash, but asserts no positive behavior. Per audit methodology, tests that only assert not_to raise_error are near-ghosts.
- Evidence: Spec line 47-49: expect { described_class.perform_now(textract_result_id: 99_999_999) }.not_to raise_error. Production code line 30: return unless textract_result. The test does exercise the guard (deleting the guard would cause NoMethodError), but it verifies only absence of error, not that the job correctly short-circuits without side effects (no summary created, no credit consumed, no broadcast sent).

**F3 [HIGH] [Prong 3: drift] No coverage for retry_on CustomErrorAiSummary exhaustion block**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:13-22 (retry_on exhaustion block not tested)`
- The job defines retry_on CustomErrorAiSummary with a 3-attempt exhaustion block (lines 13-22 of the job). The exhaustion block marks the summary as failed and calls broadcast_completion. No test exercises this path. The exhaustion block contains non-trivial logic: it accesses job.arguments.first[:textract_result_id], finds the textract_result, updates the summary status to failed, and broadcasts completion. This is a critical error-recovery path with no spec coverage.
- Evidence: Job lines 13-22: retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3 do |job, error| ... ai_summary&.update_columns(status: :failed, error_message: error&.message); broadcast_completion(textract_result, job.arguments.first[:requesting_organization_user_id]) end. No it block in the spec exercises CustomErrorAiSummary at all.

**F4 [HIGH] [Prong 3: drift] No coverage for CustomErrorAiSummary re-raise path in perform**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:35-38 (rescue CustomErrorAiSummary not tested)`
- The job's perform method has a rescue CustomErrorAiSummary block (lines 35-38 of the job) that logs and re-raises the error for retry_on to handle. No test verifies that CustomErrorAiSummary errors are re-raised (allowing retries) while StandardError errors are swallowed (preventing retries). This distinction is critical: if the re-raise were removed, CustomErrorAiSummary would be caught by the StandardError rescue below it and the job would never retry.
- Evidence: Job lines 35-38: rescue CustomErrorAiSummary => e; ap ...; raise. Job lines 39-45: rescue StandardError => e (no raise). The spec has no test that verifies CustomErrorAiSummary is re-raised vs StandardError being swallowed.

**F5 [MED] [Prong 3: drift] Flipper.enable is dead code in this spec -- neither the job nor generate_ai_summary_with_credit_flow check it**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:28-30`
- The spec enables Flipper flag :AI_APPLICANT_SUMMARY at line 29. However, neither GenerateAiJobApplicationSummaryJob#perform nor TextractResult#generate_ai_summary_with_credit_flow check this Flipper flag. The flag is checked only in ValidateAiSummaryGeneration (called from the queue_ai_summary_job callback, not from the direct perform path). The Flipper enable is vestigial from when the job or credit flow had a Flipper gate, and creates a misleading impression that Flipper gating is being tested.
- Evidence: Spec line 29: Flipper.enable(:AI_APPLICANT_SUMMARY, organization). grep for Flipper in app/jobs/generate_ai_job_application_summary_job.rb: zero results. grep for Flipper in app/models/textract_result.rb: zero results. The flag is only checked in app/interactors/validate_ai_summary_generation.rb:66 and app/models/job.rb:689, neither of which is in the perform_now call path.

**F6 [MED] [Prong 2: tests what it claims] TextractResult let! creation fires queue_ai_summary_job callback, potentially enqueuing a second job**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:18-26`
- The let!(:textract_result) at line 18 creates a TextractResult with textract_job_result_text set. TextractResult has after_commit :queue_ai_summary_job on [:create, :update]. This callback checks saved_change_to_textract_job_result_text? (true) and then checks should_auto_generate_ai_summaries? and ValidateAiSummaryGeneration. With the test queue adapter, any enqueued job just queues without executing. But the callback fires before the Flipper.enable at line 29, so ValidateAiSummaryGeneration would fail (Flipper not enabled). This is not a bug but creates a subtle ordering dependency that could break if the Flipper enable were moved before the let!.
- Evidence: TextractResult line 7: after_commit :queue_ai_summary_job, on: [:create, :update]. Let! at spec line 18 runs before the before block at line 28. The callback at textract_result.rb line 114-143 fires during creation but the test queue adapter prevents actual execution.

**C1 [Convention] cursor_rules/backend/background_jobs.md (not a direct rule violation, but a pattern note)**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:60,100,133,168,190,197`
- The spec uses allow_any_instance_of throughout (lines 60, 100, 133, 168, 190, 197). While not prohibited by cursor_rules, allow_any_instance_of is widely considered an RSpec anti-pattern because it is fragile, deprecated in newer RSpec versions, and doesn't verify which specific instance receives the call. The spec could use allow(textract_result).to receive(:generate_ai_summary) for the #perform tests and allow(textract).to receive(:generate_ai_summary_with_credit_flow) for the broadcast tests, which would be more precise.

**C2 [Convention] cursor_rules/backend/_base.md (organization callback suppression)**
- Location: `spec/jobs/generate_ai_job_application_summary_job_spec.rb:19`
- Line 19 uses Organization.skip_callback(:commit, :after, :complete_setup_workers, raise: false). The test helpers at spec/support/ai_credits_test_helpers.rb already handle this via define_singleton_method on each test org instance (line 56). The skip_callback at line 19 is redundant and operates at the class level, which can leak across tests. The comment says 'noop in case' suggesting the author was uncertain whether it was needed.

---

### `get_resume_text_from_textract_job_spec.rb`

**Code under test:** `app/jobs/get_resume_text_from_textract_job.rb`
**File chain:** spec/jobs/get_resume_text_from_textract_job_spec.rb -> app/jobs/get_resume_text_from_textract_job.rb -> app/services/get_resume_text_from_textract.rb, app/models/textract_result.rb (broadcast_ai_summary_failed), app/models/ai_job_application_summary.rb, app/errors/custom_error_textract.rb

**Summary:** The spec file covers only `cleanup_orphaned_summary`, a class method that serves as the retry exhaustion handler. The three tests that exercise actual behavior (destroy with broadcast, destroy without broadcast for auto-generated summaries) are well-constructed and not ghosts. However, two tests (lines 52-56 and 79-84) are near-ghosts that only assert `not_to raise_error` on guard clause paths without verifying any behavioral outcome. The spec has two significant drift gaps: zero coverage for the `perform` method (the job's primary entry point, which delegates to GetResumeTextFromTextract) and zero coverage for the `retry_on` exhaustion block wiring that connects CustomErrorTextract retries to cleanup_orphaned_summary. The code under test's production shape is considerably larger than what the spec exercises.

**F1 [BLOCKER] [Prong 1: works] Near-ghost: 'when no textract_processing summary exists' only asserts not_to raise_error**
- Location: `spec/jobs/get_resume_text_from_textract_job_spec.rb:52-56`
- The test 'does not raise' in the 'when no textract_processing summary exists' context only asserts `not_to raise_error` without verifying any behavior. It does not assert that no summary was destroyed or that no broadcast was sent. If the production code's guard clause at line 16 of get_resume_text_from_textract_job.rb was removed and the method proceeded past the nil summary (causing an error on `summary.requested_by_organization_user_id`), the test would still tell you something is wrong -- but if the production code was replaced with a no-op or the guard clause logic changed to silently proceed with wrong behavior, this test would not catch it.
- Evidence: Spec lines 52-56: `expect { described_class.cleanup_orphaned_summary(job_application.id) }.not_to raise_error`. Production code lines 14-16 have a guard clause `return unless summary` after `find_by(status: :textract_processing, stale: false)`. The test verifies the guard does not raise but does not verify the method's actual no-op behavior (no destruction, no broadcast). A meaningful test would add `expect(GlobalChannel).not_to receive(:broadcast_to)` and assert no summaries are destroyed.

**F2 [BLOCKER] [Prong 1: works] Near-ghost: 'when job_application does not exist' only asserts not_to raise_error**
- Location: `spec/jobs/get_resume_text_from_textract_job_spec.rb:79-84`
- The test 'does not raise' in the 'when job_application does not exist' context only asserts `not_to raise_error` without verifying any behavior. It checks that passing a non-existent job_application_id (99_999_999) does not raise, verifying the `find_by` + guard clause at lines 11-12 of the production code. But it does not assert that no summary is destroyed or no broadcast is sent.
- Evidence: Spec lines 79-84: `expect { described_class.cleanup_orphaned_summary(99_999_999) }.not_to raise_error`. Production code lines 11-12: `job_application = JobApplication.find_by(id: job_application_id); return unless job_application`. The test verifies graceful handling of a missing record but does not verify that no side effects occur. A meaningful test would add `expect(GlobalChannel).not_to receive(:broadcast_to)` and assert no AiJobApplicationSummary records are destroyed.

**F3 [HIGH] [Prong 3: drift] Zero coverage for the perform method**
- Location: `spec/jobs/get_resume_text_from_textract_job_spec.rb (entire file)`
- The spec file only tests `cleanup_orphaned_summary` (the retry exhaustion handler). The `perform` method at lines 25-31 of the production code, which is the job's primary entry point, has no test coverage at all. perform instantiates GetResumeTextFromTextract and calls parse_resume_text. The service handles multiple code paths (job not found, no textract result, nil textract_job_id, succeeded/failed/other status, InvalidJobIdException rescue). None of these are exercised by the spec.
- Evidence: Production code lines 25-28: `def perform(job_application_id) textract_service = GetResumeTextFromTextract.new(job_application_id); textract_service.parse_resume_text; end`. The spec has no `describe '#perform'` or `describe '.perform'` block. grep for 'perform' in the spec returns zero results.

**F4 [HIGH] [Prong 3: drift] Zero coverage for retry_on exhaustion block wiring**
- Location: `spec/jobs/get_resume_text_from_textract_job_spec.rb (entire file)`
- The production code has `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3 do |job, _error| cleanup_orphaned_summary(job.arguments.first) end` at lines 6-8. The spec tests cleanup_orphaned_summary directly as a class method, but never tests that the retry exhaustion block actually calls it with the correct argument. If someone changed the exhaustion block to call a different method or pass incorrect arguments, no test would break.
- Evidence: Production code lines 6-8 define the retry_on exhaustion block that wires cleanup_orphaned_summary to job retry exhaustion. The spec has no test that exercises the retry_on configuration (e.g., by performing the job 3 times with CustomErrorTextract and verifying the exhaustion block fires). The spec only tests cleanup_orphaned_summary in isolation.

---

### `stripe_webhook_handler_ai_credits_spec.rb`

**Code under test:** `app/jobs/stripe_webhook_handler_job.rb`
**File chain:** spec/jobs/stripe_webhook_handler_ai_credits_spec.rb -> app/jobs/stripe_webhook_handler_job.rb -> app/interactors/apply_ai_credit_purchase.rb -> app/models/organization_ai_credit_purchase.rb -> app/models/organization_ai_credit_balance.rb -> app/models/ai_credit_balance_transaction.rb -> spec/support/ai_credits_test_helpers.rb

**Summary:** The spec has one BLOCKER and two HIGH findings. The BLOCKER is that test 3 ('grants subscription credits via renewal path') is fundamentally broken: the invoice double does not stub 'lines', so when ApplyAiCreditPurchase#apply_subscription accesses invoice.lines.data.first&.period, an RSpec::Mocks::MockExpectationError (which inherits from Exception, not StandardError) is raised and crashes the test. This was verified by checking the MockExpectationError class hierarchy (inherits from Exception) and confirming that no rescue block in the production code catches Exception-level errors. The related HIGH finding is that even if the stub were added, the test makes no assertion on the period fields that apply_subscription updates, leaving that behavior untested. The second HIGH finding is that the charge.refunded handler -- an AI credit feature path that calls handle_charge_refunded and dispatches to ApplyAiCreditRefund -- has zero coverage in this spec despite the spec claiming to cover AI credit routing extensions. Tests 1, 2, and 4 are structurally sound: they exercise production code paths, their stubs match production method signatures, and their assertions verify real behavior changes (purchase linking, balance increment, idempotency). No cursor_rules convention violations apply since _base.md explicitly excludes spec/ files.

**F1 [BLOCKER] [Prong 1: works] Test 3 crashes: invoice double missing 'lines' stub causes MockExpectationError**
- Location: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb:110-118`
- The 'grants subscription credits via renewal path' test creates an invoice double at lines 110-118 without stubbing 'lines'. The production flow is: handle_subscription_credit_pack_invoice_paid (line 443) calls ApplyAiCreditPurchase.call(invoice: invoice, ..., kind: :subscription). Inside apply_subscription (apply_ai_credit_purchase.rb:98), invoice.lines.data.first&.period is accessed. Calling .lines on an RSpec double that doesn't have it stubbed raises RSpec::Mocks::MockExpectationError, which inherits from Exception (not StandardError). None of the rescue blocks in the production code (Stripe::StripeError, ActiveRecord::RecordInvalid, StandardError) catch Exception subclasses. The Interactor gem's run! method has a bare rescue that catches it, but only to call context.rollback! and re-raise. The exception propagates through the entire call stack and the test crashes rather than making any assertion.
- Evidence: Invoice double (spec line 110-118): double('invoice', id: 'in_test_renewal', customer: ..., subscription: ..., amount_paid: 2900, currency: 'usd', metadata: {}). No 'lines' method stubbed. Production code at apply_ai_credit_purchase.rb:98: period = invoice.lines.data.first&.period. Verified via ruby -e that calling unstubbed method on double() raises RSpec::Mocks::MockExpectationError (inherits from Exception, not StandardError). This makes the entire test non-functional.

**F2 [HIGH] [Prong 2: tests what it claims] Test 3 stubs Stripe::Subscription.retrieve but does not stub invoice.lines, creating a signature mismatch with ApplyAiCreditPurchase#apply_subscription**
- Location: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb:82-129`
- Even if the missing 'lines' stub were fixed, the test has a deeper stub-vs-production mismatch. The production ApplyAiCreditPurchase#apply_subscription method at line 98 accesses invoice.lines.data.first&.period to extract period.start and period.end for updating subscription_current_period_start/end on the purchase record. The test provides no mechanism for this data to flow through. If 'lines' were stubbed to return nil-safe data, the test would need to also verify that the period fields get updated on the purchase -- which it currently does not assert. The test only checks addon_subscription_credits_remaining, so even with a fix, the period-update behavior of the subscription path is entirely untested.
- Evidence: Production code apply_ai_credit_purchase.rb:98-103: period = invoice.lines.data.first&.period; existing.update(subscription_current_period_start: period && Time.at(period.start).to_datetime, subscription_current_period_end: period && Time.at(period.end).to_datetime). Test assertion at spec line 125-127 only checks: change { organization.organization_ai_credit_balance.reload.addon_subscription_credits_remaining }.by(50). No assertion on subscription_current_period_start/end.

**F3 [HIGH] [Prong 3: drift] charge.refunded AI credit path has zero test coverage**
- Location: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb (entire file)`
- The production code at stripe_webhook_handler_job.rb lines 266-270 handles 'charge.refunded' events by calling handle_charge_refunded (lines 403-429), which looks up an OrganizationAiCreditPurchase via the payment intent's invoice or checkout session and calls ApplyAiCreditRefund.call(purchase: purchase). This is an AI credit feature path (refund handling) but has no test in this spec. The spec header comment says it covers 'AI credit pack routing extensions on StripeWebhookHandlerJob' but the refund routing extension is completely missing. handle_charge_refunded has two sub-branches (invoice-based lookup for subscriptions, session-based lookup for one-offs) and a guard clause -- none are exercised.
- Evidence: Production code at stripe_webhook_handler_job.rb:266-270: when 'charge.refunded' -> handle_charge_refunded(charge). Method handle_charge_refunded at lines 403-429 routes to ApplyAiCreditRefund.call. No 'charge.refunded' describe/context block exists in the spec file. grep for 'charge.refunded' or 'handle_charge_refunded' or 'ApplyAiCreditRefund' in the spec returns zero hits.

**F4 [MED] [Prong 2: tests what it claims] Invoice doubles stub 'amount_total' which is never accessed by production code**
- Location: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb:58,146`
- Tests 2 and 4 stub amount_total: 1500 on the invoice doubles (lines 58 and 146). The production code never accesses object.amount_total -- it uses object.amount_paid (line 196 for the top_up branch, line 439 for the subscription branch). The stale stub is harmless but misleading -- it suggests the production code uses amount_total, which it does not. This could mask a future refactoring error if someone changes the production code to use amount_total and assumes it's already tested.
- Evidence: Spec line 58: amount_total: 1500 (test 2 invoice double). Spec line 146: amount_total: 1500 (test 4 invoice double). grep 'amount_total' app/jobs/stripe_webhook_handler_job.rb returns zero hits. Production code uses object.amount_paid at line 196.

---
