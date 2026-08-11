# item2-rescore-threading-contract — Pass 1

Scope: Task F3 (`useAiJobApplicationSummary.ts`, SPEC 2.3) + Task B6 (`ai_job_application_summaries_controller.rb`, SPEC 2.2) + Task T3 (controller spec, SPEC 2.8) + the PlatoTab callsite portion of Task F4.

## Fact Check

| Claim (plan) | Verify | Result |
|---|---|---|
| `GenerateParams { jobApplicationId: number }` (F3) | Read hook `:4-6` | TRUE |
| params ride into `variables: { aiJobApplicationSummary: params }` POST body | hook line 11 | TRUE |
| `generateAiSummary` / `GenerateParams` not exported (internal) | hook | TRUE — only `useGenerateAiSummary`/`useAiJobApplicationSummary` exported |
| controller `create` uses `exists(...) do |job_application|`, `ValidateAiSummaryGeneration.call` then `result = CreateAiSummaryGeneration.call(` (B6.2 insertion point) | Read controller `:4-27` | TRUE — Validate 8-15, Create at 17 |
| controller has NO existing params method / no `private` (B6.1 adds one) | controller | TRUE |
| pinned param pattern `bulk_ai_job_application_summaries_controller.rb:77-86` (`require(...)` then `.require(:rescore_requested)`) | Read bulk controller | TRUE — Rails `require` returns the value; special-cases `false` as present |
| `handleGenerate` = `() => {` at line 73 (F4.1) | Read PlatoTab | TRUE |
| `generate({ jobApplicationId: jobApplication.id }, {` at 74-75 (F4.2) | lines 74-75 | TRUE |
| Regenerate `onConfirm` `{ removeModal(); handleGenerate(); }` at 106-109 (F4.3) | lines 106-109 | TRUE |
| three bare `onClick={handleGenerate}` at 192, 203, 233 (F4.4) | grep | TRUE — exactly three |
| noResume callsite line 222 uses `handleNavigateToResumeTab` (do NOT touch) | line 222 | TRUE |
| `PlatoTabEmptyState` `onClick?: () => void` forwards the DOM event (`onClick={props.onClick}`) | Read PlatoTabEmptyState `:12,137` | TRUE — bare pass would deliver event as truthy `rescoreRequested`; arrow-wrap required |

## Rails `require` false-as-present (verified)

`ActionController::Parameters#require` returns the value when `value.present? || value == false`; raises `ParameterMissing` only when truly absent/blank. So `rescore_requested: false` (JSON boolean) returns `false`; a missing key raises. The chained `params.require(:ai_job_application_summary).require(:rescore_requested)` returns the scalar boolean, which B6.2 assigns to `job_application.ai_summary_rescore_requested`. The single-send controller only needs the scalar (unlike the bulk controller which also `.permit`s other keys) — owner-approved shape (SPEC 2.2). CORRECT.

## Completeness (SPEC 2.2 / 2.3 / 2.4 / 2.8)

- F3: `rescoreRequested: boolean` required (no `?`). COVERED.
- B6.1: one `ai_job_application_summary_params` (core rule 5), no begin block (core rule 1). B6.2: set attribute immediately before `CreateAiSummaryGeneration.call`, matching bulk placement. COVERED.
- F4.1/F4.2: required param, passed as `generate({ jobApplicationId, rescoreRequested }, ...)`. COVERED.
- F4.3: Regenerate → `handleGenerate(true)` after `removeModal()`. COVERED.
- F4.4: three empty-state callsites arrow-wrapped `() => handleGenerate(false)`. COVERED.
- camelCase↔snake_case boundary honored (core rule 7); no fabricated fallback — required field enforces presence at compile (core rule 10 / known-failure #13). COVERED.
- T3.2 missing-param rejection: stubs Validate to reach the require (require sits after Validate), expects `ActionController::ParameterMissing` (base controllers don't rescue it — plan verified, confirmed against policy/base flow). Falsifiable by removing B6.1. COVERED.
- T3.3 value threads onto record: stubs both interactors, captures `job_application`, asserts `ai_summary_rescore_requested == true`, returns a real persisted summary for `render_one`. Falsifiable by removing B6.2. Policy `create?` authorizes via the same `can_use_ai_credits?` as `bulk_create?`, so the mirrored bulk-spec setup (org_owner/admin) passes authorization. COVERED.
- T3 stubs pass `rescore_requested` in the real param shape — no type/param mismatch masked (known-failure #7). COVERED.

## Findings
- No issues found. (T3.3's `receive(:call) do |args|` capture: the interactor is invoked with keyword-style args against `Interactor.call(context={})`, which Ruby 3.1 collapses to a positional hash; RSpec `ruby2_keywords` forwarding binds the flagged hash to the block's positional `args`, so `args[:job_application]` resolves. Plan's own risk note flags runtime verification via T4. Not a defect.)

## Amendments Applied
- None.
