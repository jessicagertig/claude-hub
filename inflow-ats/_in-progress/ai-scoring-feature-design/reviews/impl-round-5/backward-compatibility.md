# backward-compatibility -- Round 5

## Scope
All consumers of modified code verified. Critical: every reference to status enum methods on `AiJobApplicationSummary` across the entire codebase.

## Exhaustive status reference audit

### Removed enum values: `in_progress`, `extracted`

Grep for `status_in_progress\|status: :in_progress\|status_extracted\|status: :extracted` across all `*.rb` files in `app/` and `spec/`:

Hits found:
- `app/services/ai_job_application_action/orchestrate.rb:80` -- `ai_job_criteria&.status_in_progress?` -- this is on `AiJobCriteria`, which still has `in_progress`. SAFE.
- `app/services/ai_job_application_action/scoring/extract_criteria.rb:28` -- `@ai_job_criteria.status_in_progress?` -- on `AiJobCriteria`. SAFE.
- `spec/models/job_criteria_lifecycle_spec.rb:61` -- `AiJobCriteria.create!(status: :in_progress)` -- on `AiJobCriteria`. SAFE.
- `spec/models/textract_result_ai_trigger_spec.rb:47` -- `textract_job_status: :in_progress` -- on `TextractResult`, different enum. SAFE.
- `spec/models/ai_job_criteria_spec.rb:37` -- `AiJobCriteria.create!(status: :in_progress)` -- on `AiJobCriteria`. SAFE.
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb:105` -- `AiJobCriteria.create!(status: :in_progress)` -- on `AiJobCriteria`. SAFE.

**Zero references to `in_progress` or `extracted` on `AiJobApplicationSummary`.** All hits are on `AiJobCriteria` (which retains `in_progress`) or `TextractResult` (different enum).

### `status_succeeded?` references

All 8 references verified in credit-consumption-timing.md. Every usage is semantically correct for the new meaning of `succeeded` (full pipeline complete).

### `status: :textract_processing` references

5 references across `app/`, all on `AiJobApplicationSummary`. The symbol name is unchanged; integer value moved from 6 to 1 but symbol-based queries resolve correctly via Rails enum mapping. Feature is not in production -- no existing data migration needed.

## Frontend compatibility

API response shape changes:
- Full serializer adds 3 new fields -- additive, backward compatible
- Shallow serializer adds `score_percentage` -- additive, backward compatible
- `ShallowJobApplicationSerializer` adds `ai_job_application_summary_status` association -- additive, backward compatible
- Bulk controller now accepts `job_id`, `hiring_stage_id`, `included_job_application_ids`, `excluded_job_application_ids` instead of `job_application_ids` -- frontend updated in same branch

## Findings

None.
