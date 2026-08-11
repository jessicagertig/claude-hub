# Findings — AI Summary Creation Gaps + docx→Textract Trigger (2026-06-23)

Source repo: `/Users/jessica/wrk/wrk-corp/inflow-ats` · branch `ai-summary-creation-gaps`.
Method: each issue traced against the verified map + LIVE code, adversarially verified by an independent agent, and (issues 1/5/6 + DELTA-1) **reproduced with passing rspec** (temp spec, since deleted). Per-issue detail: `exploration/issue*.md`. Orchestrator-verified live-code facts: `orchestrator-grounding-notes.md`.

Every gap below is a DELTA proven against code, not the map alone. Where the 2026-06-22 map and live code disagree, **live code wins** (noted).

---

## Executive summary

| # | Gap (one line) | Confidence | In this spec? |
|---|---|---|---|
| 1 | Auto-generate NEVER creates an `AiJobApplicationSummary` — no summary exists for an auto-gen application until/unless a human manually generates | PROVEN + reproduced | **YES — core** |
| 2 | docx resumes race: `SubmitResumeToTextract` submits the raw `.docx` to AWS before `DocxToPdfJob` attaches the PDF → no usable `TextractResult` → no auto summary | PROVEN (DELTA mechanism-independent) | **YES — core** |
| 3 | `AiJobApplicationSummaryStatus` has no failed/error value; the row stays `initial_summary_pending`/`regenerating`/`current` with stale data when a summary ends `failed`; recoverable only by manual regen | PROVEN | **YES (3a)** — failed display state |
| 4 | `awaiting_job_criteria` + `retrying` are excluded from `BROADCAST_STATUSES`; the detail card freezes, the list/Activity show nothing while a summary is mid-pipeline | PROVEN | **YES — core** |
| 5 | `has_many :ai_job_criteria` is internally consistent and prevents the OLD overwrite — but it is NOT the incident's fix. The incident is the stuck-pending poison (see #6). | PROVEN + reproduced | **YES — V1 root-cause fix** |
| 6 | An `AiJobCriteria` can sit `pending` forever (no advancing actor) and poison all future extraction for the job; root trigger is an enqueue-inside-transaction race (V1) | PROVEN + reproduced | **Investigate-only** (V1 fix lands under #5; sweeper DEFERRED) |
| C1 | `update_summary_status_record` has no `stale?` guard → copies a stale summary's data onto the status row | PROVEN | **YES** (merge w/ #3) |
| C4 | X3 `resume_waiting_summaries` drops the requesting user → criteria-resumed manual summary loses its `AI_SUMMARY_COMPLETE` toast | PROVEN | **YES** (1-line) |
| C3 | T8 bulk backfill has no idempotency guard → duplicate `TextractResult`s | PROVEN | DEFER (note) |
| C6 | `lib/tasks/ai_bulk_extract.rake` writes enum values not in the enum → `ArgumentError` | PROVEN | OUT (dead rake) |

**The cross-cutting root cause (issues 5 + 6 + the incident):** criteria extraction is enqueued **inside the Job `before_update` transaction** (V1). On Rails 6.1.7.7 (no `enqueue_after_transaction_commit`), a Sidekiq worker can run `ExtractJobCriteriaJob` before the Job commits → `AiJobCriteria.find_by(id:)` is nil → `return unless ai_job_criteria` → the job exits silently → the criteria record commits `pending` with nothing left to advance it. The `pending`-guard then blocks every later extraction (incl. the manual generate). This exactly reproduces Jessica's incident, and `has_many` does not touch it.

---

## Issue 1 — Auto-generate never pre-creates a summary  [PROVEN; reproduced]

**CURRENT.** `enqueue_new_job_application` (`job_application.rb:164-171`, `after_commit on: [:create]`) creates only the status row (`find_or_create_ai_job_application_summary_status`, `:170`) — never an `AiJobApplicationSummary`, never reads `should_auto_generate_ai_summaries?`. The auto-gen decision lives ONLY in the bridge `TextractResult#queue_ai_summary_job` else branch (`textract_result.rb:137-143`, `should_auto_generate_ai_summaries?` at `:138`), which fires only after Textract text lands (`:115-116`). With no pre-existing summary the else branch enqueues a job that returns without creating one (`Orchestrate#call` bails at `orchestrate.rb:16`; `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82`). And a FAILED Textract uses `update_columns` (`get_resume_text_from_textract.rb:40`) which never sets `textract_job_result_text`, so the bridge never even fires. **Reproduced:** a new auto-gen job_application has **0** `AiJobApplicationSummary` records and only a `none` status row.

**Broader than the incident:** auto-gen first-summary creation is non-functional even on Textract SUCCESS — not only on failure. Decisive corroboration: `bulk_generate_ai_summaries_job.rb:70-72` carries an in-code comment that the bulk path must pre-create the row via `CreateBulkAiSummaryGeneration` "or Orchestrate finds no row and bails"; the single-send path uses `CreateAiSummaryGeneration`; the auto-gen bridge else branch has NO equivalent.

**INTENDED.** On every auto-gen submission (auto-gen ON, gates pass), build an `AiJobApplicationSummary` immediately; `textract_processing` while Textract is pending; the bridge then advances it.

**DELTA.** No auto-gen pre-create step exists. Mirror the analog `CreateAiSummaryGeneration` (`create_ai_summary_generation.rb:46-58`, builds `status: :textract_processing`).

**Scope decision (in spec).** Add a synchronous pre-create on the auto-gen entry, gated by `should_auto_generate_ai_summaries?` + the `ValidateAiSummaryGeneration` guards (flipper, credits, has_resume, has_job_description) **without** Validate's Textract-submit side effect (`validate_ai_summary_generation.rb:39`), since `enqueue_new_job_application:168` already submits. Synchronous (in the after_commit callback), not a job, so it exists before `SubmitResumeToTextractJob` runs (preserves the stale/relink ordering at `submit_resume_to_textract.rb:18-26`). Then the bridge's waiting-summary `if` branch (`textract_result.rb:121-135`) advances it with no requesting user (no toast), charging a credit on success.

**Decisions (I will resolve in the spec; Jessica may override):**
1. **On Textract terminal failure → PERSIST the summary as `failed`, do NOT destroy it.** Jessica's stated intent ("that summary should be `textract_processing` so it's visible") + issue-3's failed display state argue for persistence. This requires `cleanup_orphaned_summary` (`get_resume_text_from_textract_job.rb:10-23`) to transition the auto summary to `failed` rather than `destroy` it (C8). [Decision — flagged.]
2. **Charge a credit on auto-gen success** (it produces a real summary, like manual). This is a behavioral change from today's case-1 "no credit." [Decision — flagged.]
3. **Apply uniformly to all auto-gen entries** (T1/T3/T4/T5) via the `should_auto_generate_ai_summaries?` gate.

**Side effects to handle (from issue-7):** C7 — `destroy_previous_textract_results` (`ai_job_application_summary.rb:47-55`) + `TextractResult dependent: :destroy` (`textract_result.rb:5`) can cascade-destroy a pre-created in-flight summary if a sibling `TextractResult` succeeds first. C8 — `cleanup_orphaned_summary` (handled by decision 1).

---

## Issue 2 — docx→Textract ordering race  [PROVEN; DELTA mechanism-independent]

**CURRENT.** `enqueue_new_job_application` (`job_application.rb:165-169`) and the T2 controller (`job_applications_controller.rb:110-114`) enqueue `DocxToPdfJob` and `SubmitResumeToTextractJob` as independent `perform_later` with NO ordering. `DocxToPdfJob#perform` → `handle_possible_docx_resume` (`job_application.rb:733-751`) converts via a slow ConvertApi call (180s timeout, `:759`) then attaches `resume_docx_to_pdf` and broadcasts `docx_to_pdf_conversion_complete` (`:746`) — it does NOT trigger Textract. `SubmitResumeToTextract:15` falls back to the raw `resume` when `resume_docx_to_pdf` is not yet attached. Because conversion is slow and the Textract submit is fast, **docx predictably loses the race** and the raw `.docx` is sent to AWS Textract (PDF-only). Whatever AWS does (sync `UnsupportedDocumentException` or async FAILED job), `textract_job_result_text` is never populated, so the bridge guard `textract_result.rb:115` blocks summary generation. No automatic actor re-submits (self-healing needs an existing `TextractResult`; recovery actors need user/manual action).

**INTENDED.** For docx: fire Textract only after `resume_docx_to_pdf` is attached. For PDF: fire directly as today.

**DELTA.** The docx ordering does not exist. Holds under both AWS failure modes (bridge guard `:115` is the mechanism-independent reason).

**Scope decision (in spec).** Branch on `resume_is_docx` (`job_application.rb:697-701`) at both creation sites: PDF → direct `SubmitResumeToTextractJob` (flag-gated); docx → enqueue `SubmitResumeToTextractJob` from `DocxToPdfJob#perform` **after** `handle_possible_docx_resume` returns (covers conversion-failure: still attempts as today, no regression), re-checking `TEXTRACT_RESUME_PROCESSING`. `DocxToPdfJob` still always runs for docx (the viewer needs it). Analog: `submit_resume_to_textract.rb:27` already chains a follow-on job from inside a success path. **Note:** the recovery actors (`validate_ai_summary_generation.rb:39/55`, `queue_bulk_ai_summary_jobs.rb:29`) remain docx-race-exposed; lower severity (they run after conversion usually completes) — out of this fix's scope, noted.

---

## Issue 3 — Status row has no failed state; stale denormalized data  [PROVEN]

**CURRENT.** `AiJobApplicationSummaryStatus` enum = `{none, initial_summary_pending, current, regenerating}` (`ai_job_application_summary_status.rb:9-14`) — no failed value. `update_summary_status_record` fires only on `→succeeded` (`ai_job_application_summary.rb:69`). **Critical mechanism split (verifier):** the dominant terminal-failure writers use `update_columns` (`generate.rb:180/184`, `generate_ai_job_application_summary_job.rb:19/44`) which BYPASS the callback entirely; the `.update` failure writers (`score_job_application.rb`, `integrate_analysis.rb`) fire the callback but hit the `:69` guard. Either way the row never moves to a failed state. Three windows leave the row stuck/stale; all recover on a later manual/bulk regen (none stuck-forever). Worst sub-case: a row at `current` whose summary later fails keeps showing the OLD score as authoritative.

**INTENDED.** When the latest summary ends `failed`, the row should show a failed/error display state, not a frozen "generating" or stale "current."

**DELTA (3a, in spec).** No failed enum value + no writer transitions the row on summary failure. **Fix must write the status-row failure at the failure SITES (or a shared helper), NOT only via the after_commit callback** — because `update_columns` failures bypass it. Add an enum value (`failed`/`error`) outside counter_culture's `status IN (2,3)` range (so a failed review decrements `jobs.ai_job_application_summaries_count` — correct). Update FE consumers (`JobApplicationNavItem`, `PlatoTab`, `JobApplicationActivity`, TS union `jobApplication.ts:4`).

**Merge C1 (in spec):** add `return if stale?` at the top of `update_summary_status_record` (`ai_job_application_summary.rb:74-80`) so the success path never copies a stale summary's denormalized fields onto the row (map window #7). Same staleness symptom, distinct mechanism.

**Deferred (NOT in spec):** clearing denormalized columns on the `regenerating` transition (behavior change — currently prior data is shown intentionally during regen; needs Jessica's call). **Solution 3 (S-D/T2 auto-continuation building a fresh summary + charging a credit)** — billing change, high blast radius (touches `Orchestrate`'s central selection) — separate spec cycle per pipeline rule 10.

---

## Issue 4 — No UI signal during awaiting_job_criteria / retrying  [PROVEN]

**CURRENT.** `BROADCAST_STATUSES` (`ai_job_application_summary.rb:23`) omits `awaiting_job_criteria` and `retrying`; `broadcast_status_change` (`:100-102`) suppresses those transitions. The status row stays `initial_summary_pending`. PlatoTab's full-summary query is invalidated only by `ai_summary_status_change` (which never fires for these), with no `refetchInterval`, so the card freezes at the last broadcast step ("Analyzing the candidate"). The list/Activity render nothing (row not current/regenerating). Happy path: X3 (`resume_waiting_summaries` on criteria succeeded) advances to scoring/integrating/succeeded (which broadcast). Under issue 6 (stuck-pending criteria) the window is unbounded → permanent frozen card.

**INTENDED.** The user should see live progress during these windows.

**DELTA + scope decision (in spec).** Add `awaiting_job_criteria` + `retrying` to `BROADCAST_STATUSES` (analog: `regenerating` already broadcasts `ai_summary_status_change`). HARD requirements: (1) convert `generate.rb:175` retrying `update_columns`→`.update` (else the generate-path retrying stays silent — `update_columns` bypasses callbacks); (2) invert the committed spec `ai_job_application_summary_spec.rb:57-62` (asserts NO broadcast) and grep `spec/` for stale refs (Known Failure Pattern #6); (3) extend `PlatoLoadingState.tsx:22-28` `STATUS_TO_STEP` to include these statuses (else the stepper stays frozen even when the query goes live). Only detail-view queries invalidate — no list refetch storm.

---

## Issue 5 — has_many criteria: sound refactor, NOT the incident fix  [PROVEN; reproduced]

**CURRENT / verdict.** `Job has_many :ai_job_criteria` (`job.rb:52`) is **internally consistent and complete**: non-unique index (`schema:190`, migration `20260622204646`), collection-aware readers `latest_ai_job_criteria`/`latest_succeeded_ai_job_criteria` (`job.rb:688-694`), new-row writers (`job.rb:703/720`), no surviving singular reader, no serializer/FE/`_ids` ripple, `resume_waiting_summaries` unaffected. **It prevents the OLD has_one overwrite** (reproduced: a failed row is preserved, a NEW record is created). The **map is STALE** on cardinality (describes the deleted has_one reset writer).

**The incident is NOT overwrite — it is the stuck-pending poison (issue 6).** Reproduced: a `pending` latest criteria makes `extract_job_criteria` and `auto_extract_job_criteria` no-ops (poison guard `job.rb:701/718`), and Orchestrate parks the summary at `awaiting_job_criteria`. `has_many` is byte-identical here.

**DELTA-5/V1 (in spec — root-cause fix).** Criteria extraction is enqueued inside the Job `before_update` transaction: `before_update :handle_before_update` (`job.rb:60`) → `handle_status_changed_to_published` (`:544-560`) / `handle_description_change` (`:726-731`) → `auto_extract_job_criteria` → `ExtractJobCriteriaJob.perform_later` (`job.rb:707/709`), pre-commit, on Rails 6.1.7.7 (no `enqueue_after_transaction_commit`). Worker can run before commit → `find_by` nil → silent exit → stuck `pending`. **Fix:** move the criteria enqueue to after the Job commits — the file already has `after_commit :handle_after_update_commit` (`job.rb:59/491`) enqueuing other jobs (Webflow/WhatJobs); route `auto_extract_job_criteria`'s enqueue there (or wrap the enqueue post-commit). Surgical, low-risk, mirrors the existing after-commit enqueue pattern. This prevents the incident at the source.

**DELTA-1 (decision — likely DEFER).** `orchestrate.rb:74` + `score_job_application.rb:19` use `latest_ai_job_criteria` (newest, any status); a newer FAILED masks an older SUCCEEDED → a redundant re-extraction (self-healing, never a wrong score). `latest_succeeded_ai_job_criteria` is dead code. A naive switch risks serving STALE criteria after a description edit (`handle_description_change` deliberately re-extracts) — needs freshness logic. LOW severity + self-healing + risky → DEFER/NOTE unless Jessica wants it.

**Spec-coverage gap (note):** none of the 5 pre-loaded specs test multiple criteria rows — the has_many semantics, `latest`/`latest_succeeded` selection, failed-then-retrigger, and the poison guard are UNTESTED. New specs should cover these.

---

## Issue 6 — AiJobCriteria stuck pending forever  [PROVEN; reproduced — INVESTIGATE-ONLY per KICKOFF]

**CURRENT.** A `pending` criteria's only advancing actor is its own `ExtractJobCriteriaJob` → `ExtractCriteria#extract` (first write `update_columns(:in_progress)` at `extract_criteria.rb:28`). Once a job's `latest_ai_job_criteria` is `pending`, every other entry point is guarded off: `auto_extract_job_criteria` (`job.rb:701`), `extract_job_criteria` (`job.rb:718`), Orchestrate (`orchestrate.rb:80`), ScoreJobApplication pending branch (`score_job_application.rb:27-30`). No cron/sidekiq-cron/rake re-drives pending criteria. Loss vectors: **V1** enqueue-in-transaction race (code-attributable, the publish path — strongest); **V2** job enqueued but never run (infra); **V3** record deleted / `@job`|`@organization` nil before `:28`. The poison guard then blocks all future criteria for the job → every later job_application's summary parks at `awaiting_job_criteria` (amplifier to issues 4 + 5). The `failed`-criteria variant stalls identically (C9: `update_columns` failure → `resume_waiting_summaries` never fires).

**Scope.** Per KICKOFF, **investigate-only — do NOT build the sweeper tonight.** The **V1 after_commit fix (under issue 5)** prevents most NEW stuck-pending records at the source. A polling sweeper/reaper for already-stuck records and residual V2/V3 (and possibly making `extract_criteria.rb:23/26` early-returns write `failed`) is **DEFERRED** (needs usage data) — documented for a future cycle.

---

## Other gaps (issue-7 sweep)

- **C1** (in spec, merged with #3): `update_summary_status_record` no stale guard.
- **C4** (in spec): X3 `resume_waiting_summaries` (`ai_job_criteria.rb:24-27`) drops the requesting user → lost `AI_SUMMARY_COMPLETE` toast for a criteria-resumed manual summary. 1-line fix: pass `requesting_organization_user_id: ai_job_application_summary.requested_by_organization_user_id`.
- **C3** (DEFER, note): T8 bulk backfill (`queue_bulk_ai_summary_jobs.rb:22-30`) has no idempotency guard → duplicate `in_progress` `TextractResult`s. Resource/cost gap, not a "summary not created" gap. Note for a follow-up.
- **C2** (NOT a gap): no-row case unreachable (`find_or_create` always runs first; `save==false` path dead).
- **C5** (NOT a gap; defensive note): bridge selector vs Orchestrate advancer — at most one non-stale `textract_processing` summary per job_application, so they coincide. Optionally add `order(created_at: :desc)` to the bridge selector (`textract_result.rb:121-123`) defensively.
- **C6** (OUT): `lib/tasks/ai_bulk_extract.rake` writes `:in_progress`/`:extracted` (not in the enum) → `ArgumentError`. Dead/broken rake; retire separately.

---

## Reproductions run (temp rspec, since deleted) — all passed

1. has_many preserves a failed criteria; a NEW record is created (no overwrite).
2. Poison guard: `extract_job_criteria` + `auto_extract_job_criteria` are no-ops when latest criteria is `pending`.
3. DELTA-1: `latest_ai_job_criteria`→newer failed; `latest_succeeded_ai_job_criteria`→older succeeded.
4. Issue 1: a new auto-gen job_application has 0 summaries, only a `none` status row.
5. Issue 6 amplifier: Orchestrate parks the summary at `awaiting_job_criteria`, creates no new criteria, criteria stays `pending`.

---

## Scope of the spec (decision)

**IN SCOPE (implement):** Issue 1 (auto-gen pre-create), Issue 2 (docx chaining), Issue 3a (status failed state + C1 stale guard), Issue 4 (broadcasts + loading state), Issue 5/V1 (criteria enqueue after_commit), C4 (X3 requesting user).

**DECISIONS made (Jessica may override):** persist-auto-summary-as-failed on Textract failure; charge a credit on auto-gen success; failed-status value outside counter_culture range.

**DEFERRED / OUT (documented, not built):** Issue 6 sweeper/reaper; Issue 3 regenerating-clear + Solution 3 (S-D/T2 credit); DELTA-1 (latest_succeeded freshness); C3 (bulk backfill idempotency); C5 (defensive selector order); C6 (dead rake).
