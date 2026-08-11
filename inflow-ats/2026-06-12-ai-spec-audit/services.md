# Service Specs Audit — Round 2 (8 files)

**Branch:** `UI-polishes` | **Date:** 2026-06-18
**Totals:** 27 findings (4 BLOCKER, 12 HIGH, 11 MED), 1 convention issues, 1 clean specs

## Files

| # | File | Findings | Status |
|---|------|----------|--------|
| 1 | `orchestrate_spec.rb` | 2B, 4H, 2M, 1C | BLOCKER |
| 2 | `calculate_spec.rb` | 1M | MED |
| 3 | `extract_criteria_spec.rb` | 2H, 2M | HIGH |
| 4 | `integrate_analysis_spec.rb` | 2M | MED |
| 5 | `score_job_application_spec.rb` | 2B, 3H, 1M | BLOCKER |
| 6 | `plan_feature_gate_ai_credits_spec.rb` | 1M | MED |
| 7 | `cancel_credit_pack_subscription_spec.rb` | 0 | CLEAN |
| 8 | `submit_resume_to_textract_spec.rb` | 3H, 2M | HIGH |

## Findings

### `orchestrate_spec.rb`

**Code under test:** `app/services/ai_job_application_action/orchestrate.rb`
**File chain:** spec/services/ai_job_application_action/orchestrate_spec.rb -> app/services/ai_job_application_action/orchestrate.rb -> app/services/ai_job_application_action/summary/generate.rb -> app/services/ai_job_application_action/scoring/score_job_application.rb -> app/services/ai_job_application_action/scoring/integrate_analysis.rb -> app/models/ai_job_application_summary.rb -> app/models/ai_job_criteria.rb -> app/models/job.rb (extract_job_criteria)

**Summary:** The orchestrate_spec.rb has two BLOCKER near-ghost tests (lines 33-37 and 40-44) that only assert `not_to raise_error` without verifying any behavior, giving false confidence that the guard clauses are tested. Two HIGH findings flag that ScoreJobApplication.new and IntegrateAnalysis.new are stubbed without argument verification, meaning constructor signature drift between orchestrate.rb and these dependencies would go undetected. Three additional HIGH drift findings reveal that the spec covers only 3 of the 7 status branches in the orchestrator's case statement -- the core state-machine logic for resuming interrupted pipelines (summarizing, scoring, integrating, textract_processing, extracting, retrying) has zero test coverage. The check_criteria_and_score method's guard clauses and extract_job_criteria trigger are also uncovered. Overall, the spec provides shallow coverage of the happy path (pending -> awaiting_job_criteria, awaiting_job_criteria -> scoring -> integration) and terminal states, but misses the orchestrator's primary value: resuming pipelines from intermediate failure states.

**F1 [BLOCKER] [Prong 1: works] Near-ghost: 'when textract_result does not exist' only asserts not_to raise_error**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb:33-37`
- This test only asserts that calling with a non-existent textract_result_id does not raise an error. It does not verify any behavior -- no state change assertions, no method call expectations, nothing. If the production guard clause at orchestrate.rb:12 were removed, the test would fail with NoMethodError on line 14, but that is incidental breakage from nil, not a deliberate assertion. The test claims to verify 'returns silently' but does not verify anything was returned or that execution stopped at the right point. A test whose only assertion is not_to raise_error is a near-ghost.
- Evidence: Spec line 34-36: `expect { described_class.new(textract_result_id: 99_999_999).call }.not_to raise_error`. Production orchestrate.rb:12: `return unless @textract_result`. The spec does not verify that no downstream methods were called (e.g., Summary::Generate, ScoreJobApplication). Compare to the 'does nothing for succeeded' test at line 49 which correctly uses `expect(X).not_to receive(:new)` to verify no downstream work happens.

**F2 [BLOCKER] [Prong 1: works] Near-ghost: 'when no summary exists' only asserts not_to raise_error**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb:40-44`
- Same near-ghost pattern as the previous test. Only asserts not_to raise_error. Does not verify that execution stopped at the guard clause (orchestrate.rb:16) or that no downstream services were invoked. The describe/context block claims to test the 'no summary exists' path, but the assertion would pass for any scenario that doesn't raise -- including one where the production code continued past the guard and did work it shouldn't.
- Evidence: Spec line 41-43: `expect { described_class.new(textract_result_id: textract_result.id).call }.not_to raise_error`. Production orchestrate.rb:15-16: `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first; return unless @ai_job_application_summary`. No message expectations on Summary::Generate or any downstream service.

**F3 [MED] [Prong 2: tests what it claims] Dead code: unused generate_double variable in 'does nothing for succeeded' test**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb:57`
- Line 57 creates `generate_double = instance_double(AiJobApplicationAction::Summary::Generate)` but this variable is never used. The assertion on line 58 uses `expect(AiJobApplicationAction::Summary::Generate).not_to receive(:new)` which does not reference the double. This is dead test code that adds confusion.
- Evidence: Line 57: `generate_double = instance_double(AiJobApplicationAction::Summary::Generate)` is assigned but never referenced in the test body. The actual assertion is on line 58-59.

**F4 [HIGH] [Prong 2: tests what it claims] ScoreJobApplication.new stubbed without argument verification**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb:129-130`
- The spec stubs ScoreJobApplication.new without verifying the keyword arguments passed by production code. Production code at orchestrate.rb:89-92 passes `ai_job_application_summary: @ai_job_application_summary, textract_result: @textract_result`. The spec's stub would pass even if the production code changed to pass completely different arguments (e.g., dropped textract_result or swapped the summary). This masks potential argument drift between orchestrate.rb and ScoreJobApplication's constructor.
- Evidence: Spec line 130: `expect(AiJobApplicationAction::Scoring::ScoreJobApplication).to receive(:new).and_return(score_double)` -- no .with() matcher. Production orchestrate.rb:89-92: `AiJobApplicationAction::Scoring::ScoreJobApplication.new(ai_job_application_summary: @ai_job_application_summary, textract_result: @textract_result).score`. ScoreJobApplication's actual constructor at score_job_application.rb:6 takes `ai_job_application_summary:, textract_result:` as required keyword args.

**F5 [HIGH] [Prong 2: tests what it claims] IntegrateAnalysis.new stubbed without argument verification**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb:139-140`
- Same issue as ScoreJobApplication. The spec stubs IntegrateAnalysis.new without verifying keyword arguments. Production code at orchestrate.rb:101-103 passes `ai_job_application_summary: @ai_job_application_summary`. The spec would not catch if the production code stopped passing this argument or changed its shape.
- Evidence: Spec line 140: `expect(AiJobApplicationAction::Scoring::IntegrateAnalysis).to receive(:new).and_return(integrate_double)` -- no .with() matcher. Production orchestrate.rb:101-103: `AiJobApplicationAction::Scoring::IntegrateAnalysis.new(ai_job_application_summary: @ai_job_application_summary).integrate`. IntegrateAnalysis constructor at integrate_analysis.rb:6 takes `ai_job_application_summary:` as required keyword arg.

**F6 [HIGH] [Prong 3: drift] No coverage for summarizing, scoring, integrating, textract_processing, extracting, or retrying status branches**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb (entire file)`
- The production code's case statement (orchestrate.rb:21-49) has 7 distinct status branches. The spec only covers 3: pending (line 77), awaiting_job_criteria (line 108), and the terminal succeeded/failed (line 48). The remaining branches have zero test coverage: (1) textract_processing, extracting, retrying -- same branch as pending but untested; (2) summarizing -- has two sub-branches (summary_complete? true vs false) both untested; (3) scoring -- has two sub-branches (criteria_results present vs not) both untested; (4) integrating -- untested. These represent the orchestrator's core state-machine logic for resuming interrupted pipelines.
- Evidence: Production orchestrate.rb:22-25 handles textract_processing/extracting/retrying, :28-34 handles summarizing (with summary_complete? branching), :37-43 handles scoring (with criteria_results branching), :44-45 handles integrating. None of these have corresponding context/it blocks in the spec. The case statement is the orchestrator's primary business logic.

**F7 [HIGH] [Prong 3: drift] No coverage for check_criteria_and_score guard clauses and extract_job_criteria trigger**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb (entire file)`
- The private method check_criteria_and_score (orchestrate.rb:68-83) has multiple branches: (1) status_failed? early return (line 69), (2) summary_complete? early return (line 70), (3) criteria nil/not-succeeded triggers extract_job_criteria (line 80), (4) criteria pending/in_progress skip extraction (line 80). The 'pending' test indirectly exercises branch 3 but does not assert that extract_job_criteria was called. No test exercises branches 1, 2, or 4.
- Evidence: Production orchestrate.rb:69: `return if @ai_job_application_summary.status_failed?` -- no test creates a summary that becomes failed after run_summary and verifies check_criteria_and_score exits. orchestrate.rb:70: `return unless summary_complete?` -- no test creates a summary where headline or summary_text is missing after generate. orchestrate.rb:80: `@ai_job_application_summary.job_application.job.extract_job_criteria unless ai_job_criteria&.status_pending? || ai_job_criteria&.status_in_progress?` -- no test verifies extract_job_criteria is called or skipped based on criteria status.

**F8 [MED] [Prong 3: drift] No coverage for run_scoring and run_integration guard clauses**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb (entire file)`
- Both run_scoring (orchestrate.rb:86-94) and run_integration (orchestrate.rb:96-104) have guard clauses that check status_failed? and (for run_integration) criteria_results.present?. These guards protect against continuing the pipeline when a prior step has failed. No test exercises these defensive guards.
- Evidence: Production orchestrate.rb:87: `return if @ai_job_application_summary.status_failed?` in run_scoring. orchestrate.rb:98-99: `return if @ai_job_application_summary.status_failed?` and `return unless @ai_job_application_summary.criteria_results.present?` in run_integration. No test puts the summary into a failed state mid-pipeline and verifies these guards activate.

**C1 [Convention] General code quality (no dead code/unused variables)**
- Location: `spec/services/ai_job_application_action/orchestrate_spec.rb:57`
- generate_double is assigned via instance_double but never referenced in the test. This is dead code that should be removed.

---

### `calculate_spec.rb`

**Code under test:** `app/services/ai_job_application_action/scoring/calculate.rb`
**File chain:** spec/services/ai_job_application_action/scoring/calculate_spec.rb -> app/services/ai_job_application_action/scoring/calculate.rb (self-contained, no external dependencies beyond Rails core)

**Summary:** This is a clean, well-structured spec for a pure calculation service. The spec has zero stubs, zero factories, and zero mocking -- every test directly calls the class method `AiJobApplicationAction::Scoring::Calculate.compute` with explicit hash inputs and asserts on the calculated return value. Ghost risk is zero. All major production code paths are covered: nil input, empty array, each tier weight (tier_1/tier_2/tier_3), each score value (full_match/partial_match/not_found), the title_technology multiplier, mixed-criteria scenarios, and the unknown-tier fallback. The test calculations are arithmetically correct against the production constants (TIER_WEIGHTS, SCORE_VALUES, TITLE_TECHNOLOGY_MULTIPLIER). The only gap is a missing test for the unknown-score fallback on production line 18 (`SCORE_VALUES[result['score']] || 0.0`), which parallels the unknown-tier test that does exist. This is a MED finding since the fallback value (0.0) equals the 'not_found' value and would only matter if the default were changed. No convention issues found.

**F1 [MED] [Prong 3: drift] Unknown score fallback path not tested**
- Location: `app/services/ai_job_application_action/scoring/calculate.rb:18`
- Production line 18 has a fallback for unknown score values: `SCORE_VALUES[result['score']] || 0.0`. The spec tests 'full_match' (1.0), 'partial_match' (0.7), and 'not_found' (0.0) but never passes an unrecognized score string. While the fallback (0.0) happens to match the 'not_found' value, it is a distinct production code path (the `||` branch) that is never exercised. If the default were changed to something other than 0.0, no test would catch it.
- Evidence: Spec tests only 'full_match', 'partial_match', and 'not_found' as score values. Production code on line 18 has `SCORE_VALUES[result['score']] || 0.0` which handles any unrecognized score string by defaulting to 0.0. The spec already tests the analogous pattern for unknown tiers (line 63-67: 'defaults to tier_2 weight for unknown tier') but has no equivalent test for unknown scores.

---

### `extract_criteria_spec.rb`

**Code under test:** `app/services/ai_job_application_action/scoring/extract_criteria.rb`
**File chain:** spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb -> app/services/ai_job_application_action/scoring/extract_criteria.rb -> app/models/ai_job_criteria.rb -> app/services/ai_client.rb -> app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb -> app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb -> app/models/ai_api_request.rb -> app/errors/custom_error_ai_summary.rb -> spec/support/ai_credits_test_helpers.rb

**Summary:** The spec file is well-structured and covers the main happy path, heading tier overrides, deduplication, and error handling. No ghost tests were found -- all assertions exercise real production behavior and would fail if the production code were removed. Stub signatures and return shapes match the current production code. There are no convention violations. However, four drift findings were identified: two HIGH (uncovered branch for all-duplicates-filtered path and uncovered update-failure-raises-CustomErrorAiSummary path) and two MED (untested defensive tier-label stripping and untested guard clauses for missing job/organization). The two HIGH findings represent real production branches that have no spec coverage -- if those branches fire in production, no test would have caught regressions in their behavior.

**F1 [HIGH] [Prong 3: drift] Uncovered branch: all criteria are duplicates (non_duplicates.empty?)**
- Location: `app/services/ai_job_application_action/scoring/extract_criteria.rb:121-124`
- Production code at lines 121-124 has a branch where after deduplication, all criteria are marked as duplicates, resulting in an empty non_duplicates array. This sets status to 'failed' with error_message 'No criteria extracted from job description'. The spec has no test for this path. This is distinct from the 'no criteria sections' test (which covers the extraction_result having no criteria sections at line 60-63). This branch covers the case where criteria sections exist and criteria are extracted, but ALL are marked duplicate.
- Evidence: Production code lines 121-124: `if non_duplicates.empty? @ai_job_criteria.update_columns(status: :failed, error_message: 'No criteria extracted from job description') return end`. No spec test covers this path. The deduplication test at spec line 234-273 only tests partial deduplication (1 of 2 is duplicate), not total deduplication.

**F2 [HIGH] [Prong 3: drift] Uncovered branch: update failure raises CustomErrorAiSummary**
- Location: `app/services/ai_job_application_action/scoring/extract_criteria.rb:140-141`
- Production code at lines 140-141 checks the return value of @ai_job_criteria.update(update_params). If update fails (validation error), it raises CustomErrorAiSummary with the error messages. This path is not tested. The error handling test at spec line 279-288 only tests CustomErrorAiSummary raised by the ai_client.chat call, not by the update failure. The update failure raise would be caught by the same rescue block (lines 143-147) setting status to 'retrying' and re-raising, but this distinct trigger path is untested.
- Evidence: Production code line 140-141: `unless @ai_job_criteria.update(update_params) raise CustomErrorAiSummary, "Failed to update AiJobCriteria: #{@ai_job_criteria.errors.full_messages.join(', ')}"`. No spec test triggers an update validation failure on the final save.

**F3 [MED] [Prong 3: drift] Uncovered defensive logic: tier label stripping from criterion text**
- Location: `app/services/ai_job_application_action/scoring/extract_criteria.rb:94-100`
- Production code at lines 94-100 strips leading tier labels (e.g., '[tier_1]: ') from criterion text as a defensive measure against AI model behavior. The spec has no test for this defensive logic. If a criteria_response contained text like '[tier_1] 5+ years Ruby experience', the spec would not verify that the leading label is stripped.
- Evidence: Production code line 99: `criterion['text'] = criterion['text'].sub(/\A\s*\[tier_\d+\]\s*:?\s*/i, '')`. No spec test provides criteria with leading tier labels to verify they are stripped.

**F4 [MED] [Prong 3: drift] Uncovered guard clauses: missing job and missing organization**
- Location: `app/services/ai_job_application_action/scoring/extract_criteria.rb:22-26`
- Production code has guard clauses at lines 22-23 (return unless @job) and 25-26 (return unless @organization). Neither is tested. While guard clauses for nil returns are simple enough that missing coverage is minor, these are distinct from the 'ai_job_criteria does not exist' guard (which IS tested at spec line 53-57). An AiJobCriteria could exist but belong to a nil job (if the job were deleted), or the job could have a nil organization.
- Evidence: Production code lines 22-23: `@job = @ai_job_criteria.job; return unless @job`. Lines 25-26: `@organization = @job.organization; return unless @organization`. No spec tests create an AiJobCriteria with a missing job or a job with a missing organization.

---

### `integrate_analysis_spec.rb`

**Code under test:** `app/services/ai_job_application_action/scoring/integrate_analysis.rb`
**File chain:** spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb -> app/services/ai_job_application_action/scoring/integrate_analysis.rb -> app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb -> app/services/ai_client.rb -> app/models/ai_api_request.rb -> app/models/ai_job_application_summary.rb -> app/errors/custom_error_ai_summary.rb -> spec/support/ai_credits_test_helpers.rb

**Summary:** The spec for AiJobApplicationAction::Scoring::IntegrateAnalysis is structurally sound and covers the major code paths: nil guard, happy path (status transition, integrated_role_analysis population, score/criteria preservation, AiApiRequest creation), nil structured_data handling, and three error rescue branches (CustomErrorAiSummary, JSON::ParserError, StandardError). No ghost tests were found -- all assertions exercise real behavior through the production code. Two MED findings: (1) the criteria_results fixture data uses a 'summary' key where production code reads 'display_sentence', causing nil values in the (unstubbed) prompt generation -- masked because AiClient#chat is stubbed; (2) the explicit update-failure branch (integrate_analysis.rb:53-55) that raises CustomErrorAiSummary when the model update fails is not tested, though the rescue path for externally raised CustomErrorAiSummary is tested. No convention violations were found.

**F1 [MED] [Prong 3: drift] criteria_results fixture uses 'summary' key but production reads 'display_sentence'**
- Location: `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb:33-41`
- The spec's criteria_results fixture data uses 'summary' as a key (line 39), but the production code's Prompts::IntegratedAnalysis.messages method (prompts/integrated_analysis.rb:115) accesses cr['display_sentence']. Since Prompts::IntegratedAnalysis is NOT stubbed and runs for real during the test, the prompt text passed to the (stubbed) AI client contains nil where display_sentence should be. The test passes because the AI client response is stubbed, masking the data shape mismatch.
- Evidence: Spec fixture (line 39): 'summary' => 'Excellent Ruby skills'. Production code (prompts/integrated_analysis.rb:115): "- [#{cr['tier']}] [#{cr['score']}] #{cr['display_sentence']}". The 'display_sentence' key does not exist in the spec fixture, so cr['display_sentence'] evaluates to nil. The generated prompt text would read '- [tier_1] [full_match] ' (empty where the display sentence should be). This does not cause a test failure because AiClient#chat is stubbed, but the test exercises a prompt shape that would never occur in production.

**F2 [MED] [Prong 2: tests what it claims] No test for update failure branch that raises CustomErrorAiSummary**
- Location: `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb:156-167 vs app/services/ai_job_application_action/scoring/integrate_analysis.rb:53-55`
- The production code has an explicit 'unless update(update_params)' check (integrate_analysis.rb:53-55) that raises CustomErrorAiSummary with message 'Failed to update integrated analysis:...' when the model update fails. This is a distinct code path from CustomErrorAiSummary being raised by the AI provider (tested at spec line 157). The update-failure branch is never exercised by the spec.
- Evidence: Production code (integrate_analysis.rb:53-55): 'unless @ai_job_application_summary.update(update_params) raise CustomErrorAiSummary, "Failed to update integrated analysis: ..." end'. Spec's CustomErrorAiSummary test (line 158): allow(ai_client_double).to receive(:chat).and_raise(CustomErrorAiSummary, 'AI provider error') -- this triggers the error from chat, never from the update call. The update-failure path (which would produce a message starting with 'Failed to update integrated analysis:') has zero coverage.

---

### `score_job_application_spec.rb`

**Code under test:** `app/services/ai_job_application_action/scoring/score_job_application.rb`
**File chain:** spec/services/ai_job_application_action/scoring/score_job_application_spec.rb -> app/services/ai_job_application_action/scoring/score_job_application.rb -> app/services/ai_job_application_action/scoring/calculate.rb -> app/services/ai_job_application_action/summary/anonymize_for_ai.rb -> app/services/ai_job_application_action/scoring/prompts/job_application_scoring.rb -> app/services/ai_job_application_action/scoring/prompts/scoring_display.rb -> app/services/ai_client.rb -> app/models/ai_job_criteria.rb -> app/models/ai_job_application_summary.rb -> app/models/job.rb#extract_job_criteria

**Summary:** This spec file has two BLOCKER findings and three HIGH findings, all stemming from a fundamental setup defect: the ai_job_application_summary is created without populating the structured_data column. The production code (score_job_application.rb lines 34-37) checks structured_data immediately after the criteria guard and raises CustomErrorAiSummary when it is blank. Since the spec never sets structured_data (and the column has no default), every test in the happy path context (4 tests) and the error handling context (3 tests) is a ghost test -- they cannot pass as written and exercise the wrong code paths. Beyond the broken tests, the spec's display_response stub uses the wrong key name ('summary' instead of 'display_sentence'), creating a drift between the test assertions and the production code's actual merge behavior. Additionally, the spec has no coverage for the boundary re-scoring logic (lines 66-87 of production), which is a major code path that triggers up to 5 AI calls and median-selects the result, nor for the structured_data and empty criteria guard branches. Of the 10 it blocks in this spec, 3 tests in the criteria-not-available context appear valid, 7 tests are fundamentally broken.

**F1 [BLOCKER] [Prong 1: works] All happy path tests are ghost tests: structured_data is never set, causing CustomErrorAiSummary before any AI call**
- Location: `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb:17-26 (let!) and lines 139-198 (happy path context)`
- The ai_job_application_summary is created at lines 17-26 without setting the structured_data column (a jsonb column with no default). In production code (score_job_application.rb lines 34-37), structured_data is checked immediately after the criteria guard: `structured_data = @ai_job_application_summary.structured_data || {}` then `if structured_data.blank?` raises `CustomErrorAiSummary, "Structured data missing"`. Since nil || {} gives {}, and {}.blank? is true, every happy path test (lines 154-198) hits this raise before any AI client calls. The rescue at line 127-131 catches CustomErrorAiSummary, sets status to :retrying, and re-raises. The tests call .score without expect { }.to raise_error, so they will raise an unhandled exception and fail. These four tests -- 'transitions status to integrating', 'populates score_percentage', 'populates criteria_results with merged data', 'creates AiApiRequest records for both calls' -- cannot pass as written and test nothing they claim to test.
- Evidence: Spec lines 17-26: AiJobApplicationSummary.create! with headline, summary_text, status, stale, job_application, textract_result -- no structured_data. Production score_job_application.rb lines 34-37: `structured_data = @ai_job_application_summary.structured_data || {}; if structured_data.blank?; raise CustomErrorAiSummary, "Structured data missing..."`. The column has no default (db/schema.rb line 150: t.jsonb "structured_data"). No callback or factory sets it.

**F2 [BLOCKER] [Prong 1: works] All error handling tests are ghost tests: same structured_data nil issue means errors fire for the wrong reason**
- Location: `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb:200-254 (error handling context)`
- The error handling context (lines 200-254) shares the same ai_job_application_summary without structured_data. All three error tests -- CustomErrorAiSummary (line 210), JSON::ParserError (line 225), StandardError (line 241) -- will have their intended error paths preempted by the structured_data guard raising CustomErrorAiSummary at line 36-37 of production code. (1) The CustomErrorAiSummary test at line 210-223 expects error_message to include 'AI provider error' but gets 'Structured data missing...', so the assertion at line 222 fails. (2) The JSON::ParserError test at line 225-239 expects not_to raise_error, but CustomErrorAiSummary is raised and re-raised, so it fails. (3) The StandardError test at line 241-254 also expects not_to raise_error but gets a re-raised CustomErrorAiSummary.
- Evidence: Production score_job_application.rb lines 34-37 raise CustomErrorAiSummary before the ai_client.chat call that the error tests stub. Rescue at line 127-131 catches CustomErrorAiSummary, sets status to :retrying (not :failed as the JSON/StandardError tests expect), and re-raises. The stubs at lines 211, 227, 242 (allow(ai_client_double).to receive(:chat).and_raise/and_return) are never reached.

**F3 [HIGH] [Prong 3: drift] Display response stub uses wrong key 'summary' instead of 'display_sentence'; assertion targets nonexistent key**
- Location: `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb:58-72 and line 186`
- The spec's display_response at lines 58-72 returns criteria entries with the key 'summary'. The production code at score_job_application.rb line 114 merges display data using the key 'display_sentence' (matching the ScoringDisplay JSON schema at scoring_display.rb lines 44-46 which requires 'display_sentence'). The spec assertion at line 186 checks results.first['summary'] -- a key that will never exist in the merged criteria_results. Even if the structured_data issue were fixed, this assertion would fail because the production code writes 'display_sentence', not 'summary'.
- Evidence: Spec line 62: 'summary' => 'Strong Ruby background...'. Production score_job_application.rb line 114: score_entry.merge('display_sentence' => display_entry&.dig('display_sentence') || ''). ScoringDisplay JSON schema (scoring_display.rb line 44): display_sentence: { type: 'string' }. Spec line 186: expect(results.first['summary']).to eq('Strong Ruby background...').

**F4 [HIGH] [Prong 3: drift] No coverage for boundary re-scoring logic (5 AI calls + median selection)**
- Location: `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb (entire file)`
- The production code at score_job_application.rb lines 66-87 implements a significant code path: when the initial score is within 5 points of 40, 60, or 80, it runs 4 additional scoring calls and selects the median result. This boundary re-scoring is a core business logic branch that controls whether candidates get 1 AI call or 5. The spec has zero tests for this path -- no test with a score near a boundary, no test verifying median selection, no test verifying behavior when additional runs fail (returning nil).
- Evidence: Production score_job_application.rb lines 66-87: `near_boundary = [40, 60, 80].any? { |b| (first_score - b).abs <= 5 }; if near_boundary; ... 4.times do |i| run = run_scoring(...); ... end; sorted_runs = ...; median_index = ...; selected_run = sorted_runs[median_index]`. Spec: grep for 'boundary', 'median', 'near_boundary' returns no matches.

**F5 [HIGH] [Prong 3: drift] No coverage for structured_data blank guard or empty criteria guard**
- Location: `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb (entire file)`
- Two guard branches in the production code have no spec coverage: (1) score_job_application.rb lines 34-37 -- when structured_data is blank, raises CustomErrorAiSummary. This is the very guard that breaks all existing tests. (2) score_job_application.rb lines 43-48 -- when criteria array is empty despite AiJobCriteria being succeeded, it fails the criteria record, sets awaiting_job_criteria, triggers extract_job_criteria, and returns. Neither path is tested.
- Evidence: Production score_job_application.rb line 35: `if structured_data.blank?; raise CustomErrorAiSummary, "Structured data missing..."`. Line 43: `if criteria.blank?; ai_job_criteria.update_columns(status: :failed, ...); @ai_job_application_summary.update(status: :awaiting_job_criteria); @job.extract_job_criteria; return`. Spec: no describe/context/it block names or assertions reference structured_data or empty criteria.

**F6 [MED] [Prong 3: drift] No coverage for run_scoring internal failure (nil return) and 'Scoring call failed' raise**
- Location: `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb (entire file)`
- The production code's run_scoring private method (lines 187-221) has its own rescue block that returns nil on any StandardError. The score method at line 58 checks `raise CustomErrorAiSummary, "Scoring call failed" unless first_run`. The spec never tests the scenario where the first scoring call fails internally (e.g., JSON parse error inside run_scoring) and returns nil, triggering this raise path.
- Evidence: Production score_job_application.rb lines 218-221: `rescue StandardError => e; ap ...; nil; end`. Line 58: `raise CustomErrorAiSummary, "Scoring call failed" unless first_run`. No spec test simulates a chat response that causes run_scoring to return nil via its internal rescue.

---

### `plan_feature_gate_ai_credits_spec.rb`

**Code under test:** `app/services/plan_feature_gate.rb`
**File chain:** spec/services/plan_feature_gate_ai_credits_spec.rb -> app/services/plan_feature_gate.rb -> config/initializers/01_variables.rb (Variables::AI_DAILY_CREDIT_ALLOCATION)

**Summary:** The spec is fundamentally sound. It tests real PlanFeatureGate instances with no stubs, so there is zero ghost-test risk. The monthly_ai_credit_allocation tests are comprehensive -- all 14 plans in plan_rules are tested with correct expected values, plus the unknown-plan fallback. The daily_ai_credit_allocation tests are thin (3 of 14 plans plus fallback) and the test description overstates its coverage by claiming "each configured plan tier." Since all 14 plans currently use the same DAILY_AI_CREDIT_ALLOCATION constant, the gap is low-risk today, but if any plan later gets a different daily allocation the spec would not catch the change. No stubs exist to drift. No convention violations found. One MED finding for the misleading test description.

**F1 [MED] [Prong 2: tests what it claims] daily_ai_credit_allocation test name claims 'each configured plan tier' but only tests 3 of 14**
- Location: `spec/services/plan_feature_gate_ai_credits_spec.rb:44-48`
- The it-block description says 'returns DAILY_AI_CREDIT_ALLOCATION for each configured plan tier' but the test only exercises plan_ats_tier_starter_v2, plan_ats_tier_growth_v2, and plan_ats_tier_scale_v2. The production plan_rules hash defines daily_ai_credit_allocation for all 14 plans. The test name is misleading -- it implies comprehensive plan coverage that does not exist. This is not a ghost (the 3 plans tested DO exercise real production code), but the describe text overstates coverage.
- Evidence: Spec line 44-48: tests only %w[plan_ats_tier_starter_v2 plan_ats_tier_growth_v2 plan_ats_tier_scale_v2]. Production plan_rules (plan_feature_gate.rb:142-246) defines daily_ai_credit_allocation: DAILY_AI_CREDIT_ALLOCATION for all 14 plans. The monthly_ai_credit_allocation test (lines 12-31) exhaustively tests all 14 plans, but the daily_ai_credit_allocation test does not mirror this approach.

---

### `cancel_credit_pack_subscription_spec.rb`

**Code under test:** `app/services/stripe/cancel_credit_pack_subscription.rb`
**File chain:** spec/services/stripe/cancel_credit_pack_subscription_spec.rb -> app/services/stripe/cancel_credit_pack_subscription.rb -> Stripe::Subscription.update (gem boundary, stop). Also traced caller: app/interactors/cancel_ai_credit_subscription.rb (confirms the service is called with purchase.stripe_subscription_id).

**Summary:** Clean spec. The production code is a single class method (self.cancel) with no branches, no guards, no callbacks -- it delegates directly to Stripe::Subscription.update with cancel_at_period_end: true and returns the result. The spec covers both code paths: (1) happy path verifies the correct arguments are forwarded to Stripe::Subscription.update and the return value is passed through, (2) error path verifies Stripe::StripeError propagates to callers. Neither test is a ghost -- deleting the production code would cause the have_received assertion to fail in test 1 and would raise NoMethodError instead of Stripe::StripeError in test 2. Stubs match the real Stripe::Subscription.update signature (positional subscription ID + keyword cancel_at_period_end). No drift detected -- the spec exactly reflects the current production code. No convention violations found.

No findings.

### `submit_resume_to_textract_spec.rb`

**Code under test:** `app/services/submit_resume_to_textract.rb`
**File chain:** spec/services/submit_resume_to_textract_spec.rb -> app/services/submit_resume_to_textract.rb -> app/services/textract_resume_parser.rb (TextractResumeParser::Client) -> app/models/textract_result.rb -> app/models/ai_job_application_summary.rb -> app/models/job_application.rb (has_resume, has_resume_docx_to_pdf, resume, hash_id, textract_results, ai_job_application_summaries) -> app/jobs/get_resume_text_from_textract_job.rb -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization, create_credit_test_job, create_credit_test_job_application)

**Summary:** The spec for SubmitResumeToTextract covers only the happy path: submitting a resume when one exists, creating a TextractResult, linking a waiting AiJobApplicationSummary, and enqueuing GetResumeTextFromTextractJob. The stub setup is accurate -- instance_double on TextractResumeParser::Client verifies method existence and arity, and the find_by_id stub correctly returns the stubbed job_application object. None of the three tests are ghosts; they all exercise the production code and make assertions that would fail if the production code were removed. However, the spec has significant drift from the production code: two early-return guard clauses (missing job_application, no resume), two rescue blocks (InvalidS3ObjectException and StandardError error recovery), the stale-marking business rule (update_all stale: true for existing summaries), the TextractResult save failure branch, and the DOCX-to-PDF resume selection branch are all untested. The most concerning gap is the error rescue blocks -- these handle AWS Textract integration failures and update the textract_result status to 'failed', which is critical for the system to detect and report processing failures.

**F1 [HIGH] [Prong 3: drift] No coverage for early-return guard clauses**
- Location: `spec/services/submit_resume_to_textract_spec.rb:50-58 vs app/services/submit_resume_to_textract.rb:9-10`
- The production code has two early-return guards: 'return JobApplication not found unless @job_application' (line 9) and 'return No resume attached unless @job_application.has_resume' (line 10). The spec has no context or it block that tests either guard. The 'JobApplication not found' case (nil job_application_id or nonexistent ID) and 'no resume attached' case are entirely unexercised.
- Evidence: Production code (submit_resume_to_textract.rb:9-10) returns string messages for missing job_application and missing resume. The spec's before block (line 17) stubs has_resume to always return true, and line 20 stubs find_by_id to always return a valid job_application. No test ever invokes submit_resume without these stubs in place, so neither guard clause is ever triggered.

**F2 [HIGH] [Prong 3: drift] No coverage for either rescue block (InvalidS3ObjectException and StandardError)**
- Location: `spec/services/submit_resume_to_textract_spec.rb (missing) vs app/services/submit_resume_to_textract.rb:31-40`
- The production code has two rescue blocks: one for Aws::Textract::Errors::InvalidS3ObjectException (lines 31-35) which updates textract_result status to 'failed' and logs, and a catch-all StandardError rescue (lines 36-40) that also marks the result as 'failed' and logs. Neither rescue path is tested. These are the error recovery paths for the AWS Textract integration -- if they silently broke (e.g., the textract_result reference became nil after a refactor), the status would never be set to 'failed' and the system would have no error signal.
- Evidence: The spec never configures the mock_parser to raise an exception. All test paths follow the happy path where send_to_textract returns mock_textract_response successfully. The production code at lines 31-40 has two distinct rescue blocks that update @textract_result and log errors -- none of this is exercised.

**F3 [HIGH] [Prong 3: drift] No coverage for stale-marking logic on existing summaries**
- Location: `spec/services/submit_resume_to_textract_spec.rb (missing) vs app/services/submit_resume_to_textract.rb:18-20`
- The production code at lines 18-20 contains an important business rule: unless a textract_processing summary already exists, ALL existing ai_job_application_summaries are marked stale via update_all(stale: true). This ensures old summaries are invalidated when a new textract submission starts. The spec never tests this path with pre-existing non-textract_processing summaries. In the 'no textract_processing summary exists' context (line 50), no summaries exist at all, so the update_all is a no-op. In the 'textract_processing summary exists' context (line 24), the exists? check returns true and the block is skipped.
- Evidence: Production code: 'unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists? then @job_application.ai_job_application_summaries.update_all(stale: true)'. The spec's 'when no textract_processing summary exists' context creates zero summaries (no let! for any AiJobApplicationSummary), so update_all runs against an empty collection. No test creates a pre-existing succeeded or failed summary and verifies it gets marked stale.

**F4 [MED] [Prong 3: drift] No coverage for TextractResult save failure path**
- Location: `spec/services/submit_resume_to_textract_spec.rb (missing) vs app/services/submit_resume_to_textract.rb:28-30`
- The production code at lines 24-30 checks the return value of @textract_result.save and has an else branch (line 29) that logs a failure message via ap. The spec never tests the case where the save fails (e.g., due to a validation error on TextractResult). The else branch would silently not enqueue GetResumeTextFromTextractJob and not update the waiting summary.
- Evidence: Production code: 'if @textract_result.save ... else ap Failed to save initial TextractResult ... end'. The spec always allows the save to succeed because the TextractResult is built with valid attributes (textract_job_id and textract_job_status). No test stubs .save to return false or creates conditions that would cause a save failure.

**F5 [MED] [Prong 3: drift] No coverage for has_resume_docx_to_pdf true branch**
- Location: `spec/services/submit_resume_to_textract_spec.rb:18 vs app/services/submit_resume_to_textract.rb:15`
- The production code at line 15 selects between resume_docx_to_pdf and resume based on has_resume_docx_to_pdf. The spec always stubs has_resume_docx_to_pdf to return false (line 18), so the code path where a DOCX-converted PDF is used instead of the raw resume is never exercised.
- Evidence: Production code: 'resume_for_textract = @job_application.has_resume_docx_to_pdf ? @job_application.resume_docx_to_pdf : @job_application.resume'. Spec line 18: 'allow(job_application).to receive(:has_resume_docx_to_pdf).and_return(false)'. No test sets has_resume_docx_to_pdf to true and verifies resume_docx_to_pdf is used.

---
