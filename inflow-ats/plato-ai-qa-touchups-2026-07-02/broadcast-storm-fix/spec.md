# Spec: Fix AI review broadcast / query-invalidation storm

**Status:** DRAFT — contains OPEN DECISIONS that must be confirmed before implementation.
**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Symptom:** Redis overloaded with Sidekiq jobs + ActionCable pub-sub; frontend hammered. Reproduces on both `inflow-ats-production` and App Develop (separate apps, separate Redis) → it is **code**, not one overloaded Redis instance.
**Trigger correlation (Jessica):** started when we added live broadcasting of `AiJobApplicationSummaryStatus` changes to handle the no-job-criteria case.

---

## 1. Original intent to preserve (do NOT regress)

The `AiJobApplicationSummaryStatus` broadcast was added (commit `bf65446fd`, 2026-07-06) to fix a real UX bug on **retry / regenerate**:

1. Clicking retry did not update the card to show it was **processing**.
2. When it later failed (due to job criteria), the card did not update to show **failed**.
3. If it did briefly show processing (a race), it never cleared the processing state on criteria failure.

This behavior is correct and required. The fix below must keep the card updating live on retry (processing → failed / succeeded). The bug is **how** it broadcasts, not **that** it broadcasts.

**Load-bearing fact:** generation creates a new summary row —
`app/services/ai_job_application_action/summary/generate.rb:35` → `AiJobApplicationSummary.create(...)`.
So `AiJobApplicationSummary`'s `after_commit :handle_after_update_commit, on: [:update]` does **not** fire on a fresh review, and on regenerate the prior succeeded summary stays `current` while a new row is inserted. The **only** live signal for "regeneration started" is the `AiJobApplicationSummaryStatus` transition (`current → regenerating`). Therefore the status-record broadcast cannot simply be deleted.

---

## 2. Root cause (traced end-to-end)

Chain:
`app/jobs/bulk_generate_ai_summaries_job.rb`
→ `app/models/ai_job_criteria.rb` (`fail_waiting_summaries` / `resume_waiting_summaries`)
→ `app/models/ai_job_application_summary.rb` (`broadcast_status_change` + `update_summary_status_record`)
→ `app/models/ai_job_application_summary_status.rb` (`after_commit :broadcast_status_change, on: :update`)
→ `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:73-82`

### 2a. Two batch loops fan out per-record, with no grouping

`app/models/ai_job_criteria.rb`:

```ruby
# criteria FAILS (added in bf65446fd)
def fail_waiting_summaries
  job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each do |ai_job_application_summary|
    ai_job_application_summary.update(status: :failed, error_message: error_message)   # per-record write
  end
end

# criteria SUCCEEDS
def resume_waiting_summaries
  return unless saved_change_to_status? && status_succeeded?
  job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each do |ai_job_application_summary|
    GenerateAiJobApplicationSummaryJob.perform_later(...)   # one Sidekiq job PER waiting applicant
  end
end
```

### 2b. Each per-record summary write now fires TWO broadcasts

`app/models/ai_job_application_summary.rb`:
- `broadcast_status_change` fires because `failed`/`succeeded` ∈ `BROADCAST_STATUSES` (line 23) → event `ai_summary_status_change`.
- `update_summary_status_record` (line 60) writes the status record → `AiJobApplicationSummaryStatus` `after_commit` → event `ai_summary_status_record_change`.

`BROADCAST_STATUSES = %w[pending textract_processing extracting summarizing awaiting_job_criteria scoring integrating succeeded failed]` — ~8 states, so a single normal scoring lifecycle already broadcasts ~8 times before the doubling.

### 2c. The frontend runs the SAME 3 invalidations for BOTH events

`app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:73-82`:

```tsx
case "ai_summary_status_change":
case "ai_summary_status_record_change":
  queryClient.invalidateQueries(["aiJobApplicationSummary", data.payload.aiJobApplicationSummaryId]);
  queryClient.invalidateQueries(["jobApplication", data.payload.jobApplicationId]);
  queryClient.invalidateQueries(["jobApplicationsForStage", data.payload.hiringStageId]);   // ← ALL apps in the stage
```

`["jobApplicationsForStage", hiringStageId]` refetches **every** job application in the hiring stage via
`app/controllers/api/v1/job_applications_controller.rb:27,38` (`.includes(resume_attachment: :blob).includes(:ai_job_application_summary_status).order(updated_at: :desc)`) — an expensive list query.

### 2d. Amplification math

- **Criteria fails on a bulk of N applicants:** `fail_waiting_summaries` → N × 2 broadcasts → **2N full stage-list refetches**, on **every** connected client viewing that job.
- **Criteria succeeds:** `resume_waiting_summaries` → **N new Sidekiq jobs**, each running the full scoring lifecycle → up to ~8 states × 2 events = **~16 stage-list refetches per applicant**, per client.
- All on the same Redis as the Sidekiq queue → the "too many jobs AND websocket handler" symptom.

### 2e. JobIteration re-runs the fail fan-out

`build_enumerator` (bulk job) resolves criteria synchronously and calls `update_remaining_statuses_to_failed(payload)` when criteria is not succeeded. `JobIteration::Iteration#build_enumerator` is re-invoked on every interruption/resume, so criteria extraction + the fail fan-out can run **more than once** per bulk run.

### 2f. Stray debug

`app/jobs/bulk_generate_ai_summaries_job.rb:208-210` — leftover `ap '[notify_failure] ...'` / `ap user&.id` / `ap job_title` debug prints in the failure path.

---

## 3. OPEN DECISIONS — confirm before implementation

Each has a PROPOSED default. Override any.

**D1 — Which states invalidate the whole stage list (`jobApplicationsForStage`)?**
PROPOSED: only **terminal, list-content-changing** states → `succeeded` and `failed` (a review outcome changes score/headline/sort/filter in the list). Start/intermediate/regenerating → **card-level only** (`["jobApplication", id]` + `["aiJobApplicationSummary", id]`), which still makes the card show processing live. Open question: does the stage list currently sort/filter such that `failed` must invalidate it, or is `succeeded` the only one that changes list content?

**D2 — Grouping mechanism for batch operations.**
PROPOSED: **backend grouping.** After a batch loop (`fail_waiting_summaries`, `resume_waiting_summaries`, `update_remaining_statuses_to_failed`), fire **one** stage-scoped broadcast per affected `hiring_stage_id` that triggers a single `jobApplicationsForStage` invalidation — and suppress the per-record stage-list invalidation for these bulk paths. (Alternative considered: frontend debounce/coalesce of `jobApplicationsForStage` invalidations. Rejected as a timing hack unless you prefer it.) Note: a bulk run can span multiple hiring stages → group per `hiring_stage_id`.

**D3 — Keep both broadcasts, re-scoped (do not delete either).**
PROPOSED: keep `ai_summary_status_change` (summary) and `ai_summary_status_record_change` (status record) but give them **distinct jobs** so they stop duplicating:
- `ai_summary_status_change` (intermediate summary transitions) → **card-level** invalidation only.
- `ai_summary_status_record_change` (status-record transitions incl. regenerate-start and terminal) → drives card update; stage-list invalidation only on terminal per D1.
Rationale: §1 shows the status-record event is the only regenerate-start signal.

**D4 — Make `build_enumerator` criteria resolution + fail fan-out idempotent.**
PROPOSED: **in scope.** Guard so criteria extraction and `update_remaining_statuses_to_failed` run at most once per bulk run even if JobIteration re-invokes `build_enumerator`.

**D5 — N scoring jobs from `resume_waiting_summaries` is correct and stays.**
PROPOSED: **out of scope.** One Sidekiq job per applicant is inherent to per-application scoring; this spec does not reduce job count. It only removes the broadcast/invalidation storm and groups invalidations. Confirm you agree the job count itself is acceptable.

---

## 4. Proposed design (pending §3)

### Backend

1. **Introduce broadcast intent, not just status delta.** Distinguish *card-level* vs *stage-list* broadcasts. Options to finalize with D1/D2/D3: either a `scope:`/`event:` discriminator on the existing `JobChannel` events, or a new stage-scoped batch event (e.g. `ai_summary_stage_batch_change` carrying `hiringStageId`).
2. **`AiJobApplicationSummary#broadcast_status_change`** — keep firing on intermediate transitions but mark them card-level (no stage-list invalidation downstream).
3. **`AiJobApplicationSummaryStatus#broadcast_status_change`** — keep; mark terminal transitions as stage-list-eligible per D1.
4. **`AiJobCriteria#fail_waiting_summaries` / `#resume_waiting_summaries`** — after the loop, emit **one** grouped stage-scoped broadcast per `hiring_stage_id`; do not let each per-record write drive a stage-list refetch.
5. **`BulkGenerateAiSummariesJob#build_enumerator`** — idempotency guard (D4).
6. Remove stray `ap` debug at `bulk_generate_ai_summaries_job.rb:208-210`.

### Frontend — `WebsocketJobChannelHandler.tsx`

1. Split the two `case` blocks so they no longer share a body.
2. Card-level events → invalidate only `["jobApplication", id]` and `["aiJobApplicationSummary", id]`.
3. Terminal / grouped batch events → invalidate `["jobApplicationsForStage", hiringStageId]` (once).
4. Verify the card's processing/failed UI is driven by the single-application query so the retry UX (§1) still works with card-level-only invalidation.

---

## 5. Files to modify (confirm complete during planning)

Backend:
- `app/models/ai_job_application_summary.rb`
- `app/models/ai_job_application_summary_status.rb`
- `app/models/ai_job_criteria.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- possibly `app/channels/job_channel.rb` (if event shape changes)

Frontend:
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx`
- possibly `app/javascript/shared/types/aiJobApplicationSummary.ts` (if payload shape changes)

Read-only dependencies to re-verify during planning:
- `app/controllers/api/v1/job_applications_controller.rb` (`jobApplicationsForStage` query cost)
- `app/services/ai_job_application_action/summary/generate.rb` (insert semantics)
- `app/services/ai_job_application_action/scoring/score_job_application.rb` (criteria fail/blank branches)

## 6. Test requirements (mandatory — no "no tests")

- Model spec: `fail_waiting_summaries` over N awaiting summaries emits exactly **one** grouped stage broadcast per hiring stage (not N, not 2N). Assert broadcast count, not just that a broadcast happened (avoid ghost tests).
- Model spec: `resume_waiting_summaries` enqueues one `GenerateAiJobApplicationSummaryJob` per waiting applicant and emits exactly one grouped stage broadcast.
- Model spec: an **intermediate** summary transition emits a card-level broadcast and does **not** trigger a stage-list invalidation signal; a **terminal** transition does (per D1).
- Model spec: `AiJobApplicationSummaryStatus` `current → regenerating` still broadcasts (regenerate-start signal preserved — §1).
- Job spec: `build_enumerator` re-invocation does not re-run the fail fan-out twice (D4).
- Frontend: `WebsocketJobChannelHandler` invalidates only card queries for card-level events and includes `jobApplicationsForStage` only for terminal/grouped events.

## 7. Out of scope

- Reducing the number of per-applicant scoring jobs (D5).
- Splitting ActionCable onto its own Redis instance — a valid separate mitigation, not required once the storm is removed; revisit with production Redis metrics (`used_memory`, `maxmemory-policy`, `evicted_keys`, `blocked_clients`) if still needed.

## 8. Known-failure-pattern guardrails (from CLAUDE.md)

- Rule 20: do **not** add enum values or repurpose `AiJobApplicationSummaryStatus` states to implement this. Grouping is a broadcast/invalidation change, not a status-model change.
- Rules 10 / 23: fix stays within this defect's scope — no rewriting adjacent methods, no dropping validations, no new migrations.
- Rule 2: trace every AI-summary creation path (single, bulk, automation, apply-response) to confirm the new grouped/card-level broadcast distinction is applied consistently, not only in the bulk path.
