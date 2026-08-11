# item2-rescore-threading-contract — Pass 2

## Pass 1 corrections for this angle
- plan.md line 66 "(F6)" → "(B6)" — VERIFIED applied (controller task is Task B6).
- plan.md F4.4 failed callsite "line 202" → "line 203" — VERIFIED applied (three identical bare `onClick={handleGenerate}` at 192/203/233, all handled).

## Fresh sweep
- End-to-end thread has a piece at every hop with no drop: `GenerateParams.rescoreRequested` (F3, required) → POST body `{ aiJobApplicationSummary: params }` (unchanged hook) → `params.require(:ai_job_application_summary).require(:rescore_requested)` (B6.1) → `job_application.ai_summary_rescore_requested = <scalar>` (B6.2) → interactor gate (B4). Complete.
- Required-not-optional typing (F3, no `?`) makes the compiler enforce presence at every `generate({...})` callsite — the two consumers are PlatoTab (all 4 callsites pass a literal) and AiSummaryState (deleted). No fabricated fallback.
- B6.1 is the single params method (rule 5); B6.2 sets the attribute right before `CreateAiSummaryGeneration.call`, mirroring the bulk path; no begin block (rule 1).
- Rails `require` false-as-present re-confirmed as genuine framework behavior — `rescore_requested: false` returns `false`, missing key raises `ParameterMissing` (not rescued by `Api::V1::BaseController`/`ApplicationController`).
- Arrow-wrapping is genuinely required: `PlatoTabEmptyState` forwards `onClick={props.onClick}` (line 137) so the DOM event would otherwise arrive as a truthy `rescoreRequested`.
- T3.2/T3.3 falsifiable (remove B6.1 → no ParameterMissing; remove B6.2 → attribute stays false). Policy `create?` == `bulk_create?` authorization, so the mirrored setup authorizes.

## Findings
- No issues found.

## Amendments Applied
- None (Pass 1 amendments verified in place).
