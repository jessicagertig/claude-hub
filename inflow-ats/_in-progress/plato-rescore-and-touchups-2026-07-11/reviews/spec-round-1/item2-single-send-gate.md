# item2-single-send-gate — Round 1

Trace: SPEC 2.1,2.8 → create_ai_summary_generation.rb:30-73 → create_bulk_ai_summary_generation.rb:45 (pinned gate) → validate_ai_summary_generation.rb (upstream gate) → textract_result.rb:67-68 → job_application.rb:32 (latest_ai_job_application_summary) → find_or_create_ai_job_application_summary_status.rb → spec/interactors/create_bulk_ai_summary_generation_spec.rb (mirror)

## Source-accuracy checks (confirmed)
- `create_ai_summary_generation.rb:36` = `if active_ai_summary` (current gate). CONFIRMED. Becomes `if active_ai_summary && !job_application.ai_summary_rescore_requested`.
- `create_bulk_ai_summary_generation.rb:45` = `if active_ai_summary && !job_application.ai_summary_rescore_requested` (the ONE pinned copied line). CONFIRMED byte-for-byte.
- `textract_result.rb:68` = `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. CONFIRMED (line 68 exactly).
- `job_application.rb:32` = `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }`. CONFIRMED — resolves to the NEWEST summary.

## End-to-end pipeline trace (SPEC 2.1 self-resolution claim VERIFIED)
1. Controller sets `job_application.ai_summary_rescore_requested = true`, calls `ValidateAiSummaryGeneration` then `CreateAiSummaryGeneration` on the SAME in-memory job_application.
2. `ValidateAiSummaryGeneration` for an already-scored candidate: flipper on, has_resume true, credits available (Regenerate button only shows when credits>0 per SPEC 2.5), has_job_description true, latest_textract_result present + text ready → `textract_pending=false`, success. It has NO "summary already exists" check — the re-score is NOT blocked upstream. CONFIRMED the untouched gate stays passable.
3. `CreateAiSummaryGeneration` with the new gate: `active_ai_summary && !true` = false → falls through. `validation_result.textract_pending`=false → builds a `:pending` row + `GenerateAiJobApplicationSummaryJob.perform_later`. Matches SPEC 2.1.
4. Job runs → `textract_result.rb:67-68`: `latest_ai_job_application_summary` is now the NEW pending row (newest created_at) → `status_succeeded?` false → guard does NOT fire → generation proceeds. SPEC 2.1's "self-resolves — the new pending row becomes latest_ai_job_application_summary" is CORRECT.
- The virtual attribute `ai_summary_rescore_requested` (job_application.rb:11, `attribute … default:false`, not persisted) is only needed in-request; the background job does not re-read it. No persistence gap.

## Status-record path (SPEC 2.7 VERIFIED)
- `regeneration_in_progress?` = `generation_in_progress? && latest_succeeded_ai_job_application_summary.present?`; `generation_in_progress?` is status-based (`present? && !succeeded? && !failed?`), NO stale check. During re-score: latest = new pending (present, not succeeded/failed) AND old succeeded row present → `regenerating`; `ai_job_application_summary_id` points to `latest_succeeded_…` (old row) → prior score stays on screen. After success: latest succeeded → `current` pointing at the new row. `current → regenerating → current` CONFIRMED; "regeneration_in_progress? does not check stale" CONFIRMED.

## Findings
- F1 [MED] SPEC 2.8 interactor-spec direction: the single-send `CreateAiSummaryGeneration` reads `validation_result.textract_pending` at :41 on the fall-through (rescore-true) path. The bulk interactor does NOT read it, so `create_bulk_ai_summary_generation_spec.rb`'s double is `double('validation_result', textract_result: textract_result)` (no `textract_pending`). A spec that mirrors that double verbatim will raise `RSpec::Mocks::MockExpectationError` on the unstubbed `textract_pending` message when the rescore-true path calls it. AMENDED SPEC 2.8 to require the double also stub `textract_pending: false`. Accuracy fix — the mirror is not a pure copy because the single-send interactor reads one extra field.

## Amendments Applied
- SPEC 2.8: added that the interactor spec's `validation_result` double must stub `textract_pending: false` (single-send interactor reads it at :41; the bulk double does not include it).

## Rejected as false positives (guardrails)
- Bulk interactor's staleness-refresh block (`:40-43`), missing `textract_pending` branch, and missing enqueue — guardrail 1: NOT deviations the single-send interactor should adopt/match. The single-send interactor keeps its own `textract_pending` branch and its own enqueue. Rejected.
- Any demand to compare the two interactors wholesale — guardrail 1. Rejected.
