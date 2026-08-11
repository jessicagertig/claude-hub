# item2-regenerate-gating-and-dead-code-deletion — Round 1

Trace: SPEC 2.5-2.6 → PlatoTab.tsx:247-271 → AiSummaryState.tsx (delete) → grep app/ + cypress/

## Source-accuracy checks (confirmed)
- `PlatoTab.tsx:247` = `} else if (statusValue === "current" && fullSummary?.stale) {`. CONFIRMED. Becomes `} else if (statusValue === "current") {`.
- Inside the branch (unchanged): credits check `isLoadingCredits || totalRemaining > 0` (:248) choosing Regenerate button vs Buy-credits fallbacks (admin nav button :254-265 / non-admin alert modal :266-269); Regenerate `<Button … loading={buttonLoading} disabled={buttonLoading}>` (:250) — the `loading`+`disabled` PAIRING is present (pipeline known-failure #11 / HARD sub-rule satisfied). CONFIRMED.
- `AiSummaryState.tsx` exists; its only `generate({ jobApplicationId }, …)` call (:32-33) lacks `rescoreRequested` → becomes a compile error once `GenerateParams.rescoreRequested` is required. Deletion removes it. CONFIRMED.
- Grep `AiSummaryState` across `app/javascript` + `cypress`: only self-references inside `AiSummaryState.tsx` (function def, default export, emotion labels). ZERO external importers/references. SPEC 2.6 "zero references" CONFIRMED independently.
- Grep `useGenerateAiSummary` importers: only `PlatoTab.tsx` and `AiSummaryState.tsx`. After deletion + PlatoTab callsite updates, no dangling `generate({ jobApplicationId })` without `rescoreRequested`. CONFIRMED.

## Findings
- No issues found.

## Amendments Applied
- None.

## Rejected as false positives (guardrails / known-failures)
- No scope creep in the deletion: `AiSummaryState.tsx` is the only file named for deletion (SPEC 2.6); nothing else is removed alongside it (known-failure #23). Confirmed the SPEC scopes it correctly.
- Regenerate button `loading` without `disabled` would be a defect (known-failure #11), but the SPEC keeps the existing `loading={buttonLoading} disabled={buttonLoading}` pairing "exactly as-is." Not flagged.
