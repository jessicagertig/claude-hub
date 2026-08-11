# Round 4 — routes-controller segment audit

Segment: `config/routes.rb` billing collection + every `BillingController` action in the flow
(`customer_subscription`, `prices`, `change_subscription_portal_session`,
`update_payment_method_and_subscription_portal_session`,
`continue_change_subscription_portal_session`) + `determine_price_id`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

Chains traced:
- `config/routes.rb:163-186` (billing collection)
- `app/controllers/api/v1/billing_controller.rb` → `app/policies/billing_policy.rb:24` → `app/policies/application_policy.rb:50` → `app/models/organization.rb:469/474/481`

## Structural verification summary (all SAME unless listed below)

Routes — every route line the trace cites is exact:
- POST `change_subscription` `:168`; POST `change_subscription_portal_session` `:169`;
  POST `update_payment_method_and_subscription_portal_session` `:170`;
  GET `prices` `:174`; GET `customer_subscription` `:177`;
  GET `continue_change_subscription_portal_session` `:178`. ALL SAME.

`determine_price_id` call sites — the trace's 8 sites (`:50`, `:198`, `:252`, `:279`, `:299`,
`:311`, `:343`, `:643`) and def `:630` match grep exactly. SAME.

`change_subscription_portal_session` (`:268-327`) — action `:268`, authorize `:269`, `ap` `:270`,
guards `:272-274`, ValidateSubscriptionChange `:277-281` (determine_price_id `:279`),
`unless result.success?` `:283`, `render_general_errors` `:284`, `return` `:285`,
`subscription_item_id` `:288`, options `:290-304`, `Stripe::BillingPortal::Session.create` `:306`,
`ap` `:307`/`:308`, `PosthogTrackJob.perform_later` `:311`, render `:313`,
rescues `:314`/`:320`/`:324` (StandardError at `:324` has NO Sentry — confirmed). ALL SAME.

`prices` (`:535`), authorize `:536`, Stripe.list limit 20 `:537`, render `:540`. SAME.

`customer_subscription` (`:606`), `ap` `:607`/`:608`, branch `:609`, render-nil `:611`,
render-happy `:614`, rescue `:615`, Sentry `:616`, logger `:617`, render-error `:618`,
no authorize, `stripe_subscription` called twice (`:608` + `:614`). ALL SAME.

`update_payment_method_and_subscription_portal_session` (`:331-380`) — authorize `:332`,
guards `:335-337`, `subscription_item_id` `:339`, `final_return_path` `:340`, `final_return_url` `:341`,
`target_price_id = determine_price_id` `:343`, continue_url `:346-349`, options `:351-361`,
`redirect: { return_url: continue_url }` `:357`, top-level `return_url: final_return_url` `:360`,
Stripe create `:363`, `ap` `:364`/`:365`, render `:367`, rescues `:368`/`:372`/`:376`,
StandardError Sentry `:377`. ALL SAME.

`continue_change_subscription_portal_session` (`:385-470`) — no authorize; customer-blank `:390`,
logger `:391`, raw-`params[:return_url]` redirect `:392`; subscription-blank `:395`/`:396`/`:397`;
`subscription_item_id` `:400`; `target_price_id = params[:target_price_id]` `:401`;
return_url build `:403-407`; blank check `:409`, redirect `:411`; ValidateSubscriptionChange `:418`;
`unless success` `:424`, redirect `:427`, return `:428`; options `:433-447`, Stripe create `:452`,
`redirect_to session.url` `:457`; rescues Stripe `:458`/redirect `:463`,
StandardError `:464`/redirect `:469`. ALL SAME.

`determine_price_id` (`:630-640`) — `params.key?(:price_id)` `:631` → `params[:price_id]` `:632`;
else `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` `:634` →
`prices.data.find { |price| price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` `:637`.
`DEFAULT_PRICE_LOOKUP_KEY = 'plan_simple_ats_per_job_tiered'` `:7`. ALL SAME.

`BillingPolicy#change_subscription?` `:24` → `is_org_admin?` (`application_policy.rb:50`),
`prices?` `:4` → `is_org_user?` `:54`. SAME.

---

## Discrepancies

### D1 — trace omits the leading `ap` debug statement in `update_payment_method_and_subscription_portal_session`

TRACE SAYS (item 18b): "`authorize :billing, :change_subscription?` (`:332`). Three entry guards
(`:335-337` ...)". It jumps from authorize at `:332` straight to the guards at `:335`, omitting the
executable `ap` statement between them.

ACTUAL CODE: line 333 is `ap 'Update Payment Method then redirect to Confirm Subscription Change via Stripe Portal'`
— the SECOND executable statement of the action (between authorize `:332` and the first guard `:335`).

Severity: MINOR (debug `ap` line). But it IS a structural inconsistency: the trace explicitly
documents the analogous `ap 'Change Subscription via Stripe Portal Session'` at `:270` for the
sibling `change_subscription_portal_session`, and explicitly documents the `ap` lines at `:364-365`
in this same action, yet drops `:333`. The action's `:335-337` guard lines are therefore reached
one statement later than the trace's enumeration implies.

file:line — `app/controllers/api/v1/billing_controller.rb:333`

### D2 — trace omits the leading `ap` debug statement in `continue_change_subscription_portal_session`

TRACE SAYS (item 18b): "`BillingController#continue_change_subscription_portal_session`
(`billing_controller.rb:385-470`): NO `authorize`. ... [first item listed is] `if current_organization.stripe_customer_id.blank?` (`:390`)".
The trace presents the customer-blank guard at `:390` as the first body statement, omitting the
`ap` at `:386`.

ACTUAL CODE: line 386 is `ap 'Continue: Create Subscription Confirmation Portal Session after Payment Method Update'`
— the FIRST executable statement of the action body, before the `:390` guard.

Severity: MINOR (debug `ap` line). Same inconsistency as D1: for `customer_subscription` the trace
explicitly called out the first `ap` (`:607`) and for `change_subscription_portal_session` the
first `ap` (`:270`), but it omits the first `ap` here. (Several further `ap` debug lines in this
action — `:414-416`, `:425-426`, `:453-454`, `:461-462`, `:467-468` — are likewise not enumerated,
but D2 captures the representative first-statement omission.)

file:line — `app/controllers/api/v1/billing_controller.rb:386`

---

## Conclusion

For the routes + controller-action segment the trace is structurally accurate: every route line,
every action def/guard/param/render/redirect/rescue line number, the `determine_price_id` body and
its 8 call sites, and the Stripe `flow_data` option shapes all match the code exactly. The only
discrepancies are two omitted leading `ap` debug statements (`:333`, `:386`) — minor, but flagged
because the trace's stated discipline (and its own treatment of `:270`, `:607`, `:364-365`) is to
enumerate every executable statement including debug `ap` lines.
