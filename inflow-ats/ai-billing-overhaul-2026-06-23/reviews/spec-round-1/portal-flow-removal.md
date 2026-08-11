# Angle 6: Portal Flow Removal — Round 1

## Checks performed

1. Verified all three controller actions exist at claimed line numbers
2. Verified all three route definitions exist
3. Verified frontend hooks and functions exist and are exported
4. Verified `handleChangeSubscriptionViaStripePortal`, `handleUpdateWithPaymentMethod`, `handleSelectTier` exist in `AiCreditSubscription.tsx`
5. Verified `redirectToStripe` function and all its callers
6. Checked for other files that import/reference the removed identifiers

## Findings

### P1: Removing `redirectToStripe` will break `purchaseTopUpCheckoutSession` — HIGH

**Location:** SPEC.md line 647

**Problem:** The spec says "Remove `redirectToStripe` function (no longer needed — no Stripe portal redirect)." However, `redirectToStripe` is NOT only used by the portal flow. It is also called by `purchaseTopUpCheckoutSession` at line 231 of `AiCreditSubscription.tsx`:

```tsx
const purchaseTopUpCheckoutSession = (pack: AiCreditPack) => {
  purchaseCheckoutSession(
    { stripePriceLookupKey: pack.lookupKey },
    {
      onSuccess: (data: { url: string; sessionId: string }) => {
        redirectToStripe({ url: data.url });
      },
```

`redirectToStripe` is a simple wrapper: `const redirectToStripe = (data: { url: string }) => { window.location.href = data.url; };`

Removing it would cause a build error — `purchaseTopUpCheckoutSession` references an undefined function.

**Fix:** Remove the spec instruction to delete `redirectToStripe`. It must be kept because the top-up checkout session flow still uses it. The spec should say: "Remove `handleChangeSubscriptionViaStripePortal` function entirely", "Remove `handleUpdateWithPaymentMethod` function entirely", but keep `redirectToStripe` because it is used by the top-up checkout flow.

## Verdict

1 HIGH finding (P1). Requires spec amendment.
