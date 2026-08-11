# Pass 1 — pipeline-status-lifecycle

## Fact Check

### Line numbers in `Summary::Generate` (app/services/ai_job_application_action/summary/generate.rb)

| Plan claim | Actual | Verdict |
|------------|--------|---------|
| Line 31: `status_in_progress?` | Line 31: confirmed `status_in_progress?` present | CORRECT |
| Line 32: `update_columns(status: :in_progress)` | Line 32: confirmed | CORRECT |
| Line 35: `status: :in_progress` (create) | Line 38: `status: :in_progress` | WRONG LINE — plan says 35, actual is 38 |
| Line 65: `status: :extracted` | Line 65: `status: :extracted` | CORRECT |
| Lines 162-163: `status: :succeeded` | Lines 162-163: `status: :succeeded` | CORRECT |
| Line 174: `status: :retrying` | Line 174: `status: :retrying` | CORRECT |
| Lines 179, 183: `status: :failed` | Lines 179, 183: `status: :failed` | CORRECT |

### Enum values — current vs. proposed

Current enum (7 values, despite plan and spec both saying 6):
```
pending: 0, in_progress: 1, succeeded: 2, failed: 3, extracted: 4, textract_processing: 6, retrying: 7
```

The existing spec test at `spec/models/ai_job_application_summary_spec.rb` line 7-16 asserts 6 values — it omits `retrying` from its assertion. The plan at C.7.1 says "Update the enum assertion from 6 values to 10 values" which matches the spec file (6 tested), not the model (7 defined).

Proposed enum (10 values):
```
pending: 0, textract_processing: 1, extracting: 2, summarizing: 3, awaiting_job_criteria: 4, scoring: 5, integrating: 6, succeeded: 7, retrying: 8, failed: 9
```

All 10 values match the spec exactly.

### Orchestrator `retrying` status gap

The plan's case statement in E.1.3 does NOT handle `status_retrying?`. The plan acknowledges this in R3/R6 ("Action: add `status_retrying?` to the `extracting` branch") but the actual code block in E.1.3 does not include the fix. An implementing agent following the code block verbatim would produce an orchestrator that falls through on `retrying` status with no action taken.

## Completeness

Spec requirements for this angle — all accounted for:
- [x] 10 enum values defined (B.3.1)
- [x] Every transition reachable (checked via service/orchestrator flow)
- [x] No dead-end states (all non-terminal states have forward progress paths)
- [x] `succeeded` means full pipeline complete (confirmed in E.1.3, D.4.4)
- [x] `retrying` re-enters via job retry mechanism

## Findings

**F1 [HIGH] — Orchestrator case statement in E.1.3 omits `status_retrying?`**

Where: Phase E, step E.1.3 — the case statement code block.

What: The case statement handles `pending`, `textract_processing`, `extracting`, `summarizing`, `awaiting_job_criteria`, `scoring`, `integrating`, `succeeded`, and `failed`. It does NOT include `status_retrying?`. The plan's R3/R6 section says to add it to the `extracting` branch, but the actual code in E.1.3 was never updated.

Evidence: E.1.3 case statement covers 9 of 10 statuses. `retrying` is missing. R3 says "add `status_retrying?` to the `extracting` branch of the case statement (re-run summary from the beginning)" but the code block at E.1.3 does not reflect this.

Fix: Add `@ai_job_application_summary.status_retrying?` to the first `when` branch of the case statement alongside `status_pending?`, `status_textract_processing?`, `status_extracting?`.

**F2 [MED] — Plan cites wrong line number for `status: :in_progress` create path**

Where: Phase C, step C.1.5

What: Plan says "Line 35: `status: :in_progress`" but the `AiJobApplicationSummary.create` with `status: :in_progress` is at line 38 in the actual source file. Line 35 is `ai_summary = AiJobApplicationSummary.create(`. The `status: :in_progress` is inside the hash at line 38.

Evidence: `app/services/ai_job_application_action/summary/generate.rb` lines 35-39.

Fix: Update line reference from 35 to 38.
