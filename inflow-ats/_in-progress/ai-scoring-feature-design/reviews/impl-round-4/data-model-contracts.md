# data-model-contracts -- Round 4

## Scope

jsonb shape consistency between writers and readers, read model sync, new column nullability/defaults, polymorphic `AiApiRequest` attachment.

## Findings

### criteria_results jsonb shape

`ScoreJobApplication#score` writes `criteria_results` as an array with elements: `criterion_text`, `tier`, `contains_title_technology`, `score`, `reasoning`, `summary`. Matches spec Section 3 exactly.

`AiJobApplicationSummarySerializer` exposes `criteria_results` as a regular attribute -- no transformation. Direct column exposure per `cursor_rules/backend/serializers.md` Rule 1.

### AiJobCriteria.criteria jsonb shape

`ExtractCriteria#extract` writes `criteria` as an array with elements: `text`, `tier`, `tier_reasoning`, `binary`, `contains_title_technology`, `source_heading`, `source_text`. The `duplicate` field is deleted before storage. Matches spec Section 1.

`ScoreJobApplication#score` reads `criteria` via `ai_job_criteria.criteria` and accesses `['text']` and `['contains_title_technology']`. These fields exist in the stored shape. Contract consistent.

### AiJobCriteria.metadata jsonb shape

`ExtractCriteria#extract` writes `metadata` as: `title_technology`, `raw_criteria_count`, `criteria_count`. Matches spec Section 1.

### New columns on ai_job_application_summaries

Migration adds `t.decimal :score_percentage`, `t.jsonb :criteria_results`, `t.text :integrated_role_analysis`. All nullable with no default -- correct per spec Section 3. Populated only when scoring/integration completes.

### AiJobApplicationSummaryStatus read model

- `belongs_to :job_application` (required)
- `belongs_to :ai_job_application_summary, optional: true`
- `validates :job_application_id, uniqueness: true` (model-level)
- Database unique index on `job_application_id`
- `regenerating` defaults to `false`, `NOT NULL`
- Created via `find_or_create_by` -- idempotent (called from both `after_commit :create_status_record` on `AiJobApplicationSummary` and from `CreateAiSummaryGeneration`)
- Updated via `update_columns` in `update_summary_status_record` when summary reaches `succeeded`

Lifecycle matches spec Section 2.

### AiApiRequest polymorphic attachment

`AiJobCriteria` has `has_many :ai_api_requests, as: :requestable`. `ExtractCriteria` creates `AiApiRequest` records with `requestable: @ai_job_criteria`. The `ai_api_requests` table already has `requestable_type` and `requestable_id` polymorphic columns. No migration needed -- polymorphic associations accept any type. Correct.

### Serializers

- Full serializer: adds `score_percentage`, `criteria_results`, `integrated_role_analysis`. Matches spec Section 3.
- Shallow serializer: adds `score_percentage`. Matches spec Section 3.
- Status serializer: `id`, `ai_job_application_summary_id`, `regenerating`. Matches spec Section 2.
- `ShallowJobApplicationSerializer`: `has_one :ai_job_application_summary_status`. Matches spec Section 2.
- Controller eager loading: `.includes(:ai_job_application_summary_status)` on both paginated queries. Prevents N+1.

## Result: PASS -- 0 findings
