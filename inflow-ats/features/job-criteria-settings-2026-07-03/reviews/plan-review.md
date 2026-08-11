# Plan Review

**Source:** `plan.md` (this directory)
**Spec:** `SPEC.md` (this directory)
**Verdict: NEEDS-REVISION — corrections applied inline; Reviewed Plan below is implementation-ready**
**Reviewed:** 2026-07-03 (two fixed passes per plan-review-prompt.md; worktree re-verified clean at `05c9513ef` throughout)

## Pass 1 Summary

| Angle | Findings |
|---|---|
| zero-criteria-review-guard | 0 BLOCKER / 0 HIGH / 0 MED / 1 LOW (shared F3 citation drift) — entry-point table independently re-traced and confirmed complete |
| bulk-claim-row-and-queue-signature | **1 HIGH (F1)** — E.4.6 "replace :60" wording + a snippet beginning with the existing :59 line would, read literally, duplicate `ValidateAiSummaryGeneration.call` (side effects: double `SubmitResumeToTextractJob` enqueues). Amended inline |
| gating-job-signature-broadcast | 0 / 0 / 0 / 1 LOW — flag 4 (optional positional) verified MATCHED; analog citations all exact |
| api-surface | 0 findings — controller/serializer SPEC-verbatim; D-6 insertion point exact; policies verified record-safe |
| frontend-display-states | 0 / 0 / 0 / 1 LOW — SPEC 8.2 table implemented exactly; failed latest renders the empty state over an older succeeded card (flag 5); NO trace of the reverted display-fallback bullet; D-3/D-4 fact-checked true (Icon has no size prop; every poly token name exists in light AND dark themes; `t.poly.color.*` accessor real) |
| modals-frozen-props | 0 findings — mutation ownership inside the confirm modal; both behavioral props; frozen-prop staleness consciously accepted per SPEC 8.4 |
| websocket-copy-decided-out | 1 MED (F2) — F.4.1's bare-`guard` diff grep can false-positive on backend spec text; scope it to frontend files when executing. Copy sweep clean against all SPEC 10 rules; decided-OUT absences verified |
| cursor-rules-compliance | 1 MED (MED-2) — E.2.5 `reload` vs backend/_base.md §8: SPEC-verbatim, R-1-documented, human-gate-bound; deliberately NOT amended (amending would contradict SPEC §7 + REVIEW-ANGLES Angle 3) |

Pass 1 verdict: FAIL (1 HIGH, amended and verified). claude-md-compliance: no database-safety, branch, or authorization violations; no migrations at all.

## Pass 2 Summary

| Angle | Findings |
|---|---|
| zero-criteria-review-guard | 0 new — amendment side-effect citations verified against source |
| bulk-claim-row-and-queue-signature | 0 new — F1 amendment verified correct at plan.md:268-276; no stale wording; no new inconsistencies |
| gating-job-signature-broadcast | 0 new — flags 1/3/4 re-verified MATCHED in the amended plan |
| api-surface | 0 new — E.3-before-E.5 dependency, idempotent POST body, authz-split test feasibility re-verified |
| frontend-display-states | 0 new — Button `loading`/`disabled`/`styleType` and LoadingIndicator existence verified; "Criteria tiers" title verified in the decided design |
| modals-frozen-props | 0 new — `dismissModalWithAnimation(() => onCancel)` confirmed as the analog's exact idiom |
| websocket-copy-decided-out | 0 new — full-stack analog chain closes with no missing layer; `queryCache` identifier matches the handler |
| cursor-rules-compliance | 0 new — amendment introduces no rules regression |

Pass 2 verdict: PASS (0 BLOCKER, 0 HIGH). claude-md-compliance re-verified after amendment.

## Verdict

**NEEDS-REVISION** — one HIGH finding (F1, E.4.6 replace-instruction ambiguity producing a duplicated validator call under a literal reading) was corrected inline during Pass 1 and verified in Pass 2. All corrections are applied in the Reviewed Plan below (identical to the amended `plan.md`); the implementation agent uses the Reviewed Plan and can execute it as-is.

Standing non-blocking notes for the implementer and the human gate:
1. **[MED F2]** When executing F.4.1, scope the bare-`guard` absence grep to frontend files (`app/javascript`); keep `GuardTitle`/`GuardBody`/`GuardFoot` diff-wide. Backend spec text may legitimately contain the word "guard".
2. **[MED MED-2 / plan R-1]** E.2.5's SPEC-verbatim `ai_job_criteria.reload` conflicts with `cursor_rules/backend/_base.md` §8 (no `reload` in app/). Implement SPEC-verbatim as the plan directs; the Phase 6.5 conventions pass will flag it and Jessica rules (rule-compliant one-liner already recorded in R-1).
3. **[LOW F3]** ±1 line-citation drift at four spots (E.1.4 `latest_succeeded_ai_job_criteria` is :692-694; `auto_extract_job_criteria` :696-711; `extract_job_criteria` :713-724; the Styled-idiom cite on a 251-line file). All instructions are by method/name and unambiguous.

Fact-check base: every file:line citation load-bearing to an instruction was verified against the worktree at `05c9513ef`; all seven flag rulings verified MATCHED; the SPEC §6.1 entry-point table independently re-traced (grep set per REVIEW-ANGLES Angle 1) with zero unlisted creation paths; all 9 new-file targets verified absent and all 24 modified-file targets verified present; SPEC §12/§13 coverage complete with no dropped requirements.

## Reviewed Plan

The corrected plan follows verbatim (identical to the amended `plan.md` in this directory — either copy may be executed; they are the same text).

---

# Implementation Plan — Job criteria in Plato AI settings

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## A. Summary

Expose AI-extracted job criteria in the per-job Plato AI settings tab. Backend: new GET/POST singleton endpoint (`/api/v1/jobs/:job_id/ai_job_criteria`) with a dedicated Job serializer; the Jessica-approved `Job#extract_job_criteria_immediately` gating change plus a `requesting_organization_user_id:` kwarg; `ExtractJobCriteriaJob` gains an optional positional second arg and a `JOB_CRITERIA_EXTRACTION_COMPLETE` WebSocket completion broadcast at three sites; a zero-criteria review guard at four sites spanning all seven traced AI-summary entry points; and the `BulkGenerateAiSummariesJob` claim-row fix. Frontend: new `useAiJobCriteria` hook file, a Job criteria FormSection (extracted into `JobCriteriaSection.tsx`), three empty states, a criteria card with tier count rail, sidebar tier glossary, a FullModal read-only slide-over, a CenterModal regenerate confirm that owns its mutation, and a new WS handler case.

**Authority chain:** This plan implements `SPEC.md` (adversarially reviewed, 5 rounds, 2 clean passes) in this directory. `DECISIONS.md` wins over design files. Flags 1–7 are pre-adjudicated (ORCHESTRATION-LOG.md + SPEC-REVIEW-COMPLETE.md) — do not re-litigate. Design bundles (`design/bundle-1-decisions/`, `design/bundle-3-reference-tsx/`) supply structure/styles ONLY — their variable names, guard modals, tier hints (`TierHint`), `tier1/tier2/tier3` payload keys, and sync-response assumptions are all overridden.

**Repo/worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`, branch `job-criteria-settings` off `qa-refinements`, clean at `05c9513ef`. All file:line citations below verified against this worktree on 2026-07-03. All new-file targets verified ABSENT; all modified-file targets verified PRESENT.

**Open-PR conflict check (done):** `gh pr list --limit 20` — newest open PR is #3035 (`messaging-improvements`, 2026-06-05); its diff touches zero files in this feature's inventory (verified via `gh pr diff 3035 --name-only` grep). No conflicts. `qa-refinements` → develop is the expected base merge, not a conflict.

## B. Pattern precedents

Primary full-stack analog: **the manual single AI-summary generation flow** (user-triggered async AI work + fetchable status payload + backend WS completion toast). Where the analog differs from general convention, follow the ANALOG (REVIEW-ANGLES §2 priority rule).

| # | Pattern | Precedent (file:line) |
|---|---|---|
| P1 | Job-nested singleton route, explicit controller | `config/routes.rb:189` (`resource :ai_credits, only: [:show], controller: 'organization_ai_credit_balance'`); nesting block `config/routes.rb:224-267` |
| P2 | AI-scoring controller shape (`exists`+block, authorize-after-find, `render_one`, create-returns-resource, validator fail → `render_general_errors`) | `app/controllers/api/v1/ai_job_application_summaries_controller.rb:4-38`; helpers `app/controllers/application_controller.rb` (`render_general_errors` :40, `exists` :52-60, `render_one` :89) |
| P3 | Singleton show controller | `app/controllers/api/v1/organization_ai_credit_balance_controller.rb:3-10` |
| P4 | Serializer conventions (list jsonb raw §1, delegate computation to model §7) | `app/serializers/api/v1/organization_ai_credit_balance_serializer.rb`; `cursor_rules/backend/serializers.md` |
| P5 | Completion-broadcast job (requesting-user threading, 3 broadcast sites, terminal-status guard, auto path never broadcasts) | `app/jobs/generate_ai_job_application_summary_job.rb` (:13-22 exhaustion, :24 signature, :34 perform-end, :39-46 rescue, :50-80 helper) |
| P6 | Retry/failure-write shape already in the target job | `app/jobs/extract_job_criteria_job.rb:5-10` (exhaustion write), :19-28 (dual rescue) |
| P7 | WS handler case (toast + invalidations, `Number()` cast) | `WebsocketGlobalChannelHandler.tsx:216-234` (`AI_SUMMARY_COMPLETE`), :152-154 (`attachExternalResumeComplete` Number cast); imports :7 |
| P8 | Query+mutation hook file, array query keys, `enabled:` guard, hook-level invalidation | `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts:35-47`; `useBulkGenerateAiSummaries.ts:4-36` (inline interfaces) |
| P9 | Confirm modal OWNING its mutation (rule 22), loading+disabled both on primary (rule 11), `dismissModalWithAnimation(() => onCancel)`, error toast stays open | `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx:43, 150-173 (buttons), 90 (dismiss), 92-98 (error toast)` |
| P10 | CenterModal + statement box + description-link button | `app/javascript/ats/src/views/jobApplications/RunPlatoAddDescriptionModal.tsx:16-40, 63-83` (Statement styled with svg sizing), :32 (`/jobs/${jobId}/setup/description`) |
| P11 | FullModal custom header (omit `headerTitleText` → built-in header not rendered) | `app/javascript/ats/src/components/modals/FullModal.tsx:104-111` |
| P12 | Settings-view loading treatment + router-prop navigation | `app/javascript/ats/src/views/accountAdmin/OrganizationAiUsage.tsx:15-31` (`LoadingIndicator label="Loading..."`), :17-19 (`props.history.push`) |
| P13 | Sidebar aside register (sticky aside, h3, per-entry heading + bold-lead paragraph) | `app/javascript/ats/src/views/accountAdmin/AccountTeam.tsx:441-477` (JSX), :515-552 (styled) |
| P14 | openModal/removeModal wiring | `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageListItem.tsx:52-64` |
| P15 | Plato disc asset (gradient + inset ring built in) | `app/javascript/ats/src/components/shared/PlatoMark.tsx:60-66` (`PlatoChip`, `size`/`radius` props) |
| P16 | Relative time | `app/javascript/shared/lib/time.ts:89-91` (`distanceInWords`, adds "ago") |
| P17 | Controller spec harness (auth stubbing, credit-test helpers, ActiveJob test adapter) | `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb:5-49` |
| P18 | Serializer spec dir precedent | `spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb` |
| P19 | Validator interactor fail chain | `app/interactors/validate_ai_summary_generation.rb:24-29`; `validate_auto_ai_summary_generation.rb:13-18` |
| P20 | Claim-row `update_columns` sibling writes | `app/jobs/bulk_generate_ai_summaries_job.rb:54, 66, 86` |

## C. Files to create or modify (complete inventory — carries SPEC §13)

### New files (ALL verified absent in the worktree at `05c9513ef`)

| File | What | Task |
|---|---|---|
| `app/controllers/api/v1/ai_job_criteria_controller.rb` | GET show / POST create | E.5 |
| `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` | Criteria payload off Job | E.5 |
| `app/javascript/shared/queryHooks/useAiJobCriteria.ts` | `useAiJobCriteria` + `useRegenerateAiJobCriteria` | F.1 |
| `app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx` | Extracted Job criteria section (plan decision D-1: extraction IS happening — see §D) | F.2 |
| `app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx` | FullModal slide-over | F.3 |
| `app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx` | Confirm modal owning the mutation | F.3 |
| `spec/controllers/api/v1/ai_job_criteria_controller_spec.rb` | Controller coverage | E.5 |
| `spec/interactors/validate_ai_summary_generation_spec.rb` | Validator coverage incl. new guard (no dedicated spec exists today — verified) | E.4 |
| `spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb` | Serializer coverage | E.5 |

### Modified files (ALL verified present)

| File | Change | Task |
|---|---|---|
| `app/models/ai_job_criteria.rb` | Constants + `zero_criteria_failure?` | E.1 |
| `app/services/ai_job_application_action/scoring/extract_criteria.rb` | Constants at :62, :122 | E.1 |
| `app/services/ai_job_application_action/scoring/score_job_application.rb` | Constant at :43 | E.1 |
| `app/models/job.rb` | `zero_criteria_extraction_failure?` (E.1); gating change + kwarg (E.3) | E.1, E.3 |
| `app/jobs/extract_job_criteria_job.rb` | Signature + `broadcast_completion` at 3 sites | E.2 |
| `app/models/textract_result.rb` | Funnel guard in `generate_ai_summary_with_credit_flow` | E.4 |
| `app/interactors/validate_ai_summary_generation.rb` | Zero-criteria `fail!` | E.4 |
| `app/interactors/validate_auto_ai_summary_generation.rb` | Zero-criteria `fail!` | E.4 |
| `app/interactors/queue_bulk_ai_summary_jobs.rb` | Optional `job` input + `fail!` | E.4 |
| `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` | Pass `job: @job` in both actions | E.4 |
| `app/jobs/bulk_generate_ai_summaries_job.rb` | Claim-row `:failed` fix (flag 6) | E.4 |
| `config/routes.rb` | Nested singleton resource | E.5 |
| `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` | New payload interface + header comment | F.1 |
| `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` | `JOB_CRITERIA_EXTRACTION_COMPLETE` case | F.1 |
| `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` | Section mount, sidebar, no other changes | F.2 |
| `spec/models/ai_job_criteria_spec.rb` | `#zero_criteria_failure?` truth table | E.1 |
| `spec/models/job_criteria_lifecycle_spec.rb` | `_immediately` / `_if_needed` describes | E.3 |
| `spec/jobs/extract_job_criteria_job_spec.rb` | Broadcast coverage (behavioral) | E.2 |
| `spec/interactors/validate_auto_ai_summary_generation_spec.rb` | Zero-criteria contexts | E.4 |
| `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` | Zero-criteria context + job-less calls still pass | E.4 |
| `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb` | `hash_including(job:)` + 422 path | E.4 |
| `spec/models/textract_result_ai_trigger_spec.rb` | Funnel-guard context | E.4 |
| `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` | Validation-failure row `:failed` | E.4 |

**NOT touched, ever:** `internal_job_criteria` (anything), `AiJobCriteria#resume_waiting_summaries`, `Job#auto_extract_job_criteria`, `Job#extract_job_criteria`, `Orchestrate`, `ScoreJobApplication` guard placement, `CreateAiSummaryGeneration`, `CreateBulkAiSummaryGeneration`, `ModalContext.tsx`, `ToastContext.tsx`, `api.ts`, `Api::V1::JobSerializer`, existing Cypress specs, existing interfaces in `aiSummaryWebsocketPayloads.ts`, the existing Plato-reviews FormSection / dirty tracking / Save flow in `JobSetupAiSettings.tsx`.

## D. Plan-level pinned decisions (SPEC left these to the plan)

- **D-1 — Component extraction: YES.** `JobSetupAiSettings.tsx` is 83 lines; the section (intro + card + rail + 3 empty states + action row + state derivation + styled components ≈ 300+ lines) plus the sidebar (~90 lines) would cross the ~400 threshold (`cursor_rules/frontend/components/component_size_and_extraction.md`). Create `jobSetup/components/JobCriteriaSection.tsx` (dir exists, file verified absent). `JobCriteriaSection` owns `useAiJobCriteria`, `useModalContext`, display-state derivation, card/empty states/action row, and opens both modals. Sidebar glossary JSX + its styled components stay in `JobSetupAiSettings.tsx` (the `sidebar` prop must be built there anyway; keeping it there avoids an EXTRA file beyond the SPEC inventory). Result: `JobSetupAiSettings.tsx` ≈ 200 lines, `JobCriteriaSection.tsx` ≈ 300 lines.
- **D-2 — Action-row placement (SPEC 8.2, orchestrator mandate).** `EmptyState` accepts ONLY `title`/`message`/`icon`/`borderless`/`roomy` (`EmptyState.tsx:7-13`) — NO action/button prop. The action row is a section-level styled `div` rendered inside the FormSection, BELOW the `EmptyState` (states 2/3/5) or below the criteria card (state 4). Never pass buttons through `message`.
- **D-3 — Icon sizing.** The shared `Icon` component (`app/javascript/ats/src/components/shared/Icon/index.js`) takes ONLY `name` — no `size` prop (bundle-3's `size={16}`/`size={14}`/`size={13}` props would be silently ignored). Set icon dimensions via the wrapping styled component's CSS targeting `svg` (precedent: `RunPlatoAddDescriptionModal.tsx:75-81` `svg { width: 1rem; height: 1rem; }`). Where DECISIONS pins 2px stroke (tier icons, statement icons), add `stroke-width: 2px;` in the same svg selector. Do NOT edit the shared Icon component.
- **D-4 — Theme token map** (bundle-3 names → real tokens; poly tokens auto-switch for dark mode — prefer them; verified in `app/javascript/shared/styles/lightTheme.ts:4-34`):
  | bundle-3 | use |
  |---|---|
  | `theme.color.canvas` | `t.poly.color.canvas` (card: `t.poly.color.cardCanvas`) |
  | `theme.color.border` | `t.poly.color.border` (card: `t.poly.color.cardBorder`) |
  | `theme.color.textLoud` | `t.poly.color.loudText` |
  | `theme.color.textPrimary` | `t.poly.color.primaryText` |
  | `theme.color.textSecondary` | `t.poly.color.secondaryText` |
  | `theme.color.textPlaceholder` | `t.poly.color.placeholderText` |
  | `theme.color.hoverSubtle` | `t.poly.color.subtleHover` |
  | `theme.color.neutral100` (row divider) | `t.dark ? t.color.gray[700] : t.color.gray[100]` (no poly token at this weight; gray[100]/[700] exist in `theme.ts`) |
  | `theme.color.neutral900` (disc icon color) | not needed — `PlatoChip` carries its own colors; do not restyle it |
  Check `app/javascript/ats/styles/theme.ts:3-56` before using ANY other color (core rule 2). Emotion text utilities are complete declarations — `${t.text.sm};` standalone, never `font-size: ${t.text.sm};` (pipeline rule 1).
- **D-5 — `isInFlight` derivation.** `const isPayloadStatusInFlight = payload?.status === "pending" || payload?.status === "in_progress" || payload?.status === "retrying";` and `const isInFlight = isPayloadStatusInFlight || isFetching;` where `isFetching` comes from the `useAiJobCriteria` query. The `isFetching` OR covers the just-POSTed window (modal success → invalidation → refetch not yet landed) per SPEC 8.3. Documented cost: background refetches briefly show button loading — acceptable. Do NOT use local mutation state for this (DECISIONS: backend status must drive it; survives reload).
- **D-6 — Route insertion point.** Inside the `resources :jobs do` block, immediately after `resources :bulk_channel_messages, only: [:create]` (`config/routes.rb:265`).
- **D-7 — Sidebar copy leads.** DECISIONS wins over bundle-3 where they differ: bold leads are DECISIONS-verbatim ("Must-haves that count most toward a candidate's score." / "Nice-to-haves that count toward the score, less than core criteria." / "A small boost when a candidate has them."); the trailing descriptive sentences come from the decisions.html wording carried in bundle-3's aside (E.7 has the full strings). Copy iteration expected later — ship these drafts.

## E. Backend changes

**Read before ANY backend step:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/_base.md`, `cursor_rules/backend/core_critical_rules.md`. Per-step tags below add to these.

Global backend rules that will bite here: no begin blocks (core 1); bare guard returns (core 8); no bang methods outside spec/ (core 11); check save returns (core 12); single quotes unless interpolating; full-model-name variables — `ai_job_criteria`, `requesting_organization_user`, `job_application_bulk_job_status`, `new_ai_job_criteria` — never `row`/`record`/`latest`/`criteria_row`.

### - [ ] E.1 Zero-criteria vocabulary: constants, predicates, writer substitutions (+ specs)

*Tags: `cursor_rules/backend/code_style_and_structure.md`, `cursor_rules/backend/services.md` (constant substitutions ONLY — flag anything beyond one-line swaps), `cursor_rules/backend/architecture.md`.*

- [ ] E.1.1 `app/models/ai_job_criteria.rb` — add above the enum (public constants + one public method; keep `resume_waiting_summaries` and the trailing inflection comment byte-identical):
  ```ruby
  ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE = 'No criteria sections found in job description'
  ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE = 'No criteria extracted from job description'
  ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE = 'Criteria array is empty'

  ZERO_CRITERIA_ERROR_MESSAGES = [
    ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE,
    ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE,
    ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE
  ].freeze

  def zero_criteria_failure?
    status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)
  end
  ```
  The three strings must EXACTLY match the writer strings (verified): `extract_criteria.rb:62`, `:122`, `score_job_application.rb:43`. A typo silently breaks the guard.
- [ ] E.1.2 `app/services/ai_job_application_action/scoring/extract_criteria.rb` — line 62: replace `'No criteria sections found in job description'` with `AiJobCriteria::ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE`; line 122: replace `'No criteria extracted from job description'` with `AiJobCriteria::ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE`. One-line substitutions, zero behavior change, nothing else in the file.
- [ ] E.1.3 `app/services/ai_job_application_action/scoring/score_job_application.rb` — line 43: replace `'Criteria array is empty'` with `AiJobCriteria::ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE`. Same discipline.
- [ ] E.1.4 `app/models/job.rb` — add directly after `latest_succeeded_ai_job_criteria` (:691-693):
  ```ruby
  def zero_criteria_extraction_failure?
    latest_ai_job_criteria&.zero_criteria_failure?
  end
  ```
  Semantics (deliberate — reviewers must not "fix" to latest-terminal): reads the LATEST row, any status. A new pending/in-flight extraction makes it false so reviews start and wait via existing `awaiting_job_criteria` mechanics.
- [ ] E.1.5 Spec: `spec/models/ai_job_criteria_spec.rb` — add `describe '#zero_criteria_failure?'` truth table: each of the 3 messages × `failed` → true; same messages × non-failed statuses → false; `failed` × `'Job description is blank'` → false; `failed` × `"Failed to parse AI response: x"` → false; `failed` × nil `error_message` → false.
- [ ] E.1.6 Run `bundle exec rspec spec/models/ai_job_criteria_spec.rb` (plus a quick `spec/models/job_criteria_lifecycle_spec.rb` regression pass — untouched yet, must stay green).
- [ ] E.1.7 Commit: `Add zero-criteria failure vocabulary to AiJobCriteria and Job` (see §J commit rules).

### - [ ] E.2 `ExtractJobCriteriaJob`: optional positional arg + completion broadcast (+ spec)

*Tags: `cursor_rules/backend/background_jobs.md`, `cursor_rules/backend/_base.md` (rescue shapes).*

Analog: `generate_ai_job_application_summary_job.rb` — mirror structurally (pipeline rule 14). **Flag 4 is RESOLVED: optional POSITIONAL, not the analog's kwargs** (kwargs cutover breaks in-flight positional `[id]` Sidekiq payloads at deploy: ArgumentError at invocation bypasses rescues and `retry_on`, stranding rows in-flight). Do not re-litigate.

This lands BEFORE E.3 so the job accepts two args before any caller passes them (backward compatible: all four existing enqueue sites pass one arg, which binds `requesting_organization_user_id = nil`).

- [ ] E.2.1 Signature: `def perform(ai_job_criteria_id, requesting_organization_user_id = nil)`.
- [ ] E.2.2 End of perform (after the `.extract` call, before the rescues): `broadcast_completion(ai_job_criteria, requesting_organization_user_id) if requesting_organization_user_id`. (Unreachable mid-retry: `CustomErrorAiSummary` propagates past it, status is `retrying` — matches the analog.)
- [ ] E.2.3 `retry_on` exhaustion block (existing block :5-10): after the existing `update_columns(status: :failed, ...)` write, broadcast ONLY when the row exists — mirror the analog's `if textract_result` guard (:17-21). Read args positionally: `job.arguments.first` = id, `job.arguments.second` = requesting id (positional counterpart of the analog's `job.arguments.first[:key]` reads). Shape:
  ```ruby
  retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3 do |job, error|
    ap '[ExtractJobCriteriaJob] retries exhausted'
    ap error
    ai_job_criteria = AiJobCriteria.find_by(id: job.arguments.first)
    if ai_job_criteria
      ai_job_criteria.update_columns(status: :failed, error_message: error&.message)
      broadcast_completion(ai_job_criteria, job.arguments.second)
    end
  end
  ```
  (ActiveJob instance-execs this block, so the private helper is callable — the analog does exactly this at :20. Note the existing `ai_job_criteria&.update_columns` safe-nav becomes an `if ai_job_criteria` block — a nil row must never reach `broadcast_completion`.)
- [ ] E.2.4 StandardError rescue (existing :23-28): after the failure write, add `broadcast_completion(ai_job_criteria, requesting_organization_user_id) if ai_job_criteria && requesting_organization_user_id` (analog gates on both, :45). Keep the existing re-lookup `ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria_id)` and its failure write; convert `ai_job_criteria&.update_columns(...)` guard style only as needed so the broadcast can share the looked-up variable.
- [ ] E.2.5 New private helper — SPEC-verbatim (see Risk R-1 about the `reload` before changing ANYTHING here):
  ```ruby
  private

  def broadcast_completion(ai_job_criteria, requesting_organization_user_id)
    requesting_organization_user = OrganizationUser.find_by(id: requesting_organization_user_id)
    return unless requesting_organization_user

    user = requesting_organization_user.user
    return unless user

    ai_job_criteria.reload
    return unless ai_job_criteria.status_succeeded? || ai_job_criteria.status_failed?

    payload = {
      status: ai_job_criteria.status_succeeded? ? 'succeeded' : 'failed',
      jobId: ai_job_criteria.job_id,
      jobTitle: ai_job_criteria.job.title,
      zeroCriteriaFailure: ai_job_criteria.zero_criteria_failure?
    }
    payload[:errorMessage] = ai_job_criteria.error_message if ai_job_criteria.status_failed? && ai_job_criteria.error_message.present?

    GlobalChannel.broadcast_to(
      user,
      action: 'JOB_CRITERIA_EXTRACTION_COMPLETE',
      payload: payload
    )
  end
  ```
  Payload keys are camelCase written directly in Ruby — the socket path has NO api.ts transform (analog precedent: `candidateFullName`). Broadcast fires on failure too — flag 3, APPROVED; do not narrow to success-only. Auto-path (nil requesting id) NEVER broadcasts.
- [ ] E.2.6 Spec: `spec/jobs/extract_job_criteria_job_spec.rb` — keep every existing example untouched (they call `perform_now(id)` positionally and must still pass — that IS the backward-compat assertion). Add behavioral broadcast coverage (pipeline rule 26 — outcomes, never reflection):
  - [ ] E.2.6.1 With a requesting organization user + `ExtractCriteria` stub that sets the row `succeeded`: expect `GlobalChannel` to receive `broadcast_to` with the user and `hash_including(action: 'JOB_CRITERIA_EXTRACTION_COMPLETE', payload: hash_including(status: 'succeeded'))`.
  - [ ] E.2.6.2 Zero-criteria failure (stub sets `failed` + `AiJobCriteria::ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE`): payload includes `zeroCriteriaFailure: true` and `errorMessage`.
  - [ ] E.2.6.3 StandardError raised by the service: failure write + failed broadcast (when requesting user present).
  - [ ] E.2.6.4 `CustomErrorAiSummary`: job re-enqueued (`have_enqueued_job(described_class)`) and NO broadcast (`expect(GlobalChannel).not_to receive(:broadcast_to)`).
  - [ ] E.2.6.5 No requesting user (single positional arg): no broadcast on any outcome.
- [ ] E.2.7 Run `bundle exec rspec spec/jobs/extract_job_criteria_job_spec.rb`.
- [ ] E.2.8 Commit: `Add completion broadcast and optional requesting user to ExtractJobCriteriaJob`.

### - [ ] E.3 `Job` gating change (SPEC 4.1 — explicit early task; worktree does NOT have it) (+ spec)

*Tags: `cursor_rules/backend/code_style_and_structure.md`, `cursor_rules/backend/architecture.md`.*

- [ ] E.3.1 `app/models/job.rb:726-743` — replace the two methods EXACTLY with (DECISIONS-verbatim except the approved kwarg, flag 1):
  ```ruby
  def extract_job_criteria_immediately(requesting_organization_user_id: nil)
    return unless description.present?
    return if latest_ai_job_criteria&.status_in_progress?
    return if latest_ai_job_criteria&.status_retrying?

    new_ai_job_criteria = ai_job_criteria.new(status: :pending)
    return unless new_ai_job_criteria.save

    ExtractJobCriteriaJob.perform_later(new_ai_job_criteria.id, requesting_organization_user_id)
  end

  def extract_job_criteria_if_needed
    return if latest_ai_job_criteria&.status_succeeded?

    extract_job_criteria_immediately
  end
  ```
  Keep the existing comments above `extract_job_criteria_if_needed` / `handle_criteria_extraction_after_commit` intact. DO NOT touch `auto_extract_job_criteria` (:695-710) or `extract_job_criteria` (:712-724) — their `status_pending?` guard + Flipper gate deliberately differ; do not harmonize in either direction. Documented consequence (per DECISIONS, do not "fix"): `_immediately` does NOT guard `pending` — two rapid POSTs can create two pending rows; harmless, latest row wins.
  Verified callers: `_immediately` is called only by `_if_needed` (job.rb:742); `_if_needed` only by `textract_result.rb:70`. No spec file references either method today (grepped `spec/` — zero hits), so nothing existing breaks.
- [ ] E.3.2 Spec: `spec/models/job_criteria_lifecycle_spec.rb` — add (reuse the file's `create_credit_test_organization`/`create_credit_test_job` harness and ActiveJob test-adapter around block, :5-20):
  - [ ] E.3.2.1 `describe 'Job#extract_job_criteria_immediately'`: blank description → no row, no enqueue; latest `in_progress` → no row; latest `retrying` → no row; latest `pending` → row IS created (documents the deliberate absence of a pending guard); enqueues `ExtractJobCriteriaJob` with `[new_ai_job_criteria.id, requesting_organization_user_id]` when the kwarg is passed; enqueues with `[id, nil]` by default.
  - [ ] E.3.2.2 `describe 'Job#extract_job_criteria_if_needed'`: latest `succeeded` → no-op; latest `failed` → delegates (row created); no rows at all → delegates.
  - [ ] E.3.2.3 Existing `Job#extract_job_criteria` examples untouched.
- [ ] E.3.3 Run `bundle exec rspec spec/models/job_criteria_lifecycle_spec.rb spec/models/textract_result_ai_trigger_spec.rb` (the latter exercises the `_if_needed` caller path — must stay green).
- [ ] E.3.4 Commit: `Move extraction guards into Job#extract_job_criteria_immediately and thread requesting user`.

### - [ ] E.4 Zero-criteria review guard (4 sites) + bulk claim-row fix (+ specs)

*Tags: `cursor_rules/backend/interactors/interactor_patterns_and_structure.md`, `cursor_rules/backend/interactors/interactor_usage_and_guidelines.md`, `cursor_rules/backend/background_jobs.md`, `cursor_rules/backend/controllers/controller_patterns_and_crud.md`.*

Guard condition everywhere: `zero_criteria_extraction_failure?` (E.1.4). Guard message (identical at sites 1 and 3): `'No scoring criteria were found in the job description. Regenerate job criteria in Plato AI settings before running reviews.'` Do NOT add guards in `Orchestrate`, `ScoreJobApplication`, `CreateAiSummaryGeneration`, or `CreateBulkAiSummaryGeneration` (scope creep — rule 10).

- [ ] E.4.1 `app/interactors/validate_ai_summary_generation.rb` — add after the `has_job_description?` fail (:29):
  ```ruby
  context.fail!(error: 'No scoring criteria were found in the job description. Regenerate job criteria in Plato AI settings before running reviews.') if @job_application.job&.zero_criteria_extraction_failure?
  ```
  Covers entry points 1 (manual single → synchronous 422 → existing frontend toast), 2 (bulk per-record backstop), 5 (textract completion, both branches — existing `AI_SUMMARY_FAILED` mechanism carries the message on the manual-waiting branch).
- [ ] E.4.2 `app/interactors/validate_auto_ai_summary_generation.rb` — same `fail!` line after :18 (`has_job_description?` fail), with `@job_application.job&.zero_criteria_extraction_failure?`. Covers entry points 3/4 (auto path declines silently, matching its existing credit/description declines).
- [ ] E.4.3 `app/interactors/queue_bulk_ai_summary_jobs.rb` — add after the credits fail (:18):
  ```ruby
  context.fail!(error: 'No scoring criteria were found in the job description. Regenerate job criteria in Plato AI settings before running reviews.') if context.job&.zero_criteria_extraction_failure?
  ```
  Optional input via safe navigation (flag 7, APPROVED) — existing callers without `job:` unaffected. Gives bulk users a synchronous error toast instead of an all-failed completion toast.
- [ ] E.4.4 `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` — pass `job: @job` into `QueueBulkAiSummaryJobs.call` in BOTH `create` (:13-17) and `all_stages` (:37-43). `@job` already exists at :9/:33. No other controller changes.
- [ ] E.4.5 `app/models/textract_result.rb` — defensive guard at the shared funnel `generate_ai_summary_with_credit_flow`: insert after the succeeded-summary early return (:68) and BEFORE `extract_job_criteria_if_needed` (:70):
  ```ruby
  return if job_application.job.zero_criteria_extraction_failure?
  ```
  Ordering is load-bearing: before `extract_job_criteria_if_needed` so a blocked review does not silently re-trigger extraction on an unchanged description. Bare return (core rule 8). Accepted race consequence documented in SPEC 6.4 — do NOT add a state transition for stranded summaries (rule 20; open question 3 for Jessica).
- [ ] E.4.6 `app/jobs/bulk_generate_ai_summaries_job.rb` — claim-row fix (flag 6, APPROVED as reviewed scope; MINIMAL — nothing else in this file changes): replace the two lines :59-60 (`result = ValidateAiSummaryGeneration.call(job_application: job_application, organization: organization)` + `return unless result.success?`) so the FINAL state of that region is:
  ```ruby
  result = ValidateAiSummaryGeneration.call(job_application: job_application, organization: organization)
  unless result.success?
    job_application_bulk_job_status.update_columns(status: :failed)
    return
  end
  ```
  The snippet's first line IS the existing :59 line — exactly ONE `ValidateAiSummaryGeneration.call` must remain in `each_iteration` (a second call would double-enqueue `SubmitResumeToTextractJob` via the validator's side effects, validate_ai_summary_generation.rb:39/:55). `update_columns` matches the sibling row-writes (:54, :66, :86); not inside a transaction (pipeline rule 25). `on_complete` counting stays correct (`failed = size - done - deferred`, :111); an all-failed batch still fires `notify_failure` (:117-119).
- [ ] E.4.7 Specs:
  - [ ] E.4.7.1 NEW `spec/interactors/validate_ai_summary_generation_spec.rb` (verified absent; model on `spec/interactors/validate_auto_ai_summary_generation_spec.rb` + the credit-test helpers): happy path succeeds; fails with the exact guard message when the job's latest `AiJobCriteria` is `failed` with EACH of the three `ZERO_CRITERIA_ERROR_MESSAGES`; does NOT fail when latest is `failed` with `'Job description is blank'`; does NOT fail when latest is `pending`; does NOT fail when an in-flight row sits on top of a zero-criteria row (create zero-criteria failed row, then a newer `pending` row).
  - [ ] E.4.7.2 `spec/interactors/validate_auto_ai_summary_generation_spec.rb` — mirror zero-criteria contexts (fails on zero-criteria latest; passes on in-flight-over-zero).
  - [ ] E.4.7.3 `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` — new context: call with `job:` whose latest row is a zero-criteria failure → `result.failure?` with the message, nothing enqueued, no `BulkAiSummaryJobApplication` rows created. Plus an explicit example that calls WITHOUT `job:` and still succeeds (existing examples already do this implicitly — add the assertion so the optionality is load-bearing coverage).
  - [ ] E.4.7.4 `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb` — update the `hash_including` interactor expectation (:72-77) to include `job: kind_of(Job)` for `all_stages`; add the equivalent assertion for `create`; add a 422 example per action for a zero-criteria job (response body carries the guard message).
  - [ ] E.4.7.5 `spec/models/textract_result_ai_trigger_spec.rb` — new context: `generate_ai_summary_with_credit_flow` on a zero-criteria job returns before `AiJobApplicationAction::Orchestrate` is invoked AND before `extract_job_criteria_if_needed` (e.g., `expect(job_record).not_to receive(:extract_job_criteria_if_needed)` + no summary status change / no orchestrate double touched).
  - [ ] E.4.7.6 `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` — validation-failure iteration marks the claim row `:failed` (not left `:processing`); zero-criteria job batch → all claim rows `:failed` and the completion notification still fires (`AI_SUMMARY_BULK_FAILED` path).
- [ ] E.4.8 Run: `bundle exec rspec spec/interactors/validate_ai_summary_generation_spec.rb spec/interactors/validate_auto_ai_summary_generation_spec.rb spec/interactors/queue_bulk_ai_summary_jobs_spec.rb spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb spec/models/textract_result_ai_trigger_spec.rb spec/jobs/bulk_generate_ai_summaries_job_spec.rb`.
- [ ] E.4.9 Commit: `Block new AI summary reviews when the latest criteria extraction found zero criteria`.

### - [ ] E.5 API surface: route, controller, serializer (+ specs)

*Tags: `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `cursor_rules/backend/controllers/controller_error_handling.md`, `cursor_rules/backend/controllers/pundit_policies.md`, `cursor_rules/backend/serializers.md`.*

- [ ] E.5.1 `config/routes.rb` — inside `resources :jobs do` (:224), after `resources :bulk_channel_messages, only: [:create]` (:265) per D-6:
  ```ruby
  resource :ai_job_criteria, only: [:show, :create], controller: 'ai_job_criteria'
  ```
  Singleton `resource` + explicit `controller:` per the `ai_credits` precedent (routes.rb:189); sidesteps the criteria/criterium inflection (documented `ai_job_criteria.rb:33-37`). Generates `GET/POST /api/v1/jobs/:job_id/ai_job_criteria`.
- [ ] E.5.2 NEW `app/controllers/api/v1/ai_job_criteria_controller.rb` — SPEC-verbatim:
  ```ruby
  # frozen_string_literal: true

  class Api::V1::AiJobCriteriaController < Api::V1::BaseController
    def show
      exists(current_organization.jobs.where(id: params[:job_id]), 'no job found') do |job|
        authorize job, :show?
        render_one(job, Api::V1::JobAiJobCriteriaSerializer)
      end
    end

    def create
      exists(current_organization.jobs.where(id: params[:job_id]), 'no job found') do |job|
        authorize job, :update_ai_settings?

        unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, current_organization)
          render_general_errors(['AI summaries are not enabled for this organization.'])
          return
        end

        if job.description.blank?
          render_general_errors(['This job needs a description before Plato can extract criteria. Add one in Job setup.'])
          return
        end

        job.extract_job_criteria_immediately(requesting_organization_user_id: current_organization_user.id)
        render_one(job, Api::V1::JobAiJobCriteriaSerializer)
      end
    end
  end
  ```
  Conventions in force: no begin blocks; zero params methods (no body params — compliant with core rule 5); authorize AFTER find with explicit policy queries; NO new policy methods (`JobPolicy#show?` job_policy.rb:12-14; `#update_ai_settings?` :24-26 → `AiJobApplicationSummaryPolicy#can_use_ai_credits?` — verified these never read `record`, safe for a Job); Flipper gate on POST ONLY (GET deliberately ungated, like `GET /ai_credits`); NO job-status checks anywhere (DECISIONS: regenerate in ANY job state); POST-while-in-flight no-ops via the model guards and returns the current payload (idempotent). `current_organization_user` verified on `Api::V1::BaseController:27-29`.
- [ ] E.5.3 NEW `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` — SPEC-verbatim (serializes the JOB; differently-named-Job-serializer family precedent):
  ```ruby
  # frozen_string_literal: true

  class Api::V1::JobAiJobCriteriaSerializer < ActiveModel::Serializer
    attributes :criteria, :extracted_at, :status, :zero_criteria_failure

    def criteria
      object.latest_succeeded_ai_job_criteria&.criteria
    end

    def extracted_at
      object.latest_succeeded_ai_job_criteria&.updated_at
    end

    def status
      object.latest_ai_job_criteria&.status
    end

    def zero_criteria_failure
      object.zero_criteria_extraction_failure?
    end
  end
  ```
  No `|| false` on `zero_criteria_failure` (core rule 10 / pipeline rule 13 — nil/true/false via safe navigation is the contract). Raw jsonb pass-through (serializers.md §1); computation delegated to Job model methods (§7). Do NOT add criteria fields to `Api::V1::JobSerializer` — the dedicated-endpoint deviation from the summaries analog is spec-adjudicated (SPEC 5.1).
  The six-state payload contract (frontend receives camelCased KEYS via api.ts; `status`/`tier` VALUES stay snake_case — Ruby enum exception, core rule 7):
  | State | criteria | extractedAt | status | zeroCriteriaFailure |
  |---|---|---|---|---|
  | Never ran | null | null | null | null |
  | First extraction running | null | null | "pending"/"in_progress"/"retrying" | false |
  | Succeeded | [...] | ts | "succeeded" | false |
  | Regenerating after success | [...] (old) | ts (old) | "pending"/"in_progress"/"retrying" | false |
  | Zero-criteria failure | null or [...] (older succeeded) | null or ts | "failed" | true |
  | Other failure | null or [...] (older succeeded) | null or ts | "failed" | false |
- [ ] E.5.4 Specs:
  - [ ] E.5.4.1 NEW `spec/controllers/api/v1/ai_job_criteria_controller_spec.rb` — harness copied from `bulk_ai_job_application_summaries_controller_spec.rb:5-37` (credit-test org/user/job helpers, Flipper enable, auth stubbing, ActiveJob test adapter around block).
    `#show`: payload for each of the six states above (never ran → all null; first-run in-flight; succeeded → criteria + extracted_at + status; in-flight over old success → old criteria + in-flight status; zero-criteria failed → `zero_criteria_failure` true; other failed → false).
    `#create`: creates a pending `AiJobCriteria` row and enqueues `ExtractJobCriteriaJob` with `[row.id, current_organization_user.id]`; blank description → 422 with the exact message and NO row created; Flipper disabled → 422 with the exact message, no row; latest row `in_progress`/`retrying` → 200, no new row (no-op guard), body reflects in-flight status; works on draft AND published jobs; authorization split — hiring-team member without AI-credits control: `show` allowed, `create` rejected.
  - [ ] E.5.4.2 NEW `spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb` (dir precedent P18): mixed-state derivation — latest `failed` zero-criteria row over an older `succeeded` row → `criteria`/`extracted_at` from the succeeded row, `status` `'failed'`, `zero_criteria_failure` true. Plus the never-ran all-nil case.
- [ ] E.5.5 Run `bundle exec rspec spec/controllers/api/v1/ai_job_criteria_controller_spec.rb spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb`.
- [ ] E.5.6 Commit: `Add job AI criteria endpoint and serializer`.

## F. Frontend changes

**Read before ANY frontend step:** `cursor_rules/core_critical_rules.md`, `cursor_rules/frontend/core_critical_rules.md`, `cursor_rules/frontend/_base.md`. Per-step tags add to these.

Global frontend rules in force: no `??` (frontend/_base.md §1); no fabricated fallbacks — `criteria || []`, `|| 0`, `|| ""` prohibited, use explicit conditionals (core 10 / pipeline 13); never set `undefined` deliberately; double quotes; separate styled components per visual variant, no boolean variant props forwarded to DOM (pipeline 12); Emotion text utilities standalone (pipeline 1); theme colors only from theme (D-4); keys camelCase, enum VALUES snake_case (`"in_progress"`, `"tier_1"`).

### - [ ] F.1 Data layer: hook file, WS payload type, WS handler case

*Tags: `cursor_rules/frontend/react_query/react_query_queries.md`, `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`, `cursor_rules/frontend/react_hooks.md`.*

- [ ] F.1.1 NEW `app/javascript/shared/queryHooks/useAiJobCriteria.ts` — SPEC-verbatim (interfaces inline per `useBulkGenerateAiSummaries.ts:4-16`; query key array form per `["aiJobApplicationSummary", id]`):
  ```ts
  import { useMutation, useQuery, useQueryClient } from "react-query";
  import { apiGet, apiPost } from "./api";

  export interface AiJobCriterion {
    text: string;
    tier: "tier_1" | "tier_2" | "tier_3";
    sourceHeading?: string | null;
  }

  export interface AiJobCriteriaPayload {
    criteria: AiJobCriterion[] | null;
    extractedAt: string | null;
    status: "pending" | "in_progress" | "succeeded" | "failed" | "retrying" | null;
    zeroCriteriaFailure: boolean | null;
  }

  const getAiJobCriteria = async (jobId: number) => {
    return await apiGet({ path: `/jobs/${jobId}/ai_job_criteria` });
  };

  export function useAiJobCriteria({ jobId }: { jobId: number }) {
    return useQuery<AiJobCriteriaPayload>(["aiJobCriteria", jobId], () => getAiJobCriteria(jobId), {
      enabled: jobId != undefined,
    });
  }

  const regenerateAiJobCriteria = async ({ jobId }: { jobId: number }) => {
    return await apiPost({ path: `/jobs/${jobId}/ai_job_criteria`, variables: {} });
  };

  export function useRegenerateAiJobCriteria() {
    const queryClient = useQueryClient();
    return useMutation(regenerateAiJobCriteria, {
      onSuccess: (data, variables) => {
        queryClient.invalidateQueries(["aiJobCriteria", variables.jobId]);
      },
    });
  }
  ```
  Numeric `job.id` in paths (job-nested hook precedent). Hook-level invalidation only — call sites add their own callbacks per react_query_mutations_and_cache.md.
- [ ] F.1.2 `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` — append (existing interfaces untouched):
  ```ts
  export interface JobCriteriaExtractionCompletePayload {
    status: "succeeded" | "failed";
    jobId: number;
    jobTitle: string;
    zeroCriteriaFailure: boolean;
    errorMessage?: string;
  }
  ```
  Update the file header comment (lines 1-2) to say "AI WebSocket broadcasts" instead of "AI summary WebSocket broadcasts".
- [ ] F.1.3 `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` — add `JobCriteriaExtractionCompletePayload` to the type import (:7). Add a new case after the `AI_SUMMARY_FAILED` block (its closing brace is at :248):
  ```tsx
  case "JOB_CRITERIA_EXTRACTION_COMPLETE": {
    const payload = data.payload as JobCriteriaExtractionCompletePayload;
    if (payload.status === "succeeded") {
      addToast({ title: `Job criteria generated for ${payload.jobTitle}`, kind: "success", delay: 10000 });
    } else if (payload.zeroCriteriaFailure) {
      addToast({ title: `No criteria found in the job description for ${payload.jobTitle}`, kind: "warning", delay: 10000 });
    } else {
      addToast({ title: `Could not generate job criteria for ${payload.jobTitle}`, kind: "warning", delay: 10000 });
    }
    queryCache.invalidateQueries(["aiJobCriteria", Number(payload.jobId)]);
    break;
  }
  ```
  Invalidation key MUST exactly match the hook's key shape `["aiJobCriteria", <number>]` — `Number()` cast per the `attachExternalResumeComplete` precedent (:153). Toast copy is drafted per binding copy rules; iteration expected — do not improvise different strings.
- [ ] F.1.4 Commit: `Add useAiJobCriteria hook and job criteria extraction WebSocket handling` (frontend has no test infra — documented; pre-commit runs whatever the repo runs; backend suite unaffected).

### - [ ] F.2 Job criteria section + sidebar: `JobCriteriaSection.tsx` (new) + `JobSetupAiSettings.tsx` (modified)

*Tags: `cursor_rules/frontend/components/component_architecture.md`, `cursor_rules/frontend/components/component_size_and_extraction.md`, `cursor_rules/frontend/ui_styling.md`, `cursor_rules/frontend/contexts/context_usage_and_rules.md`, `cursor_rules/frontend/contexts/context_reference.md`, `cursor_rules/frontend/boolean_variables_and_naming.md`.*

- [ ] F.2.1 NEW `app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx` (D-1). Props: `{ job: any; history: any }` (pragmatic TS per frontend/_base.md §4). Structure — take layout/styles from bundle-3 `JobSetupAiSettings.tsx` styled components (SectionIntro/CriteriaCard/CountRail/ActionRow) with D-4 token mapping; discard bundle variable names and everything decided OUT:
  - [ ] F.2.1.1 Hooks: `useAiJobCriteria({ jobId: job.id })` (destructure `data`, `isLoading`, `isFetching`), `useModalContext()` (`openModal`, `removeModal`).
  - [ ] F.2.1.2 Module-level tier constant (stored `tier_1`-form values — NOT the bundle's `tier1` keys):
    ```tsx
    const TIERS = [
      { key: "tier_1", label: "Core", icon: "check-circle" },
      { key: "tier_2", label: "Preferred", icon: "plus-circle" },
      { key: "tier_3", label: "Bonus", icon: "star" },
    ];
    ```
    Counts computed by filtering `criteria` on `tier` — only inside the state-4 card where `criteria` is known present (no `|| []`).
  - [ ] F.2.1.3 Display-state derivation — the payload is the single source of truth (SPEC 8.2, priority order exact; flag 5 APPROVED: failed latest hides an older succeeded card — implement, don't "improve"):
    | Priority | Condition | Rendering |
    |---|---|---|
    | 0 | query `isLoading` | `<LoadingIndicator label="Loading..." />` inside the FormSection (P12) |
    | 1 | `status` in pending/in_progress/retrying | Underlying content (state-4 card if `criteria` present, else state-5 EmptyState) with the Generate/Regenerate button in `loading` |
    | 2 | `status === "failed" && zeroCriteriaFailure` | EmptyState `icon="alert-triangle"`, title `"No criteria found"`, message `"No scoring criteria were found in the job description. Plato won't review candidates until it has criteria to score against."`; action row: Regenerate only, no View |
    | 3 | `status === "failed"` (other) | EmptyState `icon="alert-triangle"`, title `"Criteria generation failed"`, message `"Something went wrong while extracting criteria from the job description. Regenerate to try again."`; action row: Regenerate only, no View |
    | 4 | `criteria` present | Criteria card + count rail; action row: View + Regenerate |
    | 5 | `status === null` | EmptyState `icon="file-text"`, title `"No job criteria have been generated"`, message `"Plato extracts scoring criteria when you publish the job, or you can generate them now."`; action row: Generate only, no View |
    All three EmptyStates standard variant — no `roomy`, no `borderless`. Button label `Generate criteria` only in state 5 (and state 1 layered over 5); otherwise `Regenerate criteria`. `isInFlight` per D-5.
  - [ ] F.2.1.4 FormSection: `<FormSection title="Job criteria" intro={...}>` — use the `intro` prop (takes an element, `FormSection/index.js:11,36,47`). Intro copy (drafted; explains the automatic lifecycle per DECISIONS; "job description" is an inline link → `props.history.push(`/jobs/${job.id}/setup/description`)` — route form verified P10):
    > Plato extracts scoring criteria from your job description when you publish the job, and extracts them again when you update the description while the job is published. Each review scores a candidate against the criteria as they stand when it runs. To change them, edit your [job description].
  - [ ] F.2.1.5 Criteria card (state 4): flex card, max-width 560px, radius 7px; left cell — `<PlatoChip size={36} radius={18} />` (P15 — gradient + inset ring built in, do NOT re-style) + title "Job criteria" (15px/600) + description `Plato extracted these from your job description {distanceInWords(payload.extractedAt)}.` (12.5px/1.3, tabular figures; `distanceInWords` adds "ago", P16); right cell — count rail (186px, left border): Core `check-circle` / Preferred `plus-circle` / Bonus `star` rows, count right-aligned 450 weight tabular; Bonus row rendered ONLY when bonus count > 0. Icon sizing via wrapper CSS per D-3 (svg 14px, stroke-width 2px).
  - [ ] F.2.1.6 Action row (D-2): section-level styled div below the card/EmptyState. `View criteria` — `Button styleType="secondary"`, rendered ONLY in state 4, `onClick` → `openModal(<JobCriteriaViewModal criteria={payload.criteria} onCancel={removeModal} />)`. `Generate criteria`/`Regenerate criteria` — `Button styleType="secondary"`, `loading={isInFlight}`, `onClick` → `openModal(<RegenerateJobCriteriaConfirmModal jobId={job.id} onCancel={removeModal} />)` (P14 wiring).
  - [ ] F.2.1.7 Styled components: one per visual variant (pipeline 12) — e.g., `Styled.SectionIntro`, `Styled.CriteriaCard`, `Styled.CountRail`, `Styled.ActionRow`; no `isKey`-style boolean variant props. Emotion `label:` convention per neighboring files. Codebase styled-component idiom: `let Styled: any; Styled = {};` block after the default export (see `BulkGenerateAiSummariesConfirmModal.tsx:198-252`).
- [ ] F.2.2 `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` — keep EVERYTHING existing byte-preserved (imports, dirty tracking, `onSubmit`, BottomBarContent, Plato reviews FormSection — :15-80). Add:
  - [ ] F.2.2.1 Render `<JobCriteriaSection job={passedJob} history={props.history} />` below the Plato reviews FormSection (`props.history` is available — the container spreads route props, `JobSetupContainer.tsx:487`).
  - [ ] F.2.2.2 Sidebar tier glossary passed via `SettingsContainer`'s `sidebar` prop (`SettingsContainer.tsx:10,72`), Team-roles register (P13 — sticky aside, h3, per-entry heading + paragraph with bold lead, no dividers). Entry headings carry the tier icon (svg 13px via wrapper CSS, D-3). Copy (D-7; "Criteria tiers" title; leads DECISIONS-verbatim in bold):
    - Intro: "Plato extracts scoring criteria from the job description and sorts them into tiers. Section titles decide the tier; words inside an item can also signal it, but the title always wins."
    - Core (`check-circle`): **"Must-haves that count most toward a candidate's score."** "Plato takes them from sections titled Requirements or Must-haves, and from items with words like critical, required, or essential."
    - Preferred (`plus-circle`): **"Nice-to-haves that count toward the score, less than core criteria."** "From sections titled Preferred or Nice to have. Criteria without a strong core or bonus signal land here."
    - Bonus (`star`): **"A small boost when a candidate has them."** "Usually only from sections literally titled Bonus. Not every description produces them."
  - [ ] F.2.2.3 Layout check: adding `sidebar` switches `SettingsContainer` to `hasSidebar` layout (Content 50vw at lg, sidebar hidden below lg — `SettingsContainer.tsx:116-126, 196-208`). Visually verify the existing Plato reviews form still renders correctly at lg and below (QA phase re-verifies).
- [ ] F.2.3 Commit: `Add job criteria section and tier glossary to Plato AI settings`.

### - [ ] F.3 Modals: view slide-over + regenerate confirm

*Tags: `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`, `cursor_rules/frontend/modals/modal_state_errors_and_loading.md`, `cursor_rules/frontend/contexts/context_usage_and_rules.md`.*

- [ ] F.3.1 NEW `app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx` — display-only. Props: `{ criteria: AiJobCriterion[]; onCancel: () => void }` (import the type from `useAiJobCriteria.ts`). No data fetching inside. Frozen-prop staleness consciously accepted (SPEC 8.4, pipeline rule 22 — read-only viewer; do not "fix" with live reads).
  - [ ] F.3.1.1 `FullModal` with `onCancel={onCancel}`, OMITTING `headerTitleText` so the built-in Dismiss header does not render (P11). Esc + backdrop close come free.
  - [ ] F.3.1.2 Custom sticky header in children (bundle-3 `SlideHead` structure): h2 "Job criteria" (22px/600/-0.02em) + X icon button (28×28 hit area, styled button, Feather `x` via `Icon` with svg sized 16px per D-3) calling `onCancel`.
  - [ ] F.3.1.3 Body: description paragraph (14px/400/1.6 secondary): "New reviews score candidates against these. To change them, edit the job description. Reviews that have already run keep the criteria they were scored against."
  - [ ] F.3.1.4 Single bordered list container (radius 7px) grouped by tier using the same `TIERS` shape: tier head row (icon + label + count, tabular count), criterion rows (13.5px/1.45, top border between rows); empty tiers omitted; tiers after the first get top border + margin. **NO `TierHint` sentences** (decided OUT). Read-only: no hover states, no footer. Styled components per bundle-3 `SlideHead`/`SlideBody`/`Description`/`ListBox`/`TierHead`/`Row` with D-4 tokens.
- [ ] F.3.2 NEW `app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx` — analogs P9 (mutation ownership) + P10 (anatomy). Props: `{ jobId: number; onCancel: () => void }`.
  - [ ] F.3.2.1 OWNS its mutation: `const { mutate: regenerateAiJobCriteria, isLoading } = useRegenerateAiJobCriteria();` INSIDE the modal (rule 22 — internal hook state is live; a parent-passed `isLoading` prop would freeze at `openModal` time). Also `useModalContext()` for `dismissModalWithAnimation`, `useToastContext()`.
  - [ ] F.3.2.2 `CenterModal` with `headerTitleText="Regenerate job criteria?"` (required prop, `CenterModal.tsx:13`) and `onCancel`.
  - [ ] F.3.2.3 Lead paragraph (manual variant ONLY — the after-description-update variant is decided OUT): "Plato will re-extract scoring criteria from the current job description. Reviews that have already run keep the criteria they were scored against."
  - [ ] F.3.2.4 Bordered statement box with `refresh-cw` icon (mirror `Styled.Statement`, P10, svg sized per D-3): "Regenerating works best when you have changed the parts of the description that affect scoring, like requirements or responsibilities. Keeping regenerations rare keeps scores comparable across candidates. If the criteria change significantly, you can also regenerate all candidate reviews."
  - [ ] F.3.2.5 Footer: primary `Button` `Regenerate criteria` with BOTH `loading={isLoading}` AND `disabled={isLoading}` (pipeline rule 11 — the analog passes both, `BulkGenerateAiSummariesConfirmModal.tsx:157-158`); secondary `Cancel` → `dismissModalWithAnimation(() => onCancel)`.
  - [ ] F.3.2.6 Confirm handler: `regenerateAiJobCriteria({ jobId }, { onSuccess, onError })`. onSuccess: `dismissModalWithAnimation(() => onCancel)` — NO success toast (completion arrives over WebSocket; the section button enters loading via the invalidated payload). onError: `addToast({ title: error?.data?.errors?.general?.[0] || "Could not regenerate job criteria", kind: "warning", delay: 10000 })`, modal STAYS open (analog :92-98).
- [ ] F.3.3 Commit: `Add job criteria view slide-over and regenerate confirm modals`.

### - [ ] F.4 Final verification sweep (whole diff)

- [ ] F.4.1 `git diff qa-refinements...HEAD` absence greps — ALL must return zero hits in the diff: `internal_job_criteria`; `guard`/`GuardTitle`/`GuardBody`/`GuardFoot` (guard modals decided OUT); `TierHint` (decided OUT); after-description-update confirm variant strings; `tier1`/`tier2`/`tier3` as payload keys (bundle leak); `??` in new frontend code; `|| []`, `|| 0`, `|| ""` fabricated fallbacks in new code (the error-toast `|| "Could not regenerate job criteria"` fallback string and analog-matching toast fallbacks are the sanctioned exceptions).
- [ ] F.4.2 Copy sweep over every new user-facing string (toasts, 3 empty states, card description, section intro, sidebar glossary, both modals, backend error messages): no em dashes; sentence case; no emoji; "extract" never "read"; "count most/less toward the score" never "weight/heaviest"; static button labels (no interpolated counts); timestamps only in the card description; never "candidates will be rescored".
- [ ] F.4.3 Run the full affected backend suite in one pass:
  `bundle exec rspec spec/models/ai_job_criteria_spec.rb spec/models/job_criteria_lifecycle_spec.rb spec/models/textract_result_ai_trigger_spec.rb spec/jobs/extract_job_criteria_job_spec.rb spec/jobs/bulk_generate_ai_summaries_job_spec.rb spec/interactors/validate_ai_summary_generation_spec.rb spec/interactors/validate_auto_ai_summary_generation_spec.rb spec/interactors/queue_bulk_ai_summary_jobs_spec.rb spec/controllers/api/v1/ai_job_criteria_controller_spec.rb spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb`
- [ ] F.4.4 Confirm working tree is fully committed (`git status` clean) — reviews review committed code (pipeline rule 15). Confirm no Claude-generated files were left in the repo tree and `.gitignore` untouched.

## G. Validation and constraints (binding checklist for the implementer)

- **Decided OUT — do not build:** guard modals; after-description-update confirm variant + trigger; tier hint sentences; anything touching `internal_job_criteria`.
- **Regenerate allowed in ANY job state** — no `published`/`draft`/`status` conditions on Job anywhere in the new endpoint or UI.
- **Loading states are mandatory** (named recent failure mode): initial-fetch `LoadingIndicator`; button loading driven by BACKEND status (survives reload), per D-5.
- **Flags 1–7 are settled** (kwarg; third zero-criteria message; failure broadcasts; positional job args; failed-latest display precedence; claim-row fix; optional `job` input). Implement as specified; do not re-open; do not "improve".
- **Fix-agent discipline during later review rounds:** minimum change per finding (pipeline rules 10/23); no new enum values/status transitions/callbacks (rule 20 — the funnel-guard race stays documented-and-accepted); re-grep after every rename/fix (rule 6).
- **Backward compatibility invariants:** old positional `[id]` Sidekiq payloads still perform; `extract_job_criteria_immediately` callable with no args; `QueueBulkAiSummaryJobs` callable without `job:`; existing `extract_job_criteria_job_spec.rb` positional examples pass unmodified; `aiSummaryWebsocketPayloads.ts` existing interfaces untouched.
- **Visual spec:** radius 7px, disc 36px (PlatoChip as-is), rail 186px, description 14px/400/1.6 secondary, meta 12.5px/1.3, weights 400/450/500/600 only, tabular figures on counts/timestamp, monochrome neutrals + accent gradient only, poly tokens per D-4.

## H. Test plan

RSpec per task group (tests land WITH their code — E.1.5, E.2.6, E.3.2, E.4.7, E.5.4 — not deferred; pre-commit hooks run tests and every commit must pass). Load-bearing cases: the six serializer/controller payload states; the three-message truth table; the no-pending-guard documentation test; broadcast behavioral assertions (`GlobalChannel.broadcast_to` outcomes — reflection-only tests are ghost tests, BLOCKER per pipeline rule 26); the claim-row `:failed` test; the job-less `QueueBulkAiSummaryJobs` call still passing.

**Frontend tests: none — documented decision, not an omission** (SPEC 12: the codebase has a single component test, `Button.test.tsx`; no view/hook test infra to extend). Frontend behavior is verified in LIFECYCLE Phase 8 QA against the running app.

**Cypress: NO changes** (SPEC: documented — no existing job-setup Cypress coverage to extend was found). Existing Cypress specs are source of truth; do not modify them. No new Cypress specs.

## I. Documentation impact

None. No README/docs files in scope. The only comment-level changes shipped: the `aiSummaryWebsocketPayloads.ts` header comment update (F.1.2) and preserving the existing comments around the `job.rb` gating methods (E.3.1). Do not add date annotations or narration comments elsewhere.

## J. Commit strategy

One commit per task group (7 commits: E.1–E.5, F.1–F.3 as listed; F.4 amends nothing — it verifies). Pre-commit tests are non-negotiable: never `--no-verify`, never weaken a test to pass; commit via `nvm use && git commit ...` outside the sandbox per pipeline rules. No branch operations — `job-criteria-settings` is already checked out. Every commit message ends with the Claude Code attribution footer:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

## K. Risks and open questions

- **R-1 — `ai_job_criteria.reload` vs `cursor_rules/backend/_base.md` §8 ("No reload in application code").** SPEC section 7 specifies `ai_job_criteria.reload` in `broadcast_completion` (needed because `ExtractCriteria` writes status via `update_columns` on a DIFFERENT in-memory instance; REVIEW-ANGLES Angle 3 explicitly requires the reload before the terminal check). But backend/_base.md §8 prohibits `reload` in `app/` and the Phase 6.5 conventions pass runs that file against this diff. The analog satisfies both by re-querying fresh (`textract_result.ai_job_application_summaries.order(created_at: :desc).first`, analog :60) instead of reloading. **Implement SPEC-verbatim (`reload`)** — the spec is authoritative and review-hardened — but expect the conventions pass to flag it; the one-line rule-compliant equivalent is `ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)` + nil guard. Needs a human-gate ruling if flagged; do NOT preemptively deviate.
- **R-2 — Shared `Icon` has no `size` prop and ships stroke-width 1.75px.** Bundle-3 passes `size={13..16}` (ignored) and DECISIONS says 2px stroke. D-3 resolves via wrapper CSS (svg width/height/stroke-width). If QA judges the 2px override too heavy against the app's 1.75px norm, dropping the stroke-width override is a one-line-per-wrapper change.
- **R-3 — `isFetching` in the `isInFlight` OR (D-5)** makes the Generate/Regenerate button show loading during any background refetch (window focus), not only post-POST. Faithful to SPEC 8.3's "query is refetching" clause; cosmetic cost accepted. If flagged, the alternative is `useIsMutating` with a mutation key — a design change requiring a gate ruling.
- **R-4 — Sidebar changes existing layout.** `hasSidebar` puts Content at 50vw (lg) where the settings form previously had `max-width: 50vw` via the no-sidebar branch — net similar, but the existing Plato reviews form must be visually verified at lg and below (sidebar is `display: none` below lg). QA Phase 8 item.
- **R-5 — Carried open questions for Jessica (from SPEC-REVIEW-COMPLETE, none block implementation):** flag 4 positional ruling (ships unless she orders a kwargs migration); flag 6 claim-row fix (approved overnight, still ⚠️ for her review); funnel-guard race leaving a summary stuck `pending`/`textract_processing` (documented-and-accepted; alternative needs her approval); failed-latest hiding an older succeeded card (user-visible data disappearing, ruled); non-AI orgs reaching the tab by direct URL (coherent today).
- **R-6 — `render_general_errors` returns 422** (`application_controller.rb:40-42`) — the "422 with message" expectations in E.5.4.1 rest on this helper; if any assertion fails on status code, check the helper, not the controller.
- **R-7 — Copy is draft-grade by design** (section intro, failure empty state, toasts, sidebar descriptions): DECISIONS says iteration expected later. Ship the drafted strings verbatim; do not wordsmith mid-implementation.

## L. Estimated scope

- **Backend:** ~9 app files modified + 2 new (controller, serializer) + 1 route line; ~120 new lines of app code. 3 new spec files + 6 modified; ~450 lines of spec code.
- **Frontend:** 4 new files (hook, section, 2 modals) + 3 modified (settings view, WS handler, payload types); ~700 lines including styled components.
- **7 commits**, each green through pre-commit tests. Single implementer, sequential task groups; E.2 must precede E.3; E.1 precedes E.4/E.5; F.1 precedes F.2/F.3.
