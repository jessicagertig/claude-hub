# data-model-contracts -- Round 3

## Files reviewed

- `app/models/ai_job_criteria.rb` -- `criteria` and `metadata` jsonb
- `app/models/ai_job_application_summary.rb` -- enum, associations
- `app/models/ai_job_application_summary_status.rb` -- read model
- `app/serializers/api/v1/ai_job_application_summary_serializer.rb` (working tree)
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb` (working tree)
- `db/migrate/20260611120000_create_ai_job_criteria.rb`
- `db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb`
- `db/migrate/20260311120000_create_ai_job_application_summaries.rb` (working tree)

## Assessment

1. **`criteria_results` jsonb shape:** `ScoreJobApplication` produces `{ criterion_text, tier, contains_title_technology, score, reasoning, summary }` per element. Matches spec Section 3 exactly. Serializer exposes it via `attributes :criteria_results`.

2. **`AiJobApplicationSummaryStatus` read model:** `belongs_to :job_application` (required), `belongs_to :ai_job_application_summary, optional: true`, `validates :job_application_id, uniqueness: true`. Database unique index on `job_application_id`. Correct per spec Section 2.

3. **New columns on `ai_job_application_summaries`:** Working tree migration adds `score_percentage` (decimal), `criteria_results` (jsonb), `integrated_role_analysis` (text). All nullable, no defaults. Correct per spec Section 3.

4. **`AiJobCriteria` migration:** `job_id` with foreign key, unique index (using `index: false` on `t.references` + separate `add_index` with unique). `status` integer NOT NULL default 0. `criteria` jsonb nullable. `metadata` jsonb nullable. `error_message` text nullable. Timestamps. Correct per spec Section 1.

5. **`AiApiRequest` polymorphic:** `requestable` on `AiApiRequest` already supports polymorphic types. `ExtractCriteria` sets `requestable: @ai_job_criteria`, `ScoreJobApplication` and `IntegrateAnalysis` set `requestable: @ai_job_application_summary`. No schema change needed. Correct.

6. **Serializer output (working tree):** Full serializer includes all three new attributes. Shallow serializer includes `score_percentage`. Status serializer exposes `id, ai_job_application_summary_id, regenerating`. `ShallowJobApplicationSerializer` has `has_one :ai_job_application_summary_status`. All correct per spec Sections 3 and 2.

7. **Controller eager loading (working tree):** Both index actions in `job_applications_controller.rb` add `.includes(:ai_job_application_summary_status)`. Correct per plan H.4.2.

## Findings

No NEW findings beyond BLOCKER-1 (migration and serializer changes are uncommitted).
