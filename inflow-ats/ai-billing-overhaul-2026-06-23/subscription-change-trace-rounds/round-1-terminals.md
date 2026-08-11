# Round 1 — TERMINALS segment audit (subscription-change analog trace)

Auditor scope: every point data reaches the SCREEN (what `AccountBillingPlans` renders), goes to STRIPE (each `Stripe::` call + exact args), or touches the DATABASE (columns read/written). Verified identifier-by-identifier against the analog code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Worktree verified: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Chains traced to terminal:
- SCREEN/DB-read (live subscription): `AccountBillingPlans.tsx` → `useBilling.ts` (`useStripeCustomerSubscription`→`getStripeCustomerSubscription`) → `api.ts` (`apiGet`) → `routes.rb` → `billing_controller.rb#customer_subscription` → `organization.rb#stripe_subscription` → STRIPE `Stripe::Subscription.retrieve` + DB read `stripe_subscription_id`.
- SCREEN/STRIPE (prices): `AccountBillingPlans.tsx` → `useBilling.ts` (`useBillingPrices`→`getPrices`) → `api.ts` → `routes.rb` → `billing_controller.rb#prices` → STRIPE `Stripe::Price.list`.
- STRIPE-write (change): `AccountBillingPlans.tsx` (`handleChangeSubscriptionWithGate`→`handleChangeSubscriptionViaStripePortal`) → `useBilling.ts` (`useChangeSubscriptionViaStripePortal`→`changeSubscriptionViaStripePortal`) → `api.ts` (`apiPost`→`apiMutate`) → `routes.rb` → `billing_controller.rb#change_subscription_portal_session` → `validate_subscription_change.rb` (STRIPE `Stripe::Price.retrieve` + DB read `jobs.status`) → STRIPE `Stripe::BillingPortal::Session.create` + `PosthogTrackJob` (DB read `users`).

---

## DISCREPANCY 1 — wrong schema line for `stripe_subscription_id` column
TRACE SAYS: `Organization#stripe_subscription_id` (column) — `db/schema.rb:1052` (trace skeleton item 8 / line 22; also price-model table area).
ACTUAL CODE: `t.string "stripe_subscription_id"` is at `db/schema.rb:1056`. Line 1052 is `t.integer "plan", default: 101`.
file:line: `db/schema.rb:1056` (not 1052)

## DISCREPANCY 2 — wrong schema line for `plan` column
TRACE SAYS: `organizations.plan` integer enum (default 101 = `plan_no_plan`) — `db/schema.rb:1048` (trace price-model table, line 90).
ACTUAL CODE: `t.integer "plan", default: 101` is at `db/schema.rb:1052`. Line 1048 is `t.string "thirdparty_ats_identifier"`. (The two columns are shifted: trace put `plan`=1048/`stripe_subscription_id`=1052; reality is `plan`=1052/`stripe_subscription_id`=1056.)
file:line: `db/schema.rb:1052` (not 1048)

## DISCREPANCY 3 — `customer_subscription` render line wrong; nil-branch + rescue SCREEN terminals omitted
TRACE SAYS: `BillingController#customer_subscription` — `billing_controller.rb:606` → renders `{ subscription: current_organization.stripe_subscription }` (raw live Stripe object, no serializer) (trace skeleton item 6 / line 20).
ACTUAL CODE: `def customer_subscription` is at line 606, but the render `{ subscription: current_organization.stripe_subscription }` is at line **614**. The action first does `if current_organization.stripe_subscription_id.nil?` (line 609 — DB read terminal) and renders `{ subscription: nil }` (line 611 — a SCREEN terminal), and has a `rescue StandardError` rendering `{ errors: ['Unable to load subscription'] }` (line 618 — a SCREEN terminal). The trace names only the success render and omits the nil-branch SCREEN terminal, the `stripe_subscription_id` nil DB read, and the error SCREEN terminal.
file:line: `billing_controller.rb:609-618` (render at 614, not 606)

## DISCREPANCY 4 — `Organization#stripe_subscription` Stripe call line; nil-guard omitted
TRACE SAYS: `Organization#stripe_subscription` — `organization.rb:474` → `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` (trace skeleton item 7 / line 21).
ACTUAL CODE: `def stripe_subscription` is at line 474, but the `Stripe::Subscription.retrieve(...)` STRIPE terminal is at line **477**. There is a `return if stripe_subscription_id.nil?` guard at line 475 (the method returns nil — feeding the SCREEN's `currentSubscription = null` branch) that the trace does not mention. Stripe args themselves match exactly.
file:line: `organization.rb:477` (retrieve), guard at `:475`

## DISCREPANCY 5 — `prices` Stripe call line
TRACE SAYS: `BillingController#prices` — `billing_controller.rb:535` → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` (trace skeleton item 13 / line 30; price-model table cites `:535/537`).
ACTUAL CODE: `def prices` is at line 535; the STRIPE terminal `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` is at line **537**; `render json: price_list` (SCREEN terminal) is at line 540. Args match. The skeleton item attaches the Stripe call to the def line (535) rather than 537; price-model table's `:535/537` is correct.
file:line: `billing_controller.rb:537` (Stripe::Price.list), `:540` (render)

## DISCREPANCY 6 — `getPlansForPeriod` lookupKey-match line wrong
TRACE SAYS: `getPlansForPeriod` — `planLookups.js:553` → matches `price.lookupKey.includes(planConfig.key)`, sets `priceId = priceData.id` (`planLookups.js:568`) (trace skeleton item 14 / line 31; price-model table line 84 cites `:553`/`:568`).
ACTUAL CODE: `getPlansForPeriod` def is at line 553, but the match `planDataMatches.find((price) => price.lookupKey.includes(planConfig.key))` is at line **560**, not 553. `priceId: priceData?.id || null` is at line 568 (line correct, but the value is `priceData?.id || null`, not bare `priceData.id` — the trace drops the `|| null`).
file:line: `planLookups.js:560` (match, not 553); `:568` (priceId with `|| null`)

## DISCREPANCY 7 — `handleChangeSubscriptionWithGate` structure mis-stated (branching to SCREEN/other terminals omitted)
TRACE SAYS: `handleChangeSubscriptionWithGate` — `AccountBillingPlans.tsx:322` → joins `plan.priceId` + `currentSubscriptionItemId` (then proceeds to `handleChangeSubscriptionViaStripePortal`) (trace skeleton item 16 / line 36).
ACTUAL CODE: At line 322 the handler first calls `checkPlanLimitsGate(plan.lookupKey)` (line 323). It calls `handleChangeSubscriptionViaStripePortal` (joining `plan.priceId` + `currentSubscriptionItemId`) ONLY when `result.shouldProceed` AND `currentOrganization.stripeDefaultPaymentMethodOnFile` (lines 325-330). If payment method is NOT on file it calls `handleUpdateWithPaymentMethod` (line 332, → `update_payment_method_and_subscription_portal_session`, a DIFFERENT backend action). If the gate fails it opens `PlanChangeBlockedModal` (SCREEN terminal, line 340-348) and fires `trackEvent('plan_change_blocked_modal_shown', ...)` (line 339). The trace presents the gate handler as an unconditional join → portal call, omitting the `stripeDefaultPaymentMethodOnFile` fork and the blocked-modal SCREEN terminal.
file:line: `AccountBillingPlans.tsx:323` (gate), `:326` (payment-method fork), `:332` (update-payment path), `:340` (blocked modal)

## DISCREPANCY 8 — success/error SCREEN terminals of the change call omitted
TRACE SAYS: `handleChangeSubscriptionViaStripePortal` — `AccountBillingPlans.tsx:283` (adds `returnUrl: '/hire/settings/billing'`) (trace skeleton item 17 / line 37). Trace does not name what happens to the returned data.
ACTUAL CODE: On success the handler does `window.location.href = data.redirectUrl` (line 303 — the SCREEN terminal: browser navigates to the Stripe portal URL returned by `render json: { redirectUrl: session.url }`). On error it does `addToast({ title: errorMessage, kind: 'error' })` (line 313 — a SCREEN terminal), with `errorMessage` read from `error?.data?.errors?.general?.[0]`. The trace stops at `apiPost` and never reaches these two SCREEN terminals where the redirectUrl/error actually reaches the user's screen.
file:line: `AccountBillingPlans.tsx:303` (redirect), `:313` (error toast)

## DISCREPANCY 9 — `allKeysToSnake` transform attributed to `apiPost`, actually in `apiMutate`
TRACE SAYS: `apiPost({ path: '/billing/change_subscription_portal_session', variables: { priceId, subscriptionItemId, returnUrl } })` (`allKeysToSnake` → `price_id`, `subscription_item_id`, `return_url`) (trace skeleton item 19 / line 39).
ACTUAL CODE: `apiPost` (`api.ts:25`) does NOT itself call `allKeysToSnake`; it delegates to `apiMutate` (line 27), and `allKeysToSnake(variables)` runs inside `apiMutate` at line 52 (`data: skipKeysToSnake ? variables : allKeysToSnake(variables)`). The snake transform is real and produces the named keys, but it lives in `apiMutate`, not `apiPost`. (`apiGet`'s response `allKeysToCamel` is at line 22 — correct.)
file:line: `api.ts:52` (allKeysToSnake in apiMutate, not apiPost at :25)

## DISCREPANCY 10 — `PosthogTrackJob` DB-read terminal (`users`) not named
TRACE SAYS: `PosthogTrackJob.perform_later(...)` — `billing_controller.rb:311` → `PosthogTrackJob#perform` (`posthog_track_job.rb:6`); `Posthog::Track#track` → posthog client, not traced (trace skeleton item 29 / line 53; unresolved list line 104).
ACTUAL CODE: `perform` reads `User.find_by(id: user_id)` at `posthog_track_job.rb:7` — a DATABASE read terminal (`users` table) that gates the track call (`return unless user`, line 8). For a terminals audit this DB-read terminal should be named; the trace stops at the Posthog framework boundary without noting the `users` read.
file:line: `posthog_track_job.rb:7`

## DISCREPANCY 11 — `ValidateSubscriptionChange` DB-read terminal (`jobs`) present but not flagged as a DATABASE terminal
TRACE SAYS: `organization.jobs.where(status: 'published').count` (`validate_subscription_change.rb:42`) vs `target_job_limit` → `context.fail!` or `context.success!` (trace skeleton item 25 / line 49).
ACTUAL CODE: Line 42 is verified exactly. This is a DATABASE read terminal (`jobs` table, `status` column, scoped to the organization). The line/identifier are correct; noting for completeness that within the terminals segment this is a DB terminal the trace documents in passing but does not label as such. (No identifier error — included so the DB-terminal inventory is complete.)
file:line: `validate_subscription_change.rb:42`

---

## Confirmed correct (terminals segment) — no discrepancy
- STRIPE `Stripe::BillingPortal::Session.create(options)` — `billing_controller.rb:306` ✓; flow_data shape (`type: 'subscription_update_confirm'`, `subscription_update_confirm.subscription = current_organization.stripe_subscription_id`, `items: [{ id: subscription_item_id, price: determine_price_id, quantity: 1 }]`) matches lines 290-304 exactly; `customer`/`return_url` match.
- STRIPE `Stripe::Price.retrieve(target_price_id)` — `validate_subscription_change.rb:15` ✓; `target_lookup_key = target_price.lookup_key` `:16` ✓.
- STRIPE `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` — `billing_controller.rb:537` (prices) ✓; args exact.
- STRIPE `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` — `organization.rb:477` ✓; args exact.
- SCREEN `render json: { redirectUrl: session.url }` — `billing_controller.rb:313` ✓.
- SCREEN `render json: price_list` — `billing_controller.rb:540` ✓.
- `render_general_errors` — `application_controller.rb:40` ✓.
- `determine_price_id` — `billing_controller.rb:630` ✓; invoked 3× at lines 279, 299, 311 ✓.
- Routes `:169/:174/:177` ✓ for `change_subscription_portal_session`/`prices`/`customer_subscription`.
- Hooks `useChangeSubscriptionViaStripePortal:181`, `useStripeCustomerSubscription:245`, `useBillingPrices:266` ✓; consts `changeSubscriptionViaStripePortal:46`, `getStripeCustomerSubscription:98`, `getPrices:102` ✓.
- `apiGet:5` ✓ (`allKeysToCamel` at `:22`).
- Frontend reads `currentSubscription:62`, `currentPriceObject:67`, `currentSubscriptionItemId:136` ✓.
- `plans`/`plansWithButtonText:175/177`; plan object carries `priceId`(568)/`lookupKey`(569)/`key`(571) ✓.
- `currentOrganizationPlanOptions:3` ✓; `getPlansForPeriod` returns `lookupKey: planConfig.value` at `:569` ✓.
- Policy chain `BillingPolicy#change_subscription?:24` → `is_org_admin?` (`application_policy.rb:50`) ✓.
- `assign_plan_name_from_lookup_key` (`organization.rb:678`) → `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key` (`subscription_status_checker.rb:113`) → `PLAN_LOOKUP_MAPPING` (`:16`, substring `find` at `:117`) ✓.
- `PlanFeatureGate.all_plan_rules:72` → `plan_rules:142` ✓.
- enum `plan` `organization.rb:94`, `plan_no_plan: 101` `:95` ✓.
- `DEFAULT_PRICE_LOOKUP_KEY = 'plan_simple_ats_per_job_tiered'` `billing_controller.rb:7` ✓; duplicate `organization.rb:176` ✓.
- Method-level rescues `billing_controller.rb:314` (Pundit), `:320` (Stripe::InvalidRequestError + Sentry), `:324` (StandardError) ✓ (trace cited 315/321/325 — off-by-one on the `rescue` keyword line vs. body, immaterial).
- No DB write in `change_subscription_portal_session` ✓; `sync_with_stripe` deliberately out of scope per trace ✓.
