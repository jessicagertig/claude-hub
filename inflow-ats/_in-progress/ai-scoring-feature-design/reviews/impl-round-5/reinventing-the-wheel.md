# reinventing-the-wheel -- Round 5

## Scope
Check for reimplemented patterns that already exist in the codebase or framework.

## Files reviewed
All new service, model, job, and serializer files.

## Analysis

1. **`create_ai_api_request` private method**: Copied from `Summary::Generate` (lines 294-311). Each service has its own copy with the same signature. This is acceptable -- the `requestable` differs per service (`@ai_job_criteria` vs `@ai_job_application_summary`), making extraction into a shared helper non-trivial without adding complexity. Follows the analog pattern.

2. **Error handling three-tier rescue**: Same pattern across `ExtractCriteria`, `ScoreJobApplication`, `IntegrateAnalysis`, and `Summary::Generate`. Consistent but duplicated. Again, the record being updated differs per service. Follows analog.

3. **`find_or_create_by` for status record**: Used in both `AiJobApplicationSummary#create_status_record` (after_commit) and `CreateAiSummaryGeneration` interactor. The duplication is intentional belt-and-suspenders -- both paths are safe because `find_or_create_by` is idempotent.

4. **`ActionView::Base.full_sanitizer.sanitize`**: Used in `description_meaningfully_changed?` -- same approach as existing `description_without_html` method at line 681-682. Reuses the existing pattern, not a reinvention.

5. **`Calculate.compute`**: Pure computation class. No existing score calculator in the codebase to reuse.

6. **`resolve_job_application_ids` in BulkAiJobApplicationSummariesController**: Follows the `job_id` + `hiring_stage_id` + `included/excluded` pattern used by bulk move and bulk message controllers. This was a specific fix from pre-work findings (pipeline failure pattern #14 -- analog structural matching).

## Findings

None.
