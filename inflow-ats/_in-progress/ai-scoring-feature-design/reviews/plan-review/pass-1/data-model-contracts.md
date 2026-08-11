# Pass 1 — data-model-contracts

## Fact Check

### `AiApiRequest` polymorphic `requestable`

Plan B.1.1 adds `has_many :ai_api_requests, as: :requestable` to `AiJobCriteria`. Verified `AiApiRequest` model at `app/models/ai_api_request.rb`:
```ruby
belongs_to :requestable, polymorphic: true
```
Polymorphic association — no table changes needed for new `requestable_type`. CORRECT.

### Existing migration — `20260311120000_create_ai_job_application_summaries.rb`

Plan A.1.3 adds `t.decimal :score_percentage`, `t.jsonb :criteria_results`, `t.text :integrated_role_analysis` inside the `create_table` block. Verified the migration at `db/migrate/20260311120000_create_ai_job_application_summaries.rb` — the `create_table` block has the expected structure. CORRECT.

### `criteria_results` jsonb shape

Plan D.2.5 builds `criteria_results` with keys: `criterion_text`, `tier`, `contains_title_technology`, `score`, `reasoning`, `summary`. Spec Section 3 specifies the same 6 keys. CORRECT — shapes match.

### `AiJobCriteria.criteria` jsonb shape

Plan D.1.5-D.1.6 produces criteria with keys: `text`, `tier`, `tier_reasoning`, `binary`, `contains_title_technology`, `source_heading`, `source_text` (after dedup removes `duplicate`). Spec Section 1 specifies the same 7 keys. CORRECT.

### `AiJobCriteria.metadata` jsonb shape

Plan D.1.7 builds metadata with keys: `title_technology`, `raw_criteria_count`, `criteria_count`. Spec Section 1 specifies the same 3 keys. CORRECT.

### `AiJobApplicationSummaryStatus` model

Plan B.2.1 creates with `belongs_to :job_application`, `belongs_to :ai_job_application_summary, optional: true`, and `validates :job_application_id, uniqueness: true`. Spec Section 2 matches. CORRECT.

### `AiJobApplicationSummaryStatusSerializer`

Plan H.3.1 creates with `attributes :id, :ai_job_application_summary_id, :regenerating`. Spec Section 2 says frontend accesses `ai_job_application_summary_id` and `regenerating`. CORRECT.

### Serializer attribute lists

Plan H.1.1 adds `score_percentage`, `criteria_results`, `integrated_role_analysis` to full serializer. Spec Section 3 says same. CORRECT.

Plan H.2.1 adds `score_percentage` to shallow serializer. Spec Section 3 says same. CORRECT.

### `ShallowJobApplicationSerializer` eager loading

Plan H.4.1 notes the implementing agent should add `.includes(:ai_job_application_summary_status)` to the controller query. Verified: `app/controllers/api/v1/job_applications_controller.rb` lines 25 and 35 use `ShallowJobApplicationSerializer` with `.includes(resume_attachment: :blob)`. The plan correctly identifies this needs updating. However, the plan does NOT include modifying the controller as an explicit task step.

### Migration for `ai_job_criteria` — duplicate index issue

Plan A.2.2 correctly notes `t.references :job` adds `index: true` by default and uses `index: false` with a separate `add_index :ai_job_criteria, :job_id, unique: true`. CORRECT handling.

### Migration for `ai_job_application_summary_statuses` — index naming

Plan A.3.2 uses `name: 'idx_ai_summary_statuses_on_job_application_id'` for the unique index. This follows the existing pattern in the `create_ai_job_application_summaries` migration (line 18: `name: 'idx_ai_job_app_summaries_on_job_app_id_and_created_at'`). CORRECT.

## Completeness

- [x] `criteria_results` shape matches between ScoreJobApplication output and serializer
- [x] `AiJobCriteria.criteria` shape matches between ExtractCriteria output and ScoreJobApplication input
- [x] `AiJobApplicationSummaryStatus` read model matches spec
- [x] New columns nullable and defaultless
- [x] `AiApiRequest` polymorphic works for new requestable type
- [x] Migration rollback procedure documented (A.1)

## Findings

**F4 [MED] — Controller eager loading for `ShallowJobApplicationSerializer` not a task step**

Where: Phase H, step H.4.1.

What: The plan notes "The implementing agent should find where `ShallowJobApplicationSerializer` is used in controllers and add `.includes(:ai_job_application_summary_status)` to the query" but this is a comment, not a checkbox task step. The controllers at `app/controllers/api/v1/job_applications_controller.rb` lines 25 and 35 need `.includes(:ai_job_application_summary_status)` added to their query chains. Without an explicit task step, this will be missed.

Evidence: `grep -rn "ShallowJobApplicationSerializer" --include="*.rb" app/controllers/` shows two usages in `job_applications_controller.rb`.

Fix: Add explicit task step H.4.2 to modify `app/controllers/api/v1/job_applications_controller.rb` lines 25 and 35 to add `.includes(:ai_job_application_summary_status)` to the existing `.includes(resume_attachment: :blob)` chain. Also add this file to the "Modified Files" table.
