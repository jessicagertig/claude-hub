# QA MED Findings -- AI Scoring Integration

Consolidated MED findings from all layers across all runs.

## MED-1: OpenAI provider temperature=0 globally applied (Layer 1)

`app/services/ai_providers/openai.rb` adds `temperature: 0` to all OpenAI chat requests. This affects existing summary calls (Calls 1-4), not just the new scoring calls. Likely intentional for reproducibility but changes pre-existing behavior. Also adds timeout settings (120s timeout, 30s open_timeout) which affect all OpenAI calls.

## MED-2: Rake tasks reference non-existent CriteriaReview class (Layer 1)

`lib/tasks/ai_scoring_pipeline.rake` references `AiJobApplicationAction::Scoring::Prompts::CriteriaReview` which does not exist in the codebase. Will cause `NameError` if those specific rake tasks (`ai:scoring:pipeline` or `ai:scoring:stability`) are run. These are development/benchmarking tools only -- not part of the production feature.

## MED-3: ExtractCriteria error handling deviates from spec pattern (Layer 1)

Spec says ExtractCriteria should follow "same error handling pattern as Summary::Generate." Summary::Generate sets `retrying` on `CustomErrorAiSummary`. ExtractCriteria sets `failed` because `AiJobCriteria` has no `retrying` status. Functionally correct (the job retries regardless, and the service resets to `in_progress` on re-entry) but deviates from the spec's stated pattern.

## MED-4: Bulk controller + frontend changes not in spec (Layer 1)

The spec says "Frontend is out of scope." The diff includes frontend changes to `BulkGenerateAiSummariesConfirmModal.tsx`, `JobStageMenu.tsx`, and `useBulkGenerateAiSummaries.ts`, plus the backend `BulkAiJobApplicationSummariesController` refactor. These are a pre-work analog pattern fix (Known Failure Pattern #14) that should have been enumerated in the spec. The changes are correct.

## MED-5: GenerateAiJobApplicationSummaryJob exhaustion block behavioral change (Layer 1)

Added exhaustion block, changed retry broadcast behavior. Previously each retry attempt would broadcast to the frontend; now only exhaustion and StandardError do. Changes user-visible behavior (fewer error toasts during retries). Correct per analog pattern but not in spec.

## MED-6: Supporting infrastructure changes not enumerated in spec (Layer 1)

AiClient pricing table expansion, date parsing fix in Summary::Generate, data migration made reversible. All necessary and correct but not explicitly spec'd.

## MED-7: Flipper test configuration issue (Layer 4)

`spec/models/job_criteria_lifecycle_spec.rb` test "when Flipper is disabled returns without creating criteria" fails. The test enables AI_APPLICANT_SUMMARY for the organization in a `before` block, then disables it in a nested `before` block. The Flipper actor gate behavior causes the disable to not fully override the enable. This is a test setup issue, not a code defect -- the `extract_job_criteria` Flipper guard works correctly at the application level.
