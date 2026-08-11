# spec-compliance -- Round 4

## Scope

Verify every spec requirement is implemented in the committed code. Trace spec sections to implementation.

## Findings

### Section 1: ai_job_criteria table

- Migration `20260611120000_create_ai_job_criteria.rb`: `t.references :job, null: false, foreign_key: true, index: false` + `add_index :ai_job_criteria, :job_id, unique: true`. Columns: `status` (integer, NOT NULL, default 0), `criteria` (jsonb, nullable), `metadata` (jsonb, nullable), `error_message` (text, nullable), `timestamps`. MATCHES.
- Model: `belongs_to :job`, `has_many :ai_api_requests, as: :requestable`, status enum with `_prefix: true` (4 values). MATCHES.
- `after_commit` callback on `succeeded`: finds `awaiting_job_criteria` summaries, enqueues jobs. Uses `update` for `succeeded` (in `ExtractCriteria`), `update_columns` for `failed`. MATCHES.
- Heading tier override: implemented in `ExtractCriteria` with soft skill skip. MATCHES.
- Dedup: filters `duplicate: true`, deletes `duplicate` key from stored criteria. MATCHES.
- Metadata: `title_technology`, `raw_criteria_count`, `criteria_count`. MATCHES.

### Section 2: ai_job_application_summary_statuses table

- Migration `20260611120001`: unique index on `job_application_id`, foreign key on `ai_job_application_summary`, `regenerating` (boolean, NOT NULL, default false). MATCHES.
- Model: `belongs_to :job_application`, `belongs_to :ai_job_application_summary, optional: true`, validates uniqueness. MATCHES.
- Lifecycle: created when AI evaluation kicks off (via `after_commit :create_status_record` on `AiJobApplicationSummary` and `CreateAiSummaryGeneration`). Updated when summary reaches `succeeded`. MATCHES.

### Section 3: ai_job_application_summaries modifications

- Three new columns added to existing migration: `score_percentage` (decimal, nullable), `criteria_results` (jsonb, nullable), `integrated_role_analysis` (text, nullable). MATCHES.
- Status enum redesigned to 10 values with correct integer mappings. MATCHES.
- `Summary::Generate` updated: `in_progress` -> `extracting`, `extracted` -> `summarizing`, `succeeded` removed from final update. MATCHES.
- Serialization: full serializer adds 3 new attributes, shallow adds `score_percentage`. MATCHES.
- `has_one :ai_job_application_summary_status` added to `AiJobApplicationSummary` and `JobApplication`. MATCHES.

### Section 4: Scoring orchestration services

- `ExtractCriteria`: Call 1 (openai, `JobDescriptionStructuredData.model`), Call 2 (openai, `JobDescriptionCriteriaExtraction.model`), heading override, dedup, `AiApiRequest` tracking, `update` for succeeded, `update_columns` for failed. MATCHES.
- `ScoreJobApplication`: criteria check with `awaiting_job_criteria` fallback, scoring call (gemini), display call (gemini), `Calculate` delegation, `AiApiRequest` tracking. MATCHES.
- `Calculate`: tier weights (6/4/2), score values (1.0/0.7/0.0), title technology 3x multiplier, formula. MATCHES.
- `IntegrateAnalysis`: reads `structured_data` fields + `criteria_results` + `score_percentage`, one AI call, writes `integrated_role_analysis`, transitions to `succeeded`. MATCHES.

### Section 5: Pipeline orchestrator

- `Orchestrate`: constructor takes `textract_result_id:`, resumes from status checkpoints, criteria gap handling with `extract_job_criteria` trigger. MATCHES.
- Four entry points all reach `Orchestrate` through `generate_ai_summary_with_credit_flow`. MATCHES.

### Section 6: Integration into TextractResult

- `generate_ai_summary` calls `Orchestrate`, moved to private. MATCHES.
- `textract_result_id` parameter chain intact. MATCHES.
- Resume from `awaiting_job_criteria` via callback. MATCHES.

### Section 7: Job lifecycle triggering

- `extract_job_criteria`: Flipper gate, debounce, 2-minute delay, all status handling. MATCHES.
- `handle_description_change`: guards, called from `handle_before_update`. MATCHES.
- `description_meaningfully_changed?`: HTML strip, non-alpha removal, lowercase. MATCHES.
- `ExtractJobCriteriaJob`: queue, retry, exhaustion block, `find_by` guard. MATCHES.

### Section 8: Credit, Flipper, broadcasting

- Flipper: reuses `:AI_APPLICANT_SUMMARY`. MATCHES.
- Credit: 1 per evaluation, consumed at `succeeded`. MATCHES.
- Broadcasting: `AI_SUMMARY_COMPLETE` fires after `succeeded`. MATCHES.

### Section 9: Test plan

- Existing tests updated (enum spec). MATCHES.
- New specs: `ai_job_criteria_spec`, `ai_job_application_summary_status_spec`, `extract_job_criteria_job_spec`, `extract_criteria_spec`, `score_job_application_spec`, `calculate_spec`, `integrate_analysis_spec`, `orchestrate_spec`, `job_criteria_lifecycle_spec`. MATCHES.

## Result: PASS -- 0 findings
