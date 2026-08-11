# backward-compatibility (always-on) — Round 2

- `GenerateParams` now-required `rescoreRequested`: grep of `app/javascript/` shows the only consumers of `useGenerateAiSummary` are the hook file itself and `PlatoTab.tsx`. All PlatoTab `generate({...})` callsites thread `rescoreRequested`. `AiSummaryState.tsx` (the other former callsite) is deleted. `GenerateParams` is non-exported and local; the bulk hook uses a separate `BulkGenerateParams` — no cross-hook breakage. No surviving callsite omits the field. ✓
- `BulkGenerateAiSummariesConfirmModal` props (`Props` interface) unchanged — callers pass the same props. ✓
- `BulkAllStagesAiSummaryResultMailer.complete/.failed` signatures unchanged (`user_id` retained, `complete` still 6-arg, `failed` still 3-arg) — only the internal `to:` resolution changed. Callers/jobs unaffected. ✓ (The mailer spec's prior 5-arg `complete` call was itself stale and is now corrected to 6 args, reconciling to the real signature.)
- `create_ai_summary_generation` interactor input/output contract unchanged (still reads `job_application`/`validation_result`/`user`, sets `context.ai_summary`). ✓

## Findings
No issues found.
