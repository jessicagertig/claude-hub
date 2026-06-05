# Investigation — Note #9B: AI credit pack bugs (from live flow testing)

> Source: a prior agent's flow-test. Per Jessica, ONLY the bugs + the real lookup keys/pack names/credit amounts are trusted. The agent's file-lists, line numbers, and proposed fixes are NOT imported — every structural site below is to be reinvestigated when 9B is worked.

## Real packs (trusted — confirmed by Jessica)
| Lookup key | Type | Credits | Price (Stripe, do NOT hardcode) |
|---|---|---|---|
| ai_credit_pack_top_up_small | one-off | 100 | $15 |
| ai_credit_pack_top_up_large | one-off | 1000 | $79 |
| ai_credit_pack_subscription_small_monthly | subscription | 500/mo | $29/mo |
| ai_credit_pack_subscription_large_monthly | subscription | 2000/mo | $99/mo |
Fabricated (current) keys: `ai_credits_{starter,growth,scale}_{one_off,subscription}` (50/150/500) — none exist in Stripe. Subscription products are standalone (not bundled with main plan).

## 9B-1 — wrong identifiers (verified)
- Backend registry `AiCreditPacks.CREDIT_PACKS_BY_LOOKUP_KEY` (config/initializers/ai_credit_packs.rb) holds the fabricated keys + 50/150/500. (Moving onto OrganizationAiCreditPurchase = note #6A.)
- Frontend `AccountBillingAiCredits.tsx` `SUBSCRIPTION_TIERS`/`TOP_UP_TIERS` use the fabricated keys (`ai_credits_{starter,growth,scale}_*`) with 50/150/500 credits; blurbs describe credits, no prices. Specs reference the fabricated keys. (Re-verified against committed baseline after the prior agent's working-tree changes were reverted.)

## 9B-2 — no prices shown, no Stripe fetch (verified, baseline)
- `AccountBillingAiCredits.tsx` blurbs show credit amounts only, NO prices; imports only useOrganizationAiCreditBalance + useAiCreditSubscription — NO Stripe price fetch. (The "$29/mo" etc. prices I first saw were the prior agent's reverted edits, not the baseline.)
- Plan-billing pattern to mirror: `BillingController#prices` (billing_controller.rb:535) → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })`; route `GET /api/v1/billing/prices` (routes.rb:174). 9B-2 = add an analogous fetch filtered to the AI credit pack lookup keys, send to FE.

## 9B-3 — AI-credit subscription clobbers main plan (verified)
- `organizations.stripe_subscription_id` is a single column (one-sub assumption); an org can now have plan + AI-credit-pack subs concurrently.
- `Organization#sync_with_stripe` (organization.rb ~538): `subscriptions.find { active/trialing } || subscriptions[0]` — NO AI-credit filter → AI pack (listed most-recent-first) wins, overwrites stripe_subscription_id/status/period/plan. Verified live.
- Also: `StripeWebhookHandlerJob` checkout.session.completed subscription-mode falls through to `attributes['stripe_subscription_id'] = object.subscription` (currently no-op only by accident — subscribe sets no stripe_checkout_session_id).
- Already-guarded paths: customer.subscription.updated/.deleted, invoice.paid (use `AiCreditPacks.subscription_key?`). Principle: scope EVERY stripe_subscription_id write + customer-subscription-list read to plan-vs-credit-pack. All write paths to be reinvestigated.

## 9B-4 — billing UI doesn't show active credits (verified render branch exists)
- `AccountBillingAiCredits.tsx` HAS a branch: `subscription?.subscriptionStatus === "active"` → shows `subscriptionCreditsPerPeriod credits / month`, plus `<AiCreditBalanceDisplay />`. "Shows nothing" is likely downstream of 9B-1 (wrong keys → no active purchase created) / 9B-3 (clobbering). Re-verify after upstream fixes.
- NOTE: #9A changes this consumer (consolidated hook + #show unwrapped shape), so 9B-4 work overlaps #9A.
