# Modal Behavior — Round 1

## Findings

- F1 [HIGH] Spec "RunPlatoReviewAllModal" says "Credit check: use `useOrganizationAiCreditBalance` ... derive `available` from `data?.totalCreditsRemaining`". But `data?.totalCreditsRemaining` uses optional chaining (`?.`). The codebase uses `||` not `??` (CLAUDE.md rule #11 bans `??`). The analog at BulkGenerateAiSummariesConfirmModal:48 uses `data?.totalCreditsRemaining || 0` — this uses optional chaining (`?.`) which IS allowed (it's the nullish coalescing `??` that's banned, not optional chaining). The `|| 0` is the analog's pattern. Verified: the spec says "derive `available` from `data?.totalCreditsRemaining`" which matches the analog. No issue — withdrawing.

- F2 [MED] Spec "RunPlatoReviewAllModal" mentions `FormContainer` with errors (from the analog), but the handoff design's `RunPlatoReviewAllModal` does NOT include `FormContainer` — it has a custom layout with `Styled.Body`, `Styled.Toggle`, `Styled.Statement`, `Styled.Actions`. The spec should clarify whether to follow the handoff's layout or the analog's `FormContainer` pattern. The analog uses `FormContainer` with `errors` state to display validation errors from `validateBulkGenerateAiSummaries`. Since the spec says to follow the analog for behavioral aspects, `FormContainer` should be used for the credit validation error display, even if the visual layout follows the handoff.

  The spec currently implies `FormContainer` (via "validate with `validateBulkGenerateAiSummaries`") but doesn't explicitly state it. Add explicit mention.

- F3 [MED] Spec "RunPlatoReviewAllModal" says "Success/error toasts via `useToastContext`" but doesn't specify the toast messages. The analog has specific toast text (BulkGenerateAiSummariesConfirmModal:77-88 for success, :93-97 for error). The spec should note that toast messages follow the analog's pattern.

## Amendments Applied

- Spec "RunPlatoReviewAllModal" section: added "Use `FormContainer` with `errors` state for credit validation error display, following `BulkGenerateAiSummariesConfirmModal`" after the credit check description
- Spec "RunPlatoReviewAllModal" section: added "Toast messages follow the analog's pattern — success shows queued/skipped/pending counts, error shows the API error message or a fallback" after the toast mention

