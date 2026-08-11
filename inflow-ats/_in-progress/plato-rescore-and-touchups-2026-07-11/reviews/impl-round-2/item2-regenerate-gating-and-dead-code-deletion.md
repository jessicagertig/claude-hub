# item2-regenerate-gating-and-dead-code-deletion — Round 2

Independent re-verification against SPEC 2.5 / 2.6.

- `PlatoTab.tsx:247` header-right condition changed from `statusValue === "current" && fullSummary?.stale` to `statusValue === "current"` alone — Regenerate now renders for every current review, stale or not. ✓
- Everything inside the branch byte-for-byte unchanged: the `isLoadingCredits || totalRemaining > 0` credits check, the Regenerate `Button` with `loading={buttonLoading} disabled={buttonLoading}` (pairing intact — known-failure #11 / core-rules HARD sub-rule), and both Buy-credits fallbacks. The `regenerating` branch above is untouched. ✓
- `AiSummaryState.tsx` deleted (221 lines removed in the commit). Grep of `app/` and `cypress/` for `AiSummaryState` → zero references. ✓ (SPEC 2.6)
- Only consumer of `useGenerateAiSummary` / `generate({...})` remaining is `PlatoTab.tsx`, and all its `generate` callsites thread `rescoreRequested` — no un-updated callsite survives to break the compile once `rescoreRequested` is required in `GenerateParams`. ✓
- Scoped deletion (known-failure #23): only `AiSummaryState.tsx` deleted, nothing else. ✓

## Findings
No issues found.
