# Subscription-Change Code Round 2 — Fix Log

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

Round 2 found 5 deviations, all in the FRONTEND / SCREEN terminals (the model-serializer and routes-controller segments reported ZERO non-sanctioned deviations). All 5 were FIXABLE structural mismatches — none forced by the data model; nothing appended to `AGENT-WHITELIST-subscription-change.md`.

The three SCREEN findings (D1/D2/D3-SCREEN) share a single root cause: OURS derived the active-subscription display values (credits headline + per-tier button label) through a SEPARATE frontend lookup table (`AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`) that (a) was out of sync with the backend model's source-of-truth key set and (b) is a second divergent source the analog does not have. The analog derives every current-subscription display value from ONE source keyed off the live Stripe `lookupKey`. Fixed by (1) syncing the frontend table to the model and (2) deriving `currentCredits` from the same `subscriptionTiers` list the cards render from.

---

## D1 (SCREEN) — active-subscription credits headline derived from a local divergent table — FIXED

The analog derives the current plan's display rank by matching the live `currentPriceObject.lookupKey` against the SAME plan-options the cards render from (one source). OURS indexed a separate `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` table, so a live model lookupKey missing from that table produced `currentCredits = null` → blank headline.

Fix — `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:66-70`
Replaced `currentCredits = AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY[currentPlanLookupKey] ?? null` with a derivation off the already-built `subscriptionTiers` list (the same list the tier cards render from): `currentSubscriptionTier = subscriptionTiers.find((tier) => tier.lookupKey === currentPlanLookupKey)` → `currentCredits = currentSubscriptionTier ? currentSubscriptionTier.credits : null`. This mirrors the analog matching `currentPriceObject.lookupKey` against the same plan options the cards use — a single source. If a tier card renders, its credits are now guaranteed available to the headline. Removed the now-unused `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` import (`AiCreditSubscription.tsx:26`). `?? null`/no-fabricated-fallback preserved (`currentCredits` is `null` only when not subscribed / no matching tier).

## D2 (SCREEN/DATABASE) — frontend credits table out of sync with the backend model key set — FIXED

The frontend `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` defined `ai_credit_pack_subscription_small/medium/large_monthly` + `ai_credit_pack_top_up_medium` and lacked ALL `plato_ai_credit_subscription_*` keys, while the backend model `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (`organization_ai_credit_purchase.rb:4-57`, the source of truth feeding `prices`) defines the `plato_*` keys + `ai_credit_pack_{subscription_small,subscription_large,top_up_small,top_up_large}` (no `_medium`). A live Stripe subscription on a `plato_*` price (a real model key surfaced by `#prices`) reached the SCREEN unresolved.

Fix — `app/javascript/shared/lib/planHelpers.ts:68-100`
Rewrote `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` and `AI_CREDIT_PACK_DISPLAY_NAMES` to mirror the backend model's `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` key set + credit values exactly: production keys `plato_ai_credit_top_up_small/medium/large` (100/500/1000) and `plato_ai_credit_subscription_small/medium/large` (500/1000/2000); development keys `ai_credit_pack_top_up_small/large` (100/1000) and `ai_credit_pack_subscription_small/large_monthly` (500/2000). Dropped the frontend-only `ai_credit_pack_top_up_medium` and `ai_credit_pack_subscription_medium_monthly` (the model defines neither; they can never be returned by `#prices`, which lists by `OrganizationAiCreditPurchase.ai_credit_lookup_keys`). Added a comment documenting the table MUST track the model. Both tables are consumed only inside `planHelpers.ts` (`aiCreditPrices` iterates the keys) — grep-verified no external consumers of the dropped keys, so `subscriptionTiers`/`topUpTiers` now surface every model subscription/top-up tier. The credits-table mechanism + `ai_credit_*` naming remains (SANCTIONED #5); only the divergent key SET was corrected.

## D3 (SCREEN) — per-tier change-button label degraded to "Change plan" on a table miss — FIXED (transitively)

The label `deriveTierButtonText(isSubscribed, currentCredits, tier.credits)` (`AiCreditSubscription.tsx:284`) returns "Change plan" whenever `currentCredits == null`, so a missing live lookupKey (D1/D2) degraded every tier label for a subscribed user. With D1 sourcing `currentCredits` from `subscriptionTiers` and D2 syncing the table to the model, a subscribed user's `currentPlanLookupKey` now always resolves to a tier and `currentCredits` is non-null, so `deriveTierButtonText` produces the correct Upgrade/Downgrade/Change-plan labels. No change to `aiSubscriptionHelpers.ts:30-39` was required — its `currentCredits == null` branch now only fires when not subscribed, matching the analog (a subscribed user always resolves a current plan). The credits-rank comparison is the AI-domain analog of `getPlanButtonText`'s `jobLimit` comparison (no job limits on credit plans — SANCTIONED #3).

## D1 (MED, frontend) — no `cancelAtPeriodEnd` display state derived from the live subscription — FIXED

The analog renders a distinct live-subscription-derived block when `currentSubscription?.cancelAtPeriodEnd` is true: `prettyDate(currentSubscription.cancelAt)` ("scheduled to cancel on {date}", `AccountBillingPlans.tsx:384-396`). OURS read neither field and unconditionally rendered "Renews {date}" + the "Cancel subscription" affordance whenever subscribed, so after OURS' own cancel flow set `cancel_at_period_end` on Stripe the banner gave no pending-cancellation indication.

Fix —
- `AiCreditSubscription.tsx:72-73` — derived `cancelAtPeriodEnd = currentSubscription?.cancelAtPeriodEnd` and `cancelAt = currentSubscription?.cancelAt` off the live Stripe object (the controller renders the raw subscription; `apiGet` camelCases Stripe's `cancel_at_period_end`/`cancel_at` — same fields the analog reads at `AccountBillingPlans.tsx:30`).
- `AiCreditSubscription.tsx:266-273` — passed `cancelAtPeriodEnd` and `cancelAt` to `<AiSubscriptionStatus>`.
- `AiSubscriptionStatus.tsx:9-51` — added `cancelAtPeriodEnd?`/`cancelAt?` props; when `cancelAtPeriodEnd` is true the active-subscription block renders `Scheduled to cancel on {formatResetDate(cancelAt)}` (via the existing `prettyDate`-wrapping `formatResetDate`, mirroring the analog's `prettyDate(currentSubscription.cancelAt)`) instead of the "Renews {date}" line, and the "Cancel subscription" button is suppressed (`isSubscribed && !cancelAtPeriodEnd`) since cancellation is already scheduled.

## D2 (LOW, frontend) — tier-card change button omitted the live-fetch `loading` prop — FIXED

The analog's change `Styled.Button` carries `loading={isLoadingButton}` (= `isFetchingStripeCustomerSubscription`, `PlanCard.tsx:209`, threaded from `AccountBillingPlans.tsx:453`) IN ADDITION to `disabled={isLoading}` (mutation flags). OURS' `AiSubscriptionTierCard` button had only `disabled={isLoading}`.

Fix —
- `AiSubscriptionTierCard.tsx:18-32` — added `isLoadingButton?` prop (default `false`).
- `AiSubscriptionTierCard.tsx:61-65` — added `loading={isLoadingButton}` to the change `Styled.Button` (a `SmallButton` → `Button`, which supports `loading`, verified `Button/index.js:18`), alongside the existing `disabled={isLoading}` — structurally matching the analog's button.
- `AiCreditSubscription.tsx:289` — threaded `isLoadingButton={isFetchingAiCreditCustomerSubscription}` to the card (mirrors the analog's `isLoadingButton={isFetchingStripeCustomerSubscription}`). Note: as the finding observed, OURS still early-returns the whole component while this fetch flag is true (`AiCreditSubscription.tsx:260-262`, identical to the analog), so the button-`loading` terminal is effectively unreachable in BOTH — but the second SCREEN terminal of the fetch flag now exists structurally as in the analog.

---

## Whitelist

No new entries appended to `AGENT-WHITELIST-subscription-change.md`. Every Round 2 deviation was a genuine structural mismatch not forced by the data model, and all were fixed in OUR code.
