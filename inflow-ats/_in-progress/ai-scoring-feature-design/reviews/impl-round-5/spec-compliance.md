# spec-compliance -- Round 5

## Scope
Verify implementation matches every requirement in SPEC.md. Walk spec section by section.

## Section 1: `ai_job_criteria` table

- Table created with correct columns: `status` (integer, NOT NULL, default 0), `criteria` (jsonb, nullable), `metadata` (jsonb, nullable), `error_message` (text, nullable). Verified in migration and schema.
- `t.references :job` with `null: false, foreign_key: true, index: false` + separate `add_index :ai_job_criteria, :job_id, unique: true`. Correct.
- Status enum with `_prefix: true`: `pending: 0`, `in_progress: 1`, `succeeded: 2`, `failed: 3`. Verified in model.
- `after_commit` callback: fires on `saved_change_to_status? && status_succeeded?`, finds waiting summaries, enqueues jobs. Verified.
- Uses `update` (not `update_columns`) for `succeeded` transitions in `ExtractCriteria`. Verified at line 120.

## Section 2: `ai_job_application_summary_statuses` table

- Table created with correct columns: `job_application_id` (NOT NULL, FK), `ai_job_application_summary_id` (nullable, FK), `regenerating` (boolean, NOT NULL, default false). Verified.
- Unique index on `job_application_id`. Verified.
- Model has `belongs_to :job_application`, `belongs_to :ai_job_application_summary, optional: true`, `validates :job_application_id, uniqueness: true`. Verified.

## Section 3: Modified `ai_job_application_summaries`

- New columns added to existing migration: `score_percentage` (decimal), `criteria_results` (jsonb), `integrated_role_analysis` (text). All nullable. Verified.
- Redesigned status enum: 10 values with correct mappings. Verified.
- `Summary::Generate` updated: `in_progress` -> `extracting`, `extracted` -> `summarizing`, `succeeded` removed from final update. Verified.
- Serializers updated: full serializer has all 3 new attributes, shallow serializer has `score_percentage`. Verified.
- `has_one :ai_job_application_summary_status` on `AiJobApplicationSummary`. Verified.
- `has_one :ai_job_application_summary_status` on `JobApplication`. Verified.
- Status record serializer and `ShallowJobApplicationSerializer` integration. Verified.

## Section 4: Scoring orchestration services

- `ExtractCriteria`: 2 calls (gpt-4.1-mini + gpt-4o), heading override, dedup, status transitions, error handling matching `Summary::Generate` pattern. Verified.
- `ScoreJobApplication`: criteria check, awaiting_job_criteria path, 2 calls (Gemini), Calculate delegation, merge results, status transitions. Verified.
- `Calculate`: tier weights (6/4/2), score values (1.0/0.7/0.0), title technology multiplier (3x), formula correct. Verified.
- `IntegrateAnalysis`: reads structured_data + criteria_results, 1 AI call, sets `integrated_role_analysis`, transitions to `succeeded`. Verified.
- Prompt files: 4 frozen files untouched (confirmed via `git log`). `integrated_analysis.rb` created as new file. Verified.

## Section 5: Pipeline orchestrator

- `Orchestrate` takes `textract_result_id:`, matches `Summary::Generate` constructor. Verified.
- Status-based resume logic covers all 10 statuses. Verified.
- `summary_complete?` checks `headline` and `summary_text` presence. Verified.
- Criteria gap handling: sets `awaiting_job_criteria`, triggers `extract_job_criteria` if not pending/in_progress. Verified.

## Section 6: Orchestrator integration into TextractResult

- `generate_ai_summary` now calls `Orchestrate.new(textract_result_id: id).call`. Verified.
- Made private. Verified.
- All trigger paths documented in spec Section 5 flow through correctly. Verified.

## Section 7: Job lifecycle triggering

- `extract_job_criteria` added to `handle_status_changed_to_published`. Verified.
- `handle_description_change` added to `handle_before_update`. Verified.
- `description_meaningfully_changed?` strips HTML, removes non-alpha, lowercases. Verified.
- `ExtractJobCriteriaJob` with retry/exhaustion pattern. Verified.
- 2-minute delay on job enqueue. Verified.
- Debounce via `pending` status check. Verified.

## Section 8: Credit consumption, Flipper, broadcasting

- Reuses `:AI_APPLICANT_SUMMARY` flag. Verified.
- 1 credit per evaluation, consumed only at `succeeded`. Verified.
- `AI_SUMMARY_COMPLETE` broadcast fires after `succeeded`. Verified.

## Section 9: Test plan

- Existing tests updated for enum changes. Verified.
- New specs for all new models, services, jobs, lifecycle. Verified (9 new spec files).

## Findings

None.
