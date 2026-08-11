# Angle 5: Frontend Data Flow — Round 1

## Checks performed

1. Verified preview response shape against TypeScript interface
2. Verified amount formatting (cents to dollars)
3. Verified `AI_CREDIT_PACK_DISPLAY_NAMES` and `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` contain all needed keys
4. Verified `prettyDate` import path
5. Verified `isLoading` / `disabled` prop threading (known failure pattern #11)
6. Verified query invalidation keys against existing hooks
7. Verified error toast pattern
8. Verified `removeModal()` usage on cancel and success paths
9. Verified `currentCredits` derivation
10. Verified `Styled` pattern against modal analogs

## Findings

### F1: Styled component pattern mismatch between spec and modal analogs — LOW (informational)

**Location:** SPEC.md line 447

**Problem:** The spec says the new modal should use `let Styled: any; Styled = {};` (matching `AiCreditSubscription.tsx` lines 356-357). But both existing modal analogs (`CancelAiCreditSubscriptionConfirmModal.tsx` line 50 and `PurchaseAiCreditTopUpConfirmModal.tsx` line 38) use `const Styled: any = {};`.

The spec explicitly says the structural analog for the modal is `CancelAiCreditSubscriptionConfirmModal.tsx` and `PurchaseAiCreditTopUpConfirmModal.tsx`. The `let` pattern is used in the parent page component (`AiCreditSubscription.tsx`), not in modals.

**Severity:** LOW — both patterns work identically. The implementer should follow whichever the modal analogs use (`const`), but this is a style preference, not a functional issue. No spec amendment needed.

### F2: `isLoading` prop threading — spec correctly includes it — PASS

The spec's modal props include `isLoading: boolean` and the modal description says "Confirm" button. The spec's `handleSelectTier` passes `isLoading={isCommittingChange}`. The cancel modal analog has `disabled={isLoading}` on its confirm button. The spec follows known failure pattern #11 correctly. PASS.

### F3: Query invalidation includes `aiCreditCustomerSubscription` — correct deviation from portal hooks — PASS

The portal hooks invalidated `currentOrganization` + `organizationAiCreditPurchase`. The new commit hook invalidates `organizationAiCreditPurchase` + `organizationAiCreditBalance` + `aiCreditCustomerSubscription`. This is correct: the portal flow changed the org's payment method (requiring `currentOrganization` invalidation), but the new flow does not. The new flow changes the subscription (requiring `aiCreditCustomerSubscription` invalidation) and may change the credit balance (requiring `organizationAiCreditBalance` invalidation). PASS.

## Verdict

0 MED or higher findings. PASS for this angle.
