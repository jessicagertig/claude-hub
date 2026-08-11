# Modal Behavior — Round 1

## Findings

No issues found.

Verified against `BulkGenerateAiSummariesConfirmModal` analog:
- **Mutation ownership:** `RunPlatoReviewAllModal` owns mutation via `useBulkGenerateAllStagesAiSummaries` (:32) — matches analog (:43)
- **Close pattern:** `dismissModalWithAnimation(() => onCancel)` at (:43, :76) — matches analog (:53, :90)
- **Credit check:** `useOrganizationAiCreditBalance` at (:37-38) → `available` → `shortfall` — matches analog (:47-50)
- **Validation gate:** `validateBulkGenerateAiSummaries` at (:48-54) — matches analog (:58-64)
- **Loading/disabled:** `loading={isLoading} disabled={isLoading || candidatesToScoreCount === 0}` at (:96-97) — matches analog (:136-137)
- **Toasts:** success toast with queued/skipped/pending counts (:64-75), error toast with API error (:78-84) — matches analog (:75-98)
- **FormContainer with errors:** (:138) — matches analog (:160)
- **trackEvent:** (:63) — matches analog (:76)
- **Shortfall warning:** conditional rendering at (:139-145) — matches analog (:161-167)
- **AddDescription modal:** receives `onCancel` from hook, uses `type="internalLink"` with correct route `/jobs/${job.id}/setup/description`
- **NoCandidates modal:** branches on `autoGenerateEnabled`, uses `Link` from `react-router-dom` for inline links (`:57-62`), correct routes `/hire/settings/plato-ai` and `/jobs/${job.id}/setup/ai`
