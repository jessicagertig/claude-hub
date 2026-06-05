# Investigation — Note #9B-3: AI-credit subscription overrides the main plan subscription

## File chain
`app/models/organization.rb#sync_with_stripe` (:520-~568) → `#stripe_customer_subscriptions` (:481, `Stripe::Subscription.list`) → `#assign_plan_name_from_lookup_key` (:673) → `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key`
`app/jobs/stripe_webhook_handler_job.rb` checkout.session.completed (:53-96, write at :71) ; invoice.paid → `ApplyAiCreditPurchase#apply_subscription` (`apply_ai_credit_purchase.rb:80-129`)

## sync_with_stripe — the central fragile point
- Selection (:538-540): `subscriptions = stripe_customer_subscriptions.data` (all the customer's subs, limit 3, status all) → `subscriptions.find { active/trialing } || subscriptions[0]`. NO AI-credit filter.
- Writes (:563-568): stripe_subscription_id, stripe_subscription_status, stripe_current_period_end_at, plan (via assign_plan_name_from_lookup_key on the selected sub's lookup_key).
- Called from 12+ sites: organization.rb:260; sync_with_stripe_job.rb:11; stripe_webhook_handler_job.rb:140/171/188 (188 = customer.subscription.updated, fires unconditionally); billing_controller.rb:171/211/260/624; bad_actor_organization_takeover.rb:110; frontend GET /billing/sync_with_stripe.
- ⇒ Fixing the SELECTION inside sync_with_stripe is high-leverage (protects all callers).

## Timing finding (validates Jessica's concern)
- `OrganizationAiCreditPurchase` (subscription) is created in `apply_subscription`, called on **invoice.paid** — sets stripe_subscription_id = invoice.subscription (`:81,:102`).
- At **checkout.session.completed**, that row may NOT exist yet (Stripe does not guarantee checkout.session.completed precedes invoice.paid). ⇒ discriminating by the purchase row FAILS at the checkout moment.

## Reliable discriminators (NOT the purchase row)
- **sync_with_stripe**: each live Stripe sub carries `items.data[0].price.lookup_key` (already read at :547). Exclude subs whose lookup_key is an AI-credit-pack subscription key (registry / AiCreditPacks.subscription_key?, per #6A). lookup_key is always present on the live sub regardless of our row.
- **checkout.session.completed**: the subscribe (→ checkout per #9A) session sets metadata `ai_credit_pack_subscription: 'true'` (ai_credit_subscriptions_controller.rb:40). That metadata is on the session at checkout.session.completed regardless of invoice.paid timing — use it to route the AI-credit subscription away from the stripe_subscription_id write (mirrors note #4's metadata gating for top-ups).

## Already-guarded paths (precedent)
customer.subscription.updated/.deleted, invoice.paid (credit-pack branch) already guard via `AiCreditPacks.subscription_key?`.

## Non-clobber stripe_subscription_id writes (verified, leave alone)
organization.rb:499 (nil reset), :748 ('free_plan' sentinel), :779 (plan sub creation), :792/805/818 (test helpers).
