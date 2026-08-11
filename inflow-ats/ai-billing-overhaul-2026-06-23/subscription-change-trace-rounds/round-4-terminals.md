# Round 4 — TERMINALS segment audit (SCREEN / STRIPE / DATABASE)

Scope: every point data reaches the SCREEN (what AccountBillingPlans/PlanCard render), goes to STRIPE (each `Stripe::` call + exact args), or touches the DATABASE (each column read/written). Verified against the actual analog code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Chains traced to terminal:
- SCREEN: `AccountBilling.tsx` → `AccountBillingPlans.tsx` → `PlanCard.tsx` → `useBilling.ts` → `api.ts` → (`planLookups.js` for the rendered price). Terminals: `window.location.href`, `addToast`, `openModal`, `<LoadingIndicator>`, `<ManageBillingActions>` vs `<Styled.Button>`, the rendered `price`/`currentProductPrice`/`buttonText`.
- STRIPE: `billing_controller.rb` (`#prices`, `#customer_subscription`, `#change_subscription_portal_session`, `#update_payment_method_and_subscription_portal_session`, `#continue_change_subscription_portal_session`, `#determine_price_id`), `organization.rb` (`#stripe_subscription`, `#stripe_customer`, `#stripe_customer_subscriptions`), `validate_subscription_change.rb`. Terminals: `Stripe::Price.list`, `Stripe::Price.retrieve`, `Stripe::Subscription.retrieve`, `Stripe::Subscription.list`, `Stripe::Customer.retrieve`, `Stripe::BillingPortal::Session.create`.
- DATABASE: `validate_subscription_change.rb:42` (`jobs.status`), `posthog_track_job.rb:7` (`users`), `organization.rb#sync_with_stripe` (`organizations.update`, `organization_ai_credit_balances.update_columns`), schema columns.

Overall: the TERMINAL claims in the trace are almost entirely correct — every STRIPE call, every DB write column, and every SCREEN terminal landing point matches the real code. The discrepancies below are structural/characterization slips, not wrong terminals.

---

## Discrepancy 1

TRACE SAYS (line 84): "… → `context.fail!(message: error_message)` (`:72`). … **Else** `context.success!` (`:76`)."

ACTUAL CODE: There is no `else` branch. The `if current_published_count > target_job_limit` block (`:53-73`) contains only a `context.fail!` (`:72`); `context.success!` at `:76` executes unconditionally after the `if` block (it is reached because `context.fail!` halts via `Failure` exception, not because of an `else`). Framing it as "Else context.success!" misstates the control structure of the SCREEN/validation terminal.

file:line — `app/interactors/validate_subscription_change.rb:53` (if, no else), `:76` (unconditional `context.success!`)

---

## Discrepancy 2

TRACE SAYS (line 85): "FIVE `context.fail!` exit points total: `:23`, `:31`, `:40`, `:72`, `:79`/`:82`."

ACTUAL CODE: There are SIX `context.fail!` invocations, at `:23`, `:31`, `:40`, `:72`, `:79`, and `:82`. The trace collapses `:79` and `:82` into a single "exit point" to arrive at "FIVE." `:79` (rescue `Stripe::InvalidRequestError`) and `:82` (rescue `StandardError`) are two distinct `context.fail!` calls with different messages ('Invalid price ID provided' vs 'An error occurred while validating the subscription change'), reached by two distinct exception classes — they are not one exit point.

file:line — `app/interactors/validate_subscription_change.rb:23`, `:31`, `:40`, `:72`, `:79`, `:82` (six `context.fail!`)

---

## Discrepancy 3

TRACE SAYS (line 26): "The ONLY SCREEN fallback actually downstream of this `currentPriceObject` guard is `currentProductPrice = currentPriceObject != undefined ? ... : null` (`AccountBillingPlans.tsx:137-142`, gated by `currentPriceObject != undefined`)."

ACTUAL CODE: The `currentProductPrice` expression at `:137-142` is NOT a simple `? ... : null`; it is a NESTED ternary that, when `currentPriceObject != undefined`, branches again on `currentPriceObject.billingScheme === "tiered"` and reaches the SCREEN value from one of TWO different price sources — `currentPriceObject.tiers[0].unitAmount / 100.0` (`:140`) or `currentPriceObject.unitAmount / 100.0` (`:141`). The trace's "..." hides a second SCREEN terminal branch (the `tiered` path reads `tiers[0].unitAmount`, a different field than the flat `unitAmount`). For a terminals audit, the `tiered` branch is a distinct value-to-SCREEN path that the trace does not name.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:137-142` (nested `billingScheme === "tiered"` ternary)

---

## Discrepancy 4 (minor / off-by-one)

TRACE SAYS (line 39): "the `<PlanCard ...>` element spans `:439-457`".

ACTUAL CODE: The `<PlanCard` opening tag is at `:439` and the self-closing `/>` is at `:456`; `:457` is the closing `);` of the `return (`. The element spans `:439-456`, not `:439-457`. (The prop-line citations `:443`, `:449`, `:455` are all correct.)

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:439-456`

---

## Verified correct (no discrepancy) — terminals confirmed against real code

STRIPE terminals — all exact:
- `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` — `billing_controller.rb:537` (render `:540`).
- `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` — `billing_controller.rb:634` (determine_price_id else-branch; `.find { lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` `:637`).
- `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` — `organization.rb:477`.
- `Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' })` — `organization.rb:482`.
- `Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] })` — `organization.rb:471`.
- `Stripe::Price.retrieve(target_price_id)` — `validate_subscription_change.rb:15`.
- `Stripe::BillingPortal::Session.create(options)` — change `:306`, update_payment `:363`, continue `:452`. Options blocks (`:290-304`, `:351-361`, `:433-447`) verified field-by-field, including `after_completion.redirect.return_url: continue_url` (`:357`) and top-level `return_url: final_return_url` (`:360`).

SCREEN terminals — all exact:
- `window.location.href = data.redirectUrl` — portal `:303`, payment-method `:263`.
- `addToast({ title: errorMessage, kind: "error" })` error toasts — `:313`, `:274`; both read `error?.data?.errors?.general?.[0]` (`:307`, `:267`).
- `openModal(modal)` (modal assigned to local const `:340-347`, then `openModal` on `:348`) — exact.
- `<LoadingIndicator label="Loading..." />` early return gated by `isFetchingStripeCustomerSubscription` — `:352-354`.
- PlanCard button branch `{isCurrentPlan || isFreePlan ? <ManageBillingActions .../> : <Styled.Button .../>}` — `:199`; ManageBillingActions `:200-205`; Styled.Button `:207-214` with `onClick` `:208`, `loading={isLoadingButton}` `:209`, `disabled={isLoading}` `:210`.
- `render json: { subscription: nil }` `:611` / `render json: { subscription: current_organization.stripe_subscription }` `:614` / `render json: { errors: ['Unable to load subscription'] }` `:618`.
- `render json: price_list` `:540`; `render json: { redirectUrl: session.url }` `:313`, `:367`; `redirect_to session.url` `:457`; the `?error=` redirects `:392`, `:397`, `:411`, `:427`, `:463`, `:469`.
- `getPlansForPeriod` rendered price `price: priceData ? priceData.unitAmount / 100 : 0` `planLookups.js:564`; `priceId: priceData?.id || null` `:568`.

DATABASE terminals — all exact:
- READ `organization.jobs.where(status: 'published').count` — `validate_subscription_change.rb:42` (jobs table, status column).
- READ `User.find_by(id: user_id)` — `posthog_track_job.rb:7` (users table).
- READ `stripe_subscription_id` nil-check — `billing_controller.rb:609`, `organization.rb:475`.
- WRITE `update(changes_to_make)` — `organization.rb:600`; columns set in `attributes`: `stripe_subscription_id` `:568`, `stripe_subscription_status` `:569`, `stripe_current_period_end_at` `:570`, `plan` `:573`, `stripe_default_payment_method_on_file` `:580` — exactly the 5 columns the trace lists.
- WRITE `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` — `organization.rb:605`, allocation from `PlanFeatureGate#monthly_ai_credit_allocation` `plan_feature_gate.rb:134`.
- Schema: `organizations.plan` integer default 101 — `db/schema.rb:1052`; `organizations.stripe_subscription_id` — `:1056`; `stripe_current_period_end_at` `:1058`; `stripe_subscription_status` `:1065`; `stripe_default_payment_method_on_file` default false `:1066`.

Transport — exact: `apiGet` allKeysToCamel `api.ts:22`; `apiMutate` CSRF `:50`, allKeysToSnake `:52`, allKeysToCamel response `:67` / error `:56`.
