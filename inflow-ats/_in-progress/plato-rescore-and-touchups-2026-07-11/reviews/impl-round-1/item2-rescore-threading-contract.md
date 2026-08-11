# item2-rescore-threading-contract — Round 1

Reviewed hook `useAiJobApplicationSummary.ts`, `PlatoTab.tsx`, controller `ai_job_application_summaries_controller.rb` + controller spec (commit f9ec4a80d) against SPEC 2.2/2.3/2.4 and pinned param pattern `bulk_ai_job_application_summaries_controller.rb:77-86`.

## Verified — hop by hop (no silent drop)
- `GenerateParams` gains `rescoreRequested: boolean` (:6) — REQUIRED, no `?`. Rides into `variables: { aiJobApplicationSummary: params }` (:12) unchanged. Body root `aiJobApplicationSummary` → API layer → `ai_job_application_summary`, matching the controller's `require(:ai_job_application_summary)`.
- `handleGenerate` gains required `rescoreRequested: boolean` (no default) and passes `generate({ jobApplicationId, rescoreRequested }, ...)` (PlatoTab :73-75).
- All four callsites pass the literal explicitly: three `PlatoTabEmptyState` `onClick={() => handleGenerate(false)}` (:192, :203, :233) — arrow-wrapped so the click event cannot ride in as truthy; Regenerate `onConfirm` calls `handleGenerate(true)` after `removeModal()` (:107-108). No bare `onClick={handleGenerate}` remains (grep confirmed; noResume callsite untouched — uses `handleNavigateToResumeTab`).
- Controller: ONE params method `ai_job_application_summary_params` = `params.require(:ai_job_application_summary).require(:rescore_requested)` (core rule 5, scalar `require.require`, no `.permit`, no begin block). Attribute set `job_application.ai_summary_rescore_requested = ai_job_application_summary_params` (:17) placed after `ValidateAiSummaryGeneration` success and immediately before `CreateAiSummaryGeneration.call` — matches bulk placement (owner-approved L4).
- camelCase/snake_case boundary (core rule 7) honored; `:boolean` virtual attribute (`job_application.rb:11`) typecasts the stringified param.

## Verified — controller spec (falsifiable, no masked mismatch)
- Test 1 rejects request without `rescore_requested`: stubs Validate to reach the require, expects `ActionController::ParameterMissing` (base controllers don't rescue it — verified). Falsifiable by removing the `require`.
- Test 2 threads value onto record: stubs Validate + Create, captures `job_application`, asserts `ai_summary_rescore_requested` is `true` and 200. Falsifiable by removing the attribute-set line. Real controller code (params method + attribute set) runs unstubbed — no type mismatch masked (known-failure #7). Confirmed live: rspec green.

## Findings
No issues found.
