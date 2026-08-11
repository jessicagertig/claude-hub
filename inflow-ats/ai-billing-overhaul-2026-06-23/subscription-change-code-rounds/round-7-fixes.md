# Round 7 — Fix Log (FIX agent)

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`. Analog SPEC: `traces/subscription-change-analog-trace.md`. Read fresh: `SANCTIONED-subscription-change.md` (#1-5) + `AGENT-WHITELIST-subscription-change.md` (W1-W5).

3 deviations addressed. All 3 FIXED (genuine structural mismatches, none forced by the data model). No new whitelist entries.

---

## D1 (frontend) — `deriveTierButtonText` routed a SUBSCRIBED org to the UNSUBSCRIBED label `"Subscribe"` on a credits lookup-miss

**FIXED** — `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts:35-36`

Before:
```ts
if (!isSubscribed || currentCredits == null) return "Subscribe";
return tierCredits > currentCredits ? "Upgrade" : "Change plan";
```
After:
```ts
if (!isSubscribed) return "Subscribe";
return currentCredits != null && tierCredits > currentCredits ? "Upgrade" : "Change plan";
```

Analog structure (`planLookups.js:586-619`): unsubscribed labels (`"Start plan"`/`"Start free trial"`) come ONLY from `getUnsubscribedPlanButtonText`, gated strictly on subscription STATE (the not-`hasActiveSubscription` branch). For a SUBSCRIBED org, `getPlanButtonText`'s FIRST guard `if (!currentPlan || !targetPlan) return "Change plan"` (`:607-609`) handles the lookup-miss (subscribed but live `currentPlanLookupKey` matches no plan option) → SUBSCRIBED fallback `"Change plan"`, never the unsubscribed label.

OURS conflated the two regimes: the `|| currentCredits == null` disjunct routed a subscribed org (`isSubscribed === true`) to `"Subscribe"` whenever `currentCredits` was null — which is exactly the lookup-miss case (`AiCreditSubscription.tsx:66-70`, live `currentPlanLookupKey` absent from `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`). Produced a self-inconsistent SCREEN (`isSubscribed`-true `"Active subscription"` banner + blank credits headline + `"Subscribe"` tier buttons). Fix gates `"Subscribe"` on `!isSubscribed` ALONE (matching the analog's state-only unsubscribed gate) and falls through to `"Change plan"` for the subscribed-with-null-credits case (matching the analog's `!currentPlan → "Change plan"` fallback). The `!isSubscribed → "Subscribe"` first disjunct is unchanged (W5: AI-domain analog of `getUnsubscribedPlanButtonText`). NOT a forced deviation: the analog's own subscribed fallback is `"Change plan"`, so the fix breaks no correct behavior. (W4's "round-2 D1/D3 RESOLVED" note was stale — this instance was still live; now actually resolved.)

---

## D1 (controller) — `#prices` authorized a different policy METHOD than the analog

**FIXED** — `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:217`; `app/policies/organization_ai_credit_purchase_policy.rb` (added `prices?`)

Before: `authorize :organization_ai_credit_purchase, :show?`
After:  `authorize :organization_ai_credit_purchase, :prices?`

Analog (`billing_controller.rb:536`): `authorize :billing, :prices?` → `BillingPolicy#prices?` → `is_org_user?` (org-USER gate). The analog has a DEDICATED `prices?` policy method for the prices action. OURS reused the `#show` action's `:show?` method for the `#prices` action — a structural mismatch (different policy method than the analog's `prices?`).

Fix adds `prices?` to `OrganizationAiCreditPurchasePolicy` (def `prices? = is_org_user?`, mirroring `BillingPolicy#prices?`) and points `#prices` at it. The policy CLASS stays `:organization_ai_credit_purchase` (the sanctioned AI-credit domain policy, SANCTIONED #2/#5 — not the analog's `:billing` class). Only the method-name structure is matched. Gate level is unchanged (`is_org_user?` both before and after — `show?` and `prices?` both resolve to `is_org_user?`), so no authorization-behavior regression; the change is purely the analog's structural separation of a dedicated `prices?` policy method. NOT forced.

---

## D2 (controller) — `#prices` `Stripe::Price.list` dropped the analog's `limit: 20`

**FIXED** — `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:219`

Before: `Stripe::Price.list(lookup_keys: OrganizationAiCreditPurchase.ai_credit_lookup_keys, active: true, expand: ['data.tiers'])`
After:  `Stripe::Price.list(lookup_keys: OrganizationAiCreditPurchase.ai_credit_lookup_keys, active: true, limit: 20, expand: ['data.tiers'])`

Analog (`billing_controller.rb:537`): `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })`. OURS kept the sanctioned `lookup_keys:` domain scoping (SANCTIONED #5 / W4) but DROPPED the analog's explicit `limit: 20` with no replacement. With Stripe's default page limit of 10 and OUR `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` table holding exactly 10 lookup keys, the result sat at the default page boundary — adding an 11th key would silently truncate a SCREEN price card. The dropped `limit` is not sanctioned (SANCTIONED #5 covers only the `lookup_keys:` naming/scoping, not the bounded-list argument). Restored `limit: 20` to match the analog's bounded-list structure. NOT forced.

---

## Whitelist appends

None. All three were genuine structural mismatches fixable in OUR code without breaking correct behavior; none were forced by the data model / product.
