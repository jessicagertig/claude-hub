# Review Angles — AI Summary Creation Gaps + docx→Textract Trigger

Generated from: `SPEC.md` (with `FINDINGS.md` + `exploration/*.md` as verified background)
Date: 2026-06-23
Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats` (branch `ai-summary-creation-gaps`, HEAD `7831b7d16`) — read-only

This file scopes BOTH the spec review (Phase 2) and the post-implementation review (Phase 6). Angles are thematic lenses spanning all layers, not layer silos. Every file:line in the spec was checked against live code as part of scoping; discrepancies are captured in the **source-accuracy** angle below (read it first — several spec citations are off-by-one or name non-existent spec files).

---

## Subsystems touched

**Backend — models**
- `app/models/job_application.rb` — `enqueue_new_job_application` (164-171); W1 call-site for the new interactor (after `:170`), W2 docx/PDF Textract-submit branch (`:166-169`); helpers `resume_is_docx` (697-701), `has_resume_docx_to_pdf` (722-723), `handle_possible_docx_resume` (733-751), `latest_textract_result` (685-686); `after_commit :enqueue_new_job_application, on: [:create]` (`:45`)
- `app/models/job.rb` — W3: `before_update :handle_before_update` (`:60`), `after_commit :handle_after_update_commit, on: [:update]` (**`:58`**, spec says `:59`), `handle_after_update_commit` (491-511), `handle_status_changed_to_published` (544-561, calls `auto_extract_job_criteria` `:560`), `handle_description_change` (726-732, calls it `:731`), `auto_extract_job_criteria` (696-711, `.save` `:704`, enqueue `:707/:709`), `extract_job_criteria` (713-723), pending guards (`:701/:718`), `latest_ai_job_criteria`/`latest_succeeded_ai_job_criteria` (688-694), `should_auto_generate_ai_summaries?` (934-942), `has_many :ai_job_criteria` (`:52`)
- `app/models/ai_job_application_summary.rb` — W4: `BROADCAST_STATUSES` (`:23`), `broadcast_status_change` (100-111); W5: `update_summary_status_record` (57-98, guard `:69`, `.update` 74-80) + new C1 stale guard + new `record_failure` choke-point; summary `enum status` already includes `failed: 9` (10-21); `destroy_previous_textract_results` (47-55, C7)
- `app/models/textract_result.rb` — W1 bridge `queue_ai_summary_job` (114-144; if-branch 125-135, else 137-143, `should_auto_generate_ai_summaries?` `:138`), `generate_ai_summary_with_credit_flow` (61-89; early-return `:68`, credit `:84`), `set_initial_summary_pending` (98-108), `broadcast_ai_summary_failed` (146-160, nil-user return `:147`), `has_many :ai_job_application_summaries, dependent: :destroy` (`:5`, C7)
- `app/models/ai_job_application_summary_status.rb` — W5: `enum status` (9-14, add `failed: 4`), `counter_culture` proc + `column_names` (`:7`, counts status IN (2,3))
- `app/models/ai_job_criteria.rb` — W6: `resume_waiting_summaries` (21-29, re-enqueue 24-27 missing requesting user); `after_commit ... on: [:update]` (`:17`); enum (7-13)

**Backend — interactors / services / jobs**
- `app/interactors/create_auto_ai_summary_generation.rb` — **NEW** (W1, `CreateAutoAiSummaryGeneration`)
- `app/interactors/create_ai_summary_generation.rb` — W1 analog (single-send; reuse-guard 30-44, build 47-53, `requested_by_organization_user_id` `:50`)
- `app/interactors/create_bulk_ai_summary_generation.rb` — W1 analog (bulk; build `:50`, "or Orchestrate bails" comment 3-12)
- `app/interactors/validate_ai_summary_generation.rb` — W1 guard source (checks 26-29; methods 65-83; the Textract-submit side effect `:39`/`:55` must NOT be triggered by the auto path)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — W4 broadcast analog (15-20), W5 stale-check analog (`:27`)
- `app/jobs/docx_to_pdf_job.rb` — W2: `perform` (6-15), enqueue `SubmitResumeToTextractJob` after `handle_possible_docx_resume` (`:8`), rescue (12-15)
- `app/services/submit_resume_to_textract.rb` — W2 follow-on-enqueue analog (`:27`); stale-guard + relink (18-26)
- `app/jobs/get_resume_text_from_textract_job.rb` — W1/C8: `cleanup_orphaned_summary` (10-23, `summary.destroy` `:19`) — must transition to `failed` instead of destroying
- `app/jobs/generate_ai_job_application_summary_job.rb` — W5 failure writers `update_columns(status: :failed)` (`:19` exhaustion, `:44` StandardError); `broadcast_completion` (50-77)
- `app/services/ai_job_application_action/orchestrate.rb` — W3 asymmetry note (`extract_job_criteria` via `:80` runs in Sidekiq, not in txn); `check_criteria_and_score` (68-83, awaiting write `:72`)
- `app/services/ai_job_application_action/summary/generate.rb` — W4 retrying writer `update_columns(status: :retrying)` (`:175`, convert to `.update`); W5 failed writers `:180`, `:184`
- `app/services/ai_job_application_action/scoring/score_job_application.rb` — W5 failed writers (**`:134`, `:138`**, spec says `:135,:139`); retrying `:129`; awaiting writes `:22/:28/:44`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` — W5 failed writers (`:64`, `:68`); retrying `:59`

**Frontend**
- `app/javascript/shared/types/jobApplication.ts` — W5: `AiJobApplicationSummaryStatus.status` union (`:4`, add `"failed"`)
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` — W5 failed display (note: a `fullSummaryStatus === "failed"` branch ALREADY exists at 175-186; status-row `statusValue` branches at 42/50/52/151/154/187/210/218)
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoLoadingState.tsx` — W4: `STATUS_TO_STEP` (22-28) + `PlatoGenerationStatus` union (8-13) need `awaiting_job_criteria` + `retrying`
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx` — W5: Harvey ball gated current/regenerating (26-29)
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` — W5: platoReview gated current/regenerating (79-94) — spec says unchanged
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` — W4 consumer: `ai_summary_status_change` → detail-view invalidation (73-76)
- `app/javascript/ats/styles/theme.ts` — color check before any new FE color (core rule 2)

**Tests (referenced)**
- Update: `spec/models/ai_job_application_summary_spec.rb` (W4 invert 57-62; W5), `spec/models/ai_job_application_summary_status_spec.rb` (W5 enum), `spec/models/ai_job_criteria_spec.rb` (W6), `spec/models/textract_result_ai_trigger_spec.rb` (W1), `spec/jobs/generate_ai_job_application_summary_job_spec.rb` (W5), `spec/services/.../score_job_application_spec.rb` + `integrate_analysis_spec.rb` (W5), `spec/services/submit_resume_to_textract_spec.rb` (W2), `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb`
- **NEW:** `spec/interactors/create_auto_ai_summary_generation_spec.rb` (W1), `spec/jobs/docx_to_pdf_job_spec.rb` (W2 — spec correctly hedges "if absent")
- **Spec names non-existent files** (see source-accuracy angle): `spec/models/job_application_spec.rb` and `spec/models/job_spec.rb` do NOT exist. Real homes: `spec/models/job_application_ai_summary_status_spec.rb` (enqueue_new_job_application — W1/W2) and `spec/models/job_criteria_lifecycle_spec.rb` (publish/auto_extract — W3). `spec/interactors/create_ai_summary_generation_spec.rb` also does not exist.

---

## Full-stack analog

There is **no single end-to-end analog** for the whole feature, because the feature is six surgical edits to an existing pipeline rather than one new vertical slice. Instead the spec correctly anchors EACH workstream to a specific in-pipeline analog. Reviewers compare each workstream against its analog at the STRUCTURAL level (parameter shape, callback site, write mechanism, error/rescue shape), per Known Failure Patterns #14/#16.

- **W1 (auto pre-create summary)** → `CreateAiSummaryGeneration` (`create_ai_summary_generation.rb`, single-send) + `CreateBulkAiSummaryGeneration` (`create_bulk_ai_summary_generation.rb`, bulk). These are the two existing siblings that pre-create the `AiJobApplicationSummary` row "or Orchestrate finds no row and bails" (comment in the bulk interactor, 3-12). The new `CreateAutoAiSummaryGeneration` is the third sibling. Compare: `.build(status: :textract_processing, requested_by_organization_user_id: ...)` shape, the reuse-guard (`where.not(status: :failed).where(stale: false).order(created_at: :desc).first`), save-via-return-value, NO job enqueue. Deviation the spec REQUIRES (do not flag): the auto path must NOT route through `ValidateAiSummaryGeneration` (its `:39`/`:55` submit Textract, double-submitting) — it reuses only the *guard predicates* (26-29).
- **W2 (docx→Textract chain)** → `submit_resume_to_textract.rb:27` (a follow-on `GetResumeTextFromTextractJob` enqueued from inside a success path). The new `DocxToPdfJob` enqueue of `SubmitResumeToTextractJob` mirrors this "chain the next step after the current one" shape.
- **W3 (criteria enqueue after commit)** → `handle_after_update_commit` (`job.rb:491-511`), which already post-commit-enqueues `WebflowSyncOneJob`/`SyncWhatJobsListingJob` by inspecting `previous_changes`. The criteria enqueue must move onto this exact post-commit pattern.
- **W4 (broadcast new statuses)** → `regenerating` already broadcasts `ai_summary_status_change` via `find_or_create_ai_job_application_summary_status.rb:16-20`, consumed by `WebsocketJobChannelHandler.tsx:73-76`. The two new BROADCAST_STATUSES ride the existing `broadcast_status_change` path.
- **W5 (status-row failed writer + stale guard)** → success writer `update_summary_status_record` (`ai_job_application_summary.rb:74-80`) is the structural analog for the new `record_failure` writer (same status-row `.update`, same denormalized-column set). Stale-guard analogs: `textract_result.rb:68`, `find_or_create_ai_job_application_summary_status.rb:27`.
- **W6 (carry requesting user)** → `create_ai_summary_generation.rb` / the bridge if-branch (`textract_result.rb:128-131`) both pass `requesting_organization_user_id`; W6 makes `resume_waiting_summaries` (`ai_job_criteria.rb:24-27`) do the same.

**Priority rule:** Where an analog deviates from a general convention, the analog wins (it shares the domain constraints). Three deviations are spec-mandated and must NOT be flagged: (1) W1 reuses Validate's guards but bypasses its Textract submit; (2) W5 keeps `update_columns` for the *summary*-side failed write (rescue-path re-entrancy) while using `.update` for the *status-row* write (so counter_culture fires); (3) `orchestrate.rb` has a documented `reload`-in-`app/` deviation (`:59-66`) — pre-existing, out of scope.

---

## Angles

### 1. summary-lifecycle / state-machine
**What this covers:** The `AiJobApplicationSummary` status machine and the parallel `AiJobApplicationSummaryStatus` row machine, traced together across model callbacks, the bridge, the orchestrator, the pipeline services, and the FE that renders each state — ensuring W1 (new `textract_processing` entry), W5 (new `failed` row state + choke-point + stale guard), and the C7/C8 cascade/cleanup side effects compose into a consistent lifecycle with no orphaned or double-applied transitions. The dominant risk: a state written via `update_columns` that silently bypasses the callback a fix relies on (this is why W4/W5 convert specific writers).
**Files across all layers:**
- `app/models/ai_job_application_summary.rb` (enum 10-21, callbacks 29-31, `update_summary_status_record` 57-98, `destroy_previous_textract_results` 47-55, new `record_failure`)
- `app/models/ai_job_application_summary_status.rb` (enum 9-14 + new `failed`, counter_culture `:7`)
- `app/models/textract_result.rb` (bridge 114-144, credit flow 61-89, `set_initial_summary_pending` 98-108)
- `app/jobs/get_resume_text_from_textract_job.rb` (`cleanup_orphaned_summary` 10-23 — C8 destroy→failed)
- `app/jobs/generate_ai_job_application_summary_job.rb` (failed writers 19/44)
- `app/services/ai_job_application_action/{orchestrate.rb, summary/generate.rb, scoring/score_job_application.rb, scoring/integrate_analysis.rb}` (every status writer, esp. the `update_columns` vs `.update` split)
- `app/interactors/{create_auto_ai_summary_generation.rb (NEW), create_ai_summary_generation.rb, find_or_create_ai_job_application_summary_status.rb}`
- FE: `PlatoTab.tsx` (42/50/52/151/154/175-186/187), `JobApplicationNavItem.tsx` (26-29), `JobApplicationActivity.tsx` (79-94), `jobApplication.ts:4`
**Analog files for comparison:** `create_ai_summary_generation.rb`, `create_bulk_ai_summary_generation.rb` (W1 build shape); `update_summary_status_record` 74-80 (W5 writer shape)
**Convention context:** `cursor_rules/backend/_base.md`, `cursor_rules/core_critical_rules.md` (rules 11/12 bang+return-value, rule 8 bare return); pipeline `CLAUDE.md` #16 (companion records created via unconditional owner), #18 (clear ALL denormalized columns when disassociating), #13 (no fabricated fallbacks)

### 2. textract-trigger ordering & concurrency
**What this covers:** Whether Textract is submitted exactly once and always on a Textract-acceptable format, across the create path, the docx-conversion job, and the T2 controller-update path — and whether W1's synchronous pre-create preserves the stale/relink ordering invariant in `SubmitResumeToTextract`. Includes the W2 conversion-FAILURE degenerate case (must still attempt Textract, no regression) and the defense-in-depth `TEXTRACT_RESUME_PROCESSING` gate at every submit site.
**Files across all layers:**
- `app/models/job_application.rb` (`enqueue_new_job_application` 164-171; docx/PDF branch; `resume_is_docx` 697-701, `has_resume_docx_to_pdf` 722-723, `handle_possible_docx_resume` 733-751)
- `app/jobs/docx_to_pdf_job.rb` (perform 6-15; new enqueue after `:8`, must survive the rescue at 12-15)
- `app/controllers/api/v1/job_applications_controller.rb` (T2 path 110-114 — docx/PDF branch; one-params-method rule)
- `app/services/submit_resume_to_textract.rb` (fallback `:15`, stale-guard `:18-19`, build `:22`, relink `:25-26`, follow-on enqueue `:27`)
- `app/interactors/validate_ai_summary_generation.rb` (out-of-scope recovery submits `:39`/`:55` — confirm spec scoping that they stay docx-race-exposed)
**Analog files for comparison:** `submit_resume_to_textract.rb:27` (chain-after-success)
**Convention context:** `cursor_rules/backend/_base.md`; pipeline `CLAUDE.md` #2 (trace every pipeline end-to-end); core rule 5 (one params method per controller), core rule 1 (no begin blocks / method-level rescue). Hard rule from `~/.claude/CLAUDE.md` + spec: every Textract submit stays Flipper-gated (defense in depth — Known Failure Pattern "Hard rules cannot be rationalized away").

### 3. criteria-enqueue transaction safety (W3 root-cause)
**What this covers:** That `ExtractJobCriteriaJob` is enqueued only AFTER the Job update transaction commits, so a Sidekiq worker can never find an uncommitted `AiJobCriteria` (the proven incident root cause on Rails 6.1.7.7, which lacks `enqueue_after_transaction_commit`). The reviewer must verify the publish/description-change trigger CONDITIONS are preserved exactly when the enqueue moves from the `before_update` chain to `handle_after_update_commit`, that the `.save`-then-enqueue ordering keeps the record committed before enqueue, and that the `should_auto_generate`/Flipper guard, the `wait: 30.seconds` debounce, and the pending poison-guard are all unchanged. Confirm the asymmetry note: `orchestrate.rb:80` / `score_job_application.rb:23/45` callers run inside Sidekiq (outside the txn) and must NOT be altered.
**Files across all layers:**
- `app/models/job.rb` (`before_update` `:60`, `handle_after_update_commit` 491-511, `handle_status_changed_to_published` 544-561, `handle_description_change` 726-732, `auto_extract_job_criteria` 696-711, `extract_job_criteria` 713-723, `previous_changes` pattern 501/507/537-538)
- `app/jobs/extract_job_criteria_job.rb` (`find_by` + `return unless` at 13-14 — the silent-exit the fix prevents)
- `app/services/ai_job_application_action/orchestrate.rb` (`:80` — out-of-txn caller, do-not-touch)
- `app/services/ai_job_application_action/scoring/score_job_application.rb` (`:23/:45` — out-of-txn callers)
**Analog files for comparison:** `handle_after_update_commit` 491-511 (existing post-commit `previous_changes`-driven enqueue of Webflow/WhatJobs jobs)
**Convention context:** pipeline `CLAUDE.md` #14 (callback patterns — follow analogous `after_commit`), #10 (minimum change; do not add a sweeper — explicitly deferred); core rule 8 (bare return). Known Failure Pattern "Verify the execution lifecycle matches before copying an analog pattern."

### 4. websocket-broadcast contract (incl. FE)  (W4)
**What this covers:** That adding `awaiting_job_criteria` + `retrying` to `BROADCAST_STATUSES` actually produces a live FE signal end-to-end, AND that the FE can render the new states rather than freezing. Trace: model `broadcast_status_change` → `JobChannel` event → `WebsocketJobChannelHandler` invalidation → `useAiJobApplicationSummary` refetch → `PlatoTab` loading branch → `PlatoLoadingState` stepper. The reviewer must confirm BOTH hard requirements: (1) `generate.rb:175` retrying is written via `update_columns` (bypasses ALL callbacks) and must convert to `.update` (or broadcast explicitly) or the generate-path retrying stays silent; (2) `PlatoLoadingState.STATUS_TO_STEP` (+ `PlatoGenerationStatus` union) must gain entries for both statuses or the stepper freezes even after the query goes live. Confirm only detail-view queries invalidate (no list refetch storm).
**Files across all layers:**
- `app/models/ai_job_application_summary.rb` (`BROADCAST_STATUSES` `:23`, `broadcast_status_change` 100-111)
- `app/services/ai_job_application_action/summary/generate.rb` (`:175` retrying writer)
- `app/services/ai_job_application_action/scoring/{score_job_application.rb (:129), integrate_analysis.rb (:59)}` (other retrying writers — already `.update`)
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` (73-76 consumer)
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` (loading branch 157-174, routes `awaiting_job_criteria` 163 / `retrying` 166)
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoLoadingState.tsx` (STATUS_TO_STEP 22-28, union 8-13)
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` (no refetchInterval — relies on invalidation)
**Analog files for comparison:** `find_or_create_ai_job_application_summary_status.rb:16-20` (regenerating broadcast); the existing `ai_summary_status_change` consumer wiring
**Convention context:** `cursor_rules/frontend/_base.md`; core rule 7 + 7-exception (enum values stay snake_case on FE); pipeline `CLAUDE.md` #6 (rename/grep cascade incl. spec files — invert `ai_job_application_summary_spec.rb:57-62`), #1 (Emotion theme utilities), #11 (copy behavioral props), #12 (separate styled variants)

### 5. status-row display-state & denormalization (incl. FE)  (W5 + C1)
**What this covers:** That a terminal-failed summary drives the `AiJobApplicationSummaryStatus` row to a `failed` display state through a single choke-point that fires from EVERY terminal-failure site (the dominant writers use `update_columns` and bypass the after_commit callback — a fix hooked only on the callback would silently miss them, the exact trap in Known Failure Pattern context), clearing ALL denormalized columns (`score_percentage`/`headline`/`integrated_role_analysis`) per pipeline #18, decrementing the counter_culture count correctly (the new `failed` value sits outside `status IN (2,3)`), and that the C1 `stale?` guard prevents a stale summary from copying its data onto the row on success. FE: confirm the `jobApplication.ts:4` union gains `"failed"` and the PlatoTab/NavItem/Activity consumers handle (or intentionally ignore) it — noting PlatoTab ALREADY has a `fullSummaryStatus === "failed"` branch (175-186), so the W5 FE work is narrower than "add a branch" implies.
**Files across all layers:**
- `app/models/ai_job_application_summary.rb` (new `record_failure` choke-point; `update_summary_status_record` 57-98 + C1 `return if stale?`; writer analog 74-80)
- `app/models/ai_job_application_summary_status.rb` (enum 9-14 + `failed: 4`; counter_culture `:7`)
- terminal-failure SITES the fix must route through: `generate_ai_job_application_summary_job.rb` (19, 44); `summary/generate.rb` (180, 184); `scoring/score_job_application.rb` (**134, 138** — spec says 135/139); `scoring/integrate_analysis.rb` (64, 68)
- `db/schema.rb` (status-row `status` is `t.integer` — confirms no migration; NEVER stage/commit schema)
- FE: `jobApplication.ts:4`, `PlatoTab.tsx` (42/50/52/151/154/175-186/187/210/218), `JobApplicationNavItem.tsx` (26-29), `JobApplicationActivity.tsx` (79-94), `app/javascript/ats/styles/theme.ts`
**Analog files for comparison:** `update_summary_status_record` 74-80 (success writer); stale-guards `textract_result.rb:68`, `find_or_create_ai_job_application_summary_status.rb:27`
**Convention context:** pipeline `CLAUDE.md` #18 (clear ALL denormalized cols), #16 (companion-record write site), #13 (no fabricated fallbacks); core rules 11/12 (no bang / check return values); core rule 2 (theme colors). Note the spec-mandated mechanism split (summary write stays `update_columns`; row write uses `.update`) — do not flag it.

### 6. credit-charging behavior (W1 D2)
**What this covers:** That auto-gen success now charges exactly one credit (the spec's D2 behavioral change), via the bridge if-branch → `generate_ai_summary_with_credit_flow` → `CreateAiCreditBalanceTransaction`, with no double-charge and no charge on failure; and that the W6 pass-through of `requesting_organization_user_id` does not alter charging (only the completion toast). This is the financially load-bearing slice and historically the highest-risk area in this codebase (the AI-credits failures behind several Known Failure Patterns).
**Files across all layers:**
- `app/models/textract_result.rb` (`generate_ai_summary_with_credit_flow` 61-89; credit consume `:84`; early-return `:68`)
- `app/models/ai_job_criteria.rb` (W6 re-enqueue 24-27 — passes user, not credit)
- `app/jobs/generate_ai_job_application_summary_job.rb` (`broadcast_completion` 50-77 — toast keyed on requesting user)
- `app/interactors/create_auto_ai_summary_generation.rb` (NEW — confirm it does NOT itself enqueue/charge; bridge drives it)
**Analog files for comparison:** the if-branch credit path vs the auto/else-branch (textract_result.rb 125-143)
**Convention context:** pipeline `CLAUDE.md` #10 (fix agents must not add code beyond defect scope — esp. payment area), and the AI-credits-motivated patterns in hub `CLAUDE.md` ("Fix agent code is unreviewed scope", "Spec-implementation mismatch is never MED"). Reviewer: any new payment-area method or validation change is BLOCKER unless spec'd.

### 7. analog-structural-matching
**What this covers:** A dedicated structural diff of each new/changed unit against its named analog — parameter interfaces, build shape, reuse-guard, write mechanism, error/rescue/raise sequence, callback site — per Known Failure Patterns #14/#16 and the prompt's always-on structural-matching check. Layer completeness ("there is an interactor") is insufficient; the interactor must accept/build the same shapes as `CreateAiSummaryGeneration`. Specifically: (a) `CreateAutoAiSummaryGeneration` vs the two sibling create-interactors — same `.build(status:, requested_by_organization_user_id:)`, same reuse-guard, save-via-return-value, NO enqueue, NO `ValidateAiSummaryGeneration` call; (b) the W3 enqueue vs `handle_after_update_commit`'s `previous_changes` pattern; (c) the W5 `record_failure` vs `update_summary_status_record`'s `.update`-on-the-row; (d) the W2 chain vs `submit_resume_to_textract.rb:27`; (e) the W6 re-enqueue vs the other `GenerateAiJobApplicationSummaryJob.perform_later` call shapes.
**Files across all layers:** all NEW/changed units above paired with their analogs (W1: `create_ai_summary_generation.rb` + `create_bulk_ai_summary_generation.rb`; W2: `submit_resume_to_textract.rb`; W3: `job.rb:491-511`; W5: `ai_job_application_summary.rb:74-80`; W6: `textract_result.rb:128-131` / `create_ai_summary_generation.rb:71-74`)
**Analog files for comparison:** (as named per workstream above)
**Convention context:** pipeline `CLAUDE.md` #14, #16; hub `CLAUDE.md` "Match the analog's STRUCTURE, not just its PROCESS" (build a structural manifest and diff row by row — SAME/DIFFERENT/EXTRA/MISSING). A structural mismatch or an EXTRA file/method the analog never had is BLOCKER.

### 8. test-coverage
**What this covers:** That every workstream has tests exercising its actual failure mode (not ghost coverage), that mailer/broadcast/job stubs do not mask missing calls, and that the spec's test plan points at files that EXIST. Key checks: W1 incident regression (auto-gen ON + Textract FAILED → exactly one `failed` summary, was zero; and C7 — the pre-created summary is the one that advances, not destroyed); W2 docx/PDF enqueue branch incl. conversion-raise; W3 publish enqueues after commit + has_many multi-row semantics (the 5 pre-loaded specs cover ≤1 criteria row — untested: latest/latest_succeeded selection, failed-then-retrigger, poison guard); W4 inversion of `ai_job_application_summary_spec.rb:57-62` + generate-path retrying broadcast; W5 each failure SITE → row `failed` + cleared cols + counter decrement, C1 stale-no-overwrite; W6 re-enqueue carries user (one nil, one non-nil). Verify stub arguments match production types (Known Failure Pattern #7) and that companion-record eager creation doesn't break `create!` setups (pipeline #19).
**Files across all layers:**
- NEW: `spec/interactors/create_auto_ai_summary_generation_spec.rb`, `spec/jobs/docx_to_pdf_job_spec.rb`
- Update: `spec/models/ai_job_application_summary_spec.rb`, `spec/models/ai_job_application_summary_status_spec.rb`, `spec/models/ai_job_criteria_spec.rb`, `spec/models/textract_result_ai_trigger_spec.rb`, `spec/jobs/generate_ai_job_application_summary_job_spec.rb`, `spec/services/ai_job_application_action/scoring/{score_job_application_spec.rb, integrate_analysis_spec.rb}`, `spec/services/submit_resume_to_textract_spec.rb`, `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb`
- **Correct the spec's targets:** `spec/models/job_application_ai_summary_status_spec.rb` (enqueue_new_job_application — W1/W2, the spec's "job_application_spec.rb" does not exist) and `spec/models/job_criteria_lifecycle_spec.rb` (publish/auto_extract — W3, the spec's "job_spec.rb" does not exist)
**Analog files for comparison:** existing `textract_result_ai_trigger_spec.rb`, `job_criteria_lifecycle_spec.rb` patterns; the `create_credit_test_*` helpers
**Convention context:** pipeline `CLAUDE.md` #3 (specs/plans must include test requirements), #4 (mailer `.deliver_*` — N/A here but stub-discipline applies to broadcasts/jobs), #6 (grep spec files on rename), #7 (stubs must not mask type mismatches), #19 (eager companion-record creation); hub `CLAUDE.md` "Ghost tests are blockers". Stub all external calls (AWS `send_to_textract`, `ConvertApi`, OpenAI/Gemini) as existing specs do.

### 9. source-accuracy  (READ FIRST)
**What this covers:** Verifying every file:line, identifier, column, route, and component the spec references against live code (HEAD `7831b7d16`). The following discrepancies were found during scoping and must be confirmed/resolved by the spec review — they are inputs, not yet findings:
- **MED/HIGH — spec names non-existent spec files.** `spec/models/job_application_spec.rb` and `spec/models/job_spec.rb` do NOT exist (the spec's W1/W2/W3 test plans say "Update" them as if present). `spec/interactors/create_ai_summary_generation_spec.rb` also does not exist. Real homes: `job_application_ai_summary_status_spec.rb` (enqueue) and `job_criteria_lifecycle_spec.rb` (publish). An impl agent following "Update `spec/models/job_spec.rb`" will create a stray file or skip the coverage.
- **LOW — off-by-one citations.** `score_job_application.rb` failed writers are at **134 and 138**, spec W5 cites **135, 139**. `job.rb` `after_commit :handle_after_update_commit` is at **line 58**, spec W3 cites **:59** (the `before_update :handle_before_update` IS at :60, correct). `auto_extract_job_criteria` enqueue is `:707`/`:709` (spec says `:704-709`/`:706-710` loosely — the `.save` is `:704`, enqueues `:707/:709`).
- **MED — PlatoTab failed branch already exists.** W5 says "add a branch for `failed`"; `PlatoTab.tsx:175-186` already renders `PlatoTabEmptyState status="failed"` for `fullSummaryStatus === "failed"`. The genuinely new FE work is the `jobApplication.ts:4` union + deciding whether the STATUS-ROW `failed` needs distinct handling. The spec's "add a branch … otherwise a minimal 'Plato couldn't generate a review'" risks a duplicate affordance.
- **Confirmed-accurate, load-bearing:** summary enum already has `failed: 9` (`ai_job_application_summary.rb:20`) — distinct from the STATUS-row enum (`ai_job_application_summary_status.rb:9-14`) which lacks it; the spec correctly distinguishes these. Status-row `status` column is `t.integer` (no migration needed — confirmed). `BROADCAST_STATUSES` content, `cleanup_orphaned_summary` destroy at `:19`, `broadcast_ai_summary_failed` nil-return at `:147`, `should_auto_generate_ai_summaries?` at 934-942, `resume_waiting_summaries` 24-27 dropping the user, `validate_ai_summary_generation.rb` guards 26-29 + submit `:39`, `find_or_create…rb:15-20`/`:27`, `STATUS_TO_STEP` 22-28, `ai_summary_status_change` handler 73-76, `jobApplication.ts:4` union — ALL verified correct.
- `cursor_rules/{core_critical_rules.md, backend/_base.md, frontend/_base.md}` all exist; there is no `cypress/_base.md` (not needed).

---

## Always-on checks

These apply to every feature regardless of angles:

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against current source. (Pre-seeded discrepancies are in Angle 9 — confirm each independently; do not assume they are the only ones.)

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require — including the W3 has_many multi-row semantics the 5 pre-loaded criteria specs do NOT cover, and the W1 incident regression (auto-gen ON + Textract FAILED → exactly one `failed` summary). Ghost tests (stubs that mask the failure mode) are BLOCKER.

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed: every `BROADCAST_STATUSES` consumer (W4) and every `AiJobApplicationSummaryStatus.status` consumer (W5 enum addition) across `app/` + `spec/` + `app/javascript/` (pipeline #6 grep discipline, incl. spec files). Confirm the new enum value does not shift counter_culture counts or break exhaustive FE switches.

### Full-stack analog completeness
No single full-stack analog exists; instead each workstream has a named in-pipeline analog (see "Full-stack analog" section). For each workstream the review verifies the change touches the same layers the analog touches and adds NO layer/file the analog lacks. A missing layer (e.g., W4 broadcast added but FE stepper not extended) or an EXTRA file (e.g., a new payment-area method in W1/W6) is a finding — BLOCKER if it is an unspec'd EXTRA.

### Analog structural matching
The review agent greps for each analog file, reads its parameter interfaces, build shape, reuse-guard, write mechanism (`update_columns` vs `.update`), callback site, and rescue/status/raise sequence, and diffs them against the new code (Angle 7). Layer completeness without structural matching is insufficient. Specifically:
- **Interactor build shape (W1):** `CreateAutoAiSummaryGeneration` must `.build(status: :textract_processing, requested_by_organization_user_id: nil)` and use the reuse-guard exactly as `CreateAiSummaryGeneration` (30-53) — not invent a new build or call `ValidateAiSummaryGeneration` (double-submit).
- **Post-commit enqueue (W3):** must use the `previous_changes`-driven `after_commit` pattern of `handle_after_update_commit`, not a new mechanism, and must NOT touch the out-of-txn `orchestrate.rb:80` / `score_job_application.rb` callers.
- **Status-row writer (W5):** `record_failure` must mirror `update_summary_status_record`'s `.update`-on-the-row shape and clear ALL denormalized columns; the summary-side write staying `update_columns` is spec-mandated (do not flag), but the row-side write MUST be `.update` (so counter_culture fires).
- **Error handling shape:** any new rescue must follow the codebase's method-level rescue / `=> e` / specific-class / set-status-before-raise sequence (core rule 1; no begin blocks).
- A structural mismatch is BLOCKER.

### Hard-rule & scope discipline
- **Never stage/commit `db/schema.rb`** (no migration is needed — W5 is a Rails enum value on an existing integer column; confirmed).
- **Defense in depth:** every Textract submit site stays `TEXTRACT_RESUME_PROCESSING`-gated, including the new `DocxToPdfJob` enqueue — a config/plan that omits the re-check on the moved enqueue is a finding even if another site also gates (hub `CLAUDE.md` "Hard rules cannot be rationalized away by plans").
- **Fix scope (pipeline #10, hub "Fix agent code is unreviewed scope"):** each workstream is the minimum change for its gap. No unspec'd methods, jobs, migrations, validation relaxations, or sweeper/reaper (issue 6 sweeper is explicitly DEFERRED). Any new payment-area code (W1/W6 credit path) is BLOCKER unless spec'd. A deletion of code the spec reviewed as "no change" (e.g., keeping the manual-case `AI_SUMMARY_FAILED` broadcast in C8) is a finding. Spec-implementation mismatch is HIGH/BLOCKER, never MED.
- **Ruby conventions:** no bang methods in `app/`, bare `return` (no truthy/falsy), method-level rescue, `=> e`, no `reload` in `app/` (except the documented `orchestrate.rb` deviation), match variable names to model names, single quotes, no fabricated fallbacks (`|| 0`/`|| ''`/`|| []`). FE: camelCase except Ruby enum values stay snake_case; check `theme.ts` before any color; separate styled components for visual variants.
