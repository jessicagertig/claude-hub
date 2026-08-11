# Implementation Plan — AI Summary Creation Gaps + docx→Textract Trigger

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` — branch `ai-summary-creation-gaps` already checked out (HEAD `7831b7d16`). **Do NOT create branches/commits as part of planning.** Implementation agents commit ON this branch (see "Working-tree state" below).
**Basis:** `SPEC.md` (amended + approved over 8 spec-review rounds, `reviews/SPEC-REVIEW-COMPLETE.md`), `FINDINGS.md`, `reviews/REVIEW-ANGLES.md`. Every file:line below was re-verified against live code on 2026-06-23 during planning; the spec-review's off-by-one corrections are folded in (e.g. `score_job_application.rb` failed writers are at **134/138**, not 135/139; `job.rb` `after_commit :handle_after_update_commit` is at **:58**, not :59).

---

## Summary

The AI-summary/criteria pipeline has six creation/visibility gaps, fixed as six surgical edits to an existing pipeline (no new tables; one Rails enum gains a value on an existing integer column → **no migration**). **W1:** auto-generate never actually creates an `AiJobApplicationSummary`, so auto-gen applications get no summary until a human manually generates — a new `CreateAutoAiSummaryGeneration` interactor pre-creates a `textract_processing` summary at intake so the bridge has something to advance, charging one credit on success (D2) and persisting as `failed` on Textract terminal failure (D1). **W2:** `.docx` resumes are sent to Textract (PDF-only) before the PDF conversion attaches → the docx path produces no usable `TextractResult`; Textract submission is chained to `DocxToPdfJob` for docx, while PDFs submit directly at intake. **W3:** criteria extraction is enqueued *inside* the Job `before_update` transaction, so a Sidekiq worker can run `ExtractJobCriteriaJob` before the `AiJobCriteria` row commits → it exits silently → criteria stuck `pending` forever (the reported incident); the enqueue moves to an `after_commit` path. **W6:** the criteria-resume re-enqueue drops the requesting user → a manually-requested summary loses its completion toast; the user is passed through. **W4:** `awaiting_job_criteria`/`retrying` emit no UI signal → the detail card freezes; they are added to `BROADCAST_STATUSES` and the FE stepper. **W5:** the status row has no `failed` state → a failed summary shows "generating" or stale data; a `failed` enum value + a single `record_failure` choke-point routes every terminal failure to the row, clearing denormalized columns, plus a `stale?` guard (C1).

Implement strictly in this order: **W1 → W2 → W3 → W6 → W4 → W5** (backend asks + incident first, then visibility).

---

## Working-tree state, conflicts, and hard constraints (read before any edit)

- [ ] **Working tree is NOT clean.** `git diff HEAD --stat` shows `db/schema.rb` (119 lines) **plus 16 spec files already modified** (~1228 insertions) from prior AI-scoring work. These are uncommitted on the branch. Several spec files this plan UPDATES (`ai_job_application_summary_spec.rb`, `ai_job_criteria_spec.rb`, `get_resume_text_from_textract_job_spec.rb`, `textract_result_ai_trigger_spec.rb`, `score_job_application_spec.rb`, `generate_ai_job_application_summary_job_spec.rb`, `ai_job_application_summary_status_spec.rb`, `submit_resume_to_textract_spec.rb`) already have uncommitted content — your test additions go **on top of** that content; do NOT discard it.
- [ ] **NEVER stage/commit `db/schema.rb`.** No new migration is required (W5 adds a Rails enum value on an existing integer column). The `db/schema.rb` working-tree diff is from prior already-applied migrations; leave it unstaged.
- [ ] **Open PRs / conflicting branches:** none listed (no PR table populated for this session). Sibling branches exist (`UI-polishes`, `ai-feature-work-v5`) but no overlap info is available; proceed on `ai-summary-creation-gaps` and re-check `git status` before committing.
- [ ] **Per Known Failure Pattern #15** (impl reviews review COMMITTED code): implementation agents must `git commit` their work on this branch before the Phase-6 review. Commit via `nvm use && git commit ...` OUTSIDE the sandbox; never `--no-verify`; never rewrite tests to pass.
- [ ] **Ruby hard rules** (apply to every `app/` edit): no bang methods in `app/` (OK in `spec/`); bare `return` (no truthy/falsy returns); method-level rescue only (no `begin` blocks); `=> e`; rescue specific classes; no `reload` in `app/`; single quotes unless interpolating; variable names match model names (`ai_job_application_summary`, `textract_result`, `ai_job_criteria`, `job_application`); **never fabricate fallbacks** (`|| 0`/`|| ''`/`|| []`). FE: camelCase except Ruby enum values stay snake_case; check `theme.ts` before any color; separate styled components for visual variants.
- [ ] **Defense in depth:** every Textract submit site stays `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, ...)`-gated — including the new `DocxToPdfJob` enqueue (W2).
- [ ] **Fix-scope discipline (Known Failure Patterns #10; hub "Fix agent code is unreviewed scope"):** each workstream is the MINIMUM change for its gap. No unspecced methods/jobs/migrations/validation relaxations/sweepers. Any new payment-area code (credit path) is BLOCKER unless spec'd. Do NOT delete code the spec reviewed as "no change" (e.g. the manual-case `AI_SUMMARY_FAILED` broadcast in C8). The DEFERRED list at the bottom is OUT — do not build it.

---

## Pattern precedents (verified against live code)

The feature is six surgical edits, so each workstream anchors to its own in-pipeline analog (no single full-stack analog). Compare at the STRUCTURAL level — parameter shape, build shape, reuse-guard, write mechanism (`update_columns` vs `.update`), callback site, rescue/raise sequence — per Known Failure Patterns #14/#16 and hub "Match the analog's STRUCTURE."

### Precedent 1 — W1 new interactor (`CreateAutoAiSummaryGeneration`)
- **`app/interactors/create_ai_summary_generation.rb`** (single-send, primary analog): reuse-guard `:30-44` (`where.not(status: :failed).where(stale: false).order(created_at: :desc).first`, then stale-relink check `:36-39`), textract-pending build `:46-58` (`.build(status: :textract_processing, requested_by_organization_user_id: context.user&.current_organization_user&.id)` `:47-51`, save-via-return-value `:53-56`), pending build `:60-77`.
- **`app/interactors/create_bulk_ai_summary_generation.rb`** (bulk sibling): same reuse-guard `:34-48`, build `:50-54`, `context.fail! unless ai_summary.save` `:57`, **no job enqueue** (the comment `:3-12` documents "or Orchestrate finds no row and bails" — the same reason the auto path must pre-create).
- **`app/interactors/validate_ai_summary_generation.rb`**: the four precondition predicates — `flipper_enabled?` `:65-67`, `has_resume?` `:69-71`, `credits_available?` `:77-79`, `has_job_description?` `:81-83` — and their `context.fail!` guards `:26-29`. The Textract-submit side effects are `:39` (no-textract branch) and `:55` (failed-retry branch) — these MUST NOT be triggered by the auto path.

### Precedent 2 — W2 follow-on enqueue from a success path
- **`app/services/submit_resume_to_textract.rb:27`** — `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(...)` chained from inside the `if @textract_result.save` success branch (`:24-30`). W2's `DocxToPdfJob` → `SubmitResumeToTextractJob` enqueue mirrors this "chain the next step after the current one completes" shape.

### Precedent 3 — W3 post-commit enqueue via `previous_changes`
- **`app/models/job.rb:491-511`** (`handle_after_update_commit`, `after_commit on: [:update]` at `:58`): already post-commit-enqueues `WebflowSyncOneJob` `:504` and `SyncWhatJobsListingJob` `:510` by inspecting `previous_changes.keys.map(&:to_sym)` (`:497/:501/:507`). This confirms `previous_changes` is **string-keyed** (the analog converts to symbols explicitly). W3's criteria enqueue must ride this exact post-commit pattern.

### Precedent 4 — W5 status-row writer + stale guards
- **`app/models/ai_job_application_summary.rb:74-80`** (`update_summary_status_record` success writer): `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — the structural analog for the new `record_failure` row write (same `.update`-on-the-row, same denormalized column set, same `return unless ai_job_application_summary_status` guard `:72`).
- **Stale-guard analogs:** `textract_result.rb:68` (`return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`) and `find_or_create_ai_job_application_summary_status.rb:27` (a `!stale?` check) — model for C1's `return if stale?`.

### Precedent 5 — W4 broadcast of a status into `BROADCAST_STATUSES` (+ FE consumer)
- **`app/models/ai_job_application_summary.rb:100-111`** (`broadcast_status_change`, `before_update`): broadcasts `ai_summary_status_change` for any status in `BROADCAST_STATUSES`. `regenerating`/`current` already drive the row via `find_or_create_ai_job_application_summary_status.rb:16-20`.
- **FE consumer:** `WebsocketJobChannelHandler.tsx:73-76` (`ai_summary_status_change` → invalidate `["aiJobApplicationSummary", id]` + `["jobApplication", id]`, detail-view only) → `useAiJobApplicationSummary.ts:42-46` (no `refetchInterval`; relies on invalidation) → `PlatoTab.tsx:157-174` loading branch → `PlatoLoadingState.tsx` stepper.

### Precedent 6 — W6 pass requesting user into the generation job
- **`textract_result.rb:128-131`** (bridge if-branch) and **`create_ai_summary_generation.rb:71-74`** both call `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:, requesting_organization_user_id:)`. W6 makes `ai_job_criteria.rb:24-27` pass `requesting_organization_user_id` the same way.

---

## Files to create or modify

**NEW (1 app file, 2 spec files):**
- `app/interactors/create_auto_ai_summary_generation.rb` — `CreateAutoAiSummaryGeneration` (W1).
- `spec/interactors/create_auto_ai_summary_generation_spec.rb` — W1 interactor unit tests.
- `spec/jobs/docx_to_pdf_job_spec.rb` — W2 (file does not currently exist; create it).

**MODIFY — app (12 files):**
- `app/models/job_application.rb` — W1 call-site in `enqueue_new_job_application` (`:164-171`); W2 docx/PDF Textract-submit branch.
- `app/models/textract_result.rb` — W1 verification only (no code change to the bridge; see W1.4).
- `app/jobs/get_resume_text_from_textract_job.rb` — W1/C8: `cleanup_orphaned_summary` `:19` `summary.destroy` → `summary.record_failure(...)`.
- `app/jobs/docx_to_pdf_job.rb` — W2: enqueue `SubmitResumeToTextractJob` after `handle_possible_docx_resume`.
- `app/controllers/api/v1/job_applications_controller.rb` — W2: docx/PDF branch in `update` (`:110-116`).
- `app/models/job.rb` — W3: move criteria-extraction enqueue off `before_update` into an `after_commit` path.
- `app/models/ai_job_criteria.rb` — W6: pass `requesting_organization_user_id` (`:24-27`).
- `app/models/ai_job_application_summary.rb` — W4: extend `BROADCAST_STATUSES` (`:23`); W5: new `record_failure` choke-point + C1 `return if stale?` in `update_summary_status_record` (`:57`).
- `app/services/ai_job_application_action/summary/generate.rb` — W4: `:175` retrying `update_columns`→`.update`; W5: `:180`/`:184` failed writes → `record_failure`.
- `app/services/ai_job_application_action/scoring/score_job_application.rb` — W5: `:134`/`:138` failed writes → `record_failure`.
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` — W5: `:64`/`:68` failed writes → `record_failure`.
- `app/jobs/generate_ai_job_application_summary_job.rb` — W5: `:19`/`:44` failed writes → `record_failure`.
- `app/models/ai_job_application_summary_status.rb` — W5: add `failed: 4` to the enum (`:9-14`).

**MODIFY — frontend (3 files — `PlatoOverviewCallout.tsx` is a NEW ripple this plan adds vs the spec):**
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoLoadingState.tsx` — W4: add `awaiting_job_criteria` + `retrying` to the `PlatoGenerationStatus` union (`:8-13`) AND `STATUS_TO_STEP` (`:22-28`).
- `app/javascript/shared/types/jobApplication.ts` — W5: add `"failed"` to the `AiJobApplicationSummaryStatus.status` union (`:4`).
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` — W5 **[NEW RIPPLE]**: `:13` has a SECOND inline copy of the status-row union (`summaryStatusValue?` prop type) not imported from the canonical type; add `"failed"` to it (see W5.6.6). Missed by the spec's grep because the union is inlined, not the type-name.

**MODIFY — specs (existing homes; verified to exist):**
- `spec/models/job_application_ai_summary_status_spec.rb` (the `enqueue_new_job_application` home — W1/W2). *(`spec/models/job_application_spec.rb` does NOT exist — do not create it.)*
- `spec/models/job_criteria_lifecycle_spec.rb` (the criteria-lifecycle home — W3). *(`spec/models/job_spec.rb` does NOT exist — do not create it.)*
- `spec/models/textract_result_ai_trigger_spec.rb` (W1 bridge integration).
- `spec/models/ai_job_criteria_spec.rb` (W6 — update the single-key `.with` at the `resume_waiting_summaries` enqueue test).
- `spec/jobs/get_resume_text_from_textract_job_spec.rb` (C8 — invert the destroy assertions).
- `spec/models/ai_job_application_summary_spec.rb` (W4 broadcast-loop redesign + delete the non-broadcast block; W5 `record_failure`/C1).
- `spec/models/ai_job_application_summary_status_spec.rb` (W5 enum value).
- `spec/jobs/generate_ai_job_application_summary_job_spec.rb` (W5 site routing).
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` (W5 site routing).
- `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb` (W5 site routing).
- `spec/services/submit_resume_to_textract_spec.rb` (W2, if it asserts the entry-time enqueue).
- `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb` (only if a new ripple appears — verify).
- The job_applications controller/request spec for the T2 docx/PDF branch (locate the existing one — see Test Plan TP-2.3).

---

# Backend changes (implement in priority order)

---

## W1 — Auto-generate pre-creates a `textract_processing` summary  (Issue 1)

**cursor_rules to read first:** `cursor_rules/core_critical_rules.md` (rules 8, 10, 11, 12), `cursor_rules/backend/_base.md` (all). Pipeline `CLAUDE.md` #2 (trace every pipeline end-to-end), #16 (companion records via unconditional owner), #10 (minimum change).

### W1.1 — Create the interactor `CreateAutoAiSummaryGeneration`
- [ ] **W1.1.1** Create `app/interactors/create_auto_ai_summary_generation.rb`, class `CreateAutoAiSummaryGeneration`, `include Interactor`. Inputs on context: `job_application`. Model the structure on `create_bulk_ai_summary_generation.rb` (the no-enqueue sibling) — NOT on the single-send interactor's enqueue branch.
- [ ] **W1.1.2 (guards — choose option (b), the shared extraction, if clean; else option (a) inline):** Guard the AI preconditions WITHOUT submitting Textract. The four precondition checks (mirroring `validate_ai_summary_generation.rb:26-29` backed by `:65-83`): `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`, `job_application.has_resume`, `organization.ai_credits_available?`, `job.description.present?` (use `job_application.job&.description.present?` as the predicate does at `:81-83`). Resolve `organization` from `job_application.job&.organization` (the auto path has no `context.organization`). **Do NOT reuse `textract_text_ready?` (`:73-75`) — it is not a precondition.** If any of the four is false → bare `return` (no summary built, no `context.fail!` — matches today's "no summary" when gates fail).
  - **Option (b) (PREFERRED if it keeps one source of truth):** extract the four guard predicates from `ValidateAiSummaryGeneration` into a shared, side-effect-free method (e.g. a public predicate on `ValidateAiSummaryGeneration` or a small shared module) that returns whether all four pass, and call it from both `ValidateAiSummaryGeneration` and the auto interactor. **Constraint:** the extracted method must NOT submit Textract — it returns only the boolean. If extraction would entangle `ValidateAiSummaryGeneration`'s `context`/ivar wiring, fall back to (a).
  - **Option (a) (FALLBACK):** build the four guard checks inline in the interactor.
  - **Either way:** do NOT call `ValidateAiSummaryGeneration.call(...)` from the auto interactor — its `:39`/`:55` enqueue `SubmitResumeToTextractJob`, which double-submits (intake already submits).
- [ ] **W1.1.3 (reuse-guard):** Mirror `create_ai_summary_generation.rb:30-44`: find `active_ai_summary = job_application.ai_job_application_summaries.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`; if present and `active_ai_summary.textract_result_id != job_application.latest_textract_result&.id` then `active_ai_summary.update_columns(stale: true)` and treat as nil; if an active summary remains, set `context.ai_summary = active_ai_summary` and bare `return`. (On a brand-new application none exists; this protects clone/re-entry.)
- [ ] **W1.1.4 (build):** `ai_summary = job_application.ai_job_application_summaries.build(status: :textract_processing, requested_by_organization_user_id: nil)`. **Do NOT set `textract_result`** (none exists yet — diverges from the single-send analog which has a `validation_result.textract_result`; this divergence is REQUIRED and must not be flagged). Set `context.ai_summary = ai_summary`. Save via return-value: `context.fail! unless ai_summary.save` (mirror `create_bulk_ai_summary_generation.rb:57`; no bang). **Do NOT enqueue any job** (the bridge drives it).
- [ ] **W1.1.5** Match the analog's `ap` debug-log style only if it aids parity; keep it minimal. No new methods beyond `call` and (option b) the shared guard.

### W1.2 — Call the interactor from `enqueue_new_job_application`
- [ ] **W1.2.1** In `app/models/job_application.rb`, `enqueue_new_job_application` (`:164-171`): after `find_or_create_ai_job_application_summary_status` (`:170`), add `CreateAutoAiSummaryGeneration.call(job_application: self) if job.should_auto_generate_ai_summaries?`. This runs in the existing `after_commit on: [:create]` (`:45`) — synchronous, so the summary exists before `SubmitResumeToTextractJob` runs, preserving the stale/relink ordering at `submit_resume_to_textract.rb:18-26`.
- [ ] **W1.2.2 (ordering interaction — verify, no extra code):** Because the W1 summary now exists at `textract_processing`/`stale:false`, the guard at `submit_resume_to_textract.rb:18` (`unless ...textract_processing, stale:false exists?`) is now TRUE → the `update_all(stale: true)` at `:19` is skipped → the relink at `:25-26` attaches the new `TextractResult` to the W1 summary (it was built with `textract_result_id: nil`). Confirm by reading; do not add code. (For W2's docx path the summary is still created here at intake; only the Textract submit is deferred.)

### W1.3 — C8 side effect: persist as `failed` instead of destroying (routes through W5 `record_failure`)
> **Sequencing note:** `record_failure` is defined in W5 (W5.2). Implement W5.2 before wiring this call, OR stub the call and wire it when W5 lands. Because the plan order is W1→…→W5, mark this checkbox and complete the wiring once `record_failure` exists; the W1 C8 tests (TP-1.4) depend on it.
- [ ] **W1.3.1** In `app/jobs/get_resume_text_from_textract_job.rb`, `cleanup_orphaned_summary` (`:10-23`): replace `summary.destroy` (`:19`) with `summary.record_failure('Resume processing failed after multiple attempts.')`. (`cleanup_orphaned_summary` is a class method holding the `summary` instance from `:14-15`, so `summary.record_failure(...)` is a clean instance call.)
- [ ] **W1.3.2 (preserve the manual broadcast):** Keep the existing `AI_SUMMARY_FAILED` broadcast for the manual (requesting-user) case. The current code (`:18`, `:21-22`) looks up `requesting_org_user` and calls `textract_result&.send(:broadcast_ai_summary_failed, requesting_org_user, 'Resume processing failed after multiple attempts.')`. Retain this AFTER `record_failure`; it already no-ops for a nil requesting user via `broadcast_ai_summary_failed`'s `return unless requesting_organization_user` (`textract_result.rb:147`). Do NOT delete this broadcast (the spec reviewed it as "keep" — deleting it is a finding).
- [ ] **W1.3.3 (why this is load-bearing — verify the mechanism):** On Textract terminal failure the bridge never fires (failure writes `update_columns(textract_job_status:'failed')` at `get_resume_text_from_textract.rb:40`, never setting `textract_job_result_text`), so `set_initial_summary_pending` never runs and the status row would stay `none`. Only `record_failure` (which sets the summary `failed` AND updates the status row to `failed`, pointing `ai_job_application_summary_id` at the summary) makes the detail-card `failed` branch render (`PlatoTab.tsx:175-186` requires the full-summary fetch, enabled by `summaryStatus?.aiJobApplicationSummaryId` at `PlatoTab.tsx:46`). The status row is guaranteed to exist on this path (created at intake by `enqueue_new_job_application:170`), so `record_failure`'s `return unless ai_job_application_summary_status` guard passes — do NOT re-add a `find_or_create`.

### W1.4 — C7 cascade: verify the pre-created summary is the one that advances (no code change)
- [ ] **W1.4.1** Read `ai_job_application_summary.rb:47-55` (`destroy_previous_textract_results`, `after_commit on: :update`, guarded `saved_change_to_status? && status_succeeded?` `:49`) and `textract_result.rb:5` (`has_many :ai_job_application_summaries ... dependent: :destroy`). Confirm: when a later summary `→succeeded`, it `destroy_all`s earlier non-succeeded `TextractResult`s (`created_at < textract_result.created_at`, `:51-54`), cascade-destroying any summary attached to THOSE earlier results. The W1 summary is built with NO `textract_result` and relinked (via `submit_resume_to_textract.rb:25-26`) to the SAME `TextractResult` that succeeds — so it is not an "earlier" result and is not cascade-destroyed. **No code change.** This is verified by test TP-1.5 (incl. the earlier-failed-`TextractResult` case).

### W1 decisions (resolved; do not re-litigate)
- **D1** — persist auto summary as `failed` on Textract terminal failure (via W1.3 / W5 `record_failure`), do not destroy.
- **D2** — charge exactly one credit on auto-gen success (the bridge if-branch path at `textract_result.rb:125-136` already does, via `generate_ai_summary_with_credit_flow` → `CreateAiCreditBalanceTransaction` `:84`). Behavioral change from today's "no credit."
- **D3** — applies to all auto-gen entries uniformly via the shared `should_auto_generate_ai_summaries?` gate (one call site).

---

## W2 — Chain Textract submission to docx conversion  (Issue 2)

**cursor_rules to read first:** `cursor_rules/core_critical_rules.md` (rule 1 no begin blocks, rule 5 one params method per controller), `cursor_rules/backend/_base.md`. Pipeline `CLAUDE.md` #2; hub "Hard rules cannot be rationalized away by plans" (Textract gate at every site).

### W2.1 — Intake branch in `enqueue_new_job_application`
- [ ] **W2.1.1** In `app/models/job_application.rb`, `enqueue_new_job_application` (`:164-171`): keep `DocxToPdfJob.perform_later(id)` (`:166`) unconditional (the docx viewer needs it regardless).
- [ ] **W2.1.2** Replace the unconditional Flipper-gated Textract submit (`:167-169`) with a branch:
  - if `resume_is_docx` (`:697-701`) → do NOT submit Textract here (the docx path defers to `DocxToPdfJob`, W2.2);
  - else (PDF / non-docx with resume) → keep the existing `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` then `SubmitResumeToTextractJob.perform_later(id)`.
- [ ] **W2.1.3** Order the new W1 `CreateAutoAiSummaryGeneration.call(...)` (W1.2.1) and this branch so the summary is still pre-created for BOTH docx and PDF at intake (only the Textract submit differs). The summary build does not depend on the Textract branch.

### W2.2 — Enqueue Textract from `DocxToPdfJob` after conversion
- [ ] **W2.2.1** In `app/jobs/docx_to_pdf_job.rb`, `perform` (`:6-15`): AFTER `@job_application.handle_possible_docx_resume` (`:8`) and BEFORE the method-level `rescue` (`:12`), add (with its own guards):
  ```ruby
  return unless @job_application.resume_is_docx
  return unless Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, @job_application.job.organization)
  SubmitResumeToTextractJob.perform_later(@job_application.id)
  ```
- [ ] **W2.2.2 (the `resume_is_docx` guard is REQUIRED — do not omit):** `DocxToPdfJob.perform_later` runs UNCONDITIONALLY for every application (`job_application.rb:166`, controller `:112`), so it runs for PDFs too. The PDF path already submits Textract at intake (W2.1.2 else-branch). Without this guard a PDF would submit Textract TWICE (two AWS calls, two `TextractResult`s, a race). `handle_possible_docx_resume` has its own `return unless resume_is_docx` (`:734`), but this enqueue is OUTSIDE that method and needs its own guard.
- [ ] **W2.2.3 (placement after the call, before the rescue):** Placing the enqueue after `handle_possible_docx_resume` means it runs whether conversion succeeded or failed (conversion failure is rescued INSIDE `handle_possible_docx_resume` at `:747-751` and does not propagate). On docx-conversion failure, Textract is attempted with the raw docx exactly as today (no regression), keeping the candidate recoverable. Do NOT move the enqueue inside `handle_possible_docx_resume`'s success-only path (that would skip Textract entirely on conversion failure — strictly worse than today). The only way the enqueue is skipped for a docx is a raise from `JobApplication.find` at `:7` (acceptable; `find` raising lands in the rescue).

### W2.3 — T2 controller path
- [ ] **W2.3.1** In `app/controllers/api/v1/job_applications_controller.rb`, `update` (`:88-126`), inside the `if temp_params.key?(:resume) && temp_params[:resume].present?` block (`:110-116`): keep `DocxToPdfJob.perform_later(job_application.id)` (`:112`); add a branch so Textract submits directly only for non-docx (the existing `:113-115` Flipper-gated `SubmitResumeToTextractJob`), and for docx rely on `DocxToPdfJob`'s new enqueue.
- [ ] **W2.3.2** Use the **local block variable** `job_application` (yielded by `exists(...) do |job_application|` at `:90`) for the `resume_is_docx` branch — NOT an `@job_application` ivar (this action has no such ivar). Keep the existing Flipper gate `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` (`:113`).
- [ ] **W2.3.3** Do NOT add a second params method (core rule 5) — this is control-flow only. No `begin` block (core rule 1) — the action already uses the `exists(...) do ... end` pattern.

### W2 out of scope (do not fix)
- The recovery actors `validate_ai_summary_generation.rb:39/55` and `queue_bulk_ai_summary_jobs.rb` still submit without docx-ordering — lower severity; explicitly out of scope (noted in spec).

---

## W3 — Enqueue criteria extraction AFTER the Job transaction commits  (Issue 5 root cause / V1; resolves the incident)

**cursor_rules to read first:** `cursor_rules/backend/_base.md`, `cursor_rules/core_critical_rules.md` (rule 8 bare return). Pipeline `CLAUDE.md` #14 (follow the analogous `after_commit` pattern), #10 (no sweeper — DEFERRED). Hub "Verify the execution lifecycle matches before copying an analog pattern."

**Root cause (proven):** `before_update :handle_before_update` (`job.rb:60`) → `handle_status_change` (`:479`) → `handle_status_changed_to_published` (`:560`) / `handle_description_change` (`:731`) → `auto_extract_job_criteria` (`:696-711`), which does `ai_job_criteria.new(status: :pending).save` (`:703-704`) + `ExtractJobCriteriaJob.perform_later` (`:707/:709`) **inside the before_update transaction**. Rails 6.1.7.7 has no `enqueue_after_transaction_commit`, so a Sidekiq worker can run `ExtractJobCriteriaJob` before the Job commits → `AiJobCriteria.find_by(id:)` nil (`extract_job_criteria_job.rb:13`) → `return unless ai_job_criteria` (`:14`) → silent exit → criteria stuck `pending`; the pending poison-guard (`job.rb:701/718`) then blocks all future extraction.

### W3.1 — Relocate ONLY the two `auto_extract_job_criteria` calls off the before_update chain
- [ ] **W3.1.1** Remove the `auto_extract_job_criteria` call at the END of `handle_status_changed_to_published` (`job.rb:560`). **Keep everything else in that method** (`touch(:published_at)` `:546`, `update_column(:originally_published_at, ...)` `:549`, the five `perform_later`s `:551-558`).
- [ ] **W3.1.2** Remove the `auto_extract_job_criteria` call at the END of `handle_description_change` (`job.rb:731`). **Keep its guards** (`description_changed?` `:727`, `published?` `:728`, `description_meaningfully_changed?` `:729`) — but note these guards run in `before_update` where they currently DECIDE whether to extract; under option (b) the decision moves to after_commit (W3.2), so `handle_description_change` becomes a no-op shell OR is removed from the before_update chain. **Decision for the impl agent:** under option (b), `handle_description_change`'s body is fully replaced by the after_commit logic, so leave the method only if something else calls it (grep: it is called only from `handle_before_update:480`). If nothing else needs it, the cleanest edit is to delete the `auto_extract_job_criteria` line and let the remaining guard-only method be harmless, OR remove the `handle_description_change` call from `:480` and the method. **Do the minimal change:** remove the `auto_extract_job_criteria` line from both methods; the publish/description detection now lives in after_commit (W3.2). (If `handle_description_change` becomes an empty guard chain, removing its call from `:480` is acceptable cleanup but verify no other caller.)

### W3.2 — PRIMARY: option (b) — detect the condition in `after_commit` via `saved_change_to_*` / `previous_changes` (string keys)
- [ ] **W3.2.1** Add the criteria-extraction trigger to the post-commit path. Detect publish and meaningful-description-change using the Rails 5.1+ dirty API that fires correctly in `after_commit`: `saved_change_to_status?` + `published?` (publish), and `saved_change_to_description?` + a sanitize-and-compare on `saved_change_to_description` (which returns `[old, new]`). **Equivalently** use string-keyed `previous_changes['status']` / `previous_changes['description']` — matching the analog at `:497/:501/:507` which proves `previous_changes` is string-keyed. **Do NOT use symbol keys** (`previous_changes[:description]` returns nil; `previous_changes` is a plain string-keyed Hash, not `HashWithIndifferentAccess`). *(Cross-check: `handle_visible_change:538` uses `previous_changes.key?(:visible)` with a symbol — this is a pre-existing latent bug in unrelated code; do NOT copy that symbol-key pattern. Use `saved_change_to_*` to avoid the trap entirely.)*
- [ ] **W3.2.2 (MANDATORY description-rewrite — the dirty-tracking trap):** `description_meaningfully_changed?` (`:734-737`) reads `description_was` (`:735`), which in an `after_commit` returns the CURRENT value (dirty tracking is RESET post-commit) → it would compare `description` to itself and always be false → criteria would NEVER fire on a description change. The after_commit check MUST apply the same sanitize-and-compare to the OLD value (`saved_change_to_description&.first` or `previous_changes['description']&.first`) vs the NEW value (`&.last`), reusing the exact sanitize transform from `description_meaningfully_changed?`:
  ```ruby
  ActionView::Base.full_sanitizer.sanitize(text).to_s.downcase.gsub(/[^a-z]/, '')
  ```
  Build a small private helper that takes `(old_html, new_html)` and returns whether the sanitized texts differ, and call it with the saved-change pair. **Do NOT call the existing `description_meaningfully_changed?` from after_commit** (it reads `description_was`, which is wrong post-commit). Detect publish via `saved_change_to_status? && published?` (or `previous_changes.key?('status') && published?`).
- [ ] **W3.2.3** When the publish OR description-change condition is true post-commit, call `auto_extract_job_criteria`. Its `AiJobCriteria.new(...).save` opens its own transaction and commits BEFORE its `ExtractJobCriteriaJob.perform_later` — so the worker always finds the row. **Preserve `auto_extract_job_criteria` unchanged** (the flipper guard `:697`, the pending poison-guard `:701`, the `wait: 30.seconds` debounce `:707`, the first-time `:709` path). Only the WHEN changes, not the WHAT.

### W3.3 — `skip_update_callback` (HARD requirement)
- [ ] **W3.3.1** Today criteria extraction fires in `before_update` REGARDLESS of `skip_update_callback` — `handle_before_update` (`:476-485`) has no such guard. But `handle_after_update_commit` returns early on `return if skip_update_callback` (`:492`), and `Settingsable` sets that flag true (`settingsable.rb:22,40,51`). To preserve current behavior, the after_commit criteria extraction MUST run **irrespective of `skip_update_callback`**: place it in a DEDICATED separate `after_commit on: [:update]` callback (NOT inside `handle_after_update_commit`, which is gated by `:492`), OR place it BEFORE the `:492` guard in `handle_after_update_commit`. **Prefer a dedicated callback** (e.g. `after_commit :handle_criteria_extraction_after_commit, on: [:update]`) — it is the clearest way to bypass the `skip_update_callback` early-return and keeps the criteria concern separate from the Webflow/WhatJobs concern. Register it on the model near `:58`.
- [ ] **W3.3.2** Verify the new callback does NOT inherit `skip_update_callback`'s early return. Confirm by reading the final callback body.

### W3.4 — FALLBACK: option (a) — instance flag captured in before_update (only if the option-(b) rewrite is judged too error-prone)
- [ ] **W3.4.1** If (and only if) the option-(b) `saved_change_to_description` rewrite is judged too error-prone: in `handle_before_update` (where dirty state is LIVE), capture the decision onto an instance flag, e.g. `@should_extract_criteria_after_commit = (status_changed? && published?) || (description_changed? && published? && description_meaningfully_changed?)`. Then in the dedicated after_commit callback (W3.3.1), `auto_extract_job_criteria if @should_extract_criteria_after_commit`. NOTE: option (a) introduces an instance-flag mechanism the analog does NOT use — acceptable only as a fallback, and it still must satisfy W3.3 (`skip_update_callback`). **Choose option (b) unless the rewrite is genuinely error-prone; document the choice in the commit/PR.**

### W3.5 — Asymmetry & scope (verify, no change)
- [ ] **W3.5.1** Confirm the `extract_job_criteria` callers via `orchestrate.rb:80` and `score_job_application.rb:23/45` already run inside Sidekiq jobs OUTSIDE the Job-update transaction, so they are NOT subject to V1 — **do NOT alter them.** This fix targets only the model-callback (publish / description-change) path.
- [ ] **W3.5.2** Do NOT build a sweeper/reaper for already-stuck `pending` records (issue 6 V2/V3) — explicitly DEFERRED.

---

## W6 — X3 re-trigger carries the requesting user  (C4)

**cursor_rules to read first:** `cursor_rules/backend/_base.md`. Pipeline `CLAUDE.md` #6 (grep spec files on signature change).

### W6.1 — Pass the requesting user through `resume_waiting_summaries`
- [ ] **W6.1.1** In `app/models/ai_job_criteria.rb`, `resume_waiting_summaries` (`:21-29`), change the `GenerateAiJobApplicationSummaryJob.perform_later` call (`:24-27`) to:
  ```ruby
  GenerateAiJobApplicationSummaryJob.perform_later(
    textract_result_id: ai_job_application_summary.textract_result_id,
    requesting_organization_user_id: ai_job_application_summary.requested_by_organization_user_id
  )
  ```
  (Nil for auto summaries — correct, no toast; non-nil for manual single-send — restores the `AI_SUMMARY_COMPLETE` toast.)
- [ ] **W6.1.2 (grep ripple — Known Failure Pattern #6):** grep `spec/` for every `have_enqueued_job(GenerateAiJobApplicationSummaryJob).with(...)` and `have_been_enqueued` involving `GenerateAiJobApplicationSummaryJob`. **Verified there are TWO single-key `.with(textract_result_id:)` assertions** — but only ONE breaks from W6:
  - **`ai_job_criteria_spec.rb:62` (BREAKS — update it):** this is the `resume_waiting_summaries` enqueue that W6 changes → its single-key `.with` must gain `requesting_organization_user_id:` (TP-4.2). RSpec `.with` is exact-match.
  - **`textract_result_ai_trigger_spec.rb:93` (does NOT break — do NOT edit it):** verified this assertion is in the context `'on update that changes the text (resume replacement)'`, with NO `textract_processing` waiting summary present and NO resume attached. The bridge therefore takes the AUTO/ELSE branch (`textract_result.rb:137-143`), which enqueues single-key `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` — a path W6 does NOT touch (W6 changes only `ai_job_criteria.rb`). After W1, would `enqueue_new_job_application` pre-create a summary here and flip to the if-branch? No — `create_credit_test_job_application` attaches no resume, so W1's `has_resume?` gate fails and pre-creates nothing. **`:93` stays single-key and must remain unchanged** (see Risks R-8). Confirm it still passes after W6/W1; do NOT add `requesting_organization_user_id:` to it.
  - Grep to catch any THIRD callsite before committing; re-grep after fixing `:62`.

---

# Frontend changes (implement after the backend workstreams)

---

## W4 — Broadcast `awaiting_job_criteria` and `retrying`  (Issue 4)

**cursor_rules to read first:** `cursor_rules/frontend/_base.md`, `cursor_rules/core_critical_rules.md` (rule 7 + 7-exception: enum values stay snake_case on FE; rule 2 theme colors; rule 9 no deliberate undefined). Pipeline `CLAUDE.md` #6 (rename/grep cascade incl. spec files), #1 (Emotion theme utilities are complete declarations), #11 (copy behavioral props), #12 (separate styled variants).

### W4.1 — Backend: extend `BROADCAST_STATUSES`
- [ ] **W4.1.1** In `app/models/ai_job_application_summary.rb`, add `awaiting_job_criteria` and `retrying` to `BROADCAST_STATUSES` (`:23`). The live constant is currently `%w[pending textract_processing extracting summarizing scoring integrating succeeded failed]` (8 of the 10 enum values, missing exactly `awaiting_job_criteria` and `retrying`); after this change it becomes **all 10 enum values** (the full `enum status` set) — verify the final array equals the enum keys. `before_update :broadcast_status_change` (`:100-111`) then broadcasts `ai_summary_status_change` on transitions into these statuses (guarded by `status_changed?` `:101` and `BROADCAST_STATUSES.include?(status)` `:102`); `WebsocketJobChannelHandler.tsx:73-76` invalidates the detail-view queries (`["aiJobApplicationSummary", id]` + `["jobApplication", id]`) only — no list refetch storm (list invalidation fires only on the separate `ai_summary_succeeded` event from `update_summary_status_record:93-97`).

### W4.2 — Backend HARD requirement: convert the `generate.rb` retrying writer
- [ ] **W4.2.1** In `app/services/ai_job_application_action/summary/generate.rb:175`, convert `ai_summary&.update_columns(status: :retrying, error_message: e&.message)` to `ai_summary&.update(status: :retrying, error_message: e&.message)`. **Preserve `error_message`** (do NOT drop the column) and keep the `&.` safe-nav. `update_columns` bypasses ALL callbacks (so retrying would never broadcast); `.update` fires `broadcast_status_change`. This matches the two analog retrying writers `score_job_application.rb:129` and `integrate_analysis.rb:59` (both already `&.update(status: :retrying, error_message: e&.message)`).
- [ ] **W4.2.2** It is a rescue-path best-effort write before `raise` (`:176`); like the analogs, the return value is NOT checked (consistent with the established retrying-writer pattern — do not flag the unchecked return here). Verify no harmful double-fire: `destroy_previous_textract_results` (`:47-55`) and `update_summary_status_record` (`:69`) both guard on `status_succeeded?`, so they no-op for `retrying`; the retry semantics (the subsequent `raise`) are preserved.
- [ ] **W4.2.3 (do NOT touch)** `extract_criteria.rb:146` `update_columns(status: :retrying)` is on **`AiJobCriteria`**, not the summary — leave it.

### W4.3 — Frontend: extend the union AND the step map
- [ ] **W4.3.1** In `app/javascript/ats/src/views/jobApplications/Plato/PlatoLoadingState.tsx`, add `awaiting_job_criteria` and `retrying` to BOTH the `PlatoGenerationStatus` union (`:8-13`) AND the `STATUS_TO_STEP` map (`:22-28`). The union extension is REQUIRED: `STATUS_TO_STEP` is typed `Record<PlatoGenerationStatus, number>` (`:22`), so a key not in the union is a TS compile error.
- [ ] **W4.3.2 (step mapping):** `STEPS` (`:15-20`) is `["Processing the resume"(0), "Analyzing the candidate"(1), "Scoring against the role"(2), "Finalizing the review"(3)]`. Map `awaiting_job_criteria → 2` ("Scoring against the role" — it is awaiting criteria in order to score) and `retrying → 3` ("Finalizing the review" — keep the last step so the stepper doesn't reset). Keep enum values snake_case (rule 7-exception). PlatoTab already routes both to `PlatoLoadingState` (`PlatoTab.tsx:163,166`) — no PlatoTab change needed for W4.

### W4.4 — Spec ripples in `spec/models/ai_job_application_summary_spec.rb` (Known Failure Pattern #6 — two coupled edits)
- [ ] **W4.4.1 (DELETE, do not invert):** Delete the `%w[awaiting_job_criteria retrying]` "does not broadcast" block (currently at `:57-62`). After W4 the `BROADCAST_STATUSES.each` loop (`:37-55`) iterates over `awaiting_job_criteria` + `retrying` and already asserts they DO broadcast — inverting `:57-62` would duplicate/contradict the loop. Removal is the correct edit.
- [ ] **W4.4.2 (REDESIGN the move-off helper at `:43`):** The loop's "move off the target status first" line (`summary.update!(status: :awaiting_job_criteria) if summary.status == broadcast_status`, `:43`) relies on `awaiting_job_criteria` being non-broadcasting — but W4 makes it broadcast, and after W4 **all** summary statuses in `BROADCAST_STATUSES` broadcast, so NO non-broadcasting intermediate status exists. The move-off runs at `:43`, BEFORE the `allow(JobChannel).to receive(:broadcast_to)` stub at `:47`, so it would fire a real broadcast and pollute the assertion. Redesign: stub `JobChannel` BEFORE the move-off, then reset/clear the spy (e.g. `allow(...).to receive(:broadcast_to)` first, perform the move-off, then `RSpec::Mocks.space.proxy_for(JobChannel).reset` or re-`allow` to clear, then perform the real change and assert) — OR restructure so the "real change" assertion does not depend on a non-broadcasting setup status (e.g. create each `summary` fresh at a status != `broadcast_status` without an intermediate `update!`). Pick the approach that keeps the loop asserting exactly one `ai_summary_status_change` for the target status.
- [ ] **W4.4.3 (grep):** grep `spec/` for any OTHER assertion that `awaiting_job_criteria`/`retrying` (or any now-broadcasting status) do NOT broadcast; fix each. After fixing, grep again to confirm zero stale "does not broadcast" refs for these statuses.
- [ ] **W4.4.4** Add a spec that `generate.rb`'s retrying path (W4.2) broadcasts `ai_summary_status_change` (the `.update`-on-retrying now fires it).

### W4 out of scope
- A list-level in-progress indicator (the infinite list intentionally reflects only terminal results; adding it risks a fan-out refetch storm). Criteria-pending broadcasts (net-new surface, no analog). Do not build either.

---

## W5 — Status-row `failed` display state + stale guard  (Issue 3a + C1)

**cursor_rules to read first:** `cursor_rules/backend/_base.md`, `cursor_rules/core_critical_rules.md` (rules 11/12 no bang/check returns, rule 2 theme, rule 10 no fabricated fallbacks), `cursor_rules/frontend/_base.md`. Pipeline `CLAUDE.md` #18 (clear ALL denormalized cols when disassociating), #16 (companion-record write site), #13 (no fabricated fallbacks).

### W5.1 — Data model: add `failed` to the status-row enum
- [ ] **W5.1.1** In `app/models/ai_job_application_summary_status.rb`, add `failed: 4` to the `enum status` (`:9-14`). The `status` column is already an integer — **no migration; never stage/commit `db/schema.rb`.**
- [ ] **W5.1.2 (counter_culture — verify, no change):** counter_culture (`:7`) counts only `status IN (2,3)` via its proc (`status_current? || status_regenerating?`) and `column_names` (`['ai_job_application_summary_statuses.status IN (?)', [2, 3]]`), so `failed` (4) is automatically excluded. A row transitioning `current/regenerating → failed` MUST use a callback-firing write (`.update`, NOT `update_columns`) so counter_culture decrements `jobs.ai_job_application_summaries_count` — this is why `record_failure`'s ROW write is `.update` (W5.2.2).

### W5.2 — Backend: the `record_failure` choke-point on `AiJobApplicationSummary`
- [ ] **W5.2.1** Add a single public method `record_failure(error_message)` to `app/models/ai_job_application_summary.rb` (place it with the public methods, before `private` at `:45`; it is called from jobs/services and `cleanup_orphaned_summary`).
- [ ] **W5.2.2** Body:
  1. Set the SUMMARY side via `update_columns(status: :failed, error_message: error_message)` — **keep `update_columns`** to avoid callback re-entrancy in rescue paths (this is spec-mandated; do not switch to `.update` to "add a broadcast" — see W5.4).
  2. Then sync the STATUS ROW: `ai_job_application_summary_status = job_application.ai_job_application_summary_status; return unless ai_job_application_summary_status` (mirror `update_summary_status_record:72`). Then `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'failed', score_percentage: nil, headline: nil, integrated_role_analysis: nil)` — **`.update`** (fires counter_culture). **Clear ALL denormalized columns** (`score_percentage`, `headline`, `integrated_role_analysis`) per pipeline #18 — do not leave stale values. Point `ai_job_application_summary_id` at the failed summary so the FE full-summary fetch is enabled.
  3. Check the `.update` return value (rule 12): log on failure (`Rails.logger.error` + `ap`), mirroring `update_summary_status_record:81-85`. Do NOT raise (no bang).
- [ ] **W5.2.3 (idempotency):** The row write is idempotent (re-applying `failed` + nil cols is a no-op once set); guard is unnecessary beyond the `return unless ai_job_application_summary_status`. Do not add extra guards beyond scope.

### W5.3 — Route ALL terminal `AiJobApplicationSummary` failure sites through `record_failure`
> **Verified complete site list (grep of `status: :failed` on `AiJobApplicationSummary` in `app/` — there are exactly 8 status-writes + the C8 destroy; NO others). Do NOT touch `AiJobCriteria` writes (`extract_job_criteria_job.rb:9/28`, `extract_criteria.rb:32/62/122/151/155`, `score_job_application.rb:43`), `TextractResult` writes (`submit_resume_to_textract.rb:33/39`, `get_resume_text_from_textract.rb:40/47`), `BulkAiSummaryJobApplication` (`bulk_generate_ai_summaries_job.rb:180`), or unrelated models.**
- [ ] **W5.3.1** `app/jobs/generate_ai_job_application_summary_job.rb:19` (retry-exhaustion block) — replace `ai_summary&.update_columns(status: :failed, error_message: error&.message)` with `ai_summary&.record_failure(error&.message)`. Keep the surrounding exhaustion block and the `broadcast_completion(...)` call (`:20`) unchanged.
- [ ] **W5.3.2** `app/jobs/generate_ai_job_application_summary_job.rb:44` (StandardError rescue) — replace `ai_summary&.update_columns(status: :failed, error_message: e&.message)` with `ai_summary&.record_failure(e&.message)`. Keep the `broadcast_completion(...)` call (`:45`).
- [ ] **W5.3.3** `app/services/ai_job_application_action/summary/generate.rb:180` (JSON::ParserError) — replace with `ai_summary&.record_failure("Failed to parse AI response: #{e&.message}")` (**keep the exact existing message verbatim**).
- [ ] **W5.3.4** `app/services/ai_job_application_action/summary/generate.rb:184` (StandardError) — replace with `ai_summary&.record_failure(e&.message)`.
- [ ] **W5.3.5** `app/services/ai_job_application_action/scoring/score_job_application.rb:134` (JSON::ParserError) — replace `@ai_job_application_summary&.update(status: :failed, error_message: "Failed to parse AI response: #{e&.message}")` with `@ai_job_application_summary&.record_failure("Failed to parse AI response: #{e&.message}")`.
- [ ] **W5.3.6** `app/services/ai_job_application_action/scoring/score_job_application.rb:138` (StandardError) — replace with `@ai_job_application_summary&.record_failure(e&.message)`.
- [ ] **W5.3.7** `app/services/ai_job_application_action/scoring/integrate_analysis.rb:64` (JSON::ParserError) — replace with `@ai_job_application_summary&.record_failure("Failed to parse AI response: #{e&.message}")`.
- [ ] **W5.3.8** `app/services/ai_job_application_action/scoring/integrate_analysis.rb:68` (StandardError) — replace with `@ai_job_application_summary&.record_failure(e&.message)`.
- [ ] **W5.3.9** `app/jobs/get_resume_text_from_textract_job.rb:19` (C8) — already covered by W1.3.1: `summary.record_failure('Resume processing failed after multiple attempts.')`.
- [ ] **W5.3.10 (do NOT change the retrying writers)** `generate.rb:175` (now `.update` per W4.2), `score_job_application.rb:129`, `integrate_analysis.rb:59` — these are NON-terminal (`retrying`), keep as-is. Do not route them through `record_failure`.
- [ ] **W5.3.11 (each site passes its EXISTING error_message verbatim)** — confirm the strings above match the live code: JSON::ParserError branches keep `"Failed to parse AI response: #{e&.message}"`; StandardError/exhaustion branches keep `e&.message` / `error&.message`; the C8 site keeps `'Resume processing failed after multiple attempts.'`. Do not drop or reconstruct any message.
- [ ] **W5.3.12 (grep to confirm completeness)** Before committing W5, re-grep `app/` for `status: :failed` / `status: 'failed'` and confirm every `AiJobApplicationSummary` write now goes through `record_failure` (the 8 sites above), and that no NEW summary-failed write was introduced or missed.

### W5.4 — No real-time broadcast on `failed` (by design — do NOT "fix")
- [ ] **W5.4.1** `record_failure` writes the summary side via `update_columns` (bypasses `broadcast_status_change` even though `failed` is in `BROADCAST_STATUSES`), and the status-row `.update` has no broadcast callback. So a transition into `failed` emits no `ai_summary_status_change` — intentional (the auto path has no requesting user watching; the manual paths still push via `GenerateAiJobApplicationSummaryJob#broadcast_completion` → `AI_SUMMARY_COMPLETE` with `status:'failed'` at `:61,70`). **Do NOT switch the summary-side `record_failure` write to `.update` to add a broadcast** — that re-introduces the rescue-path callback re-entrancy `update_columns` deliberately avoids. (This is a spec-mandated mechanism split: summary write = `update_columns`, row write = `.update`. Do not flag it.)

### W5.5 — C1 stale guard in `update_summary_status_record`
- [ ] **W5.5.1** In `app/models/ai_job_application_summary.rb`, add `return if stale?` at the top of `update_summary_status_record` (`:57`, before the `:69` succeeded-guard — placing it first means a stale summary reaching `succeeded` never copies its denormalized fields onto the row). Mirror the `!stale?` checks at `textract_result.rb:68` and `find_or_create_ai_job_application_summary_status.rb:27`. (Place it after the `ap` debug lines or before them — before them is cleaner; ensure it does not break the existing debug output the team relies on. Putting `return if stale?` as the very first line is acceptable.)

### W5.6 — Frontend
- [ ] **W5.6.1** In `app/javascript/shared/types/jobApplication.ts:4`, add `"failed"` to the `AiJobApplicationSummaryStatus.status` union (`"none" | "initial_summary_pending" | "current" | "regenerating" | "failed"`).
- [ ] **W5.6.2 (PlatoTab — verify, likely NO change):** `PlatoTab.tsx:175-186` ALREADY renders `PlatoTabEmptyState status="failed"` for `fullSummaryStatus === "failed"`, keyed on the full summary's status. Because W1/W5 point the status row's `ai_job_application_summary_id` at the failed summary, the full-summary fetch is enabled (`PlatoTab.tsx:46`) and this existing branch renders for the auto-failed case too — **no new PlatoTab branch required.** Verify the status-row `failed` value (now possible at `summaryStatus?.status`) does not fall through to a wrong branch: the `statusValue` branches are at `:151` (`current`), `:154` (`regenerating`), `:187` (`!statusValue || none` + no resume). A `failed` status row with a loaded `fullSummary` hits the `:175` failed branch FIRST; with no `fullSummary` it falls to the final `deriveEmptyStatus()` default (`:197-206`). Confirm `deriveEmptyStatus()` produces a sensible state for a `failed` row (read it); add handling only if it renders wrong.
- [ ] **W5.6.3 (NavItem — verify, no change):** `JobApplicationNavItem.tsx:26-29` renders the Harvey ball only for `current`/`regenerating` with non-nil score → a `failed` row shows no fit indicator (Decision default — acceptable, consistent with non-scored states). No switch to break.
- [ ] **W5.6.4 (Activity — verify, no change):** `JobApplicationActivity.tsx:80-94` gates `platoReviewEntries` on `current`/`regenerating` → a `failed` row produces no entry (spec says unchanged). No switch to break.
- [ ] **W5.6.5 (theme)** If any new FE color is needed (it should not be — no new visual element), check `app/javascript/ats/styles/theme.ts` first (core rule 2). Expectation: zero new colors.
- [ ] **W5.6.6 (NEW RIPPLE — second inline copy of the union; verified, was missing from this plan):** `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx:13` contains a SECOND, INLINE copy of the status-row union as a prop type — `summaryStatusValue?: "none" | "initial_summary_pending" | "current" | "regenerating" | null` — that is NOT imported from `jobApplication.ts`, so the W5.6.1 change does NOT propagate to it. **Action:** add `"failed"` to this inline union (`:13`) so a `failed` status-row value is type-valid when passed as `summaryStatusValue`. `deriveCalloutStatus` (`:40-47`) already falls through to `return "ask"` (`:46`) for any unrecognized value, so by default `"failed"` renders the "Ask Plato to review this candidate" callout. **Decision (default, flag to reviewer):** add `"failed"` to the inline union and let it fall through to `"ask"`, matching the existing fall-through. If a failed state should instead suppress the callout, add `if (summaryStatusValue === "failed") return null;` at the top of `deriveCalloutStatus`. (This is OQ-1 in Risks.) Per Known Failure Pattern #6 (union cascades: grep ALL references) — this site was missed by the spec's grep because the union is inlined, not the `AiJobApplicationSummaryStatus` type-name.
- [ ] **W5.6.7 (grep — both forms):** grep `app/javascript/` for consumers of the status-row `status` BY VALUE as well as by type-name: `grep -rn "summaryStatus?.status\|aiJobApplicationSummaryStatus" app/javascript/` AND `grep -rn '"initial_summary_pending"' app/javascript/` (to catch any THIRD inline copy of the union). Verified at plan time: only `jobApplication.ts:4` (canonical) and `PlatoOverviewCallout.tsx:13` (inline) carry this 4-member union. Confirm none is an exhaustive `switch`/`Record` that the new `"failed"` value breaks (the verified consumers — PlatoTab, NavItem, Activity, PlatoOverviewCallout — all use `||`/`===` chains or a fall-through `deriveCalloutStatus`, not exhaustive switches; the only `Record` maps — `STATUS_TO_STEP`, `PLATO_CALLOUT_STATES` — are keyed by `PlatoGenerationStatus`/`PlatoCalloutStatus`, NOT by the status-row union, so neither breaks).

### W5 deferred (NOT in W5)
- Clearing denormalized columns on the `regenerating` transition (behavior change — prior data is shown intentionally during regen). Solution 3 (S-D/T2 auto-continuation building a fresh summary + charging a credit). Do not build either.

---

# Validation and constraints

- [ ] **V-1 (W1 guards):** the four precondition guards (flipper, has_resume, credits_available, has_job_description) are evaluated in the auto interactor without any Textract submission. No `context.fail!` on guard failure — bare `return` (the auto path is system-initiated; a gate failure simply means no summary, matching today).
- [ ] **V-2 (W1 save):** `ai_summary.save` return value is checked (`context.fail! unless ...`); no bang (rule 11/12).
- [ ] **V-3 (W2 Textract gate):** every Textract submit site (intake PDF branch, `DocxToPdfJob` enqueue, T2 controller) re-checks `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, ...)` — defense in depth (hub hard-rule).
- [ ] **V-4 (W3 record committed before enqueue):** `auto_extract_job_criteria`'s `ai_job_criteria.new(...).save` (`:704`) commits its own transaction before `ExtractJobCriteriaJob.perform_later` (`:707/:709`); the after_commit placement guarantees the Job row is also committed. No new validation on `AiJobCriteria`.
- [ ] **V-5 (W3 skip_update_callback):** the new criteria after_commit callback runs irrespective of `skip_update_callback` (dedicated callback, not gated by `handle_after_update_commit:492`).
- [ ] **V-6 (W5 row write fires counter_culture):** the status-row failed write uses `.update` (not `update_columns`) so `jobs.ai_job_application_summaries_count` decrements when leaving `current/regenerating`. The summary-side write stays `update_columns` (rescue-path re-entrancy).
- [ ] **V-7 (W5 clear all denormalized cols):** `record_failure` sets `score_percentage`/`headline`/`integrated_role_analysis` to `nil` (pipeline #18). No `|| 0` / `|| ''` fallbacks (rule 10).
- [ ] **V-8 (W5 enum no migration):** `failed: 4` on the existing integer column; `db/schema.rb` not staged.
- [ ] **V-9 (W6 nil-safe):** `requested_by_organization_user_id` may be nil (auto) — passed through as-is, no fabricated fallback; `GenerateAiJobApplicationSummaryJob#perform` already defaults `requesting_organization_user_id: nil` and `broadcast_completion` no-ops on a nil/absent user.

---

# Test plan

**Harness:** `bundle exec rspec` works (test DB migrated). Run specs with `dangerouslyDisableSandbox: true` so they reach the local Postgres test DB (per grounding notes). Stub ALL external calls (AWS Textract `send_to_textract`, `ConvertApi`, OpenAI/Gemini clients) as existing specs do. Helpers in use: `create_credit_test_organization`, `create_credit_test_job`, `create_credit_test_job_application(job:)`. **Per pipeline #19:** `create_credit_test_job_application` triggers `enqueue_new_job_application` → `find_or_create_ai_job_application_summary_status`, so the status row already exists in tests; do not `create!` a second one (uniqueness constraint) — use the eager one or destroy it in "no row exists" contexts.

**Existing Cypress tests** covering these workflows are a source of truth and must NOT be modified. No new Cypress test is required by this feature (backend-pipeline + detail-card visibility; no new user-facing flow that existing Cypress doesn't cover). If the impl agent finds an affected Cypress spec, leave it read-only and note it.

## TP-1 — W1 (auto-gen pre-create)
- [ ] **TP-1.1** NEW `spec/interactors/create_auto_ai_summary_generation_spec.rb`: gates all pass → builds exactly one `AiJobApplicationSummary` with `status: 'textract_processing'`, `requested_by_organization_user_id: nil`, `textract_result_id: nil`, and **no job enqueued** (`expect(GenerateAiJobApplicationSummaryJob).not_to have_been_enqueued`; `expect(SubmitResumeToTextractJob).not_to have_been_enqueued`). Each of the four gates failing in isolation (flipper off / no resume / no credits / blank description) → **no summary built**. Reuse-guard: a non-failed, non-stale summary already present → no duplicate (returns the existing one).
- [ ] **TP-1.2** `spec/models/job_application_ai_summary_status_spec.rb` (the `enqueue_new_job_application` home): auto-gen ON + gates pass → a `textract_processing` summary exists after intake (was: zero); auto-gen OFF → no summary (only the `none` status row, as the existing test asserts).
- [ ] **TP-1.3** `spec/models/textract_result_ai_trigger_spec.rb`: auto-gen ON → summary created at entry; Textract SUCCESS → the summary advances to `succeeded`, the status row becomes `current`, and **exactly ONE credit is charged** (`expect { ... }.to change(AiCreditBalanceTransaction, :count).by(1)` — pin at the integration level; not 0, not 2 — `CreateAiCreditBalanceTransaction` has no per-summary idempotency guard, so the count must be pinned here). No `AI_SUMMARY_COMPLETE` toast (no requesting user).
- [ ] **TP-1.4 (C8 / incident regression):** auto-gen ON + Textract terminal FAILURE (drive `cleanup_orphaned_summary`) → exactly ONE summary persists as `failed` (was: zero summaries), the status row is `failed` with `ai_job_application_summary_id` pointing at it and cleared denormalized cols, and **ZERO credits charged** (`AiCreditBalanceTransaction.count` unchanged). Assert via `record_failure` (not destroy).
- [ ] **TP-1.5 (C7 cascade):** with an EARLIER failed `TextractResult` already present (docx race / Textract retry), on a later success the W1 summary (attached to the succeeder) is NOT cascade-destroyed and is the one that advances to `succeeded`; the earlier failed `TextractResult` (and any summary attached to IT) IS destroyed. (This is the case the spec explicitly requires.)

## TP-2 — W2 (docx→Textract chain)
- [ ] **TP-2.1** NEW `spec/jobs/docx_to_pdf_job_spec.rb`: stub `ConvertApi` and `send_to_textract`. After `perform` on a docx application: `SubmitResumeToTextractJob` enqueued when `TEXTRACT_RESUME_PROCESSING` is ON; NOT enqueued when OFF; enqueued even when `handle_possible_docx_resume` raises internally (conversion failure is rescued, does not propagate, Textract still attempted). For a PDF application: `SubmitResumeToTextractJob` NOT enqueued from `DocxToPdfJob` (the `resume_is_docx` guard).
- [ ] **TP-2.2** `spec/models/job_application_ai_summary_status_spec.rb`: docx resume at intake → `DocxToPdfJob` enqueued, `SubmitResumeToTextractJob` NOT enqueued at entry; PDF resume → both enqueued (as today). Update `spec/services/submit_resume_to_textract_spec.rb` only if it asserts the entry-time enqueue ordering that changed.
- [ ] **TP-2.3 (T2 controller)** Locate the existing job_applications controller/request spec (search `spec/requests` and `spec/controllers` for `job_applications`). Add: updating a job_application with a docx resume → `DocxToPdfJob` enqueued, `SubmitResumeToTextractJob` NOT enqueued directly; with a PDF resume → both. Stub external calls.

## TP-3 — W3 (criteria enqueue after commit)
- [ ] **TP-3.1 (DETERMINISTIC, not a ghost test):** `spec/models/job_criteria_lifecycle_spec.rb`. A bare `expect(ExtractJobCriteriaJob).to have_been_enqueued` passes for BOTH the buggy before_update and the fixed after_commit code (the test adapter enqueues regardless of transaction; single-threaded transactional tests have no real race). Instead spy on the enqueue and assert `previous_changes` is populated AT CALL TIME: `allow(ExtractJobCriteriaJob).to receive(:perform_later) { captured = job_record.previous_changes.dup }`, publish the job, then assert `captured` includes `'status'` (publish) / `'description'` (description-change). In before_update `previous_changes` is EMPTY (the delta is in `changes`) → assertion FAILS (proves the bug); in after_commit it holds `['draft','published']` / the old→new description → PASSES. Document in a comment that the actual concurrency race is not unit-testable single-threaded; the after-commit timing is additionally verified by structural placement in a dedicated `after_commit` callback (code review).
- [ ] **TP-3.2** Publishing a job creates exactly ONE `AiJobCriteria` and enqueues its `ExtractJobCriteriaJob` (regression for the single-criteria publish path).
- [ ] **TP-3.3 (description-change after commit):** editing a published job's description with a MEANINGFUL change → after commit, a new `AiJobCriteria` is created and `ExtractJobCriteriaJob` enqueued; an HTML-only/whitespace-only/case-only change → NOT enqueued (reuse the existing `description_meaningfully_changed?` fixtures at `job_criteria_lifecycle_spec.rb:104-145`, but driven through the real `save`/after_commit path, asserting the saved-change comparison works post-commit — this is the W3.2.2 trap regression).
- [ ] **TP-3.4 (skip_update_callback):** with `skip_update_callback` true (the `Settingsable` path), publishing/description-change still enqueues criteria extraction (proves the dedicated callback bypasses the `:492` guard).
- [ ] **TP-3.5 (has_many multi-row — the 5 pre-loaded specs lack this):** extraction after a FAILED criteria creates a NEW `AiJobCriteria` record (no overwrite); the pending poison-guard behavior is unchanged (a `pending` latest criteria blocks re-extraction); `latest_ai_job_criteria` vs `latest_succeeded_ai_job_criteria` select correctly with multiple rows. (Covers the multi-row has_many semantics that `ai_job_criteria_spec.rb` and the criteria specs do not.)

## TP-4 — W6 (carry requesting user)
- [ ] **TP-4.1** `spec/models/ai_job_criteria_spec.rb`: `resume_waiting_summaries` enqueues `GenerateAiJobApplicationSummaryJob` with the waiting summary's `requested_by_organization_user_id` — one case with a non-nil user, one with nil.
- [ ] **TP-4.2 (UPDATE the existing assertion):** the `'enqueues GenerateAiJobApplicationSummaryJob for each waiting summary'` test currently asserts `have_enqueued_job(GenerateAiJobApplicationSummaryJob).with(textract_result_id: textract_result.id)` (single-key). W6 adds `requesting_organization_user_id:`, so RSpec's exact-match `.with` BREAKS — update to `.with(textract_result_id: textract_result.id, requesting_organization_user_id: <expected, likely nil for that fixture>)`. The `'handles multiple waiting summaries'` test uses `.exactly(2).times` with no `.with` — unaffected.
- [ ] **TP-4.3** Per W6.1.2, grep `spec/` for any other `have_enqueued_job(GenerateAiJobApplicationSummaryJob).with(...)` missing the new param. **Verified second hit: `textract_result_ai_trigger_spec.rb:93` — this is on the auto/else-branch (no waiting summary, no resume) that W6/W1 do NOT change; it must STAY single-key and PASS unchanged. Do NOT edit it.** Only `ai_job_criteria_spec.rb:62` (TP-4.2) is updated. Re-grep after fixing to confirm no THIRD callsite.

## TP-5 — W4 (broadcasts + FE stepper)
- [ ] **TP-5.1** `spec/models/ai_job_application_summary_spec.rb`: the `BROADCAST_STATUSES.each` loop now covers `awaiting_job_criteria` + `retrying` (asserting they DO broadcast `ai_summary_status_change`) — after the move-off redesign (W4.4.2).
- [ ] **TP-5.2** DELETE the `%w[awaiting_job_criteria retrying]` "does not broadcast" block (W4.4.1).
- [ ] **TP-5.3** Add a test that `generate.rb`'s retrying path broadcasts (W4.4.4): driving the `CustomErrorAiSummary` rescue at `generate.rb:172-176` fires `ai_summary_status_change` for `retrying` (now that it is `.update` + in `BROADCAST_STATUSES`).
- [ ] **TP-5.4** Grep ripple per W4.4.3.
- [ ] **TP-5.5 (FE)** No RSpec for the FE; the union+step-map change is verified by TypeScript compile (the impl agent should run the FE typecheck/build as the project does). Confirm `STATUS_TO_STEP` keys exactly match the `PlatoGenerationStatus` union (no missing/extra key → no TS error).

## TP-6 — W5 (status-row failed + C1)
- [ ] **TP-6.1 (record_failure unit):** `spec/models/ai_job_application_summary_spec.rb` — a direct `record_failure('msg')` test: the summary → `failed` (via `update_columns`) with `error_message: 'msg'`; the status row → `failed` (via `.update`) with `ai_job_application_summary_id` pointing at the summary, cleared `score_percentage`/`headline`/`integrated_role_analysis`, and `jobs.ai_job_application_summaries_count` decremented when the row was `current`/`regenerating` before the call.
- [ ] **TP-6.2 (per-MECHANISM-CLASS integration — avoid ghost coverage):** at least one integration test per mechanism class proving the SITE routes through `record_failure` (not just the method in isolation): (a) one `update_columns` site — `generate.rb:180` or `generate_ai_job_application_summary_job.rb:19`; (b) one `.update` site — `score_job_application.rb:134` or `integrate_analysis.rb:64`; (c) the C8 `destroy`→`record_failure` site — `get_resume_text_from_textract_job.rb:19` (covered by TP-1.4). Each asserts the row reaches `failed` with cleared cols + counter decrement. Use the existing `spec/jobs/generate_ai_job_application_summary_job_spec.rb`, `spec/services/.../score_job_application_spec.rb`, `spec/services/.../integrate_analysis_spec.rb` homes.
- [ ] **TP-6.3 (C1 stale guard):** a STALE summary reaching `succeeded` does NOT overwrite the status row (the `return if stale?` at the top of `update_summary_status_record` fires; the row keeps its prior values, the stale summary's score is not copied).
- [ ] **TP-6.4** `spec/models/ai_job_application_summary_status_spec.rb`: the new `failed` enum value exists and behaves (`status_failed?`, not counted by counter_culture). Add to the existing enum coverage.

## TP-7 — full suite
- [ ] **TP-7.1** Run the affected specs together; then the broader AI-summary/criteria suite (`spec/models/ai_job_application_summary_spec.rb`, `spec/models/ai_job_criteria_spec.rb`, `spec/models/job_criteria_lifecycle_spec.rb`, `spec/models/textract_result_ai_trigger_spec.rb`, `spec/jobs/*`, `spec/services/ai_job_application_action/**`, `spec/interactors/*ai*`). All green before commit. Do NOT rewrite tests to pass (hard rule).

---

# Documentation impact

- [ ] No app-facing docs (README/help pages) are created or updated — this is internal pipeline behavior. The decisions (D1/D2/D3) and deferred items are already captured in `SPEC.md` / `FINDINGS.md` in the working directory; no source-repo doc change. If the impl agent finds an internal AI-pipeline doc/comment that describes the OLD auto-gen "no summary" or "criteria before commit" behavior, update the comment in place (do not write new doc files into the repo).

---

# Risks and open questions

- [ ] **FYI-1 (from SPEC-REVIEW-COMPLETE.md — already decided in-spec):** Bridge if-branch-else destroy (`textract_result.rb:134`) vs D1. When Textract SUCCEEDS but `ValidateAiSummaryGeneration` then fails (e.g. credits run out between intake and Textract completion), the auto summary is DESTROYED (existing manual behavior), NOT persisted as `failed`. This is a DIFFERENT path from C8 (Textract terminal failure) and is intentionally left as-is — the candidate correctly falls to the "noCredits"/"ready" empty state. **Do not "fix" it.** If Jessica later wants this edge to also persist-as-failed, it is a small follow-up (out of current scope).
- [ ] **FYI-2 (from SPEC-REVIEW-COMPLETE.md):** `CreateAiCreditBalanceTransaction` has no per-summary idempotency guard (pre-existing; identical for the manual path). The auto path's single-charge is protected only by `generate_ai_summary_with_credit_flow:68`'s early-return. The plan pins this at the integration-test level (TP-1.3 exactly-one-credit). If double-charges ever appear, the durable fix is a per-summary uniqueness guard on the transaction — but that is pre-existing scope, NOT introduced here.
- [ ] **R-3 (W3 option choice):** Option (b) (after_commit `saved_change_to_*`) is analog-matching and preferred, but carries the description-rewrite trap (W3.2.2). If the impl agent cannot cleanly reuse the sanitize transform on the saved-change pair, fall back to option (a) (instance flag captured in before_update). Document which option was chosen. Note the latent symbol-key bug in `handle_visible_change:538` (`previous_changes.key?(:visible)`) — do NOT replicate it; prefer `saved_change_to_*`.
- [ ] **R-4 (W3 `handle_description_change` shell):** removing the `auto_extract_job_criteria` call from `handle_description_change` may leave a guard-only method; confirm its only caller is `handle_before_update:480` before removing the method/call. Minimal change preferred.
- [ ] **R-5 (W1↔W5 sequencing):** `record_failure` (W5.2) must exist before W1.3 (C8) and W5.3 wiring. Because the plan order is W1→W2→W3→W6→W4→W5, implement `record_failure` early enough that the C8 change (W1.3) and its test (TP-1.4) can land — i.e. pull W5.1/W5.2 forward if doing W1's C8 first, or do the C8 wiring as part of the W5 step and mark W1.3 dependent. The impl agent should sequence so no checkbox references an undefined method at commit time.
- [ ] **R-6 (retrying step mapping is approximate):** `retrying` can occur at any pipeline stage; mapping it to a single `STATUS_TO_STEP` index (step 3) is imperfect — the stepper cannot know which stage retried. This matches the spec ("keep the last step"); no better option without per-stage retry metadata. Acceptable.
- [ ] **R-7 (uncommitted spec files):** the 16 already-modified spec files include several this plan edits. The impl agent must ADD to their current content, not overwrite. Verify with `git diff HEAD -- <spec>` before editing each.
- [ ] **R-8 (W6 — `textract_result_ai_trigger_spec.rb:93` must NOT be edited):** there are TWO single-key `.with(textract_result_id:)` enqueue assertions in `spec/`. Traced verification: `:93` exercises the bridge AUTO/ELSE branch (`textract_result.rb:137-143`, single-key, no requesting user), which W6 (changes only `ai_job_criteria.rb`) and W1 (gate `has_resume?` fails in that fixture → no pre-create, so no flip to the if-branch) both leave alone. **Only `ai_job_criteria_spec.rb:62` breaks and gets updated.** An impl agent that "fixes" `:93` to add `requesting_organization_user_id:` would BREAK a passing test (it would then expect a key the unchanged else-branch never sends). See W6.1.2 / TP-4.3.
- [ ] **OQ-1 (design — flag to reviewer/Jessica): PlatoOverviewCallout `failed` handling (W5.6.6).** The newly-discovered inline union at `PlatoOverviewCallout.tsx:13` needs `"failed"` added (or confirmation that a `failed` status-row value never reaches `summaryStatusValue`). `deriveCalloutStatus` falls through to `"ask"` ("Ask Plato to review this candidate") for unrecognized values. **Default chosen:** add `"failed"` to the inline union and let it fall through to `"ask"` (matches existing fall-through). If a failed state should suppress the callout (`return null`) or show a distinct "review failed" affordance instead, that is a design decision — surface to the reviewer. This ripple was NOT in the spec (the union is inlined, not the type-name) — a true Known Failure Pattern #6 site, added by this plan.

---

# Estimated scope

- **New files:** 3 (1 interactor `create_auto_ai_summary_generation.rb`, 2 spec files).
- **Modified app files:** ~12 (`job_application.rb`, `get_resume_text_from_textract_job.rb`, `docx_to_pdf_job.rb`, `job_applications_controller.rb`, `job.rb`, `ai_job_criteria.rb`, `ai_job_application_summary.rb`, `generate.rb`, `score_job_application.rb`, `integrate_analysis.rb`, `generate_ai_job_application_summary_job.rb`, `ai_job_application_summary_status.rb`).
- **Modified FE files:** 3 (`PlatoLoadingState.tsx`, `jobApplication.ts`, `PlatoOverviewCallout.tsx` — the last is the NEW inline-union ripple this plan adds vs the spec).
- **Modified/updated spec files:** ~10–12.
- **Migration:** 0 (Rails enum value on existing integer column).
- **Approx LOC:** ~120–180 app LOC (the new interactor ~45; `record_failure` ~18; W3 after_commit + helper ~25; the rest are small branch/site edits of 1–4 lines each), plus ~250–350 spec LOC.
