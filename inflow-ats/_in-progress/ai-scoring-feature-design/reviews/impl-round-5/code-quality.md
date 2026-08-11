# code-quality -- Round 5

## Scope
cursor_rules compliance, error handling patterns, save/update return value checks, no bang methods in app code, method-level rescue.

## cursor_rules checked
- `cursor_rules/core_critical_rules.md` -- Rules 1, 3, 8, 10, 11
- `cursor_rules/backend/_base.md` -- Rules 1, 2, 3, 6, 8

## Method-level rescue (Rule 1)

All services use method-level rescue, not begin blocks:
- `ExtractCriteria#extract` -- rescue at method level (line 121-134)
- `ScoreJobApplication#score` -- rescue at method level (line 103-117)
- `IntegrateAnalysis#integrate` -- rescue at method level (line 53-67)
- `Summary::Generate#generate` -- rescue at method level (line 170-183)
- `ExtractJobCriteriaJob#perform` -- rescue at method level (line 19-28)
- `GenerateAiJobApplicationSummaryJob#perform` -- rescue at method level (line 35-45)

## Rescue specific exceptions (Rule 2)

Three-tier pattern used consistently:
1. `CustomErrorAiSummary` (most specific)
2. `JSON::ParserError` (specific)
3. `StandardError` (fallback)

No bare `Exception` rescue anywhere.

## Guard clauses (Rule 8)

All guard clauses use bare `return`:
- `ExtractCriteria`: `return unless @ai_job_criteria`, `return unless @job`, `return unless @organization`
- `ScoreJobApplication`: `return unless @ai_job_application_summary && @textract_result`
- `IntegrateAnalysis`: `return unless @ai_job_application_summary`
- `Orchestrate`: `return unless @textract_result`, `return unless @ai_job_application_summary`
- `Job#extract_job_criteria`: `return unless Flipper.enabled?`, `return if existing_ai_job_criteria&.status_pending?`, `return unless ai_job_criteria.save`

No truthy/falsy return values found.

## No bang methods (Rule 10)

No `save!`, `update!`, `create!`, or `destroy!` in any app code file. Bang methods appear only in spec files (acceptable per convention).

## Check save/update return values (Rule 11)

- `ExtractCriteria` line 120: `unless @ai_job_criteria.update(update_params)` -> raises `CustomErrorAiSummary`
- `ScoreJobApplication` line 100: `unless @ai_job_application_summary.update(update_params)` -> raises `CustomErrorAiSummary`
- `IntegrateAnalysis` line 50: `unless @ai_job_application_summary.update(update_params)` -> raises `CustomErrorAiSummary`
- `Job#extract_job_criteria` line 699: `return unless ai_job_criteria.save`
- `Summary::Generate` lines 68, 102, 128, 167: all checked with `unless ... update` -> raises

## `update_columns` vs `update` usage

- `update_columns` used for intermediate status transitions (no callbacks needed)
- `update` used for `succeeded` on `AiJobCriteria` (to fire `after_commit` callback)
- `update` used for final data writes with status changes on `AiJobApplicationSummary`
- `update_columns` used for `failed` transitions (no callback needed)
- `update_columns` used for `retrying` status (in error handlers)

Pattern matches spec requirements and analog (`Summary::Generate`).

## `ap` debug logs

Present throughout, matching the analog pattern. Not flagged -- existing codebase convention.

## Findings

None.
