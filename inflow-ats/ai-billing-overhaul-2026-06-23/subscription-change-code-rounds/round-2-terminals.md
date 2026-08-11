# Round 2 — TERMINALS segment (SCREEN / STRIPE / DATABASE)

Adversarial audit of OUR AI-credit subscription-change flow terminals vs the verified analog trace.
Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Files traced (chain):
`OrganizationAiBilling.tsx → AiCreditSubscription.tsx → AiSubscriptionStatus.tsx / aiSubscriptionHelpers.ts / planHelpers.ts → useOrganizationAiCreditPurchase.ts → api.ts → config/routes.rb → organization_ai_credit_purchases_controller.rb → organization_ai_credit_purchase.rb → organization_ai_credit_purchase_serializer.rb`
vs `traces/subscription-change-analog-trace.md`.

Sanctioned/whitelisted and therefore NOT flagged (verified against both lists):
- `customer_subscription` / `change_subscription_portal_session` / `update_payment_method_and_subscription_portal_session` / `continue_change_subscription_portal_session` operating on the `OrganizationAiCreditPurchase` subscription row scoped `find_by(subscription_status: [:active, :past_due])` instead of `current_organization.stripe_subscription_id` — SANCTIONED #2/#4.
- `flow_data.subscription` = `organization_ai_credit_purchase.stripe_subscription_id` — SANCTIONED #1.
- No `ValidateSubscriptionChange` / job-limit gate in `change_subscription_portal_session` and `continue_change_subscription_portal_session` — SANCTIONED #3.
- `ai_credit_*` naming, `ap` debug-string text changes — SANCTIONED #5.
- `determine_price_id` else-branch raising — WHITELIST W1.
- `continue_url` pointing at `/api/v1/ai_credit_purchases/...` — WHITELIST W2.

Verified MATCHES (no deviation): `OrganizationAiCreditPurchase#stripe_subscription` STRIPE call `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` matches analog `Organization#stripe_subscription` (`organization.rb:477`) exactly; `customer_subscription` null/happy/rescue terminal structure matches analog (`billing_controller.rb:609/:614/:615-618`); per-tier `isCurrent = currentSubscription?.plan?.id === tier.priceId` reads the live Stripe object exactly as analog `isCurrentPlan` (`AccountBillingPlans.tsx:436`); `change_subscription_portal_session` `flow_data` options block + StandardError-rescue-without-Sentry matches analog; frontend `currentSubscription`/`currentSubscriptionItemId`/`currentPriceObject`/`currentPlanLookupKey` derivations match analog `AccountBillingPlans.tsx:62-68`.

---

## D1 (SCREEN terminal) — active-subscription credits headline derives from a LOCAL hardcoded credits table, not from the live Stripe subscription

ANALOG (trace): every current-subscription SCREEN value is derived from the LIVE Stripe object returned by `customer_subscription` — `currentPriceObject = currentSubscription && currentSubscription.items.data[0].price` (`AccountBillingPlans.tsx:67`), and the current-plan display reads off that live object's `lookupKey`/price/tiers (`getPlanButtonText(currentPriceObject.lookupKey, ...)`, `currentSubscription.items.data[0].price` tiered amount). The analog has NO local price-id↔credits table — "The analog has NO local price-id↔credits/limits table — it round-trips the price id through Stripe" (trace, price-model section).

OURS: the active-subscription SCREEN headline `{currentCredits?.toLocaleString()} credits / month` (`AiSubscriptionStatus.tsx:31`, rendered only when `isSubscribed`) gets `currentCredits` from a LOCAL hardcoded TS table — `currentCredits = isSubscribed && currentPlanLookupKey ? AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY[currentPlanLookupKey] ?? null : null` (`AiCreditSubscription.tsx:62-65`), table at `planHelpers.ts:68-75`. It does NOT read the credit/tier amount off the live Stripe `currentPriceObject`. When the live subscription's `lookupKey` is not a key in `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`, `currentCredits` is `null` and the active-subscription headline renders a BLANK number ("credits / month") even though Stripe returned a fully active subscription — the same class of failure as the known symptom (active subscription does not display correctly). The model's own subscription lookup keys (`plato_ai_credit_subscription_small/medium/large`, `ai_credit_pack_subscription_*`) are NOT all present in the frontend table (see D2), so a real active subscription can land on the `?? null` branch.

file:line — `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:62-65`, `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiSubscriptionStatus.tsx:31`, table `app/javascript/shared/lib/planHelpers.ts:68-75`

---

## D2 (SCREEN/DATABASE terminal) — lookup-key tables disagree across the three sources feeding the SCREEN, so the live Stripe lookupKey can miss the credits table

ANALOG (trace): the analog keys all display/limits off ONE source of truth derived from Stripe (`PLAN_LOOKUP_MAPPING` substring match on the live `lookup_key`); there is no second, divergent client-side credits table that the live key must also appear in.

OURS: the active-subscription credits headline (D1) is keyed by the live Stripe `currentPlanLookupKey` into `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` (`planHelpers.ts:68-75`), but that table's subscription keys are `ai_credit_pack_subscription_small_monthly` / `_medium_monthly` / `_large_monthly`, while the backend model `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (`organization_ai_credit_purchase.rb:4-57`) — the source of truth that gates `ai_credit_subscription_plan_lookup_key?` and `prices` — defines subscription keys `plato_ai_credit_subscription_small/medium/large` and `ai_credit_pack_subscription_small_monthly` / `ai_credit_pack_subscription_large_monthly` (NO `_medium_monthly`). The model defines `plato_ai_credit_subscription_*`; the frontend credits table does NOT contain them. So a live Stripe subscription on any `plato_ai_credit_subscription_*` price (a valid model key, present in `prices`) reaches the SCREEN with `currentCredits === null` → blank credits headline. Conversely the frontend table contains `ai_credit_pack_subscription_medium_monthly` which the model does NOT define. The terminal SCREEN value depends on a table that is out of sync with the DATABASE-backing model's lookup-key set. Not covered by SANCTIONED (which sanctions naming, not divergent key sets) nor WHITELIST.

file:line — `app/javascript/shared/lib/planHelpers.ts:68-75` (and `:77-84` display names) vs `app/models/organization_ai_credit_purchase.rb:4-57`

---

## D3 (SCREEN terminal) — `currentCredits` is ALSO consumed by the change-button text, so a missing live lookupKey degrades the upgrade/downgrade labels

ANALOG (trace): the change `Styled.Button` label (`{plan.buttonText}`, `PlanCard.tsx:213`) is derived from `getPlanButtonText(currentPriceObject.lookupKey, plan.lookupKey, billingPeriod)` (`AccountBillingPlans.tsx:180-184`) — i.e. from the live Stripe object's `lookupKey`, with a deterministic fallback ladder, never from a nullable local credits number.

OURS: the per-tier change-button label `buttonText: deriveTierButtonText(isSubscribed, currentCredits, tier.credits)` (`AiCreditSubscription.tsx:284`) is a function of `currentCredits` (the nullable local-table value from D1). `deriveTierButtonText` (`aiSubscriptionHelpers.ts:30-39`) returns `"Change plan"` whenever `currentCredits == null` even though the user IS subscribed and the tier differs — so when the live lookupKey misses the table (D2), an active subscriber sees every tier labelled "Change plan" instead of the correct Upgrade/Downgrade, a SCREEN terminal that silently degrades. The analog derives the label purely from the live Stripe `lookupKey`, never from a value that goes null when a table lookup misses.

file:line — `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:284`, `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts:30-39`
