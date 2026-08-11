# Review Angles — Plato re-score: per-stage bulk checkbox + single-send Regenerate

Generated from: SPEC.md (+ approved-decisions.md)
Date: 2026-07-11
Repo/worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (branch `job-criteria-settings-qa`)

---

## Scope guardrails for ALL reviewers (read first)

These are owner-confirmed constraints from `approved-decisions.md`. A reviewer who violates one of these produces a false finding.

1. **Item 2 interactors are NOT a whole-file analog.** `CreateBulkAiSummaryGeneration` is the source of exactly ONE copied behavior for `CreateAiSummaryGeneration`: the gate condition `&& !job_application.ai_summary_rescore_requested` (bulk `create_bulk_ai_summary_generation.rb:45` → single `create_ai_summary_generation.rb:36`). Do **not** diff the two interactors wholesale. Do **not** flag the bulk interactor's staleness-refresh block (`create_bulk_ai_summary_generation.rb:40-43`), its missing `textract_pending` branch, or its missing job enqueue as deviations the single-send interactor should adopt or match. The single-send interactor keeps all of its own existing behavior; only the one gate condition changes.

2. **Item 1 analog patterns are pinned verbatim in SPEC.md.** For `BulkGenerateAiSummariesConfirmModal.tsx`, reviewers verify the implementation against the SPEC's pinned strings, styles, and `file:line` references — NOT against their own independent reading of `RunPlatoReviewAllModal.tsx`. `RunPlatoReviewAllModal.tsx` and `CustomQuestionModal/index.js` are the pinned SOURCES the SPEC copied from; cite them only to confirm the SPEC's pin is faithful, not to invent a "better" match. Where the SPEC deliberately diverges the per-stage copy from the all-stages copy (e.g. leading "The" on the checked sentence — SPEC 1.2 state 4 vs 1.5), that divergence is owner-ruled, not a defect.

3. **No frontend tests.** Owner ruled frontend coverage is not wanted (approved-decisions "Item 1 test scope", "Item 2 test scope"). Do NOT raise a finding demanding React/Cypress tests for either item. Backend specs only.

4. **Explicitly-untouched items are out of scope** (SPEC 1.8): the per-stage no-selection branch copy, `BulkJobApplicationAiSummaryResultMailer` recipients, the `"job"` query-invalidation difference between the two bulk hooks, posthog `trackEvent` names/payloads, and the entire backend enqueue path. Do not flag these as gaps.

**Priority rule:** Where a pinned analog or an owner decision conflicts with a general convention, the pin/decision wins — note it, do not flag it.

---

## Subsystems touched

**Item 1 — per-stage bulk re-score checkbox + copy restructure + mailer**
- `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` (checkbox, 5-state copy restructure, overestimate info block, statement block, `rescoreRequested` wiring)
- `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx` (defect fixes: checked-state sentence, zero-state, statement second sentence)
- `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` (`complete` + `failed` → hiring-team recipients)
- `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` (extend)

**Item 2 — single-send Regenerate re-score**
- `app/interactors/create_ai_summary_generation.rb` (one gate condition, `:36`)
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb` (add `ai_job_application_summary_params`; set attribute before interactor)
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` (`GenerateParams.rescoreRequested: boolean`)
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` (`handleGenerate(rescoreRequested)`, 4 callsites, `:247` gating change)
- `app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx` (DELETE)
- `spec/interactors/create_ai_summary_generation_spec.rb` (CREATE)
- controller spec for `Api::V1::AiJobApplicationSummariesController` (CREATE)

**Shared / reference (not modified by this feature)**
- `app/models/job_application.rb:11` — `attribute :ai_summary_rescore_requested, :boolean, default: false` (already shipped)
- `app/models/organization_user.rb:48` — `scope :actives, -> { where(is_active: true) }`
- `app/mailers/job_application_mailer.rb:19,28-32` — recipient-resolution analog
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:77-86` — pinned source of the `require(...).require(:rescore_requested)` param pattern
- `app/interactors/create_bulk_ai_summary_generation.rb:45` — pinned source of the ONE gate condition
- `app/javascript/ats/src/components/modals/CustomQuestionModal/index.js:192-199,254+` — pinned source of the info-icon + Tooltip pattern and `Styled.Info` styles
- `config/routes.rb:315` — `resources :ai_job_application_summaries, only: [:show, :create]` (nested under job_applications)
- `spec/interactors/create_bulk_ai_summary_generation_spec.rb` — the mirror the new interactor spec follows (SPEC 2.8)

---

## Full-stack analog

This feature has **two distinct analog relationships**, both partial by owner decision — there is no single new end-to-end pipeline to trace.

**Item 1 analog — `RunPlatoReviewAllModal.tsx` (all-stages modal) is the blueprint for the per-stage modal.** Both share the same backend (`Api::V1::BulkAiJobApplicationSummariesController` → `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob` → `CreateBulkAiSummaryGeneration`), which is complete and unchanged (SPEC Background). The analog relationship is UI-copy + checkbox + credit-math only. The SPEC pins every copied string and style verbatim (guardrail 2).
- Frontend (new): `BulkGenerateAiSummariesConfirmModal.tsx` → `useBulkGenerateAiSummaries` (per-stage hook, unchanged)
- Frontend (analog): `RunPlatoReviewAllModal.tsx` → `useBulkGenerateAllStagesAiSummaries` (all-stages hook, unchanged)
- Mailer (new recipients): `BulkAllStagesAiSummaryResultMailer#complete/#failed`, recipients resolved like `JobApplicationMailer#hiring_team_new_job_application` but WITHOUT the `receives_new_job_application_emails` preference scope (SPEC 1.6 — this omission is owner-ruled, not a deviation).

**Item 2 analog — `CreateBulkAiSummaryGeneration` supplies ONE line to `CreateAiSummaryGeneration`.** The rest of the single-send pipeline is its own pre-existing structure and is the thing being minimally modified, not matched to the bulk path. The threading contract (frontend param → controller strong params → virtual attribute → interactor) mirrors the bulk controller's param pattern only at the strong-params boundary (guardrail 1).

**Priority rule (analog deviations that are already sanctioned — do NOT flag):**
- Item 1 per-stage checked sentence has a leading "The"; all-stages does not (SPEC 1.2/1.5, owner-ruled).
- Item 1 mailer omits the `receives_new_job_application_emails` preference scope that the recipient analog uses (SPEC 1.6, owner-ruled — no Plato-bulk opt-out key exists).
- Item 1 per-stage modal adds an overestimate info block that the all-stages analog lacks (all-stages counts are exact; per-stage Select-All is not — SPEC 1.3, owner-ruled).
- Item 2 single-send interactor does NOT gain the bulk interactor's staleness-refresh block, `textract_pending`-omission, or enqueue behavior (guardrail 1).

---

## Angles

### item1-modal-copy-and-state-machine
**What this covers:** `BulkGenerateAiSummariesConfirmModal.tsx` implements the SPEC's pinned 5-state precedence copy machine, the re-score checkbox, the overestimate info block, and the Statement block — each verified against the SPEC's verbatim strings and the pinned source files, with correct `candidatesToScoreCount`/`shortfall` math and correct submit-button + checkbox disable conditions in every state.
**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` (SPEC 1.1–1.4)
**Pinned sources for comparison (confirm the SPEC pin is faithful; do not re-derive):**
- `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx:118-151` (Body copy, `RescoreCheckbox`, `Statement`)
- `app/javascript/ats/src/components/modals/CustomQuestionModal/index.js:192-199` and `Styled.Info` (`:254+`) (overestimate info block)
- `app/javascript/ats/src/components/forms/FormCheckbox` (checkbox contract)
**Specific checks:**
- All 5 states present and in the SPEC's precedence order (1 no-selection → 2 unchecked/zero-processable → 3 unchecked/processable → 4 checked). Verify each state's exact string against SPEC 1.2 (numeric `0` not the word; "Up to " prefix only when `!isProcessableCountExact && !rescore`; the shortfall vs normal credit variant).
- `candidatesToScoreCount = rescore ? candidatesCount : processableCount` and `shortfall = Math.max(0, candidatesToScoreCount - available)` (SPEC 1.2). The old `shortfall` used `processableCount` directly — confirm it now tracks the rescore-aware count.
- Checkbox: `FormCheckbox` `name="rescore"`, exact label/description strings (SPEC 1.1), `checked={rescore}`, toggling `onChange`; renders **disabled but visible** when `candidatesCount === 0` (same condition as submit button).
- Submit-button disabled condition is `isLoading || state1 || state2` (states 3 & 4 enable it) (SPEC 1.2). The old code disabled on `processableCount === 0`; confirm the new condition matches the SPEC exactly.
- Overestimate info block renders **only** when `isProcessableCountExact === false && !rescore`, beneath the body (SPEC 1.3); short message + Tooltip `label` strings verbatim.
- Statement block replaces the old `Styled.Callout`; string verbatim (SPEC 1.4). Old `Styled.Caveat` + `Styled.Callout` + `shortfallText` + 4-branch `instructions` are all deleted (SPEC 1.2).
- `rescoreRequested: rescore` replaces the literal `false` in the `bulkGenerate` call (SPEC 1.1) — currently `:74`.
- Emotion labels match the SPEC's pinned names (`BulkGenerateAiSummariesConfirmModal_RescoreCheckbox`, `_Info`, `_Statement`).
**Convention context:** `cursor_rules/core_critical_rules.md` rule 1 (Emotion theme utilities are complete declarations — pipeline known-failure #1: `${t.text.sm};` standalone, never inside `font-size:`), rule 13 (styled component per element, no className), rule 9 (never set `undefined`); `cursor_rules/frontend_base.md` if present.

### item1-runplato-defect-fixes
**What this covers:** the three defect fixes in the all-stages modal `RunPlatoReviewAllModal.tsx`, verified against SPEC 1.5 and approved-decisions ("flag A", "zero-processable state").
**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx` (SPEC 1.5)
**Specific checks:**
- Checked-state body first sentence becomes "{candidatesCount} candidate(s) in this job will be reviewed, including candidates that already have a review." — **NO leading "The"** (deliberate divergence from the per-stage sentence; do not flag). Credit sentence unchanged.
- Zero-state (unchecked, `candidatesToScoreCount === 0`): "0 candidates in this job don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." Numeric `0`, no credit sentence, button stays disabled via existing `candidatesToScoreCount === 0`.
- Statement second sentence becomes "Candidates without a resume, one that's still processing, or those already part of another bulk operation are skipped." First sentence ("The hiring team gets an email with the final count when it's done.") stays — made TRUE by the 1.6 mailer change (verify the mailer change actually lands, cross-angle with item1-mailer-recipients).
- No other behavior in this modal changes (button props, hooks, trackEvent).
**Convention context:** same frontend rules as above.

### item1-mailer-recipients
**What this covers:** `BulkAllStagesAiSummaryResultMailer#complete` and `#failed` send to every active hiring-team member of the job in one email, resolved like the recipient analog but without the preference scope, with the `any?` guard — and the per-stage mailer stays untouched.
**Files across all layers:**
- `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` (SPEC 1.6)
- `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` (SPEC 1.7 — extend)
**Analog / reference files for comparison:**
- `app/mailers/job_application_mailer.rb:19,28-32` — recipient resolution + `to_recipients` map + `return unless recipients.any?`. The new code copies this shape but drops `.receives_new_job_application_emails` (owner-ruled; do not flag the omission).
- `app/models/organization_user.rb:48` — `actives` scope (`job.organization_users.actives`).
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` — MUST remain single-user (triggering user only). Confirm it is not touched.
**Specific checks:**
- Recipients = `job.organization_users.actives` mapped to `{ name, email }`, all in ONE email's `to:` array (not one email per member) — both `complete` and `failed`.
- `return unless recipients.any?` guard present in both methods (bare `return`, no truthy/falsy value — core rule 8).
- Active members included, inactive excluded (the `actives` scope enforces this — verify the mapping doesn't re-widen it).
- No preference/opt-out filter added (none exists).
- The pre-existing `@user = User.find(user_id)` single-recipient logic is replaced, not left dangling; any variables the templates need (`user_first_name`, etc.) are still populated correctly for a multi-recipient send. **`user_first_name` currently derives from the single `@user`** — verify what it resolves to now (per-recipient personalization is not part of the SPEC; confirm the template variable is still valid and not broken by the recipient change).
**⚠ Live discrepancy for the test reviewer:** `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` is **already out of sync** with the current mailer BEFORE this change: it calls `complete(user.id, job.id, 5, 1, 2)` (5 args) against the 6-arg `complete(...succeeded, failed, skipped, total)` signature, and asserts subject `"Your AI summaries for #{job.title} are ready"` + tag `'ai-summaries'`, while the mailer emits `"Your Plato reviews for..."` + `tags: ['polymer', 'user-facing']`. The spec as written cannot pass against the current mailer. The reviewer must confirm the extended spec reconciles arity, subject, and tags with the real mailer — not just adds recipient assertions on top of already-failing expectations.
**Convention context:** `cursor_rules/core_critical_rules.md` rule 8 (bare guard returns), rule 11 (no bang methods outside spec/), rule 26 (no ghost tests — recipient assertions must be falsifiable by removing the recipient change); mailer conventions if a `cursor_rules` mailer file exists.

### item2-single-send-gate
**What this covers:** the single gate change in `CreateAiSummaryGeneration`, verified as the MINIMUM change (one condition), with every other gate on the single-send path untouched, and the new interactor spec mirroring the bulk interactor spec's assertion pairs.
**Files across all layers:**
- `app/interactors/create_ai_summary_generation.rb` (SPEC 2.1 — line `:36`)
- `spec/interactors/create_ai_summary_generation_spec.rb` (SPEC 2.8 — CREATE)
**Pinned source for the ONE copied line:**
- `app/interactors/create_bulk_ai_summary_generation.rb:45` — the gate condition string `active_ai_summary && !job_application.ai_summary_rescore_requested`. This is the ONLY thing copied. (Guardrail 1: do not compare the rest of these two files.)
**Mirror for the new spec:**
- `spec/interactors/create_bulk_ai_summary_generation_spec.rb:74-113` — the rescore-path assertion pairs (`true` builds a new pending row, leaves existing untouched; `false` returns existing, enqueues/creates nothing). The single-send spec additionally asserts `GenerateAiJobApplicationSummaryJob` **is** enqueued on the `true` path (the bulk interactor does not enqueue; the single-send one does — SPEC 2.8).
**Specific checks:**
- `if active_ai_summary` becomes `if active_ai_summary && !job_application.ai_summary_rescore_requested` — nothing else in `create_ai_summary_generation.rb` changes (the `textract_pending` branch, the `pending` build+enqueue, the `ap` debug lines, the `requested_by_organization_user_id` set all stay).
- Verify the SPEC's eight untouched gates are genuinely untouched (SPEC 2.1): controller existence/tenancy, Pundit `create?`, `ValidateAiSummaryGeneration`, job entry `return unless textract_result`, `textract_result.rb:68` succeeded-and-not-stale return, job-criteria readiness, `Orchestrate` entry checks, charge-on-success balance check.
- Interactor spec: `true` → new `pending` `AiJobApplicationSummary` built + `GenerateAiJobApplicationSummaryJob` enqueued; `false` (active non-stale succeeded summary) → returns existing, enqueues nothing. Assertions must be falsifiable by reverting the gate (core rule 26 / pipeline known-failure #26 — no ghost tests).
- No `update_columns` introduced (rule 25); no bang methods outside the spec (rule 11).
**Convention context:** `cursor_rules/core_critical_rules.md` rules 8, 11, 12, 25, 26; interactor conventions if a `cursor_rules` file covers them. Pipeline known-failures #10 and #23 (fix/impl agents must not add or remove code beyond the single-condition scope — e.g. must NOT port the bulk staleness block).

### item2-rescore-threading-contract
**What this covers:** the `rescoreRequested` boolean threads cleanly frontend → API body → controller strong params → `job_application.ai_summary_rescore_requested` → interactor, with the required-not-optional typing and the arrow-wrapped callsites that prevent a click event riding in as a truthy value.
**Files across all layers:**
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` (SPEC 2.3 — `GenerateParams.rescoreRequested: boolean`, required)
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` (SPEC 2.4 — `handleGenerate(rescoreRequested)` + 4 callsites)
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb` (SPEC 2.2 — add `ai_job_application_summary_params`, set attribute before `CreateAiSummaryGeneration.call`)
**Pinned source for the param pattern:**
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:77-86` — `params.require(:bulk_ai_job_application_summary)` then `.require(:rescore_requested)` (Rails `require` treats `false` as present). The single-send controller mirrors this at the strong-params boundary only.
**Specific checks:**
- `GenerateParams` gains `rescoreRequested: boolean` with **no `?` optional marker** (SPEC 2.3); it rides into the existing `{ aiJobApplicationSummary: params }` POST body unchanged.
- Controller: ONE params method named `ai_job_application_summary_params` (core rule 5 — no `create_`/`update_` split); `params.require(:ai_job_application_summary).require(:rescore_requested)`; controller sets `job_application.ai_summary_rescore_requested = <required value>` **before** `CreateAiSummaryGeneration.call`, matching the bulk path's placement. No begin-block (core rule 1).
- `handleGenerate` gains a **required** boolean param (no default) and passes `rescoreRequested` into `generate({ jobApplicationId, rescoreRequested }, ...)` (SPEC 2.4).
- All four callsites pass the literal explicitly: the three `PlatoTabEmptyState` `onClick` paths (bulkQueued, failed, ready/noCredits) become `onClick={() => handleGenerate(false)}` — **arrow-wrapped**, because `PlatoTabEmptyState`'s `onClick?: () => void` currently receives `onClick={handleGenerate}` and a bare pass would deliver the click event as a truthy `rescoreRequested`; the Regenerate `ConfirmationModal` `onConfirm` calls `handleGenerate(true)` after `removeModal()` (SPEC 2.4). Verify no callsite passes the handler bare.
- New controller spec (SPEC 2.8): request without `rescore_requested` rejected; with it, value threads onto the record. Falsifiable assertions (core rule 26).
- Contract camelCase/snake_case boundary honored (core rule 7): frontend `rescoreRequested` ↔ backend `rescore_requested` via the API layer.
**Convention context:** `cursor_rules/core_critical_rules.md` rules 1, 5, 7, 9; `cursor_rules` controllers/base and requests-spec conventions if present. Pipeline known-failure #7 (test stubs must not mask type mismatches at the API boundary) and #13 / core rule 10 (no fabricated fallbacks — the boolean is always sent, never defaulted).

### item2-regenerate-gating-and-dead-code-deletion
**What this covers:** the Regenerate button now renders for every `current` review (not only stale ones) with everything inside the branch unchanged, and the dead `AiSummaryState.tsx` is deleted with zero dangling references and no compile breakage.
**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` (SPEC 2.5 — `:247` condition)
- `app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx` (SPEC 2.6 — DELETE)
**Specific checks:**
- `:247` header-right condition changes from `statusValue === "current" && fullSummary?.stale` to `statusValue === "current"` alone. Everything inside the branch stays byte-for-byte: the `isLoadingCredits || totalRemaining > 0` credits check choosing Regenerate vs Buy-credits fallbacks (admin nav button / non-admin alert modal), the `ConfirmationModal` copy, and the Button `loading={buttonLoading} disabled={buttonLoading}` **pairing** (pipeline known-failure #11 / core-rules HARD sub-rule: `loading` alone never blocks clicks — the paired `disabled` must remain).
- `AiSummaryState.tsx` deleted. Grep `app/` and `cypress/` for any remaining `AiSummaryState` import/reference — must be zero (SPEC 2.6 claims zero; verify independently). Its only `useGenerateAiSummary` callsite (`generate({ jobApplicationId }, ...)`) is the compile hazard once `rescoreRequested` is required in `GenerateParams`; deleting the file removes it. Confirm no other file has an un-updated `generate({ jobApplicationId })` call lacking `rescoreRequested`.
**Convention context:** `cursor_rules/core_critical_rules.md` rule 13; pipeline known-failure #11 (Button `loading`+`disabled` pairing) and #23 (deletion must be scoped — `AiSummaryState.tsx` is named in the SPEC as dead code; confirm nothing else is deleted alongside it).

---

## Always-on checks

### Source accuracy
Verify every file path, class, method, column, route, `file:line`, and component the SPEC references against the current source in the worktree. Known live points already confirmed: `create_ai_summary_generation.rb:36` (`if active_ai_summary`), `create_bulk_ai_summary_generation.rb:45` (the pinned gate), `bulk_ai_job_application_summaries_controller.rb:77-86` (param pattern), `PlatoTab.tsx:247` (stale-gated Regenerate), `BulkGenerateAiSummariesConfirmModal.tsx:74` (`rescoreRequested: false`), `organization_user.rb:48` (`actives`), `job_application_mailer.rb:19,28-32` (recipient analog), `job_application.rb:11` (virtual attribute), route `config/routes.rb:315`. Confirm the SPEC's `CustomQuestionModal/index.js:192-199` and `RunPlatoReviewAllModal.tsx:135-143 / :186-206` line references still point at the cited code.

### Test coverage
Two new backend specs (`create_ai_summary_generation_spec.rb`, `ai_job_application_summaries_controller` spec) and one extended (`bulk_all_stages_ai_summary_result_mailer_spec.rb`). No frontend tests (owner-ruled — do not demand them). Verify: (a) new specs exist and assert falsifiable outcomes (core rule 26 / known-failure #26 — mentally delete the feature line; would the assertion still pass?); (b) the interactor spec mirrors `create_bulk_ai_summary_generation_spec.rb`'s `true`/`false` pairs plus the single-send enqueue assertion; (c) **the extended mailer spec reconciles the pre-existing arity/subject/tags mismatch flagged in item1-mailer-recipients** — a spec that adds recipient assertions on top of already-failing `complete`/`failed` expectations is not passing coverage; (d) no test stub masks a type/param mismatch at the controller boundary (known-failure #7).

### Backward compatibility
Identify all consumers of every modified surface: `useGenerateAiSummary` / `GenerateParams` (now-required `rescoreRequested` — grep every `generate({...})` callsite in `app/` and `cypress/`; `AiSummaryState.tsx`'s callsite is deleted, but confirm no other survives without the field); `BulkGenerateAiSummariesConfirmModal`'s callers (props unchanged?); `BulkAllStagesAiSummaryResultMailer.complete/.failed` callers (the mailer method signatures are unchanged — only the internal `to:` resolution changes; confirm callers still pass the same args and the mailer job invocation is unaffected).

### Full-stack analog completeness
No new end-to-end pipeline is introduced (both analog relationships are partial by owner decision — see Full-stack analog). Item 1's backend enqueue path is pre-existing and unchanged. Item 2 adds only a controller param boundary + one interactor gate + frontend threading over the existing single-send pipeline. Do NOT flag "missing job / serializer / policy" for Item 2 — the single-send path already has them and they are explicitly untouched (SPEC 2.1). The one completeness check that matters: the `rescoreRequested` value must have a piece at every hop (frontend param → body → strong param → attribute → interactor gate) with no silent drop — covered by item2-rescore-threading-contract.

### Analog structural matching (SCOPED — read guardrails 1 & 2 first)
- **Item 1:** compare the implementation to the SPEC's PINNED text and pinned source files, not to a fresh independent reading of the analog. Confirm copied strings/styles/emotion-labels/`FormCheckbox` contract are faithful to the pin. The sanctioned divergences listed under Full-stack analog's priority rule are NOT structural mismatches.
- **Item 2:** the ONLY structural match required is the gate-condition string (`create_bulk_ai_summary_generation.rb:45` → `create_ai_summary_generation.rb:36`) and the strong-params `require(...).require(:rescore_requested)` shape (`bulk_ai_job_application_summaries_controller.rb` → `ai_job_application_summaries_controller.rb`). Do **not** diff the two interactors or the two controllers wholesale; do **not** report the bulk interactor's staleness block, textract_pending handling, or enqueue behavior as a mismatch the single-send code should match (guardrail 1).
