# Rescore Filter — Pass 1

## Fact Check

| Claim | Verification |
|-------|-------------|
| `:current` filter at lines 36-40 | CORRECT — lines 36-40: `AiJobApplicationSummaryStatus.where(job_application_id: ready_ids, status: :current).pluck(:job_application_id)` then `ready_ids -= already_summarized_ids; input_ids -= already_summarized_ids` |
| `:processing` filter at lines 43-45 | CORRECT — lines 43-45: `BulkAiSummaryJobApplication.where(job_application_id: ready_ids, status: :processing).pluck(:job_application_id)` |
| Plan step A.3.1.1 wraps lines 36-40 in conditional | Correct approach |
| Plan step A.3.1.2 keeps `:processing` filter unchanged | CORRECT |
| Plan step A.3.1.3 adds `kind` to payload | CORRECT |

## Completeness

All spec requirements for rescore addressed:
- Skip `:current` filter when `rescore_requested`: A.3.1.1 ✓
- Always keep `:processing` filter: A.3.1.2 ✓
- Pass `kind` to payload: A.3.1.3 ✓
- Default behavior unchanged: A.3.1.3 defaults `kind` ✓

## Findings

No issues found.
