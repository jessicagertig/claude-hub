# Plan Review — AI Scoring Integration

**Date:** 2026-06-11
**Plan reviewed:** `plan.md`
**Passes:** 2

---

## Verdict: APPROVED

The plan is factually accurate, complete against the spec, and safe to implement. Five findings were identified across two passes; all were amended.

---

## Summary of Findings

### Pass 1: 1 HIGH, 3 MED

| ID | Severity | Angle | Description | Status |
|----|----------|-------|-------------|--------|
| F1 | HIGH | pipeline-status-lifecycle | Orchestrator case statement (E.1.3) omitted `status_retrying?`, meaning a retried job would fall through with no action | AMENDED — added to first `when` branch |
| F2 | MED | pipeline-status-lifecycle | Plan cited wrong line number for `status: :in_progress` create path (said line 35, actual line 38) | AMENDED — corrected to line 38 |
| F3 | MED | credit-consumption-timing | `SubmitResumeToTextract` omitted from the "EXHAUSTIVE AUDIT" in Phase C (two `status: :textract_processing` references at lines 18 and 25) | AMENDED — added as C.7 with two entries (both unchanged) |
| F4 | MED | data-model-contracts | Controller eager loading for `ShallowJobApplicationSerializer` was a comment, not an explicit task step. `job_applications_controller.rb` lines 25 and 35 need `.includes(:ai_job_application_summary_status)` | AMENDED — added as H.4.2, controller added to Modified Files table |

### Pass 2: 0 HIGH, 1 MED

| ID | Severity | Angle | Description | Status |
|----|----------|-------|-------------|--------|
| F5 | MED | credit-consumption-timing | D.2.8 and D.4.5 said "same three-tier pattern as D.1.8" but D.1.8 operates on `AiJobCriteria` (uses `failed` for `CustomErrorAiSummary`). Scoring/integration operate on `AiJobApplicationSummary` which has `retrying`. Setting `failed` would make job retries inert. | AMENDED — D.2.8 and D.4.5 now explicitly specify `retrying` for `CustomErrorAiSummary`, `failed` for `JSON::ParserError` and `StandardError` |

---

## Files Modified

- `~/claude-hub/inflow-ats/_in-progress/ai-scoring-feature-design/plan.md` — 5 amendments applied across 2 passes

---

## Verification Summary

### Source files read and verified

Every file path, line number, method signature, class name, enum value, and behavioral claim in the plan was verified against the live source tree at `/Users/jessica/wrk/wrk-corp/inflow-ats` on branch `feature-ai-summaries-integrating-scoring-v3`.

Key verifications:
- `Summary::Generate` (315 lines) — all line number references checked
- `TextractResult` — `generate_ai_summary` (line 52), `generate_ai_summary_with_credit_flow` (line 65), `queue_ai_summary_job` (line 95), `private` (line 93)
- `AiJobApplicationSummary` — current 7-value enum confirmed, `destroy_previous_textract_results` callback at line 38-45
- `Job` model — `handle_before_update` (line 475-483), `handle_status_changed_to_published` (line 542-557), `description_without_html` (line 677-678), `has_many :ai_job_application_summaries, through: :job_applications` (line 51)
- `GenerateAiJobApplicationSummaryJob` — retry_on (line 13), broadcast (line 61)
- `BulkGenerateAiSummariesJob` — status references at lines 50, 89
- `CreateAiSummaryGeneration` — all three status assignment paths
- `ValidateAiSummaryGeneration` — confirmed no AiJobApplicationSummary status references
- `GetResumeTextFromTextractJob` — retry pattern, exhaustion block
- `SubmitResumeToTextract` — status references at lines 18, 25
- All serializer files — current attribute lists
- `AiApiRequest` — polymorphic `requestable`
- Existing migration — `20260311120000_create_ai_job_application_summaries.rb`
- All spec files referenced by the plan
- `job_applications_controller.rb` — ShallowJobApplicationSerializer usage at lines 25, 35

### Frozen prompt files

Confirmed: 4 prompt files exist at `app/services/ai_job_application_action/scoring/prompts/`. Plan does not modify any of them. Only `integrated_analysis.rb` (new) is created.

### Exhaustive enum reference audit

`grep -rn` across entire `app/` and `spec/` for all AiJobApplicationSummary status enum references. All references identified and accounted for in the plan. Removed values (`in_progress`, `extracted`) have update paths. Unchanged values (`pending`, `textract_processing`, `succeeded`, `failed`, `retrying`) verified as safe (symbol names preserved).
