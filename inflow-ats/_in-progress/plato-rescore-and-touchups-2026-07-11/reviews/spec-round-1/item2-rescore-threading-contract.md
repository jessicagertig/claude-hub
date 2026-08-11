# item2-rescore-threading-contract — Round 1

Trace: SPEC 2.2-2.4 → useAiJobApplicationSummary.ts (GenerateParams) → PlatoTab.tsx (handleGenerate + 4 callsites) → ai_job_application_summaries_controller.rb → bulk_ai_job_application_summaries_controller.rb:77-86 (pinned param pattern) → job_application.rb:11 (virtual attribute)

## Source-accuracy checks (confirmed)
- `useAiJobApplicationSummary.ts`: `interface GenerateParams { jobApplicationId: number }`; body `{ aiJobApplicationSummary: params }`. SPEC 2.3 adds `rescoreRequested: boolean` (required). CONFIRMED current shape.
- `PlatoTab.tsx`: `handleGenerate = () => generate({ jobApplicationId: jobApplication.id }, …)` (:73-75). Four `handleGenerate` callsites: `PlatoTabEmptyState onClick={handleGenerate}` at :192 (bulkQueued), :203 (failed), :233 (ready/noCredits); Regenerate `ConfirmationModal onConfirm` at :106-109 (`removeModal(); handleGenerate();`). CONFIRMED exactly 4. (The 5th empty-state at :222 is `onClick={handleNavigateToResumeTab}` — not handleGenerate; correctly excluded.)
- `ai_job_application_summaries_controller.rb`: `create` has NO strong-params method today; sets nothing before `CreateAiSummaryGeneration.call` (:17-21). CONFIRMED.
- Pinned param source `bulk_ai_job_application_summaries_controller.rb:77-86`: `params.require(:bulk_ai_job_application_summary)` then `.require(:rescore_requested)` (presence guard) then `.permit(...)`. CONFIRMED.

## Correctness checks
- Rails `ActionController::Parameters#require` special-cases `false` as present (`value.present? || value == false`) — so `.require(:rescore_requested)` accepts a literal `false`. SPEC 2.2's claim VERIFIED (this is why the bulk controller's identical require works).
- Contract boundary: frontend `rescoreRequested` ↔ backend `rescore_requested` via the API transform layer (core rule 7). The always-sent boolean (literal `false`/`true`) means no fabricated fallback (core rule 10 / known-failure #13). CONFIRMED.
- Arrow-wrapped callsites `onClick={() => handleGenerate(false)}`: `PlatoTabEmptyState`'s `onClick` currently receives the bare handler; once `handleGenerate` takes a required boolean, a bare pass would deliver the click event as a truthy `rescoreRequested`. Arrow-wrapping prevents it. SPEC 2.4 rationale CONFIRMED sound.
- Consumers of `GenerateParams`/`generate({...})`: only `PlatoTab.tsx` and `AiSummaryState.tsx` import `useGenerateAiSummary` (grep). PlatoTab's 4 callsites get updated; `AiSummaryState.tsx` is deleted (SPEC 2.6). No other `generate({...})` callsite survives without `rescoreRequested`. CONFIRMED backward-compat.
- Core rule 5 (one params method): SPEC 2.2's single `ai_job_application_summary_params` satisfies it; extracting a scalar via chained `.require` (no `.permit`) is acceptable for a single boolean assigned explicitly. Not a violation.

## Findings
- No issues found. The threading contract is fully specified and every hop (frontend param → body → strong param → virtual attribute → interactor gate) has a piece with no silent drop.

## Amendments Applied
- None.

## Rejected as false positives (guardrails)
- "Controller should `.permit` like the bulk controller" — the SPEC's scalar `.require(:ai_job_application_summary).require(:rescore_requested)` is the owner-approved shape (approved-decisions "Item 2 — param threading"); guardrail priority rule (owner decision wins). Not flagged.
