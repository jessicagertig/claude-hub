# S-E — Textract-processing Handoff (pass 1)

**Angle:** S-E — the `TextractResult#queue_ai_summary_job` after_commit callback finds an existing `textract_processing` summary and runs it. Which record, what advances it, to terminal.

## Files traced (chain)

`app/models/textract_result.rb:114` (`queue_ai_summary_job`)
→ `app/interactors/validate_ai_summary_generation.rb` (`ValidateAiSummaryGeneration.call`)
→ `app/jobs/generate_ai_job_application_summary_job.rb:24` (`perform`)
→ `app/models/textract_result.rb:61` (`generate_ai_summary_with_credit_flow`)
→ `app/models/job_application.rb:160` (`find_or_create_ai_job_application_summary_status`)
→ `app/interactors/find_or_create_ai_job_application_summary_status.rb`
→ `app/models/textract_result.rb:98` (`set_initial_summary_pending`)
→ `app/services/ai_job_application_action/orchestrate.rb:9` (`call`)
→ `app/services/ai_job_application_action/summary/generate.rb:11` (`generate`) — **the reuse/handoff point**
→ `app/services/ai_job_application_action/scoring/score_job_application.rb`
→ `app/services/ai_job_application_action/scoring/integrate_analysis.rb:11` — **terminal `succeeded`**
→ `app/models/ai_job_application_summary.rb:57` (`update_summary_status_record` after_commit)

Supporting reads: `app/models/ai_job_application_summary_status.rb`, `app/models/job_application.rb:31,32,160-171,685`.

## The S-E path (record-by-record)

### 1. The callback entry and branch selection — `textract_result.rb:114-136`
The callback fires `after_commit :queue_ai_summary_job, on: [:create, :update]` (line 7). Guards:
- `return unless textract_job_result_text.present?` (line 115)
- `return unless saved_change_to_textract_job_result_text?` (line 116) — must be the triggering write of the extracted text
- `return unless organization` (line 119)

It then queries the waiting summary (lines 121-123):
```
ai_summary_waiting_on_textract = job_application.ai_job_application_summaries
  .where(status: :textract_processing, stale: false)
  .first
```
**S-E takes the `if ai_summary_waiting_on_textract` branch (line 125).** It calls `ValidateAiSummaryGeneration.call` (line 126). On success it enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id, requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id)` (lines 128-131). On validation failure it looks up the requesting `OrganizationUser`, calls `ai_summary_waiting_on_textract.destroy` (line 134), and broadcasts `AI_SUMMARY_FAILED` (line 135).

**Branch fact (Textract IS ready here):** S-E only runs because the text is now present (guard line 115 + 116). Inside `ValidateAiSummaryGeneration`, `textract_text_ready?` is true (line 44), so `context.textract_pending = false` and validation succeeds. The summary moves FORWARD into the AI pipeline (it does NOT re-enter the textract_processing wait).

### 2. The job — `generate_ai_job_application_summary_job.rb:24-46`
`perform(textract_result_id:, requesting_organization_user_id: nil)` finds the TextractResult (line 25), `return unless textract_result` (line 30), then calls `textract_result.generate_ai_summary_with_credit_flow` (line 32). Because S-E passes `requesting_organization_user_id`, line 34 `broadcast_completion(...)` fires `AI_SUMMARY_COMPLETE` when the job finishes (this distinguishes S-E from auto-gen Trigger C, which passes nil and never broadcasts).

### 3. Credit flow + status seeding — `textract_result.rb:61-89`
- Line 67-68: `latest_ai_summary = job_application.latest_ai_job_application_summary; return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. For S-E the latest summary is the `textract_processing` one, so this guard does NOT return.
- Line 70: `status_result = job_application.find_or_create_ai_job_application_summary_status` → `FindOrCreateAiJobApplicationSummaryStatus`. The status row already exists (created at job_application creation, `job_application.rb:170`), with status `none`, so the interactor's `summary&.status_succeeded?` branch (line 14) is false → no change.
- Line 72: `set_initial_summary_pending(status_result)` — sets the status row to `initial_summary_pending` (see write site below).
- Line 74: `generate_ai_summary` → `AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call` (line 111).
- After pipeline: line 77 fetches `ai_job_application_summaries.order(created_at: :desc).first`; line 82 `return unless ...status_succeeded?`; line 84 `CreateAiCreditBalanceTransaction.call`; lines 87-88 notifications.

### 4. The handoff (reuse of the waiting record) — `summary/generate.rb:30-40`
`Orchestrate#call` (orchestrate.rb:15) loads `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first` — the `textract_processing` record. Its status dispatches to `run_summary` + `check_criteria_and_score` (orchestrate.rb:22-27, the `status_textract_processing?` case).

`run_summary` (orchestrate.rb:63-66) calls `Summary::Generate#generate`. In generate.rb:30-33:
```
existing_ai_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first
if existing_ai_summary && (existing_ai_summary.status_pending? || existing_ai_summary.status_textract_processing? || existing_ai_summary.status_extracting? || existing_ai_summary.status_retrying?)
  existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?
  ai_summary = existing_ai_summary
```
**This is the S-E handoff: the SAME `textract_processing` AiJobApplicationSummary record is REUSED and transitioned `textract_processing → extracting` via `update` (line 32), not a fresh record.**

### 5. Advancing to terminal
The reused AiJobApplicationSummary advances:
`textract_processing → extracting` (generate.rb:32, `update`)
→ `summarizing` (generate.rb:65 via `update` line 68)
→ `awaiting_job_criteria` (orchestrate.rb:72, `update`)
→ (criteria succeeded) `scoring` (score_job_application.rb:32, `update`)
→ `integrating` (score_job_application.rb:122, `update` line 124)
→ **`succeeded`** (integrate_analysis.rb:51, `update` line 53) — **TERMINAL.**

The `succeeded` `update` fires `after_commit :update_summary_status_record` (ai_job_application_summary.rb:57-98), which syncs the denormalized AiJobApplicationSummaryStatus row to `current` (line 74-80) and broadcasts `ai_summary_succeeded` on JobChannel (line 93-97).

### Dead-end / criteria wait
If `AiJobCriteria` is not succeeded at `check_criteria_and_score` (orchestrate.rb:76), the summary comes to rest at `awaiting_job_criteria` (set orchestrate.rb:72) and `Orchestrate` returns (line 81). It is re-advanced only by the separate `AiJobCriteria#resume_waiting_summaries` re-trigger (out of S-E scope, but it is the actor that clears this resting state). Within S-E alone, `awaiting_job_criteria` is a non-terminal resting state with NO further actor inside this path.

## Verdicts vs the old map

| # | Behavior | Map says | Verdict |
|---|---|---|---|
| 1 | S-E branch enqueues job WITH `requesting_organization_user_id` → `AI_SUMMARY_COMPLETE` broadcasts | Trigger E "User Broadcast: None" (line 699) | **MAP-WRONG** — job passes `requested_by_organization_user_id`; `broadcast_completion` fires `AI_SUMMARY_COMPLETE` (job line 34) |
| 2 | Reused record transitions `textract_processing → extracting` via `update` | "reuses it (transitions to `extracting` via `update_columns`)" (line 296) | **MAP-WRONG** — generate.rb:32 uses `update`, not `update_columns` |
| 3 | `set_initial_summary_pending` sets status row to `initial_summary_pending` before pipeline | ABSENT — map has no `set_initial_summary_pending`, no `initial_summary_pending` write | **NEW** |
| 4 | AiJobApplicationSummaryStatus enum {none,initial_summary_pending,current,regenerating} | Map lists {pending,textract_processing,...,failed} (lines 509-511) | **MAP-WRONG** — wrong enum copied from summary |
| 5 | `update_summary_status_record` writes `status:'current'` via `update` | "Uses `update_columns`... `status: ...['succeeded']` (integer 7)... `regenerating: false`" (lines 502, 605) | **MAP-WRONG** — uses `update`, sets `status:'current'`, no `regenerating` column |
| 6 | `create_status_record` after_commit on :create | "after_commit :create_status_record, on: :create" (line 500) | **REMOVED** — no such callback; status created via `FindOrCreateAiJobApplicationSummaryStatus` from `enqueue_new_job_application` |
| 7 | Reuse condition + dispatch in Orchestrate textract_processing case | "pending / textract_processing / extracting / retrying → run_summary" (line 273) | **CONFIRMED** |
| 8 | BROADCAST_STATUSES excludes awaiting_job_criteria + retrying | not described | **NEW** (desync surface) — ai_job_application_summary.rb:23 |

## Desync windows (status row vs latest non-stale summary)
- After `set_initial_summary_pending` (textract_result.rb:104) the row sits at `initial_summary_pending` while the summary advances through extracting→summarizing→awaiting_job_criteria→scoring→integrating. The status row is NOT updated again until `succeeded` (ai_job_application_summary.rb:74). The whole intermediate window the row disagrees with the live summary status.
- Transition into `awaiting_job_criteria` (orchestrate.rb:72) broadcasts nothing (excluded from BROADCAST_STATUSES, ai_job_application_summary.rb:23). If the path rests there (criteria not yet ready) the frontend gets no `ai_summary_status_change` event for that transition.

## Write sites on the S-E path
1. `textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` — AiJobApplicationSummaryStatus; **update_columns**
2. `summary/generate.rb:32` — `existing_ai_summary.update(status: :extracting)` — AiJobApplicationSummary.status; **update**
3. `summary/generate.rb:68` — `ai_summary.update(status: :summarizing, structured_data:)` — AiJobApplicationSummary; **update**
4. `orchestrate.rb:72` — `@ai_job_application_summary.update(status: :awaiting_job_criteria)` — **update**
5. `score_job_application.rb:32` — `@ai_job_application_summary.update(status: :scoring)` — **update**
6. `score_job_application.rb:124` — `@ai_job_application_summary.update(status: :integrating, criteria_results:, score_percentage:)` — **update**
7. `integrate_analysis.rb:53` — `@ai_job_application_summary.update(status: :succeeded, integrated_role_analysis:)` — TERMINAL; **update**
8. `ai_job_application_summary.rb:74-80` — `ai_job_application_summary_status.update(ai_job_application_summary_id:, status:'current', score_percentage:, headline:, integrated_role_analysis:)` — AiJobApplicationSummaryStatus; **update**
9. (failure) `generate_ai_job_application_summary_job.rb:19` & `:44` — `ai_summary&.update_columns(status: :failed, error_message:)` — **update_columns**
10. (validation-fail branch) `textract_result.rb:134` — `ai_summary_waiting_on_textract.destroy` — AiJobApplicationSummary destroyed
