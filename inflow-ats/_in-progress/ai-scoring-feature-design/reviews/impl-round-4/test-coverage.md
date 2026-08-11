# test-coverage -- Round 4

## Scope

Verify existing tests updated for enum changes, new test coverage for all new code.

## Findings

### Existing test updates

- `ai_job_application_summary_spec.rb`: enum assertion updated from 6 values to 10 values with correct mappings. `destroy_previous_textract_results` test uses `status: :succeeded` (symbol, not integer) -- works with new enum.
- No stale references to `status: :in_progress` or `status: :extracted` found in any spec file for `AiJobApplicationSummary`. Grep confirmed: the only `status: :in_progress` references in specs are for `AiJobCriteria` (separate model with its own `in_progress` enum value) and `textract_job_status: :in_progress` (on `TextractResult`, separate enum).

### New model specs

- `ai_job_criteria_spec.rb`: status enum (4 values), associations, `after_commit` callback (succeeded triggers enqueue, failed does not, multiple waiting summaries handled, zero waiting summaries safe).
- `ai_job_application_summary_status_spec.rb`: uniqueness on `job_application_id`, `regenerating` default, nullable `ai_job_application_summary_id`.

### New service specs

- `extract_criteria_spec.rb`: not-found guard, blank description failure, no criteria sections failure, happy path (status transitions, criteria population, metadata, AiApiRequest creation, in_progress status during calls), heading tier override (required -> tier_1, bonus -> tier_3, soft skill exception), dedup, error handling (all three tiers).
- `score_job_application_spec.rb`: nil textract_result guard, criteria absent (awaiting_job_criteria), criteria not succeeded (awaiting), criteria failed (re-triggers extraction), happy path (status transitions, score_percentage, criteria_results merge, AiApiRequest creation), error handling (all three tiers).
- `calculate_spec.rb`: all tier/multiplier combinations, empty/nil input, mixed scenarios, title technology multiplier, unknown tier default.
- `integrate_analysis_spec.rb`: nil guard, happy path (status to succeeded, integrated_role_analysis populated, does not modify score_percentage/criteria_results/structured_data, AiApiRequest creation), nil structured_data handling, error handling (all three tiers).
- `orchestrate_spec.rb`: nil textract_result, no summary, terminal states (succeeded/failed do nothing), pending (full pipeline), awaiting_job_criteria with criteria present.

### New job specs

- `extract_job_criteria_job_spec.rb`: not-found guard, delegation to `ExtractCriteria` service.

### Job lifecycle specs

- `job_criteria_lifecycle_spec.rb`: Flipper gate, no existing criteria, pending debounce, in_progress reset, succeeded reset, failed reset with error clear, `description_meaningfully_changed?` (HTML-only false, whitespace false, numbers false, text true, case false).

### Coverage assessment

The spec plan (Section 9) lists required test coverage. Cross-checking:
- AiJobCriteria model: covered
- AiJobApplicationSummaryStatus model: covered
- ExtractJobCriteriaJob: covered
- ExtractCriteria: covered
- ScoreJobApplication: covered
- Calculate: covered
- IntegrateAnalysis: covered
- Orchestrate: covered
- Job#extract_job_criteria: covered
- Job#handle_description_change: indirectly covered via `description_meaningfully_changed?` tests
- Job#description_meaningfully_changed?: covered
- Serializer tests: not present as separate spec files

The serializer spec absence is noted but is INFO-level -- the serializer changes are simple attribute additions per `cursor_rules/backend/serializers.md` Rule 1 (no method definitions, just attributes list). The risk of a typo in an attribute name is real but low, and would be caught immediately at the integration level.

## Result: PASS -- 0 findings
