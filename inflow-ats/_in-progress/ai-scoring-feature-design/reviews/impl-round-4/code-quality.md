# code-quality -- Round 4

## Scope

Code quality against `cursor_rules/backend/_base.md` and `cursor_rules/core_critical_rules.md`.

## Findings

### Method-level rescue (Rules 1)

All services use method-level rescue -- no `begin` blocks:
- `ExtractCriteria#extract`: method-level rescue with three-tier handling
- `ScoreJobApplication#score`: same
- `IntegrateAnalysis#integrate`: same
- `ExtractJobCriteriaJob#perform`: same

### Rescue specific exception classes (Rule 2)

Three-tier pattern consistently applied:
1. `CustomErrorAiSummary` -> re-raise (for retry)
2. `JSON::ParserError` -> fail, no re-raise
3. `StandardError` -> fail, no re-raise

Matches the `Summary::Generate` analog.

### Guard clauses (Rule 8)

Bare `return` without truthy/falsy values used throughout:
- `extract_job_criteria`: bare `return` for Flipper gate, pending debounce, save failure
- `Orchestrate#call`: bare `return` for nil textract_result, nil summary, terminal states
- All services: bare `return` for nil guards

### No bang methods (Rule 10)

No `save!`, `update!`, `create!` in app code. `update`, `save`, `create` used throughout with return value checks. Exception: `update!` used in specs (allowed per `cursor_rules/backend/_base.md`).

Note: `AiJobCriteria` specs use `create!` and `update!` -- this is acceptable in specs.

### Check save/update return values (Rule 11)

- `ExtractCriteria`: `unless @ai_job_criteria.update(update_params)` with raise on failure
- `ScoreJobApplication`: `unless @ai_job_application_summary.update(update_params)` with raise on failure
- `IntegrateAnalysis`: `unless @ai_job_application_summary.update(update_params)` with raise on failure
- `Job#extract_job_criteria`: `return unless ai_job_criteria.save`

All return values checked.

### Service conventions (cursor_rules/backend/services.md)

- Single descriptive public method per service: `extract`, `score`, `integrate`, `call`. Correct.
- Constructor takes IDs or objects per convention. `ExtractCriteria` takes `ai_job_criteria_id:` (loads via `find_by`). `ScoreJobApplication` takes pre-loaded objects (called from orchestrator). `IntegrateAnalysis` takes pre-loaded object.
- `find_by` used instead of `find` (no exceptions for missing records).

### `update_columns` vs `update` usage

- `update_columns` for intermediate status transitions (no callbacks needed): correct
- `update` for `succeeded` on `AiJobCriteria` (triggers `after_commit` callback): correct
- `update` for `succeeded` on `AiJobApplicationSummary` (triggers `after_commit` callbacks for `destroy_previous_textract_results` and `update_summary_status_record`): correct
- `update_columns` for `failed`/`retrying` status (no callbacks needed): correct

### Logging

`ap` debug logs used throughout, matching the `Summary::Generate` pattern. Comments "AI debugging ap logs -- do not remove unless directly requested" present in `generate_ai_summary_with_credit_flow` and `Orchestrate`.

## Result: PASS -- 0 findings
