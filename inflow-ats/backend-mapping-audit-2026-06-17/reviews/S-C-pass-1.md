# S-C — Auto-generate via TextractResult callback (else branch)

**Slice:** S-C — `TextractResult after_commit :queue_ai_summary_job`, the `else` (no-waiting-summary) branch that fires when `should_auto_generate_ai_summaries?` is on.
**Branch audited:** `UI-polishes` (map was written for `feature-ai-summaries-integrating-scoring-v4`).

## File chain traced

```
app/models/textract_result.rb:7 (after_commit :queue_ai_summary_job)
  -> textract_result.rb:114-144 (queue_ai_summary_job, else branch 137-143)
    -> textract_result.rb:138 job.should_auto_generate_ai_summaries?
        -> app/models/job.rb:914-922 (should_auto_generate_ai_summaries?)
            -> job.rb:159-163 (enum auto_generate_ai_summaries {default,enabled,disabled} _prefix:true)
            -> app/models/organization.rb:965-967 (auto_generate_ai_summaries_enabled -> settings.dig)
            -> organization.rb:1274 (default settings: auto_generate_ai_summaries_enabled: false)
    -> textract_result.rb:140 ValidateAiSummaryGeneration.call
        -> app/interactors/validate_ai_summary_generation.rb:1-84
    -> textract_result.rb:142 GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)  [no user id]
        -> app/jobs/generate_ai_job_application_summary_job.rb:24-46 (perform)
            -> generate_ai_job_application_summary_job.rb:32 textract_result.generate_ai_summary_with_credit_flow
                -> textract_result.rb:61-89 (generate_ai_summary_with_credit_flow)
                    -> textract_result.rb:67 job_application.latest_ai_job_application_summary
                        -> app/models/job_application.rb:31 (has_one latest_ai_job_application_summary)
                    -> textract_result.rb:70 find_or_create_ai_job_application_summary_status
                        -> job_application.rb:160-162 -> app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47
                    -> textract_result.rb:72 set_initial_summary_pending (private, 98-108)
                    -> textract_result.rb:74 generate_ai_summary -> Orchestrate
                        -> app/services/ai_job_application_action/orchestrate.rb:9-50 (call)
                            -> orchestrate.rb:15-16 (return unless @ai_job_application_summary)  <-- DEAD END when no summary
                            -> orchestrate.rb:64 Summary::Generate (ONLY production creator of the summary)
                                -> app/services/ai_job_application_action/summary/generate.rb:30-40
```

---

## Behaviors

### B1 — Callback fires on create AND update

(a) `app/models/textract_result.rb:7` — `after_commit :queue_ai_summary_job, on: [:create, :update]`
(b) Map line 417: "Fires `after_commit :queue_ai_summary_job` on create or update."
(c) **CONFIRMED**
(d) Map text OK.

### B2 — Early guards: text present + the triggering change

(a) textract_result.rb:115 `return unless textract_job_result_text.present?`; :116 `return unless saved_change_to_textract_job_result_text?`; :118-119 `organization = job_application&.job&.organization` / `return unless organization`
(b) Map lines 420-423 list guards 1-3 identically.
(c) **CONFIRMED**

### B3 — Branch selector: waiting summary vs else

(a) textract_result.rb:121-124 builds `ai_summary_waiting_on_textract = job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first`; :125 `if ai_summary_waiting_on_textract` ... :137 `else`.
(b) Map lines 424-428 describe two paths.
(c) **CONFIRMED**. S-C is the `else` branch (lines 137-143).

### B4 — Auto-generate setting check (only in else branch)

(a) textract_result.rb:138 `return unless job_application&.job&.should_auto_generate_ai_summaries?`
   - job.rb:914-922: returns `true` if `auto_generate_ai_summaries_enabled?` (per-job enum == enabled), `false` if `..._disabled?`, else falls to `organization.auto_generate_ai_summaries_enabled`.
   - organization.rb:965-967: `settings&.dig('auto_generate_ai_summaries_enabled')` — nil/false by default (org.rb:1274 seeds it `false`).
(b) Map lines 446-454: "Per-job enum default(0)/enabled(1)/disabled(2) _prefix:true; if default falls to org default `settings['auto_generate_ai_summaries_enabled']` (boolean, default false). Checked at TextractResult callback only."
(c) **CONFIRMED** (enum, fallback chain, org default false, checked only here all match).

### B5 — Else branch runs ValidateAiSummaryGeneration, enqueues job WITHOUT user id

(a) textract_result.rb:140 `result = ValidateAiSummaryGeneration.call(job_application:, organization:)`; :142 `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?`
   - Note: no `requesting_organization_user_id:` argument is passed (contrast the `if` branch, line 128-131, which passes it).
(b) Map line 427: "No existing summary + auto-generate enabled: validates, enqueues job."; map line 697 (Trigger C row): "User Broadcast: None."
(c) **CONFIRMED**. The absence of `requesting_organization_user_id` is what makes this path silent. Worth adding to map explicitly.
(d) Map text: "Else branch (textract_result.rb:137-143): `ValidateAiSummaryGeneration.call`; on success `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with NO `requesting_organization_user_id`. On validation FAILURE in the else branch: nothing happens (no destroy, no broadcast) — silent no-op."

### B6 — Validation failure in else branch is a silent no-op

(a) textract_result.rb:140-142 — the `else` branch only enqueues `if result.success?`. There is NO `else`/failure handling in the else branch (unlike the `if` branch lines 132-136 which destroy the summary and broadcast `AI_SUMMARY_FAILED`).
(b) Map ABSENT — the map does not state what happens on validation failure for the no-waiting-summary path.
(c) **NEW** (documentation gap in map).
(d) Map text as in B5(d).

### B7 — ValidateAiSummaryGeneration now also requires a job description

(a) validate_ai_summary_generation.rb:29 `context.fail!(error: 'This job needs a description before Plato can review candidates...') unless has_job_description?`; :81-83 `has_job_description? -> @job_application.job&.description.present?`
(b) Map lines 216-227 list checks 1-6 (job app, org, AI_APPLICANT_SUMMARY flipper, has_resume, credits, textract); NO job-description check.
(c) **CHANGED / NEW** — a 6th fail-fast guard was added that the map omits. On the S-C path, a job with no description fails validation → `result.success?` false → job never enqueued (silent, no broadcast).
(d) Map text: add to ValidateAiSummaryGeneration checks: "Job has a description: `job.description.present?` — fail message 'This job needs a description before Plato can review candidates. Add one in Job Setup.'"

### B8 — Validate's no-textract self-heal is unreachable on the S-C path

(a) validate_ai_summary_generation.rb:31 `@latest_textract_result = @job_application.latest_textract_result` (job_application.rb:685-687, latest by created_at desc); :38-42 if nil -> `SubmitResumeToTextractJob.perform_later` + `textract_pending = true` + return.
(b) Map lines 222-227.
(c) **CONFIRMED but contextually inert for S-C**: on the S-C path the callback only fires because a TextractResult exists with text (B2), so `latest_textract_result` is non-nil and `textract_text_ready?` (line 44, 73-75) is true → `textract_pending = false`. Validation succeeds. The branch logic the prompt asks about (textract_processing wait vs forward) is therefore NOT exercised inside Validate on the auto path — text is always ready when this callback fires.
(d) Map text: "On the auto-generate (S-C) path Validate always sees textract text ready (the callback's own guard requires `textract_job_result_text.present?`), so `textract_pending` resolves false and validation only fails on flipper/resume/credits/job-description."

### B9 — TERMINAL TRACE: auto-generate with NO pre-existing summary is a DEAD END

This is the headline finding for S-C.

(a) After enqueue, the job runs `generate_ai_summary_with_credit_flow` (textract_result.rb:61):
  - :67 `latest_ai_summary = job_application.latest_ai_job_application_summary` -> nil (fresh app, no summary yet)
  - :68 `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` -> guard passes (nil), proceed
  - :70 `find_or_create_ai_job_application_summary_status` -> creates/updates the STATUS row only (find_or_create_ai_job_application_summary_status.rb), NOT a summary
  - :72 `set_initial_summary_pending(status_result)` -> textract_result.rb:100-101 `return unless status_record && latest_summary` -> latest_summary nil -> returns, no-op
  - :74 `generate_ai_summary` -> Orchestrate#call -> orchestrate.rb:15 `@ai_job_application_summary = ...order(created_at: :desc).first` -> nil -> :16 `return unless @ai_job_application_summary` -> **RETURNS. Summary::Generate (orchestrate.rb:64, the ONLY production creator of an AiJobApplicationSummary) is never reached.**
  - back at :77 `ai_job_application_summary = ai_job_application_summaries.order(...).first` -> still nil -> :82 `return unless ai_job_application_summary&.status_succeeded?` -> returns. No credit consumed, no notifications, NO summary record created.

  Grep confirms the only production AiJobApplicationSummary creators are `Summary::Generate` (generate.rb:35, reached only via `Orchestrate#run_summary` at orchestrate.rb:64) and the manual/bulk interactors `create_ai_summary_generation.rb:47/60` and `create_bulk_ai_summary_generation.rb:50` (S-A / S-B paths). The auto-generate callback path goes through NONE of these when no summary pre-exists.

(b) Map lines 200-211 ("Auto-generation triggers (TextractResult callback) skip CreateAiSummaryGeneration -> ValidateAiSummaryGeneration -> GenerateAiJobApplicationSummaryJob -> generate_ai_summary_with_credit_flow -> Orchestrate -> same pipeline"), and Trigger C (lines 412-428, 697): present auto-gen as producing a summary "1 on success". The map's Orchestrate section (line 270) says it "Finds the latest AiJobApplicationSummary... reads its status, and dispatches" but NEVER documents the `return unless @ai_job_application_summary` early-out (orchestrate.rb:16). The map shows pending/textract_processing -> run_summary as if a summary always exists.

(c) **MAP-WRONG / CHANGED**: the map asserts the auto-generate callback path generates a summary; in current code on `UI-polishes` it does NOT when there is no pre-existing summary, because Orchestrate returns before `Summary::Generate` and nothing on the auto path creates the first summary. Terminal state = no summary, no credit, no broadcast (silent). The path comes to rest with NO advancing actor having created a record. This is a genuine dead end on the slice.
(d) Map text: "Orchestrate#call (orchestrate.rb:15-16) returns early `unless @ai_job_application_summary` — it dispatches an EXISTING summary, it does NOT create one. The only production creator of the first AiJobApplicationSummary is `Summary::Generate` (generate.rb:35), reachable only via `Orchestrate#run_summary` (orchestrate.rb:64), which is reached only when a summary already exists. Consequence: the auto-generate callback (S-C) path enqueues the job, but when the job_application has no pre-existing AiJobApplicationSummary the pipeline is a NO-OP — no summary is created, no credit consumed, no broadcast. Auto-generation as a standalone first-summary trigger does not produce a summary on this branch."

### B10 — set_initial_summary_pending status semantics

(a) textract_result.rb:98-108: `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')`, guarded by `status_none? || status_initial_summary_pending?` (line 102). Uses the AiJobApplicationSummaryStatus enum value `initial_summary_pending`.
(b) Map ABSENT for `set_initial_summary_pending`; map's AiJobApplicationSummaryStatus enum (lines 509-511) lists the FULL summary enum (pending..failed), which is WRONG.
(c) **MAP-WRONG** on the status enum; **NEW** behavior `set_initial_summary_pending`. Note it is a no-op on the S-C no-summary path (latest_summary nil, line 100-101).
(d) Map text: "AiJobApplicationSummaryStatus enum is `{none(0), initial_summary_pending(1), current(2), regenerating(3)}` (_prefix:true), NOT the full summary enum. `TextractResult#set_initial_summary_pending` (textract_result.rb:98-108) sets the status row to `initial_summary_pending` (only from `none`/`initial_summary_pending`) when a latest summary exists; no-op otherwise."

---

## Map structural discrepancies touching this slice (callbacks on AiJobApplicationSummary)

The map (lines 499-502) lists `after_commit :create_status_record, on: :create` on AiJobApplicationSummary. **REMOVED** — current `ai_job_application_summary.rb:29-31` has only `destroy_previous_textract_results` (on:update), `update_summary_status_record` (on:update), and `before_update :broadcast_status_change`. No `create_status_record`. Status-record creation now lives in `FindOrCreateAiJobApplicationSummaryStatus` (called from `enqueue_new_job_application` job_application.rb:170 and from `generate_ai_summary_with_credit_flow` line 70). This matches inflow-ats failure-pattern #16 refactor.

`update_summary_status_record` (ai_job_application_summary.rb:57-98): map (line 502/605) says it sets `regenerating: false` and `status: statuses['succeeded'] (7)` via `update_columns`. Current code sets `status: 'current'` via `.update` (line 74-76), does NOT touch `regenerating`, and additionally broadcasts `JobChannel ... event: 'ai_summary_succeeded'` (lines 93-97). **CHANGED.** (Primarily an AiJobApplicationSummaryStatus-slice concern; noted here because it is the actor that brings the status row to rest at `current` after a summary the S-C path would have produced.)

---

## Desync window relevant to S-C

- S-C enqueues `GenerateAiJobApplicationSummaryJob` with NO `requesting_organization_user_id`. Every broadcast in that job (`broadcast_completion`, lines 34/45/20) is gated on `requesting_organization_user_id`, so the auto path NEVER toasts the user via GlobalChannel. The only frontend signal possible on this path is the `JobChannel` broadcasts fired from `AiJobApplicationSummary#broadcast_status_change` (before_update, gated on `BROADCAST_STATUSES`) and `update_summary_status_record` (`ai_summary_succeeded`). Since transitions into `awaiting_job_criteria` and `retrying` are excluded from `BROADCAST_STATUSES` (ai_job_application_summary.rb:23), a summary parked in `awaiting_job_criteria` on the auto path emits no status-change broadcast — the stage list does not learn of the transition until a `current`/`succeeded` update fires `update_summary_status_record`. (Only reachable once a summary exists; on the no-summary dead end nothing broadcasts at all.)

---

## Record-write sites found on the S-C slice

| file:line | literal | record / column | op |
|---|---|---|---|
| app/models/textract_result.rb:104-107 | `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` | AiJobApplicationSummaryStatus: `ai_job_application_summary_id`, `status` | update_columns (no callbacks) |
| app/interactors/find_or_create_ai_job_application_summary_status.rb:15 | `@status_record.update_columns(status: 'regenerating')` | AiJobApplicationSummaryStatus: `status` | update_columns |
| app/interactors/find_or_create_ai_job_application_summary_status.rb:28-34,37 | `build_ai_job_application_summary_status` then `@status_record.save` (status 'current'+denorm cols OR 'none') | AiJobApplicationSummaryStatus: `ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis` | create via save (callbacks) |
| app/services/ai_job_application_action/summary/generate.rb:35-39 | `AiJobApplicationSummary.create(job_application:, textract_result:, status: :extracting)` | AiJobApplicationSummary: `status, textract_result_id, job_application_id` | create — **NOT reached on S-C no-summary dead end** |
| app/jobs/generate_ai_job_application_summary_job.rb:19 / :44 | `ai_summary&.update_columns(status: :failed, error_message: ...)` | AiJobApplicationSummary: `status, error_message` | update_columns — only if a summary exists (no-op on dead end) |

**Note:** `CreateAiCreditBalanceTransaction` (textract_result.rb:84) is NOT reached on the S-C no-summary dead end (returns at line 82). No credit is written.
