# Branch Notes: `feature-ai-summaries-integrating-scoring-v3`

Branched from: `feature-ai-credits-summaries-scoring-qa-qa`
Created: 2026-06-11

## Changes on this branch (not part of the scoring spec)

These changes are pre-work and cleanup. A QA diff against the parent branch will surface them. They are intentional and should not be flagged as out-of-spec.

### 1. Retry/exhaustion handling on `GenerateAiJobApplicationSummaryJob`
- Added exhaustion block to `retry_on CustomErrorAiSummary` — sets `failed` and broadcasts only when all retries spent
- Removed broadcast from `CustomErrorAiSummary` rescue — no intermediate failure messages to user
- `StandardError` rescue now explicitly sets `failed` on the summary before broadcasting
- **Why:** User was seeing multiple failure toasts before retries. Now sees exactly one broadcast per evaluation (success or final failure).

### 2. `retrying` status on `AiJobApplicationSummary`
- Added `retrying: 7` to the status enum
- `Summary::Generate` sets `retrying` (not `failed`) on `CustomErrorAiSummary`, then re-raises
- `Summary::Generate` reuse list now includes `retrying` — on retry, reuses the existing record instead of creating a new one
- **Why:** Previously, each retry created a new `AiJobApplicationSummary` record. Now one record persists across retries.

### 3. Scoring prompt cleanup
- Deleted unused prompt files: `criteria_review.rb`, `criteria_decomposer.rb`, `criteria_decomposition_judge.rb`, `criteria_expansion.rb` (saved to hub scratchpad)
- Renamed `candidate_criteria_scoring.rb` → `job_application_scoring.rb`, class `CandidateCriteriaScoring` → `JobApplicationScoring`
- Updated all rake file references to the renamed class
- Deleted `ai_scoring_expansion.rake` (referenced deleted `CriteriaExpansion` prompt)

### 4. MODEL constants pinned to API-returned versions
- `job_description_structured_data.rb`: `gpt-4.1-mini` → `gpt-4.1-mini-2025-04-14`
- `job_description_criteria_extraction.rb`: `gemini-3.1-flash-lite` → `gpt-4o-2024-08-06` (model was wrong AND unpinned)
- `job_application_scoring.rb`: `gpt-4o-mini` → `gemini-3.1-flash-lite` (model was wrong)
- `scoring_display.rb`: added `MODEL = 'gemini-3.1-flash-lite'` and `model` method (had neither)

### 5. AiClient PRICING hash keys updated
- `gpt-4o` → `gpt-4o-2024-08-06`
- `gpt-4o-mini` → `gpt-4o-mini-2024-07-18`
- `gpt-4.1-mini` → `gpt-4.1-mini-2025-04-14`
- **Why:** API returns versioned model names. Old keys didn't match, so `calculate_cost` returned nil and cost column stored $0.0.

### 6. Bulk AI summary frontend refactor (from stash — pre-existing)
- `BulkAiJobApplicationSummariesController`: changed from `job_application_ids` to `job_id` + `hiring_stage_id` + `included/excluded_job_application_ids`. ID resolution moved server-side.
- `BulkGenerateAiSummariesConfirmModal`: mutation moved into modal (was in `JobStageMenu`). Modal owns full lifecycle.
- `JobStageMenu`: stripped down, no longer imports mutation hook or toast context.
- `useBulkGenerateAiSummaries`: params interface updated to match controller.

### 7. Data migration made reversible (from stash — pre-existing)
- `20260408040802_add_ai_settings_to_existing_organizations.rb`: `down` method changed from `IrreversibleMigration` to dev-only settings cleanup.

### 8. OpenAI provider temperature (from stash — pre-existing)
- `app/services/ai_providers/openai.rb`: `temperature: 0` added to request body.

### 9. schema.rb restored
- Stash contained stale schema.rb diff from local DB state drift. Restored to branch state. Not committed.
