# item2-regenerate-gating-and-dead-code-deletion — Pass 1

Scope: Task F4.5 (`PlatoTab.tsx:247` gating, SPEC 2.5) + Task F5 (delete `AiSummaryState.tsx`, SPEC 2.6).

## Fact Check

| Claim (plan) | Verify | Result |
|---|---|---|
| `} else if (statusValue === "current" && fullSummary?.stale) {` at line 247 (F4.5) | Read PlatoTab | TRUE — line 247 |
| inside branch: `isLoadingCredits || totalRemaining > 0` (line 248); Regenerate `Button loading={buttonLoading} disabled={buttonLoading}` (line 250); Buy-credits fallbacks (admin nav 254-265, non-admin 267-269) | lines 248-270 | TRUE — pairing intact (known-failure #11) |
| `regenerating` branch above (240-246) untouched | lines 240-246 | TRUE |
| `AiSummaryState.tsx` exists, 222 lines | Read | TRUE — ends at line 222 |
| zero external `AiSummaryState` references in `app/`/`cypress/` (F5.1) | grep | TRUE — only self-references |
| only consumers of `useGenerateAiSummary` are `PlatoTab.tsx` + `AiSummaryState.tsx` (ordering note line 64) | grep `useGenerateAiSummary` | TRUE — no third consumer |
| no other `generate({...})` callsite lacking `rescoreRequested` survives F3 | grep | TRUE — other `jobApplicationId: jobApplication.id` hits (ReviewKit, JobApplicationSidebarActions) use different hooks, not `GenerateParams` |
| `AiSummaryState.tsx`'s own `generate({ jobApplicationId })` at line 33 (compile hazard once required) | Read `:33` | TRUE — removed by deletion |

## Completeness (SPEC 2.5 / 2.6)

- F4.5: condition narrows to `statusValue === "current"` alone; everything inside byte-for-byte. COVERED.
- F5.1: `git rm` only `AiSummaryState.tsx` — scoped deletion (known-failure #23). COVERED.
- F5.2: TypeScript compile check after F3–F5. COVERED.
- Atomicity: F3 (required field) + F4 (PlatoTab updated) + F5 (dead file removed) land together — the only two `GenerateParams` consumers are handled, no non-compiling intermediate state (ordering constraint HARD). COVERED.

## Findings
- No issues found.

## Amendments Applied
- None.
