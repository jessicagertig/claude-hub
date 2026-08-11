# Round 6 — Fix log (OURS vs analog trace)

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`. No git commands run; edits via Edit only. `spec/` untouched.

---

## D1 — Missing the analog's `hasActiveSubscription` create-vs-change ACTION fork — FIXED

**Analog (trace item 16; `PlanCard.tsx:98-103`):** `handleOnClickSubscriptionAction` branches on `hasActiveSubscription`: TRUE → `handleChangeSubscription()` → `onChangeSubscription(plan)`; FALSE → `onCreateNewSubscription()`. Two distinct action terminals, `hasActiveSubscription` is a load-bearing read.

**Fix:** Reproduced the analog's action fork end to end.

- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiSubscriptionTierCard.tsx`
  - Added `onCreateNewSubscription: (tier: AiCreditTier) => void` to `AiSubscriptionTierCardProps` (`:25`) and destructured it (`:36`).
  - Added `handleOnClickSubscriptionAction` (`:38-46`) that branches on `hasActiveSubscription` (now READ): TRUE → `onSelect(tier)` (the change path); FALSE → `onCreateNewSubscription(tier)` (the create-new path). Mirrors `PlanCard.tsx:98-103`.
  - Button `onClick` changed from `() => onSelect(tier)` to `handleOnClickSubscriptionAction` (`:73`). `hasActiveSubscription` is no longer a dead prop.

- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
  - Added `handleCreateNewSubscription(tier)` (`:172-194`) that invokes the previously-dead `subscribe` mutation (`useCheckoutAiCreditPack`, destructured `:35`) with `{ stripePriceLookupKey: tier.lookupKey }`, redirecting to `data.redirectUrl` on success and toasting on error (same onSuccess/onError shape as the change handlers). This is the AI-credit-domain create-new terminal: the `checkout` controller action opens a `Stripe::Checkout::Session` (mode `subscription`) and renders `{ redirectUrl }` — the natural `onCreateNewSubscription` counterpart, distinct from the change-subscription portal path which requires an existing `subscriptionItemId`.
  - Passed `onCreateNewSubscription={handleCreateNewSubscription}` to `<AiSubscriptionTierCard>` (`:319`).

`subscribe` (`mutate` from `useCheckoutAiCreditPack`) is no longer dead; its `isSubscribing` loading flag (already in the `isLoading` combination) is now consistent with a live mutation. Result matches the analog: `!isSubscribed` → create-new checkout terminal; `isSubscribed` → change-subscription fork (`stripeDefaultPaymentMethodOnFile` portal vs payment-method path).

---

## D2 — EXTRA `"Downgrade"` button-text terminal the analog never produces — FIXED

**Analog (`planLookups.js:618`):** `getPlanButtonText` returns the lower-rank case as `"Change plan"` (`targetPlan.jobLimit > currentPlan.jobLimit ? "Upgrade" : "Change plan"`). No `"Downgrade"` literal exists anywhere in the analog.

**Fix:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts`
- `deriveTierButtonText` (`:30-37`) collapsed to `return tierCredits > currentCredits ? "Upgrade" : "Change plan";`, removing the EXTRA `if (tierCredits < currentCredits) return "Downgrade";` terminal. The lower-rank (downgrade) case now routes to `"Change plan"`, exactly as the analog's lower-jobLimit case does. The credits-vs-jobLimit rank SOURCE switch remains (SANCTIONED #3 / W4); only the divergent SCREEN literal was removed.
- Removed the now-stale `"Downgrade"` reference in `deriveTierButtonType`'s explanatory comment (`:45`). `deriveTierButtonType` behavior is unchanged: `"Change plan"` → secondary (same style `"Downgrade"` previously mapped to), so the button style is unaffected — only the text terminal now matches the analog.

---

## Whitelist additions

None. Both deviations were genuine structural mismatches fixable in OUR code without breaking correct behavior — neither was forced by the AI-credit data model or a product difference, so nothing was appended to `AGENT-WHITELIST-subscription-change.md`.
