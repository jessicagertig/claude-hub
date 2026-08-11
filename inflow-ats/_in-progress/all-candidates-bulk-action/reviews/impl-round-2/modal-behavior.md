# Modal Behavior — Round 2

## Findings

No issues found.

Verified `RunPlatoReviewAllModal` against `BulkGenerateAiSummariesConfirmModal` analog:
- Mutation ownership: modal owns via `useBulkGenerateAllStagesAiSummaries` (:32) — matches analog (:43)
- `dismissModalWithAnimation(() => onCancel)` used for close (:43, :76) — matches analog (:53, :90)
- Credit balance: `useOrganizationAiCreditBalance` (:37), `available` derived from `data?.totalCreditsRemaining || 0` (:38) — matches analog (:47-48)
- Shortfall: `Math.max(0, candidatesToScoreCount - available)` (:40), rendered when `shortfall > 0 && candidatesToScoreCount > 0` (:139) — matches analog (:50, :161)
- Validation gate: `validateBulkGenerateAiSummaries({ availableCredits: available })` (:48-49), `setErrors` on failure (:52-53) — matches analog (:58-64)
- `FormContainer` with `errors` state (:138) — matches analog (:160)
- Button `loading={isLoading}` and `disabled={isLoading || candidatesToScoreCount === 0}` (:96-97) — matches analog (:136-137)
- Toast success/error with same patterns (:62-84) — matches analog (:75-98)
- `trackEvent` on confirm (:63) — matches analog (:76)

Verified `RunPlatoAddDescriptionModal`:
- `CenterModal` with `onCancel` — correct
- `type="internalLink"` Button to `/jobs/${job.id}/setup/description` — correct route
- No mutation — correct for a gate modal

Verified `RunPlatoNoCandidatesModal`:
- Content branches on `autoGenerateEnabled` — correct
- Uses `Link` from `react-router-dom` for inline links (`:57, :61`) — correct, not raw `<a href>`
- Routes: `/hire/settings/plato-ai` (:57) and `/jobs/${job.id}/setup/ai` (:61) — correct
- Primary button to `/jobs/${job.id}/setup/description` — correct route

Verified `useRunPlatoCtaModals`:
- Handler naming: `handleOnClickRunPlato` for top-level click (:55) — matches `handleOnClick*` convention
- Branch handlers: `handleNoDescription`, `handleNoCandidates`, `handleReviewAll` — internal routing, not click handlers, shorter names correct per spec
- `trackEvent` calls with appropriate event names (:24, :30, :38) — correct
- Hook does NOT hold mutation state — correct per decision 13
