# Round 3 — Fix Log (subscription-change flow, OURS vs analog)

Four deviations from the round-3 adversarial reviewers. One was a genuine structural mismatch (FIXED in code); three were forced by the AI-credit data model / product (WHITELISTED with rationale appended to `AGENT-WHITELIST-subscription-change.md`).

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`. NO git operations performed. Edits via Edit only.

---

## D1 (routes-controller) — EXTRA `#show` action → WHITELISTED (W3)

- **Finding:** OURS has a `#show` action (`organization_ai_credit_purchases_controller.rb:4-13`, route `config/routes.rb:190`) rendering the persisted `OrganizationAiCreditPurchase` row via serializer, gated on the local `subscription_status` column. The analog `BillingController` has no `show`.
- **Disposition:** WHITELISTED (W3). Verified `#show` is consumed by `AccountBillingAiCredits.tsx:39` (`useOrganizationAiCreditPurchase` → `GET /ai_credit_purchases`) — a DIFFERENT view OUTSIDE the audited subscription-change flow. `AiCreditSubscription.tsx` (the audited flow) does NOT import `useOrganizationAiCreditPurchase`; it gates the active-subscription display on the LIVE-Stripe `customer_subscription` payload (`AiCreditSubscription.tsx:53-70`), never on `#show`. So `#show` is NOT on the symptom path and does not reintroduce the column-gating defect. Deleting it to match the analog would break `AccountBillingAiCredits.tsx` — a regression outside the audited flow. Forced by the persisted-purchase-row data model (the analog's `Organization` is always present and needs no "fetch the subscription purchase row" endpoint). No code change.

## D1 (terminals) — current-subscription credits sourced from local `lookupKey → credits` table → WHITELISTED (W4)

- **Finding:** The active-subscription credits headline (`AiSubscriptionStatus.tsx:35`) resolves `currentCredits` (`AiCreditSubscription.tsx:66-70`) via the local hardcoded `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` table (`planHelpers.ts:74-87`, injected `planHelpers.ts:115`). The analog has no local price-id↔credits table.
- **Disposition:** WHITELISTED (W4). Credits-per-period is AI-domain metadata NOT carried on the Stripe price object (no `tiers`/`unitAmount`→credits field on a flat per-period grant), and unlike the analog whose limits are derived backend-side from the persisted plan alias via `PlanFeatureGate`, the AI-credit credit count has no Stripe-resident or alias-resident source. Removing the table (to match the analog) leaves the headline with no data source. Kept in sync with the backend model's `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (SANCTIONED #5 family). Round-2 D1/D3 (nullable `?? null` lookup) already RESOLVED; this entry whitelists only the table's existence. No code change.

## D2 (terminals) — `AiCreditSubscription` rendered unconditionally / dual-mode component → WHITELISTED (W5)

- **Finding:** `OrganizationAiBilling.tsx:30` renders `<AiCreditSubscription/>` UNCONDITIONALLY; the subscribed/unsubscribed fork is relocated DOWN into a single dual-mode component gated on live-Stripe `isSubscribed` (`AiCreditSubscription.tsx:59-60`, `AiSubscriptionStatus.tsx:32-52`, subtitle `:283`). The analog gates `AccountBillingPlans` in the PARENT via a 3-way `hasActiveSubscription` ternary with `AccountBillingPlansFreeTrial`/`AccountBillingPlansUnsubscribed` siblings (`AccountBilling.tsx:122-134`).
- **Disposition:** WHITELISTED (W5). The analog's parent 3-way split exists because the main plan has a free-trial product variant and a distinct unsubscribed component; the AI-credit subscription has NEITHER (no AI-credit free trial; the unsubscribed state is rendered inside the same `AiSubscriptionStatus`, not a sibling). Reproducing the analog would require inventing siblings with no product counterpart. The unsubscribed state IS rendered (not dropped), and `isSubscribed` is derived from the LIVE Stripe object — the exact terminal whose column-gated mismatch produced the original symptom, now correct. Forced product simplification; data-row scoping driving `isSubscribed` is SANCTIONED #4. No code change.

## D3 (terminals) — `prices` Stripe call's unused `expand: ['data.product']` → FIXED

- **Finding:** `organization_ai_credit_purchases_controller.rb:219` called `Stripe::Price.list(lookup_keys: …, active: true, expand: ['data.product'])`. The analog `prices` (`billing_controller.rb:537`) expands `['data.tiers']`. `expand: ['data.product']` is an EXTRA with no analog basis and NO consumer — `aiCreditPrices` (`planHelpers.ts:104-124`) reads only `lookupKey`/`type`/`id`/`unitAmount`/`currency`/`recurring`, never `price.product` (display names come from the local `AI_CREDIT_PACK_DISPLAY_NAMES` table). Grep confirmed zero `.product` reads on the prices payload across `accountPlatoAi/`, `planHelpers.ts`, `aiSubscriptionHelpers.ts`.
- **FIXED:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:219` — changed `expand: ['data.product']` → `expand: ['data.tiers']` to mirror the analog's `prices` expand exactly. The `lookup_keys:` domain filter and dropped `limit` are domain-forced (SANCTIONED #5 family) and left intact. AI-credit prices are flat (not tiered), so `data.tiers` is empty and equally has no consumer — but it matches the analog's expand verbatim, eliminating the unused-no-analog divergence.

---

## Summary

| Deviation | Disposition | Location |
|---|---|---|
| D1 EXTRA `#show` action | WHITELISTED (W3) | `organization_ai_credit_purchases_controller.rb:4-13`, `config/routes.rb:190` |
| D1 local credits table for current sub | WHITELISTED (W4) | `planHelpers.ts:74-87/115`, `AiSubscriptionStatus.tsx:35`, `AiCreditSubscription.tsx:66-70` |
| D2 unconditional render / dual-mode component | WHITELISTED (W5) | `OrganizationAiBilling.tsx:30`, `AiCreditSubscription.tsx:59-60/283`, `AiSubscriptionStatus.tsx:32-52` |
| D3 unused `expand: ['data.product']` | FIXED | `organization_ai_credit_purchases_controller.rb:219` |

One code fix (D3). Three forced deviations whitelisted (W3-W5).
