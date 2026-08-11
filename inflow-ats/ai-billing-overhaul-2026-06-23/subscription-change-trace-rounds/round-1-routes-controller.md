# Round 1 — routes-controller — Subscription-Change ANALOG Trace Audit

Reviewer: "routes-controller". Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.
Segment: `config/routes.rb` billing collection + every `BillingController` action in the subscription-change flow (`customer_subscription`, `prices`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`) + `determine_price_id`.

Files traced:
`config/routes.rb` → `app/controllers/api/v1/billing_controller.rb` → `app/models/organization.rb` → `app/policies/billing_policy.rb` → `app/policies/application_policy.rb` → `app/interactors/validate_subscription_change.rb`

What the trace got RIGHT (verified to terminal, not a discrepancy):
- Routes: `customer_subscription` = `config/routes.rb:177`, `prices` = `:174`, `change_subscription_portal_session` = `:169` — all correct.
- `customer_subscription` action at `billing_controller.rb:606`; `prices` at `:535`; `change_subscription_portal_session` at `:268`; `determine_price_id` at `:630` — all correct.
- `Organization#stripe_subscription` = `organization.rb:474` with `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` at `:477` — correct.
- `authorize :billing, :change_subscription?` at `:269`; guards at `:272-274`; `render_general_errors([result.message])` at `:284`; `subscription_item_id = params[:subscription_item_id]` at `:288`; `Stripe::BillingPortal::Session.create(options)` at `:306`; `PosthogTrackJob.perform_later` at `:311`; `render json: { redirectUrl: session.url }` at `:313`.
- `BillingPolicy#change_subscription?` = `billing_policy.rb:24`; `is_org_admin?` = `application_policy.rb:50`.
- `determine_price_id` invoked 3× in `change_subscription_portal_session` at lines 279, 299, 311 — correct.
- `ValidateSubscriptionChange` line cites (`:6/:15/:16/:26/:42`) — correct.
- flow_data `subscription_update_confirm` shape — structurally faithful.

---

## DISCREPANCY 1 — `determine_price_id` guard is `params.key?(:price_id)`, NOT "when present"
TRACE SAYS: (skeleton line 24, and price-model line 44) "`determine_price_id` → `params[:price_id]` when present, else `Stripe::Price.list`".
ACTUAL CODE: the branch condition is `if params.key?(:price_id)` — a KEY-EXISTENCE check, not a presence/`.present?` check. A `price_id` key present but blank (`""`) returns `""` (truthy-key) and does NOT fall through to the default-lookup branch.
file:line: `app/controllers/api/v1/billing_controller.rb:631`

## DISCREPANCY 2 — `determine_price_id` else-branch returns a Stripe Price OBJECT, not an id/string
TRACE SAYS: (skeleton line 24 / price-model line 92) implies `determine_price_id` resolves to a price id; the name and the `price_id:`/`target_price_id:` usages read as a string.
ACTUAL CODE: the `if` branch returns the STRING `params[:price_id]`; the `else` branch returns `prices.data.find { |price| price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` — a `Stripe::Price` OBJECT, not a string. The method has an inconsistent return type. The trace never notes this object-vs-string divergence (and downstream `determine_product_info` at `:646` explicitly handles it with `price_id.respond_to?(:id) ? price_id.id : price_id`, which only makes sense because of this dual return type).
file:line: `app/controllers/api/v1/billing_controller.rb:631-639` (else find at `:637`)

## DISCREPANCY 3 — `determine_price_id` Stripe::Price.list uses `limit: 10`, not 20
TRACE SAYS: the only `Stripe::Price.list` limit documented for this flow is `limit: 20` (skeleton line 30, prices action). The price-model table (line 92) cites `DEFAULT_PRICE_LOOKUP_KEY` but does not state the `determine_price_id` internal list call or its limit.
ACTUAL CODE: `determine_price_id`'s default branch calls `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` — `limit: 10`, distinct from the `prices` action's `limit: 20`. This second, differently-limited Stripe::Price.list call (a TERMINAL Stripe read) is omitted from the trace.
file:line: `app/controllers/api/v1/billing_controller.rb:634`

## DISCREPANCY 4 — `prices` action: `authorize :billing, :prices?` guard omitted
TRACE SAYS: (skeleton line 13/30) "`BillingController#prices` — `:535` → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })`, renders raw list". No authorization mentioned.
ACTUAL CODE: the action's FIRST line is `authorize :billing, :prices?` — a Pundit guard (→ `BillingPolicy#prices?` at `billing_policy.rb:4`). The trace omits this guard entirely.
file:line: `app/controllers/api/v1/billing_controller.rb:536`

## DISCREPANCY 5 — `prices` action: wrong line for the Stripe call and omitted render line
TRACE SAYS: cites the Stripe::Price.list at `billing_controller.rb:535` (and `:535/537` in the price-model table line 83).
ACTUAL CODE: `def prices` is line 535; the `Stripe::Price.list(...)` is line 537; `render json: price_list` is line 540. Citing `:535` for the Stripe call is the `def` line, not the call. (The price-model table's `:535/537` dual cite is closer but the skeleton's `:535` is the method header.) The terminal `render json: price_list` at `:540` is not cited.
file:line: `app/controllers/api/v1/billing_controller.rb:537` (call), `:540` (render)

## DISCREPANCY 6 — `customer_subscription`: nil-guard branch and begin/rescue omitted
TRACE SAYS: (skeleton line 20) "`BillingController#customer_subscription` — `:606` → renders `{ subscription: current_organization.stripe_subscription }` (raw live Stripe object, no serializer)".
ACTUAL CODE: the action is NOT an unconditional render. Line 609 guards `if current_organization.stripe_subscription_id.nil?` → renders `{ subscription: nil }` (line 611). Only the `else` branch (line 613) renders `{ subscription: current_organization.stripe_subscription }`, and it is wrapped in a `begin/rescue StandardError` (lines 613-619) that on error renders `{ errors: ['Unable to load subscription'] }` (line 618) with `Sentry.capture_exception` + `Rails.logger.error`. The trace presents only the happy-path render and omits the nil branch, the rescue branch, and the two error terminals.
file:line: `app/controllers/api/v1/billing_controller.rb:609-620`

## DISCREPANCY 7 — `customer_subscription`: no `authorize` (trace implies the billing flow is admin-gated)
TRACE SAYS: nothing — the action is presented as a plain render. (Not a false claim, but an omission worth flagging: the trace documents `authorize` for the change action and the reader may assume the read endpoints are likewise gated.)
ACTUAL CODE: `customer_subscription` (606-621) has NO `authorize` call at all — it is reachable by any authenticated org user, unlike `prices` (`:prices?`) and the change actions (`:change_subscription?`). This asymmetry is structurally relevant and undocumented.
file:line: `app/controllers/api/v1/billing_controller.rb:606-621` (absence of authorize)

## DISCREPANCY 8 — `update_payment_method_and_subscription_portal_session` action entirely undocumented
TRACE SAYS: the SUBJECT lists `update_payment_method_and_subscription_portal_session` as part of the flow, but the trace body has NO entry for it — not in the skeleton, not in the price-model table, not in unresolved identifiers.
ACTUAL CODE: a full action exists: `authorize :billing, :change_subscription?` (`:332`); same three guards (`:335-337`); builds a `continue_url` to `/api/v1/billing/continue_change_subscription_portal_session` with `subscription_item_id`, `target_price_id` (= `determine_price_id`, `:343`), `return_url` query params (`:346-349`); creates a `Stripe::BillingPortal::Session` with `flow_data.type: 'payment_method_update'` and `after_completion.redirect.return_url: continue_url` (`:351-363`); renders `{ redirectUrl: session.url }` (`:367`); rescues Pundit/Stripe::InvalidRequestError/StandardError (`:368-380`). Route is `POST` at `config/routes.rb:170`. This second portal entry point (and its `determine_price_id` call at `:343`) is missing from the trace.
file:line: `app/controllers/api/v1/billing_controller.rb:331-380`; route `config/routes.rb:170`

## DISCREPANCY 9 — `continue_change_subscription_portal_session` action entirely undocumented
TRACE SAYS: the SUBJECT lists `continue_change_subscription_portal_session`, but the trace body has NO entry for it anywhere.
ACTUAL CODE: a full GET action exists (route `config/routes.rb:178`). It has NO `authorize` (it is the Stripe redirect-back target). It reads `params[:subscription_item_id]`, `params[:target_price_id]`, `params[:return_url]` (`:400-407`); on missing customer/subscription/params it `redirect_to "#{return_url}?error=subscription_update_failed"` (`:390-412`); calls `ValidateSubscriptionChange.call(... target_price_id: params[:target_price_id], action_type: 'change')` using the PARAM target_price_id (NOT `determine_price_id`) at `:418-422`; on failure `redirect_to "#{return_url}?error=#{CGI.escape(result.message)}"` (`:427`); creates a `Stripe::BillingPortal::Session` `subscription_update_confirm` using `target_price_id` from params (`:433-447`); terminal is `redirect_to session.url` (`:457`), NOT `render json`. Rescues redirect to the error URL (`:458-469`). This is a distinct terminal shape (HTTP redirect to Stripe vs JSON `redirectUrl`) and a distinct price-id source (param, not `determine_price_id`) — both undocumented.
file:line: `app/controllers/api/v1/billing_controller.rb:385-470`; route `config/routes.rb:178`

## DISCREPANCY 10 — `change_subscription` (cancel+recreate) sibling action not noted as separate from the portal flow
TRACE SAYS: the trace conflates the flow with `change_subscription_portal_session` and never mentions the separate `change_subscription` action; the route list it implies is incomplete.
ACTUAL CODE: a distinct `change_subscription` action exists (`:237`, route `POST` at `config/routes.rb:168`) marked `# UNUSED`, which `Stripe::Subscription.cancel` + `Stripe::Subscription.create`. Not part of the audited flow, but it is a sibling collection route the trace's route enumeration omits. (Low-severity / scope-edge note — included for completeness since the segment is "the billing collection".)
file:line: `app/controllers/api/v1/billing_controller.rb:237-263`; route `config/routes.rb:168`

## DISCREPANCY 11 — rescue line citations point at rescue bodies, not the `rescue` keyword lines
TRACE SAYS: (skeleton line 55) rescues at "`:315` (Pundit::NotAuthorizedError), `:321` (Stripe::InvalidRequestError + Sentry), `:325` (StandardError, no Sentry)".
ACTUAL CODE: the `rescue` keyword lines are `:314` (Pundit), `:320` (Stripe::InvalidRequestError), `:324` (StandardError). The trace's `:315/:321/:325` are the first BODY line of each rescue. The characterizations are otherwise correct (StandardError at `:324-326` indeed has no Sentry; Pundit `:314-319` and Stripe `:320-323` do). Off-by-one citation only.
file:line: `app/controllers/api/v1/billing_controller.rb:314, 320, 324`

## DISCREPANCY 12 — flow_data block line range mislabeled "290-306"
TRACE SAYS: "Stripe BillingPortal flow_data shape, verbatim (`billing_controller.rb:290-306`)".
ACTUAL CODE: the `options` hash literal spans `:290-304`; line `:306` is `Stripe::BillingPortal::Session.create(options)` (the call, not part of the hash). The hash ends at `:304`. The quoted "verbatim" block also drops the two inline comments present at `:298` (`# Current subscription item id`) and `:300` (`# we can assume this is not per job pricing...`). Minor range/verbatim mismatch.
file:line: `app/controllers/api/v1/billing_controller.rb:290-304` (hash), `:306` (create)
