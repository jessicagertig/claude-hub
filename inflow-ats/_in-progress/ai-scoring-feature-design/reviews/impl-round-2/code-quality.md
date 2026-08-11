# code-quality — Implementation Review Round 2

## Files reviewed

All new and modified files checked against `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/_base.md`, `cursor_rules/backend/services.md`, `cursor_rules/backend/background_jobs.md`.

## Findings

No findings.

### cursor_rules compliance

1. **No begin blocks** (core_critical_rules #1): All rescue blocks are method-level. Correct.
2. **Specific exception classes** (backend/_base #2): Three-tier rescue pattern throughout: `CustomErrorAiSummary`, `JSON::ParserError`, `StandardError`. Correct.
3. **No empty rescue blocks** (backend/_base #4): All rescue blocks log and/or update state. Correct.
4. **`=> e` variable naming** (backend/_base #5): All rescue blocks use `=> e`. Correct.
5. **No `ensure` blocks** (backend/_base #6): None used. Correct.
6. **`reload` usage** (backend/_base #8): Orchestrator uses `reload` in `run_summary`, `run_scoring`, `run_integration`. This is a documented deviation — `Summary::Generate` and scoring services load/update the summary through their own references, making the orchestrator's reference stale. The deviation is noted in a comment (lines 59-62). Acceptable.
7. **Variable naming** (backend/_base #9): `ai_job_criteria`, `ai_job_application_summary`, `textract_result` — all match model names. Correct.
8. **Single quotes** (backend/_base #7): Used throughout. Correct.
9. **Guard clauses with bare return** (core_critical_rules #8): All guard clauses use bare `return` without truthy/falsy values. Correct.
10. **No bang methods** (core_critical_rules #10): No `update!`, `create!`, `save!` in application code. Specs use bang methods (acceptable per the rule's exception). Correct.
11. **Save/update return values checked** (core_critical_rules #11): `ai_summary.update(...)` checked with `unless` (raise on failure) in `Summary::Generate`, `ScoreJobApplication`, `IntegrateAnalysis`, `ExtractCriteria`. `ai_job_criteria.save` checked with `return unless` in `Job#extract_job_criteria` (line 699). Correct.
12. **Service naming** (services #1): No "Service" in class names. `ExtractCriteria`, `ScoreJobApplication`, `Calculate`, `IntegrateAnalysis`, `Orchestrate`. Correct.
13. **Descriptive method names** (services #2): `extract`, `score`, `compute`, `integrate`, `call`. Correct (note: `call` is used for the orchestrator, which is an entry point, not a generic service).
14. **IDs from jobs, objects from request cycle** (services #3): `ExtractCriteria.new(ai_job_criteria_id:)` takes ID (called from job). `ScoreJobApplication.new(ai_job_application_summary:, textract_result:)` and `IntegrateAnalysis.new(ai_job_application_summary:)` take objects (called from orchestrator within request cycle). Correct.
15. **Job patterns** (background_jobs): `find_by` guards, `queue_as :default`, `retry_on` with exhaustion blocks, error logging with `ap` + `Rails.logger.error`. Correct.
16. **Logging pattern** (services): Both `ap` and `Rails.logger.error` in rescue blocks. Correct.
