# callback-side-effects-and-guards -- Round 1

## Fact Check

### Existing callbacks on AiJobApplicationSummary
- `after_commit :create_status_record, on: :create` (line 27) -- CONFIRMED
- `after_commit :destroy_previous_textract_results, on: :update` (line 28) -- CONFIRMED
- `after_commit :update_summary_status_record, on: :update` (line 29) -- CONFIRMED

### Guard: `destroy_previous_textract_results`
- `return unless textract_result` (line 50) -- CONFIRMED
- `return unless saved_change_to_status? && status_succeeded?` (line 51) -- CONFIRMED
- Only fires when transitioning to `succeeded`. Safe for all intermediate statuses.

### Guard: `update_summary_status_record`
- `return unless saved_change_to_status? && status_succeeded?` (line 60) -- CONFIRMED
- Only fires when transitioning to `succeeded`. Safe for all intermediate statuses.

### Guard: `create_status_record`
- `on: :create` only. Not triggered by `update`. CONFIRMED.

### New callback: `broadcast_status_change`
- `before_update` -- fires before DB write on every `update` call
- Guard 1: `return unless status_changed?` -- correct for before_update (dirty attribute check)
- Guard 2: `return unless BROADCAST_STATUSES.include?(status)` -- filters excluded statuses
- `BROADCAST_STATUSES`: `textract_processing`, `extracting`, `summarizing`, `scoring`, `integrating`, `succeeded`, `failed`
- Excluded: `pending`, `awaiting_job_criteria`, `retrying` -- matches spec

### Status-to-broadcast matrix (all update_columns-to-update conversions)

| File | Line | Status | In BROADCAST_STATUSES? | Broadcast? |
|---|---|---|---|---|
| orchestrate.rb | 72 | awaiting_job_criteria | No | Silent |
| score_job_application.rb | 23 | awaiting_job_criteria | No | Silent |
| score_job_application.rb | 32 | scoring | Yes | Broadcast |
| score_job_application.rb | 109 | integrating (existing `update`) | Yes | Broadcast |
| score_job_application.rb | 115 | retrying | No | Silent |
| score_job_application.rb | 120 | failed | Yes | Broadcast |
| score_job_application.rb | 124 | failed | Yes | Broadcast |
| integrate_analysis.rb | 52 | succeeded (existing `update`) | Yes | Broadcast |
| integrate_analysis.rb | 59 | retrying | No | Silent |
| integrate_analysis.rb | 64 | failed | Yes | Broadcast |
| integrate_analysis.rb | 68 | failed | Yes | Broadcast |

All correct per spec intention. Intermediate silent statuses are correctly filtered by the guard.

## Completeness

| Spec requirement | Plan step | Status |
|---|---|---|
| `BROADCAST_STATUSES` excludes pending/awaiting/retrying | A.1.1 | Covered |
| Guard: `status_changed?` (not `saved_change_to_status?`) | A.1.3 | Covered |
| Existing callbacks have adequate guards | A.4.4 | Covered |
| Rescue wrapper prevents transaction abort | A.1.3 | Covered |
| `create_status_record` not affected by update | A.4.4 | Verified |

## Findings

No issues found.
