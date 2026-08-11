# Test Coverage — Round 2

## Findings

No issues found.

Round 1 HIGH (missing controller spec) — FIXED. Controller spec now exists with 5 examples covering:
- Authorization + response shape
- `kind` and `rescore_requested` passed to interactor
- Job lookup scoped to `current_organization` (RecordNotFound for other org)
- Error response on interactor failure
- Unauthorized user gets 403

Interactor spec (5 new contexts):
- `rescore_requested: true` includes `:current` candidates
- `rescore_requested: true` still filters `:processing` candidates
- Without `rescore_requested`, `:current` candidates filtered
- `kind` passes through to job payload
- `kind` defaults to `'single_hiring_stage'` when absent

Job spec (4 new contexts):
- `all_stages` broadcasts job-level `hiringStageLink`
- `all_stages` dispatches to `BulkAllStagesAiSummaryResultMailer.complete` with `.deliver_later`
- `all_stages` failure dispatches to `BulkAllStagesAiSummaryResultMailer.failed` with `.deliver_later`
- Absent `kind` dispatches to existing `BulkJobApplicationAiSummaryResultMailer`

Mailer spec (2 examples):
- `complete` sends with correct template, variables, job-level link
- `failed` sends with correct template and variables

All 31 specs pass.
