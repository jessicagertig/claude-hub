# item2-regenerate-gating-and-dead-code-deletion — Round 1

Reviewed `PlatoTab.tsx` gating + deletion of `AiSummaryState.tsx` (commit f9ec4a80d) against SPEC 2.5/2.6.

## Verified
- `:247` header-right condition changed from `statusValue === "current" && fullSummary?.stale` to `statusValue === "current"` alone. Diff shows ONLY this one condition changed on that branch.
- Everything inside the branch stays byte-for-byte: `isLoadingCredits || totalRemaining > 0` credits check, the Regenerate `Button` with `loading={buttonLoading} disabled={buttonLoading}` PAIRING (known-failure #11 satisfied), and both Buy-credits fallbacks. The `regenerating` branch above it untouched.
- `AiSummaryState.tsx` deleted (221 lines, git shows delete). Grep of `app/` and `cypress/` for `AiSummaryState` → ZERO references (SPEC 2.6 claim independently verified).
- Grep confirms no surviving `generate({...})` callsite lacking `rescoreRequested` — the only two consumers of `useGenerateAiSummary` were `PlatoTab.tsx` (updated) and `AiSummaryState.tsx` (deleted). No compile hazard from the now-required `GenerateParams.rescoreRequested`.
- Deletion is scoped (known-failure #23): only `AiSummaryState.tsx` removed, nothing else deleted alongside it.

## Findings
No issues found.
