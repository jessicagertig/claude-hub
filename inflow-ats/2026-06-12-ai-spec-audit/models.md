# Model Specs Audit — Round 2 (12 files)

**Branch:** `UI-polishes` | **Date:** 2026-06-18
**Totals:** 31 findings (2 BLOCKER, 5 HIGH, 24 MED), 2 convention issues, 1 clean specs

## Files

| # | File | Findings | Status |
|---|------|----------|--------|
| 1 | `ai_credit_balance_transaction_spec.rb` | 1M | MED |
| 2 | `ai_job_application_summary_spec.rb` | 1B, 2H, 1M | BLOCKER |
| 3 | `ai_job_application_summary_status_spec.rb` | 1H, 1M | HIGH |
| 4 | `ai_job_criteria_spec.rb` | 1B, 1H, 2M | BLOCKER |
| 5 | `job_ai_settings_spec.rb` | 0 | CLEAN |
| 6 | `job_criteria_lifecycle_spec.rb` | 4M | MED |
| 7 | `organization_ai_credit_balance_spec.rb` | 3M, 1C | MED |
| 8 | `organization_ai_credit_purchase_spec.rb` | 4M | MED |
| 9 | `organization_ai_credits_lifecycle_spec.rb` | 3M | MED |
| 10 | `organization_ai_credits_spec.rb` | 2M | MED |
| 11 | `textract_result_ai_trigger_spec.rb` | 1H, 2M | HIGH |
| 12 | `job_application_ai_summary_status_spec.rb` | 1M, 1C | MED |

## Findings

### `ai_credit_balance_transaction_spec.rb`

**Code under test:** `app/models/ai_credit_balance_transaction.rb`
**File chain:** spec/models/ai_credit_balance_transaction_spec.rb -> app/models/ai_credit_balance_transaction.rb -> app/models/organization_ai_credit_balance.rb -> spec/support/ai_credits_test_helpers.rb -> db/schema.rb (ai_credit_balance_transactions table, organization_ai_credit_balances table)

**Summary:** This spec is in good shape. It covers all associations, both enums (with exact value matching), counter_culture cache maintenance for the two most common buckets (monthly and addon), the insert-only readonly enforcement via before_update and before_destroy callbacks, and the custom entry_type_and_amount_valid validation for both debit-positive and credit-negative mismatch cases. No ghost tests detected -- every test block would fail if the corresponding production code were removed. No stubs are used anywhere in the spec, eliminating stub-mismatch risk entirely. The only gap is a minor coverage miss: the 'validations' describe block tests amount presence but omits entry_type and bucket presence validations (both also declared on the model). No convention violations found.

**F1 [MED] [Prong 3: drift] Missing validation coverage for entry_type and bucket presence**
- Location: `spec/models/ai_credit_balance_transaction_spec.rb:79-85`
- The 'validations' describe block only tests 'validates :amount, presence: true'. The model also has 'validates :entry_type, presence: true' (line 44) and 'validates :bucket, presence: true' (line 45), neither of which has a dedicated test. These are simple presence validations and unlikely to regress, but the spec's 'validations' block implies it covers all validations when it covers only one of three.
- Evidence: Spec line 79-85: the 'validations' describe block contains a single test 'requires amount'. Production code lines 43-45: three presence validations exist (amount, entry_type, bucket). The spec covers 1 of 3 presence validations.

---

### `ai_job_application_summary_spec.rb`

**Code under test:** `app/models/ai_job_application_summary.rb`
**File chain:** spec/models/ai_job_application_summary_spec.rb -> app/models/ai_job_application_summary.rb -> app/channels/job_channel.rb (broadcast_to) -> app/models/ai_job_application_summary_status.rb (companion record) -> app/models/job_application.rb (associations: textract_results, ai_job_application_summary_status) -> spec/support/ai_credits_test_helpers.rb (test helpers)

**Summary:** The AiJobApplicationSummary model spec has a BLOCKER drift finding: the broadcast_status_change payload was extended in production (commit 7ed61cd3b added aiJobApplicationSummaryId to the payload hash) but the spec was never updated. Since RSpec's with matcher does exact hash comparison, all 8 BROADCAST_STATUSES tests will fail with an argument mismatch. Beyond this, the spec has significant coverage gaps: the update_summary_status_record after_commit callback (which denormalizes data into the companion status record and broadcasts ai_summary_succeeded) has zero test coverage anywhere in the codebase, and the destroy_previous_textract_results section only tests the nil-guard edge case without testing the actual destruction behavior. The three public aggregation methods and the latest scope are also untested. No convention issues were found -- the spec follows cursor_rules patterns appropriately (bang methods in specs are allowed, single quotes are used correctly, variable naming is acceptable).

**F1 [BLOCKER] [Prong 3: drift] broadcast_status_change payload drifted -- spec will FAIL**
- Location: `spec/models/ai_job_application_summary_spec.rb:41-45`
- The broadcast_status_change tests expect the payload to be { jobApplicationId: job_application.id } but the production code (line 102 of the model) now sends { jobApplicationId: job_application.id, aiJobApplicationSummaryId: id }. The aiJobApplicationSummaryId key was added in commit 7ed61cd3b after the spec was last updated at 56d4ed882. RSpec's with matcher does exact hash comparison, so every test iterating over BROADCAST_STATUSES (8 tests) will FAIL because the expected payload is a strict subset of what is actually passed.
- Evidence: Spec lines 41-45 expect: expect(JobChannel).to receive(:broadcast_to).with(job_record, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id }). Production code line 102: JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id, aiJobApplicationSummaryId: id }). The payload hash has an extra key aiJobApplicationSummaryId that the spec does not expect. git log shows this was added in 7ed61cd3b but the spec was not updated.

**F2 [HIGH] [Prong 3: drift] update_summary_status_record callback has zero test coverage**
- Location: `app/models/ai_job_application_summary.rb:57-93`
- The update_summary_status_record after_commit callback (lines 57-93 of the model) is completely untested. This callback denormalizes score_percentage, headline, and integrated_role_analysis into the companion AiJobApplicationSummaryStatus record and broadcasts an ai_summary_succeeded event to JobChannel. No spec in the entire spec/ directory references update_summary_status_record or ai_summary_succeeded. This is a significant data-integrity and real-time-update code path with no coverage.
- Evidence: grep -rn 'update_summary_status_record' spec/ returns zero results. grep -rn 'ai_summary_succeeded' spec/ returns zero results. The callback runs on every update that transitions status to succeeded, updating 5 columns on the companion record and broadcasting a WebSocket event.

**F3 [HIGH] [Prong 3: drift] destroy_previous_textract_results only tests nil guard, not destruction behavior**
- Location: `spec/models/ai_job_application_summary_spec.rb:88-92`
- The only test for destroy_previous_textract_results (lines 88-92) asserts not_to raise_error when textract_result_id is nil. This verifies the nil guard clause but does not test the actual destruction behavior: when textract_result IS present and status transitions to succeeded, older non-succeeded textract results should be destroyed. The primary behavior of this callback is untested.
- Evidence: Spec line 88-92: expect { summary.update!(status: :succeeded) }.not_to raise_error. Production code lines 47-55: when textract_result is present and status changes to succeeded, it queries job_application.textract_results.where('created_at < ?', textract_result.created_at).where.not(textract_job_status: :succeeded).destroy_all. No test creates a textract_result and verifies the destruction query runs or that old results are removed.

**F4 [MED] [Prong 3: drift] No test coverage for total_input_tokens, total_output_tokens, total_cost, or latest scope**
- Location: `app/models/ai_job_application_summary.rb:33-43`
- The model defines three public methods (total_input_tokens, total_output_tokens, total_cost) and one scope (latest). None of these have any test coverage in this spec or anywhere in the spec directory. These are simple aggregation methods but they are part of the model's public interface.
- Evidence: grep -rn 'total_input_tokens|total_output_tokens|total_cost' spec/ returns zero results. The model defines total_input_tokens (line 33), total_output_tokens (line 37), total_cost (line 41), and scope :latest (line 27). The spec only tests status enum, broadcast_status_change, and destroy_previous_textract_results.

---

### `ai_job_application_summary_status_spec.rb`

**Code under test:** `app/models/ai_job_application_summary_status.rb`
**File chain:** spec/models/ai_job_application_summary_status_spec.rb -> app/models/ai_job_application_summary_status.rb -> app/models/job_application.rb (belongs_to, has_one), app/models/ai_job_application_summary.rb (belongs_to optional, has_one back-ref), app/interactors/find_or_create_ai_job_application_summary_status.rb (creates records via callback), spec/support/ai_credits_test_helpers.rb (test helpers), db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb (schema)

**Summary:** The spec file is small (29 lines) and covers the basics: uniqueness validation on job_application_id, default status of 'none', and default nil for ai_job_application_summary_id. All three tests are genuine (not ghosts) -- they exercise real production code through the after_commit callback chain that creates the status record via FindOrCreateAiJobApplicationSummaryStatus. However, the spec has drifted from the code under test in terms of coverage completeness. The model's five score-band scopes (poor, weak, mixed, good, excellent) on lines 18-22 are actively used in production by JobApplication.fit_bands but have zero test coverage (HIGH). These scopes use an unusual beginless-range + where.not pattern where boundary bugs are easy to introduce. Additionally, three of four enum values (initial_summary_pending, current, regenerating) are untested despite being set by multiple production code paths (MED). No convention violations were found -- the spec follows cursor_rules patterns correctly for what it does test.

**F1 [HIGH] [Prong 3: drift] Five production-active score band scopes have zero test coverage**
- Location: `spec/models/ai_job_application_summary_status_spec.rb (entire file) vs app/models/ai_job_application_summary_status.rb:18-22`
- The model defines five scopes (poor, weak, mixed, good, excellent) on lines 18-22 that partition score_percentage into bands using range queries with where.not chaining. These scopes are actively used in production: JobApplication.fit_bands (app/models/job_application.rb:105-108) calls them via public_send to filter job applications by score band. The spec tests none of these scopes. The scopes use an unusual pattern (beginless ranges like ..20 combined with where.not) where boundary conditions (0, 20, 40, 60, 80, 100, nil) are easy to get wrong. A boundary bug would silently misclassify candidates in the UI.
- Evidence: Production code at app/models/ai_job_application_summary_status.rb:18-22 defines: scope :poor -> where(score_percentage: ..20), scope :weak -> where(score_percentage: ..40).where.not(score_percentage: ..20), etc. These are consumed at app/models/job_application.rb:107 via AiJobApplicationSummaryStatus.public_send(k) in the fit_bands scope. The spec file has no test for any of these scopes.

**F2 [MED] [Prong 3: drift] Enum values initial_summary_pending, current, and regenerating have no spec coverage**
- Location: `spec/models/ai_job_application_summary_status_spec.rb (entire file) vs app/models/ai_job_application_summary_status.rb:7-13`
- The model defines a status enum with four values (none: 0, initial_summary_pending: 1, current: 2, regenerating: 3) with _prefix: true, generating predicate methods like status_none?, status_initial_summary_pending?, status_current?, status_regenerating?. The spec only tests the 'none' default. The other three values are used in production: initial_summary_pending is set by TextractResult#set_initial_summary_pending (app/models/textract_result.rb:106), current is set by AiJobApplicationSummary#update_summary_status_record (app/models/ai_job_application_summary.rb:76), and regenerating is set by FindOrCreateAiJobApplicationSummaryStatus (app/interactors/find_or_create_ai_job_application_summary_status.rb:15). No spec verifies enum transitions or the _prefix predicate methods.
- Evidence: Production code at app/models/ai_job_application_summary_status.rb:7-13 defines enum status: { none: 0, initial_summary_pending: 1, current: 2, regenerating: 3 }, _prefix: true. The spec only tests status 'none' at line 20: expect(status_record.status).to eq('none'). The other three enum values and their predicate methods are untested despite being set by production callbacks and interactors.

---

### `ai_job_criteria_spec.rb`

**Code under test:** `app/models/ai_job_criteria.rb`
**File chain:** spec/models/ai_job_criteria_spec.rb -> app/models/ai_job_criteria.rb -> app/models/job.rb (has_many :ai_job_application_summaries through :job_applications) -> app/models/ai_job_application_summary.rb -> app/jobs/generate_ai_job_application_summary_job.rb -> spec/support/ai_credits_test_helpers.rb

**Summary:** The spec has one BLOCKER and one HIGH finding. The HIGH finding is a hard drift: the status enum assertion at line 19-27 expects only 4 values but the production code now has 5 (retrying: 4 was added later), which means this test will actually FAIL when run. The BLOCKER is a near-ghost test at line 95-101 that only asserts not_to raise_error for the "no waiting summaries" context -- this assertion would pass identically if the callback were deleted entirely, providing zero behavioral coverage. Two MED findings note missing association coverage for has_many :ai_api_requests and missing validation coverage for validates :status, presence: true. The callback tests for the succeeded and failed paths (lines 39-93) are well-constructed and genuinely exercise the production code through the ActiveJob test adapter.

**F1 [HIGH] [Prong 3: drift] Enum assertion missing retrying status -- test will FAIL**
- Location: `spec/models/ai_job_criteria_spec.rb:19-27`
- The 'has all four values' test asserts that described_class.statuses equals a hash with only 4 entries (pending, in_progress, succeeded, failed). The production code at app/models/ai_job_criteria.rb:7-13 has 5 enum values including retrying: 4, added in commit 78d68c35e. This assertion will fail when run because the actual hash includes 'retrying' => 4, which is not present in the expected hash. The test title also says 'four values' when there are now five.
- Evidence: Spec line 20-26 asserts: {'pending' => 0, 'in_progress' => 1, 'succeeded' => 2, 'failed' => 3}. Code under test at ai_job_criteria.rb:7-13 has enum status: {pending: 0, in_progress: 1, succeeded: 2, failed: 3, retrying: 4}. Git history confirms retrying was added in 78d68c35e after the spec was written in 9a6bde410. The spec was never updated.

**F2 [BLOCKER] [Prong 1: works] Near-ghost test: 'does not raise' asserts nothing about behavior**
- Location: `spec/models/ai_job_criteria_spec.rb:95-101`
- The test 'does not raise' at line 98-99 only asserts not_to raise_error on an update call. This would pass identically whether the resume_waiting_summaries callback exists, is deleted, or does anything at all. The update itself does not raise -- the assertion is on the update operation, not on the callback behavior. A meaningful test for this context (no waiting summaries) would assert not_to have_enqueued_job(GenerateAiJobApplicationSummaryJob), verifying that the callback runs but correctly enqueues nothing.
- Evidence: Spec line 98-99: expect { ai_job_criteria.update!(status: :succeeded, criteria: [], metadata: {}) }.not_to raise_error. If resume_waiting_summaries were deleted from the model, the test still passes because update! on a valid record does not raise. The only behavioral assertion this context should make is that no job is enqueued, which would be: expect { ... }.not_to have_enqueued_job(GenerateAiJobApplicationSummaryJob).

**F3 [MED] [Prong 2: tests what it claims] Association test does not cover has_many :ai_api_requests**
- Location: `spec/models/ai_job_criteria_spec.rb:29-34`
- The describe 'associations' block at line 29-34 only tests belongs_to :job. The model also has has_many :ai_api_requests, as: :requestable (polymorphic) at line 5, which is not tested. While association tests are not strictly required, having an 'associations' describe block that only tests one of two associations is misleading about coverage.
- Evidence: Spec lines 29-34 test only belongs_to :job. Code under test at ai_job_criteria.rb:5 declares has_many :ai_api_requests, as: :requestable, which is not exercised anywhere in the spec.

**F4 [MED] [Prong 2: tests what it claims] No coverage for validates :status, presence: true**
- Location: `spec/models/ai_job_criteria_spec.rb:36-102`
- The model declares validates :status, presence: true at line 15 of ai_job_criteria.rb. The spec has no test for this validation. While the enum implicitly handles status values, a presence validation ensures the attribute cannot be nil. This is not covered.
- Evidence: Code under test at ai_job_criteria.rb:15 has validates :status, presence: true. No test in the spec checks that creating/updating an AiJobCriteria without a status raises a validation error.

---

### `job_ai_settings_spec.rb`

**Code under test:** `app/models/job.rb`
**File chain:** spec/models/job_ai_settings_spec.rb -> app/models/job.rb (should_auto_generate_ai_summaries? at line 914, enum auto_generate_ai_summaries at line 159) -> app/models/organization.rb (auto_generate_ai_summaries_enabled at line 965, update_settings at line 1298) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization, create_credit_test_job)

**Summary:** This spec is clean. It covers all three branches of the `should_auto_generate_ai_summaries?` method on the Job model: (1) `:enabled` returns true regardless of org setting, (2) `:disabled` returns false regardless of org setting, (3) `:default` delegates to the organization's `auto_generate_ai_summaries_enabled` JSONB setting. The spec also covers the edge case where the JSONB key is missing (returns nil/falsy). No stubs are used -- the spec exercises real production code paths through database records. No ghost tests detected: every `it` block calls the production method directly and would fail with NoMethodError if the method were deleted. No drift detected: the spec's test cases match all conditional branches in the production code (lines 914-922 of job.rb). Assertions are precise -- `be true` and `be false` for explicit boolean returns, `be_falsy` for the nil-from-missing-key case. The test helper creates organizations with stubbed-out setup callbacks (complete_setup_workers and create_ai_credit_state_if_needed) to avoid side effects, then explicitly sets the settings needed via update_settings, which correctly converts symbol keys to string keys matching the JSONB dig path.

No findings.

### `job_criteria_lifecycle_spec.rb`

**Code under test:** `app/models/job.rb`
**File chain:** spec/models/job_criteria_lifecycle_spec.rb -> app/models/job.rb (extract_job_criteria, description_meaningfully_changed?, handle_description_change at lines 688-718) -> app/models/ai_job_criteria.rb (enum status, has_one association) -> app/jobs/extract_job_criteria_job.rb -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization, create_credit_test_job)

**Summary:** The spec is structurally sound with no ghost tests and no stubs to drift. All test assertions exercise real production code against the database. The Flipper disable approach (boolean gate disable) was verified correct for Flipper 0.21.0 -- the memory adapter's disable for a boolean gate calls clear(), which removes all gate values including actor gates. Four MED findings: (1) the test at line 42 is described as testing a "2-minute delay" but exercises the new-criteria path which has no delay; (2) the retrying status (added in a later commit) has no corresponding test context; (3) handle_description_change (the before_update callback that triggers criteria extraction on description changes) is not tested anywhere; (4) the existing-criteria tests that DO exercise the delayed enqueue path do not verify the delay. No convention violations were found -- the spec follows project patterns correctly (bang methods in specs are allowed per core_critical_rules.md rule 11, ActiveJob test adapter is properly managed).

**F1 [MED] [Prong 2: tests what it claims] Test description claims 2-minute delay but code path has no delay**
- Location: `spec/models/job_criteria_lifecycle_spec.rb:42`
- The it block is named 'enqueues ExtractJobCriteriaJob with 2-minute delay' but this test is in the 'when no existing criteria' context (line 33). The production code at job.rb:702 uses plain perform_later (no delay) for newly created criteria. The 2-minute delay (set(wait: 2.minutes)) only exists at job.rb:697, which is the existing-criteria branch. The assertion itself (have_been_enqueued.with) does not verify any delay, so the test passes -- but the description is misleading and does not match the code path being exercised.
- Evidence: Spec line 42: it 'enqueues ExtractJobCriteriaJob with 2-minute delay'. Production code job.rb:698-702 (new criteria path): 'ExtractJobCriteriaJob.perform_later(ai_job_criteria.id)' -- no set(wait:). The delayed enqueue is at job.rb:697 (existing criteria path): 'ExtractJobCriteriaJob.set(wait: 2.minutes).perform_later(ai_job_criteria.id)'.

**F2 [MED] [Prong 3: drift] No test for retrying status (AiJobCriteria enum value 4)**
- Location: `spec/models/job_criteria_lifecycle_spec.rb:60-89`
- AiJobCriteria has 5 enum values: pending(0), in_progress(1), succeeded(2), failed(3), retrying(4). The spec tests pending, in_progress, succeeded, and failed but has no test for retrying. The retrying status was added in commit 78d68c35e (after the spec was first written). In the extract_job_criteria method, retrying behaves identically to in_progress/succeeded/failed (all non-pending statuses take the same update_columns + enqueue branch), so the gap is behavioral rather than a masking risk. However, the spec's 'existing criteria' contexts do not document coverage of retrying.
- Evidence: AiJobCriteria model (ai_job_criteria.rb:7-13) defines retrying: 4. The spec has context blocks for pending (line 48), in_progress (line 60), succeeded (line 70), failed (line 80) but none for retrying. git log shows retrying was added in commit 78d68c35e but the spec was not updated to cover it.

**F3 [MED] [Prong 3: drift] handle_description_change callback not tested anywhere**
- Location: `spec/models/job_criteria_lifecycle_spec.rb (missing)`
- The spec tests extract_job_criteria and description_meaningfully_changed? as isolated methods, but handle_description_change (job.rb:706-712) is not tested. This method has three guard clauses (description_changed?, published?, description_meaningfully_changed?) and then calls extract_job_criteria. It is wired as a before_update callback via handle_before_update (job.rb:480). The integration of these guards with the callback trigger is not exercised. For a spec titled 'Job criteria lifecycle', the callback-triggered extraction path is a meaningful gap.
- Evidence: Production code job.rb:706-712 defines handle_description_change with guards: return unless description_changed?, return unless published?, return unless description_meaningfully_changed?. Called from handle_before_update (job.rb:480). grep -rn 'handle_description_change' spec/ returns no results. The spec tests the sub-methods but not the callback integration.

**F4 [MED] [Prong 2: tests what it claims] Existing-criteria tests do not verify the 2-minute delay that the code uses**
- Location: `spec/models/job_criteria_lifecycle_spec.rb:63-67,73-77`
- The contexts for 'when existing criteria with in_progress status' and 'when existing criteria with succeeded status' assert 'expect(ExtractJobCriteriaJob).to have_been_enqueued' without verifying the 2-minute delay. The production code at job.rb:697 uses set(wait: 2.minutes).perform_later. The assertions would pass even if the delay were removed. Given that the new-criteria test (line 42) NAMES the delay in its description but targets the wrong path, and the existing-criteria tests (which DO have the delay) don't verify it either, the delay behavior is completely untested.
- Evidence: Production code job.rb:697: 'ExtractJobCriteriaJob.set(wait: 2.minutes).perform_later(ai_job_criteria.id)'. Spec line 66: 'expect(ExtractJobCriteriaJob).to have_been_enqueued'. RSpec ActiveJob matchers support .at(2.minutes.from_now) to verify scheduled time, but it is not used anywhere in this spec.

---

### `organization_ai_credit_balance_spec.rb`

**Code under test:** `app/models/organization_ai_credit_balance.rb`
**File chain:** spec/models/organization_ai_credit_balance_spec.rb -> app/models/organization_ai_credit_balance.rb -> app/models/ai_credit_balance_transaction.rb (has_many), app/services/plan_feature_gate.rb (monthly_credit_allocation), app/interactors/reset_ai_credits.rb (reset_ai_credits), Organization (belongs_to, current_period_end_at delegation). Helper: spec/support/ai_credits_test_helpers.rb (create_credit_test_organization). DB schema: db/schema.rb lines 944-963 (check constraints verified).

**Summary:** The spec is fundamentally sound -- no ghost tests, no broken assertions, no stubs to audit. All 10 test cases (2 association, 2 total_credits_remaining, 2 credits_available?, 4 constraint checks) exercise real production code on real objects or real database records. The constraint tests correctly use a transaction-wrapped update_columns approach to trigger PostgreSQL check constraints. The main gap is drift: the model has 5 instance methods but the spec only covers 2 (total_credits_remaining and credits_available?). The other 3 (monthly_credit_allocation, current_period_end_at, reset_ai_credits) have zero coverage in this spec file. All three are classified MED because they are simple one-liner delegations with partial indirect coverage elsewhere (serializer spec for the first two, interactor spec for the third). One minor convention issue: double quotes used without interpolation on line 54.

**F1 [MED] [Prong 3: drift] No coverage for monthly_credit_allocation method**
- Location: `spec/models/organization_ai_credit_balance_spec.rb (entire file) vs app/models/organization_ai_credit_balance.rb:20-22`
- The model defines monthly_credit_allocation (line 20-22) with branching logic: returns monthly_ai_credits_override if present, otherwise delegates to PlanFeatureGate.new(organization).monthly_ai_credit_allocation. This method has zero test coverage in the model spec. The serializer spec (organization_ai_credit_balance_serializer_spec.rb) exercises it indirectly by asserting the key exists and is an Integer, but does not test the branching logic (override vs. plan default).
- Evidence: Production code (line 20-22): `def monthly_credit_allocation; monthly_ai_credits_override.presence || PlanFeatureGate.new(organization).monthly_ai_credit_allocation; end`. The spec file has no describe/context/it block for this method. Two branches (override present, override absent) are untested at the model level.

**F2 [MED] [Prong 3: drift] No coverage for current_period_end_at method**
- Location: `spec/models/organization_ai_credit_balance_spec.rb (entire file) vs app/models/organization_ai_credit_balance.rb:24-26`
- The model defines current_period_end_at (line 24-26) which delegates to organization.stripe_current_period_end_at. This is a simple delegation with zero test coverage in the model spec. The serializer spec exercises it indirectly by asserting the key exists. This is a minor gap since the method is a one-liner delegation.
- Evidence: Production code (line 24-26): `def current_period_end_at; organization.stripe_current_period_end_at; end`. No corresponding test exists in the model spec.

**F3 [MED] [Prong 3: drift] No coverage for reset_ai_credits method**
- Location: `spec/models/organization_ai_credit_balance_spec.rb (entire file) vs app/models/organization_ai_credit_balance.rb:28-30`
- The model defines reset_ai_credits (line 28-30) which delegates to ResetAiCredits.call(organization: organization). This delegation has zero test coverage in the model spec. The ResetAiCredits interactor has its own spec (spec/interactors/reset_ai_credits_spec.rb). This is a minor gap since the method is a one-liner delegation, but a model spec should at minimum verify the delegation wiring.
- Evidence: Production code (line 28-30): `def reset_ai_credits; ResetAiCredits.call(organization: organization); end`. No corresponding test exists in the model spec. The interactor's own spec tests the interactor logic but not the model delegation wiring.

**C1 [Convention] cursor_rules/backend/_base.md rule 7 (single quotes for string literals)**
- Location: `spec/models/organization_ai_credit_balance_spec.rb:54`
- The describe block on line 54 uses double quotes for 'non-negative balance constraint' without interpolation. Convention requires single quotes for string literals that do not use interpolation. Should be: describe 'non-negative balance constraint' do.

---

### `organization_ai_credit_purchase_spec.rb`

**Code under test:** `app/models/organization_ai_credit_purchase.rb`
**File chain:** spec/models/organization_ai_credit_purchase_spec.rb -> app/models/organization_ai_credit_purchase.rb -> ApplicationRecord, Organization (belongs_to), AiCreditBalanceTransaction (has_many) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization helper)

**Summary:** The spec is well-structured and not ghostly -- all assertions exercise real model behavior via described_class.new(...) with attribute hashes and be_valid checks. No stubs are used, which eliminates an entire class of potential issues. The association and enum tests use legitimate Rails introspection. The CREDIT_PACKS_BY_LOOKUP_KEY tests directly exercise the class methods. However, there are four MED-severity findings: (1) the lookup_by_key class method is completely untested, (2) the stripe_price_lookup_key inclusion validation is untested (only presence is checked), (3) the validates :kind, presence: true constraint has no dedicated test, and (4) subscription_credits_per_period is tested for numericality (0) but not for presence (nil), unlike its analog one_off_credits_granted which tests both. No convention issues were found -- the spec follows cursor_rules patterns appropriately with bang methods in test code, proper string quoting, and clear describe/context/it naming.

**F1 [MED] [Prong 3: drift] lookup_by_key class method has no test coverage**
- Location: `spec/models/organization_ai_credit_purchase_spec.rb:139-181 vs app/models/organization_ai_credit_purchase.rb:31-33`
- The model defines a class method `self.lookup_by_key(lookup_key)` at line 31-33 that returns the full pack hash for a given key. The spec tests `registered_keys`, `subscription_key?`, `one_off_key?`, and `credit_amount_for_key` but never tests `lookup_by_key`. This method is defined in production code but has zero coverage in this spec or anywhere else in the spec suite (verified via grep).
- Evidence: Production code (line 31-33): `def self.lookup_by_key(lookup_key); CREDIT_PACKS_BY_LOOKUP_KEY[lookup_key]; end`. Grep of entire spec/ directory for 'lookup_by_key' returns no results. The CREDIT_PACKS_BY_LOOKUP_KEY describe block (lines 139-181) tests 4 out of 5 class methods, omitting this one.

**F2 [MED] [Prong 3: drift] stripe_price_lookup_key inclusion validation untested**
- Location: `spec/models/organization_ai_credit_purchase_spec.rb:50-52 vs app/models/organization_ai_credit_purchase.rb:58-59`
- The model validates stripe_price_lookup_key with both `presence: true` AND `inclusion: { in: ->(_) { OrganizationAiCreditPurchase.registered_keys } }`. The spec only tests the presence constraint (nil -> invalid at line 52). It never tests that an invalid/unregistered key is rejected by the inclusion validation. A regression that removes the inclusion constraint would not be caught.
- Evidence: Production code (lines 58-59): `validates :stripe_price_lookup_key, presence: true, inclusion: { in: ->(_) { OrganizationAiCreditPurchase.registered_keys } }`. Spec line 51-52 only tests nil. No test exists with a fabricated invalid key like 'bogus_key' to verify the inclusion constraint rejects it.

**F3 [MED] [Prong 3: drift] validates :kind, presence: true has no dedicated test**
- Location: `spec/models/organization_ai_credit_purchase_spec.rb:30-75 vs app/models/organization_ai_credit_purchase.rb:60`
- The model has `validates :kind, presence: true` at line 60. The spec has no test that verifies a record without `kind` is invalid. While every test hash includes `kind`, none removes it to verify the presence validation fires. A regression removing this validation would not be caught by the spec.
- Evidence: Production code line 60: `validates :kind, presence: true`. Spec lines 30-75 (one_off validations) and 77-109 (subscription validations) always include `kind:` in the attribute hash. No test does `valid_one_off.merge(kind: nil)` or `valid_one_off.except(:kind)` to verify presence.

**F4 [MED] [Prong 2: tests what it claims] subscription_credits_per_period presence validation not tested for nil**
- Location: `spec/models/organization_ai_credit_purchase_spec.rb:101-103 vs app/models/organization_ai_credit_purchase.rb:65-68`
- The spec tests subscription_credits_per_period with value 0 (line 102) but not with nil. The model validates both presence and numericality greater_than 0. Compare to the one_off_credits_granted test (lines 55-58) which correctly tests both 0 and nil. The subscription_credits_per_period test is incomplete -- it does not verify the presence: true part of the validation.
- Evidence: Production code (lines 65-68): `validates :subscription_credits_per_period, presence: true, numericality: { greater_than: 0 }, if: :subscription?`. Spec line 101 says 'requires subscription_credits_per_period to be positive' but only tests 0 (line 102), not nil. The analogous one_off_credits_granted test at lines 56-57 tests both 0 and nil.

---

### `organization_ai_credits_lifecycle_spec.rb`

**Code under test:** `app/models/organization.rb`
**File chain:** spec/models/organization_ai_credits_lifecycle_spec.rb -> app/models/organization.rb (#create_ai_credit_state_if_needed at line 192, #add_default_settings at line 1293, #default_settings at line 1258, #update_settings at line 1298) -> app/models/organization_ai_credit_balance.rb -> app/services/plan_feature_gate.rb (MINIMUM_AI_CREDIT_ALLOCATION = 25 at line 128)

**Summary:** The spec file tests three valid behaviors of the Organization model's AI credit lifecycle: balance creation, default settings application, and idempotency. None of the tests are ghosts -- all three exercise real production code and would fail if that code were deleted. There are no stub/mock drift concerns since the tests call production methods directly without stubs. The primary issues are naming accuracy: the describe block attributes all tests to complete_setup_workers, but the tests actually exercise two separate methods (create_ai_credit_state_if_needed and add_default_settings) that belong to different callback chains. The spec also uses class-level callback manipulation (skip_callback/set_callback) that the project's own shared test helper explicitly warns against in favor of instance-level define_singleton_method. All three findings are MED severity -- the tests work correctly and cover real behavior, but the naming is misleading about which code paths are being exercised.

**F1 [MED] [Prong 2: tests what it claims] Describe block names wrong method for the behavior under test**
- Location: `spec/models/organization_ai_credits_lifecycle_spec.rb:6`
- The describe block says '#complete_setup_workers -- AI credit state creation' but none of the three tests exercise complete_setup_workers. Tests 1 and 3 call create_ai_credit_state_if_needed directly -- that method is a separate after_create callback (organization.rb:55), not part of complete_setup_workers. Test 2 calls add_default_settings directly -- that method is called from complete_setup (organization.rb:209), which is invoked by OrgSetupJob (enqueued by complete_setup_workers), but the test never invokes complete_setup_workers or complete_setup. The describe block conflates two independent callback chains: after_create :create_ai_credit_state_if_needed (synchronous credit row creation) and after_commit :complete_setup_workers (async setup via OrgSetupJob -> complete_setup -> add_default_settings).
- Evidence: Spec line 6: describe '#complete_setup_workers -- AI credit state creation'. organization.rb line 55: after_create :create_ai_credit_state_if_needed. organization.rb line 56: after_commit :complete_setup_workers, on: [:create]. organization.rb line 180-190: complete_setup_workers enqueues OrgSetupJob but does NOT call create_ai_credit_state_if_needed. These are two separate callbacks on two different hooks.

**F2 [MED] [Prong 2: tests what it claims] Test 2 it-block says 'via complete_setup' but calls add_default_settings directly**
- Location: `spec/models/organization_ai_credits_lifecycle_spec.rb:41`
- The it-block description says 'sets the 5 AI keys in organization.settings at their defaults via complete_setup' but line 42 calls organization.add_default_settings, not organization.complete_setup. While complete_setup does call add_default_settings (organization.rb:209), the test bypasses complete_setup entirely. The test description implies it exercises the complete_setup code path including the is_claimed guard (organization.rb:210), but it does not.
- Evidence: Spec line 42: organization.add_default_settings. organization.rb line 208-222: def complete_setup calls add_default_settings as its first line, but then has an is_claimed guard protecting several other setup calls. The test calls add_default_settings directly, skipping this entire method.

**F3 [MED] [Prong 2: tests what it claims] Uses class-level skip_callback/set_callback despite project helper warning against it**
- Location: `spec/models/organization_ai_credits_lifecycle_spec.rb:25-29`
- The spec manipulates Organization's class-level callback chain via skip_callback/set_callback (lines 25-29). The project's shared AiCreditsTestHelpers (spec/support/ai_credits_test_helpers.rb:47-48) explicitly warns against this pattern: 'Avoid skip_callback / set_callback because those mutate the class-level callback chain and accumulate across runs.' The shared helper instead uses define_singleton_method for instance-level stubbing, which is safer for test isolation. While the spec does re-enable the callbacks after creating the org, the class-level mutation creates a window where other tests in the same process could be affected if test ordering or parallelism changes.
- Evidence: Spec lines 25-26: Organization.skip_callback(:commit, :after, :complete_setup_workers, raise: false) and Organization.skip_callback(:create, :after, :create_ai_credit_state_if_needed, raise: false). Spec lines 28-29 re-enable them. ai_credits_test_helpers.rb lines 47-48: 'Avoid skip_callback / set_callback because those mutate the class-level callback chain and accumulate across runs.' ai_credits_test_helpers.rb lines 56-63: uses define_singleton_method instead.

---

### `organization_ai_credits_spec.rb`

**Code under test:** `app/models/organization.rb`
**File chain:** spec/models/organization_ai_credits_spec.rb -> app/models/organization.rb (lines 28-31 associations, lines 941-963 helper methods) -> app/models/organization_ai_credit_balance.rb (lines 9-14 total_credits_remaining)

**Summary:** The spec is structurally sound and not a ghost -- all assertions exercise real production code and would fail if the production methods were deleted. There are no stubs to audit. The association tests at lines 7-21 correctly use reflect_on_association. The two findings are both MED-severity drift issues: (1) the total_ai_credits_remaining test only validates 2 of the 4 fields that the production code sums, and its describe text 'sums monthly + addon' no longer reflects the production code's 4-field sum; (2) two delegate-style helper methods (daily_ai_credits_remaining and addon_subscription_ai_credits_remaining) that belong to the same 'AI credit helpers' section are completely untested despite the spec claiming that scope. No convention issues were found -- the spec uses bang methods appropriately (allowed in specs per core_critical_rules.md rule 11), reload is used correctly (allowed in specs per backend/_base.md rule 8), and string quoting follows conventions.

**F1 [MED] [Prong 3: drift] total_ai_credits_remaining test description and assertion cover only 2 of 4 summed fields**
- Location: `spec/models/organization_ai_credits_spec.rb:48-50`
- The test is named 'sums monthly + addon' and sets only monthly_credits_remaining and addon_credits_remaining, asserting 5+10=15. However, the production code at organization_ai_credit_balance.rb:9-14 sums 4 fields: daily_credits_remaining + monthly_credits_remaining + addon_subscription_credits_remaining + addon_credits_remaining. The test passes because the other two fields default to 0/nil, but it does not verify that daily_credits_remaining and addon_subscription_credits_remaining contribute to the total. If someone removed those two fields from the sum, this test would still pass. The test description 'sums monthly + addon' does not reflect that the production code sums 4 fields.
- Evidence: Spec line 48-50 sets monthly_credits_remaining: 5, addon_credits_remaining: 10 and expects 15. Production code OrganizationAiCreditBalance#total_credits_remaining (organization_ai_credit_balance.rb:9-14) computes (daily_credits_remaining || 0) + (monthly_credits_remaining || 0) + (addon_subscription_credits_remaining || 0) + (addon_credits_remaining || 0). Two of the four terms are untested.

**F2 [MED] [Prong 3: drift] Two delegate-style helper methods under 'AI credit helpers' section have zero test coverage**
- Location: `spec/models/organization_ai_credits_spec.rb:24 (missing coverage)`
- The spec scopes itself as 'AI credit helper methods' but only covers 4 of the 6 instance helper methods in the 'AI credit helpers' section of organization.rb (lines 918-971). The methods daily_ai_credits_remaining (line 941) and addon_subscription_ai_credits_remaining (line 949) follow the same pattern as the tested methods (delegate to balance field with || 0 fallback) but have no test coverage in this spec. These methods are part of the same logical group the spec claims to test.
- Evidence: Spec describe block at line 24 is 'AI credit helper methods'. Production code has 6 methods in the 'AI credit helpers' section: daily_ai_credits_remaining (941), monthly_ai_credits_remaining (945), addon_subscription_ai_credits_remaining (949), addon_ai_credits_remaining (953), total_ai_credits_remaining (957), ai_credits_available? (961). The spec tests the last 4 but omits daily_ai_credits_remaining and addon_subscription_ai_credits_remaining.

---

### `textract_result_ai_trigger_spec.rb`

**Code under test:** `app/models/textract_result.rb`
**File chain:** spec/models/textract_result_ai_trigger_spec.rb -> app/models/textract_result.rb (queue_ai_summary_job, lines 114-144) -> ValidateAiSummaryGeneration (app/interactors/validate_ai_summary_generation.rb) -> Job#should_auto_generate_ai_summaries? (app/models/job.rb:914-922) -> Organization#auto_generate_ai_summaries_enabled (app/models/organization.rb:965-967) -> GenerateAiJobApplicationSummaryJob (app/jobs/generate_ai_job_application_summary_job.rb) -> AiJobApplicationSummary (app/models/ai_job_application_summary.rb) -> spec/support/ai_credits_test_helpers.rb

**Summary:** The spec exercises the auto-generate path of TextractResult#queue_ai_summary_job thoroughly: create with/without text, update with/without text change, and the four-way org-default/per-job-override auto-generate gate matrix. None of these tests are ghosts -- the assertions depend on real production code guards and callbacks firing. The ValidateAiSummaryGeneration stub matches the real interactor's return shape. However, the spec has drifted from the code under test: the queue_ai_summary_job method contains a significant branch (lines 121-136) for manual-trigger summaries waiting on Textract processing that has zero coverage. This branch has its own ValidateAiSummaryGeneration call with different perform_later arguments, a failure path that destroys a waiting summary and broadcasts an error, and a success path -- all untested. Additionally, the auto-generate path's validation failure case is not tested because the stub always returns success. No convention issues were found.

**F1 [HIGH] [Prong 3: drift] No coverage of the ai_summary_waiting_on_textract branch (manual trigger path)**
- Location: `spec/models/textract_result_ai_trigger_spec.rb (entire file) vs app/models/textract_result.rb:121-136`
- The queue_ai_summary_job method has two top-level branches: (1) when an AiJobApplicationSummary with status :textract_processing exists (the manual trigger path where a user requested a summary before Textract finished), and (2) the else branch (auto-generate path). The spec only exercises the else branch (auto-generate). The entire manual trigger path -- including its ValidateAiSummaryGeneration call with different perform_later arguments (passing requesting_organization_user_id), its failure path that destroys the waiting summary and broadcasts AI_SUMMARY_FAILED, and its success path -- has zero test coverage.
- Evidence: Production code at textract_result.rb:121-136 queries for job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false). If found, it calls ValidateAiSummaryGeneration, and on success enqueues GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id, requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id). On failure, it destroys the waiting summary and calls broadcast_ai_summary_failed. The spec file never creates an AiJobApplicationSummary with status :textract_processing, so this branch is never entered. Grepping the spec for 'textract_processing', 'waiting', and 'broadcast_ai_summary_failed' returns zero matches.

**F2 [MED] [Prong 3: drift] No coverage of broadcast_ai_summary_failed method**
- Location: `spec/models/textract_result_ai_trigger_spec.rb (entire file) vs app/models/textract_result.rb:146-160`
- The broadcast_ai_summary_failed private method (lines 146-160) broadcasts an AI_SUMMARY_FAILED action to the requesting user's GlobalChannel when validation fails for a manual-trigger summary that was waiting on Textract. This method is only reached through the ai_summary_waiting_on_textract failure path, which itself has no coverage. The method contains logic to look up the candidate name, construct a link, and broadcast with a specific payload shape -- none of which is verified.
- Evidence: Production code at textract_result.rb:135 calls broadcast_ai_summary_failed(requesting_organization_user, result.error). The method at lines 146-160 calls GlobalChannel.broadcast_to with action: 'AI_SUMMARY_FAILED' and a payload containing candidateFullName, jobApplicationLink, and errorMessage. The spec never exercises this path.

**F3 [MED] [Prong 3: drift] No coverage of ValidateAiSummaryGeneration failure in the auto-generate path**
- Location: `spec/models/textract_result_ai_trigger_spec.rb (entire file) vs app/models/textract_result.rb:140`
- In the auto-generate (else) path at line 140, ValidateAiSummaryGeneration.call is invoked and the job is only enqueued if result.success? is true (line 142). The spec's global before block stubs ValidateAiSummaryGeneration to always return success. There is no test verifying that when ValidateAiSummaryGeneration fails on the auto-generate path, the job is NOT enqueued. While the existing gate tests cover the should_auto_generate_ai_summaries? guard, they do not cover the validation failure path.
- Evidence: The before block at spec line 21-23 stubs ValidateAiSummaryGeneration.call to always return double('result', success?: true, ...). Production code at textract_result.rb:142 only enqueues the job 'if result.success?'. There is no test case where ValidateAiSummaryGeneration returns success?: false in the auto-generate path, so the conditional at line 142 is only exercised in the truthy direction.

---

### `job_application_ai_summary_status_spec.rb`

**Code under test:** `app/models/job_application.rb`
**File chain:** spec/models/job_application_ai_summary_status_spec.rb -> app/models/job_application.rb (enqueue_new_job_application, line 163) -> app/interactors/find_or_create_ai_job_application_summary_status.rb -> app/models/ai_job_application_summary_status.rb -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization, create_credit_test_job, create_credit_test_job_application)

**Summary:** The spec file contains a single test that exercises the JobApplication#enqueue_new_job_application after_commit callback, verifying that creating a new JobApplication results in an AiJobApplicationSummaryStatus record with status 'none'. The test is NOT a ghost: it exercises real production code through the callback chain (JobApplication after_commit -> enqueue_new_job_application -> find_or_create_ai_job_application_summary_status -> FindOrCreateAiJobApplicationSummaryStatus interactor), and the assertions would fail if that production code were removed. There are no stubs in the spec, so no stub-signature mismatches to check. The test exercises the correct path for a new job application with no prior AI summaries (the 'none' status branch at line 33-34 of the interactor). No drift was detected on the specific path tested. The only issue is a MED naming mismatch: the file is named job_application_ai_summary_status_spec.rb but RSpec.describe targets JobApplication, not AiJobApplicationSummaryStatus. A separate ai_job_application_summary_status_spec.rb already exists for the actual model. The misleading filename could cause confusion about which model each spec covers.

**F1 [MED] [Prong 2: tests what it claims] Spec file name does not match RSpec.describe subject**
- Location: `spec/models/job_application_ai_summary_status_spec.rb:5`
- The file is named job_application_ai_summary_status_spec.rb, which by Rails convention suggests it tests a model called JobApplicationAiSummaryStatus (or AiJobApplicationSummaryStatus). However, line 5 declares RSpec.describe JobApplication, type: :model. A separate spec file already exists for the actual AiJobApplicationSummaryStatus model at spec/models/ai_job_application_summary_status_spec.rb. This file tests a JobApplication callback's side effect on AiJobApplicationSummaryStatus, not the AiJobApplicationSummaryStatus model itself. The misleading filename could cause a developer to think AiJobApplicationSummaryStatus has two spec files, or to miss this spec entirely when looking for JobApplication callback tests.
- Evidence: File name: job_application_ai_summary_status_spec.rb. RSpec.describe target (line 5): JobApplication. The actual AiJobApplicationSummaryStatus model spec exists at spec/models/ai_job_application_summary_status_spec.rb. By convention, a spec file for JobApplication callbacks would be named job_application_spec.rb or placed in a descriptive subdirectory. There is no job_application_spec.rb in spec/models/.

**C1 [Convention] File Naming Conventions (core_critical_rules.md)**
- Location: `spec/models/job_application_ai_summary_status_spec.rb:1`
- The spec file name job_application_ai_summary_status_spec.rb does not match the described model JobApplication. Convention says model spec files should be named after the model they test (e.g., job_application_spec.rb for JobApplication).

---
