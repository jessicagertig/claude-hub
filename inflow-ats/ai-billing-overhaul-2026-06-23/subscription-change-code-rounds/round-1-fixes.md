# Subscription-Change Code Round 1 — Fix Log

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Summary

The root symptom (active subscription does not display) and its 4 frontend findings were one defect: the active-subscription DISPLAY was gated on the LOCAL `subscription_status` column (the `#show` row) instead of the live Stripe subscription. The analog (`AccountBillingPlans.tsx`) derives every active-subscription render from the live `currentSubscription` object returned by `customer_subscription`. Fixed by sourcing the display state from `currentSubscription`. The controller's extra `Stripe::Subscription.retrieve` item-id fallback (un-analog) was removed and the analog's top-of-method param guard restored.

---

## Frontend display-sourcing (F1–F4, D1, D6, the symptom)

### F1 (BLOCKER) — `isSubscribed` gated on local `subscription_status` column — FIXED
`app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:60-61`
Was `subscription?.subscriptionStatus === "active" || ...` (local `#show` row). Now `currentSubscription?.status === "active" || currentSubscription?.status === "past_due"` — derived from the live Stripe object (matching the analog's `currentSubscription.status` gating). Removed the `useOrganizationAiCreditPurchase()` hook call and its import (no longer the display source).

### F2 (BLOCKER) — displayed current credits derived from local column — FIXED
`AiCreditSubscription.tsx:58-65`
Was `isSubscribed ? subscription?.subscriptionCreditsPerPeriod : null` (local column). Now derives from the live subscription's price lookupKey: `currentPriceObject = currentSubscription.items.data[0].price` → `currentPlanLookupKey = currentPriceObject?.lookupKey` → mapped through `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` (`planHelpers.ts:68`). Matches the analog deriving the current amount from `currentSubscription.items.data[0].price`. Added the `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` import. Used `?? null` (not `|| 0`) per the no-fabricated-fallback rule.

### F3 (BLOCKER) — renewal/period-end derived from local column — FIXED
`AiCreditSubscription.tsx:66` (`currentPeriodEnd = currentSubscription?.currentPeriodEnd`), consumed at `:263` (AiSubscriptionStatus `periodEndsAt`) and `:249` (cancel modal `periodEndsAt`).
Was `subscription?.subscriptionCurrentPeriodEnd` (local ISO column). Now `currentSubscription?.currentPeriodEnd` (live Stripe Unix timestamp), matching the analog reading period/renewal dates off `currentSubscription` (e.g. `currentSubscription.cancelAt`, `.trialEnd`).
Cascade — period-end is now a Unix timestamp, not an ISO string:
- `aiSubscriptionHelpers.ts:1-6` — `formatResetDate` now takes `number | null` and calls `prettyDate` (Unix-timestamp formatter, `time.ts:43`, `datetime * 1000`) instead of `prettyDateSimpleISO` (ISO formatter). This mirrors the analog's `prettyDate(currentSubscription.trialEnd)`.
- `AiSubscriptionStatus.tsx:12` — `periodEndsAt?` prop type changed `string | null` → `number | null`.
- `CancelAiCreditSubscriptionConfirmModal.tsx:12,21-23` — `periodEndsAt` prop type `string | null` → `number | null`; formatting changed from `new Date(periodEndsAt).toLocaleDateString()` (ISO-string assumption) to `prettyDate(periodEndsAt)` (Unix timestamp). Added `prettyDate` import.

### F4 (HIGH) — `deriveTierButtonText` inputs were local-column-derived — FIXED (transitively)
`AiCreditSubscription.tsx:278` calls `deriveTierButtonText(isSubscribed, currentCredits, tier.credits)`. Both `isSubscribed` (F1) and `currentCredits` (F2) now source from the live `currentSubscription`, so the Upgrade/Downgrade/Change-plan/Subscribe labels are now computed from live-subscription state. The finding explicitly states the inputs are "corrected once F1/F2 source from currentSubscription"; no further change to `aiSubscriptionHelpers.ts:30-39` was needed. The per-tier `isCurrent` gate (`AiCreditSubscription.tsx:272`) already read `currentSubscription?.plan?.id === tier.priceId` (live), matching the analog's `currentSubscription?.plan?.id === plan.priceId`.

### D1 / D1(SCREEN) / D6 — display sourced from serialized local columns — FIXED
Same fix as F1–F4 above. The active-subscription banner, the "Change your plan" subtitle (`AiCreditSubscription.tsx:268`, gated on `isSubscribed`), `currentCredits`, and `periodEndsAt` now all derive from the live Stripe `currentSubscription`. The serializer's `subscription_status`/`subscription_credits_per_period`/`subscription_current_period_end` columns are no longer load-bearing for the active-subscription display. The serializer itself was left unchanged (those columns remain serialized for other consumers; they are simply no longer the display source — matching the analog where `currentOrganization.plan` exists but the active-subscription render comes from `currentSubscription`).

---

## Controller item-id deviation (F1/F2 controller findings, D2, D3, D4)

### D2 / D4 — `change_subscription_portal_session` extra Stripe retrieve + guard moved below — FIXED
`app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (was `:244-247`)
Removed the un-analog `params[:subscription_item_id].presence || Stripe::Subscription.retrieve(...).items.data.first.id` fallback (an extra STRIPE terminal the analog lacks). Restored the analog's structure: third entry guard `raise StandardError, 'Subscription item ID is missing.' unless params[:subscription_item_id].present?` at the top with the other two guards, then plain `subscription_item_id = params[:subscription_item_id]` (matching `billing_controller.rb:274` + `:288`).

### D3 — `update_payment_method_and_subscription_portal_session` same deviation — FIXED
Same controller (was `:299-302`). Removed the identical fallback + restored the top-of-method param guard and plain `subscription_item_id = params[:subscription_item_id]` (matching `billing_controller.rb:337` + `:339`).

---

## Sanctioned / not-fixed

### D5 — `customer_subscription` `subscription_status: [:active, :past_due]` row filter — NOT FIXED (sanctioned)
Covered by `SANCTIONED-subscription-change.md` #4: "Live-subscription endpoint retrieves by `purchase.stripe_subscription_id` (scoped to the org's active/past_due subscription-kind purchase)". The active/past_due scoping is the explicitly-sanctioned mechanism for selecting WHICH purchase row holds the `stripe_subscription_id` (the analog has one org→one subscription and needs no such scoping). The active-subscription column is webhook-written on subscription creation, so an active Stripe sub carries `subscription_status: active`. Left unchanged.

### D6 — `#show` `subscription_status` filter + serialized local row — NOT FIXED at the endpoint (sanctioned), defect resolved at the source
The `#show` row scoping is covered by SANCTIONED #2 (operate on the `OrganizationAiCreditPurchase` record) and #4 (active/past_due scoping). The actual defect — the FRONTEND deriving display from this local row — is fixed above (F1–F4/D1). The serializer and `#show` action were left intact.

No new entries appended to `AGENT-WHITELIST-subscription-change.md` — every deviation was either FIXABLE (fixed) or already covered by an existing SANCTIONED/whitelist entry.
