# Round 3 Fix Log — subscription-change-analog-trace.md

All 17 round-3 discrepancies corrected. Every fix verified against current code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`. Analog-only; no "ours" content introduced.

## Frontend

- **Item 13 (structural omission)** — Skeleton item 13 (prices chain) now documents the 3-way ternary at `AccountBilling.tsx:122-134`: `AccountBillingPlans` renders ONLY in the `: hasActiveSubscription ?` branch (`:128-134`); an active-sub org that is `eligibleForFreeTrial` gets `AccountBillingPlansFreeTrial` (`:122-127`) instead and never reaches `AccountBillingPlans`. Verified.

- **Item 14 (signature mis-quote)** — Corrected to `getPlansForPeriod = (period, billingPrices = [])` (`planLookups.js:553`); the empty-array default param is now shown. Verified.

- **Item 17 (structural imprecision)** — Skeleton item 17 now states the `<PlanChangeBlockedModal .../>` JSX is assigned to a local `const modal` (`:340-347`) and `openModal(modal)` is called on a separate line (`:348`), not inline. Verified.

- **Item 9 (imprecise fallback location)** — Skeleton item 9 corrected: the `currentSubscription &&` guard on `currentPriceObject` (`:67`) feeds ONLY the `currentProductPrice ... : null` fallback (`:137-142`, gated by `currentPriceObject != undefined`). The `: 0` fallback is NOT downstream of that guard — it lives in `planLookups.js:564` gated by `priceData`/`billingPrices`. Same correction applied to item 14's description of `:564`. Verified against both files.

## Routes / Controller

- **DISCREPANCY 1 / LOW (item 6, `:607-608`)** — First executable statement is `ap 'GETTING THE CUSTOMER SUBSCRIPTION'` (`:607`); the stripe-invoking `ap current_organization.stripe_subscription` is the SECOND statement (`:608`). The double-call-before-nil-check substance retained. Verified.

- **DISCREPANCY 2 (item 18b, `:357` vs `:346-349`)** — `after_completion.redirect.return_url` field is assigned at `:357`; `:346-349` builds the `continue_url` string. The two are now distinguished. Verified.

- **DISCREPANCY 3 (item 18b, `:335-337`)** — Added the three entry guards of `update_payment_method_and_subscription_portal_session` (`:335` customer, `:336` subscription, `:337` subscription_item_id), noted as mirroring the change action's `:272-274`. Verified.

- **DISCREPANCY 4 (item 18b, `:340-341`, `:349`, `:360`)** — Added `final_return_path = params[:return_url].presence || '/account'` (`:340`, `/account` fallback) and `final_return_url` (`:341`); noted it is `final_return_url` (not raw `params[:return_url]`) that is CGI-escaped into `continue_url` (`:349`) and set as the top-level `return_url:` (`:360`). Verified.

- **DISCREPANCY 5 + LOW (item 18b, `:363`/`:367`/`:368`/`:372`/`:376-377`)** — Added the STRIPE terminal `Stripe::BillingPortal::Session.create(options)` (`:363`) and SCREEN terminal `render json: { redirectUrl: session.url }` (`:367`), plus all three rescues. Flagged the structural difference: the `:376` StandardError rescue calls `Sentry.capture_exception` (`:377`), UNLIKE `change_subscription_portal_session`'s `:324` StandardError rescue which does NOT (confirmed by reading `:314-327` — only `Rails.logger.error` at `:325`). Verified.

- **DISCREPANCY 6 (items 57-58, `:391`/`:396`)** — Added the `Rails.logger.error` lines preceding each redirect in the continue action's two blank-guards (`:391` customer ID, `:396` subscription ID). Verified.

## Model / Services / Interactor

- **D1 / INFO (item 24, `validate_subscription_change.rb:26`)** — Corrected the call site to `assign_plan_name_from_lookup_key(lookup_key: target_lookup_key)` — only `lookup_key:` is passed; `subscription_nil` relies on the method default. Method signature default `subscription_nil: false` still attributed to `organization.rb:678`. Verified. (Price-model table row at trace line ~134 describes the METHOD signature hop, not the call site, so left as-is.)

- **D2 (item 24, `:10-12`)** — Added the context unpacking: `organization = context.organization` (`:10`), `target_price_id = context.target_price_id` (`:11`), `action_type = context.action_type` (`:12`) — the variables every later step reads. Verified.

- **D3 (`Organization#stripe_customer` callpoints)** — sync_with_stripe note now traces all three uses: `:530` (`return if stripe_customer.respond_to?(:deleted)` guard), `:578`, `:580` (`stripe_customer.invoice_settings.default_payment_method`, the SOURCE of the written `stripe_default_payment_method_on_file` column). `stripe_customer` def at `organization.rb:469` → `Stripe::Customer.retrieve({ id:, expand: ['subscriptions'] })` (`:471`). Verified.

- **D4 (sync_with_stripe upstream reads)** — Added the previously-undocumented block producing the `:573` arguments: `subscriptions = stripe_customer_subscriptions.data` (`:538` → `organization.rb:482` `Stripe::Subscription.list`), `plan_subscriptions` reject-by-lookup-key (`:539-542`), `current_subscription` selection (`:543-545`), `current_subscription_price` (`:550`), `current_subscription_lookup_key` (`:555`). Verified.

The sync_with_stripe note after the options block and the "Unresolved identifiers" entry were both expanded to reflect the full body trace.
