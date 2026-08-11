# item2-rescore-threading-contract — Round 2

Independent re-verification of the `rescoreRequested` thread frontend → API → controller → attribute → interactor gate.

- `useAiJobApplicationSummary.ts`: `GenerateParams` gains `rescoreRequested: boolean;` — required, no `?`. Rides into the existing `{ aiJobApplicationSummary: params }` POST body (→ `rescore_requested` via API layer, core rule 7 boundary honored). `GenerateParams` is a local (non-exported) interface; the bulk hook uses a separate `BulkGenerateParams`, so no shared-type breakage. ✓ (SPEC 2.3)
- Controller `ai_job_application_summaries_controller.rb`:
  - ONE private params method `ai_job_application_summary_params` = `params.require(:ai_job_application_summary).require(:rescore_requested)` (core rule 5; Rails `require` treats `false` as present). ✓
  - `job_application.ai_summary_rescore_requested = ai_job_application_summary_params` set at line 17, after `ValidateAiSummaryGeneration` success check, immediately before `CreateAiSummaryGeneration.call` — matches bulk placement (owner-approved). No begin block (core rule 1). `show`/`exists`/`authorize`/render branches untouched. ✓ (SPEC 2.2)
- `PlatoTab.tsx`:
  - `handleGenerate = (rescoreRequested: boolean) =>` — required param, no default; passes `generate({ jobApplicationId: jobApplication.id, rescoreRequested }, ...)`. ✓
  - Four callsites pass the literal explicitly: three `PlatoTabEmptyState` onClick paths arrow-wrapped `() => handleGenerate(false)` (bulkQueued :192, failed :203, ready/noCredits :233); Regenerate `onConfirm` calls `handleGenerate(true)` after `removeModal()`. The noResume callsite uses `handleNavigateToResumeTab` (untouched). No bare `onClick={handleGenerate}` remains. ✓ (SPEC 2.4)
- Controller spec (`ai_job_application_summaries_controller_spec.rb`, CREATE): missing-param → `raise_error(ActionController::ParameterMissing)` (base controllers don't rescue it — verified); value-threads test captures the `job_application` passed to a stubbed `CreateAiSummaryGeneration` and asserts `ai_summary_rescore_requested == true`. Real controller code runs unstubbed; stubs pass the real param shape (no masked mismatch, known-failure #7). Both falsifiable (core rule 26). ✓
- No fabricated fallback anywhere — the boolean is always sent (core rule 10 / known-failure #13). ✓

Live rspec: controller examples pass (2 of the 6).

## Findings
No issues found.
