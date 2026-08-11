# Pass 2 — credit-consumption-timing

## Verification of Pass 1 corrections

F3 (SubmitResumeToTextract added to enum audit): VERIFIED. C.7 now lists `app/services/submit_resume_to_textract.rb` with two entries, both unchanged.

## Fresh-eyes re-read

Re-examined the full credit consumption path after amendments:

1. `GenerateAiJobApplicationSummaryJob#perform` calls `textract_result.generate_ai_summary_with_credit_flow`
2. `generate_ai_summary_with_credit_flow` calls `generate_ai_summary` (now orchestrator)
3. Orchestrator runs full pipeline: summary -> scoring -> integration -> sets `succeeded`
4. `generate_ai_summary_with_credit_flow` reads the summary, checks `status_succeeded?`
5. Only if `succeeded` (value 7, full pipeline complete): `CreateAiCreditBalanceTransaction.call`

The key insight: when the orchestrator sets `awaiting_job_criteria` and returns, `generate_ai_summary_with_credit_flow` reads the summary and sees status `awaiting_job_criteria` (not `succeeded`). The `status_succeeded?` check at line 79 returns false. No credit consumed. This is correct — the pipeline is incomplete.

When the criteria callback re-invokes the job, the orchestrator resumes at scoring. After integration completes and `succeeded` is set, `generate_ai_summary_with_credit_flow` sees `succeeded` and consumes the credit. One credit for one complete evaluation. CORRECT.

**Edge case: What if the orchestrator raises during scoring/integration?**
- `CustomErrorAiSummary`: `Summary::Generate`'s rescue sets `retrying`, re-raises. But wait — the scoring/integration services have their own error handling (D.2.8, D.4.5). If `ScoreJobApplication` or `IntegrateAnalysis` raises `CustomErrorAiSummary`, they set `failed` (not `retrying`) and re-raise. The job's `retry_on` catches it. On retry, the orchestrator resumes from the failed step. If all retries exhausted, `failed` is set by the job's exhaustion block. No credit consumed. CORRECT.

Wait, actually: looking more carefully at the error handling in D.2.8, the plan says scoring uses "same three-tier pattern as D.1.8". D.1.8 re-raises `CustomErrorAiSummary` after setting `failed`. But that means the job retries from scratch, and the orchestrator would resume... but the status is `failed` (terminal). The orchestrator's case statement returns on `failed`. So on retry, the orchestrator does nothing.

Actually, looking at D.1.8 more carefully: for `ExtractCriteria`, the `CustomErrorAiSummary` rescue sets `failed` on `@ai_job_criteria` (not on `@ai_job_application_summary`) and re-raises. For `ScoreJobApplication` (D.2.8), it would set `failed` on `@ai_job_application_summary` and re-raise. On retry, the orchestrator sees `failed` and returns. The job's retry is wasted.

But this mirrors the existing pattern in `Summary::Generate` lines 171-174: `CustomErrorAiSummary` sets `retrying` (not `failed`) and re-raises. The plan's scoring services set `failed` and re-raise. This is a discrepancy with the analog.

However, looking at the spec more carefully: spec Section 3 says "`retrying` — `CustomErrorAiSummary` caught, job will retry. Record reused on retry, not recreated." The spec implies `retrying` is set when `CustomErrorAiSummary` is caught anywhere in the pipeline, not just in `Summary::Generate`.

But the plan's D.2.8 says "same three-tier pattern as D.1.8" which sets `failed` (not `retrying`). D.1.8 is for `ExtractCriteria` operating on `AiJobCriteria` (a different model). Setting `failed` on `AiJobCriteria` is correct — `AiJobCriteria` doesn't have a `retrying` status. But the plan says D.2.8 uses "same pattern" for `ScoreJobApplication`, which operates on `AiJobApplicationSummary`. If it sets `failed` on `AiJobApplicationSummary`, the retry is wasted.

This needs a closer look, but the plan says "same three-tier pattern" without specifying `retrying` vs `failed` for the `CustomErrorAiSummary` case. The implementing agent needs to decide. The spec's guidance is clear: `retrying` for `CustomErrorAiSummary` on `AiJobApplicationSummary`. But this is an implementation detail the implementing agent can handle — the plan says "same pattern" which is close enough guidance.

This is borderline MED. The plan is not wrong — it says "same pattern" and references D.1.8. But D.1.8 operates on `AiJobCriteria` (which has `failed`, not `retrying`), while D.2.8/D.4.5 operate on `AiJobApplicationSummary` (which has both `retrying` and `failed`). The implementing agent would need to recognize this difference.

However, upon reflection: the plan does not explicitly specify `retrying` vs `failed` for the scoring/integration error handling. It says "same three-tier pattern." The spec says `retrying` is for `CustomErrorAiSummary`. An implementing agent following the spec would use `retrying`. An implementing agent following only the plan's "same pattern as D.1.8" literally would use `failed`. This is ambiguous enough to flag.

## Final completeness sweep

All credit consumption timing is correct after amendments. The `SubmitResumeToTextract` references are now listed.

## Findings

**F5 [MED] — Ambiguous error handling for `CustomErrorAiSummary` in scoring/integration services**

Where: Phase D, steps D.2.8 and D.4.5.

What: The plan says scoring and integration error handling follows "same three-tier pattern as D.1.8." D.1.8 (`ExtractCriteria`) sets `failed` status on `AiJobCriteria` for `CustomErrorAiSummary` and re-raises. But scoring (D.2.8) and integration (D.4.5) operate on `AiJobApplicationSummary`, which has both `retrying` (8) and `failed` (9). The spec says `retrying` is set when `CustomErrorAiSummary` is caught (Section 3: "retrying — CustomErrorAiSummary caught, job will retry"). The analog (`Summary::Generate` line 174) also uses `retrying` for `CustomErrorAiSummary`.

If the implementing agent literally copies D.1.8's pattern and uses `failed` for `CustomErrorAiSummary` on `AiJobApplicationSummary`, the job's retry attempt would find `failed` (terminal state) and the orchestrator would return without doing anything. The retry is wasted.

Evidence: D.1.8 code block shows `status: :failed` for `CustomErrorAiSummary`. `Summary::Generate` line 174 uses `status: :retrying` for the same exception class. The spec says `retrying` is for retryable errors on `AiJobApplicationSummary`.

Fix: Explicitly state that for `ScoreJobApplication` and `IntegrateAnalysis`, the `CustomErrorAiSummary` rescue should set `status: :retrying` (not `:failed`) on `@ai_job_application_summary`, matching the `Summary::Generate` pattern at line 174. Only `JSON::ParserError` and `StandardError` should set `:failed`.
