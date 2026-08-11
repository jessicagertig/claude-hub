# Round 6 — routes + controller segment audit

Segment: `config/routes.rb` billing collection + every `BillingController` action in the flow
(`customer_subscription`, `prices`, `change_subscription_portal_session`,
`update_payment_method_and_subscription_portal_session`,
`continue_change_subscription_portal_session`) + `determine_price_id`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

Files traced (chain):
`config/routes.rb` → `app/controllers/api/v1/billing_controller.rb`
→ `app/policies/billing_policy.rb` → `app/policies/application_policy.rb`
→ `app/controllers/application_controller.rb` → `app/jobs/posthog_track_job.rb`

Result: the trace is HIGHLY accurate for this segment. Every route line, action line,
guard line, options-block line, rescue line, `determine_price_id` line, the 8
`determine_price_id` call sites, the `render_general_errors`/`PosthogTrackJob`
terminals, and the `change_subscription?` → `is_org_admin?` policy chain verified
correct. Two minor discrepancies found, both omissions (stop-short / dropped line),
no wrong identifiers or wrong line numbers.

---

## Discrepancy 1 — `prices` action's `authorize :prices?` is not traced to its policy terminal (stop-short)

TRACE SAYS: item 13 documents `BillingController#prices` with `authorize :billing, :prices?`
(`billing_controller.rb:536`) and item 6 calls out a "gating asymmetry" because
`customer_subscription` has no `authorize` while `prices` and the change actions do.
But the trace never resolves `prices?` to its terminal — `BillingPolicy#prices?` and the
role helper it returns are never opened. (Contrast item 21, which DOES trace
`change_subscription?` → `is_org_admin?`.)

ACTUAL CODE: `BillingPolicy#prices?` (`app/policies/billing_policy.rb:4-6`) returns
`is_org_user?`, NOT `is_org_admin?`. `is_org_user?`
(`app/policies/application_policy.rb:54-56`) =
`user.current_organization_user&.org_user? || is_org_admin?`. So `prices` is gated at the
ORG-USER level, whereas `change_subscription?` / `change_subscription_portal_session` /
`update_payment_method_and_subscription_portal_session` are gated at the ORG-ADMIN level.
The "gating asymmetry" the trace names is actually a THREE-way asymmetry
(no-authorize on `customer_subscription` + `continue_...`; org-user on `prices`;
org-admin on the two change actions), not the two-way (authorize vs no-authorize) the
trace describes. The `prices?` → `is_org_user?` thread is a callpoint the trace stops
short of its terminal.

file:line — `app/policies/billing_policy.rb:4-6` (`prices?` → `is_org_user?`);
`app/policies/application_policy.rb:54-56` (`is_org_user?` terminal)

---

## Discrepancy 2 — Omitted `Rails.logger.error` line in continue action's third guard

TRACE SAYS: item 18b (continue action) enumerates `Rails.logger.error` for the first two
blank-guard branches (`:391` customer-blank, `:396` subscription-blank) but for the third
guard `if subscription_item_id.blank? || target_price_id.blank?` (`:409`) it lists only
"`→ return redirect_to "#{return_url}?error=subscription_update_failed"` (`:411`)",
omitting the `Rails.logger.error` line that sits between the `if` and the `return`.

ACTUAL CODE: `app/controllers/api/v1/billing_controller.rb:410`
`Rails.logger.error 'Missing required parameters: subscription_item_id or target_price_id'`
executes before the `:411` redirect. The trace documents the analogous logger line for the
other two guards but drops it for the third — an inconsistent/omitted structural line.

file:line — `app/controllers/api/v1/billing_controller.rb:410`

---

## Verified-correct (spot list, no discrepancy)

- Routes: `change_subscription` POST `:168`, `change_subscription_portal_session` POST `:169`,
  `update_payment_method_and_subscription_portal_session` POST `:170`, `prices` GET `:174`,
  `customer_subscription` GET `:177`, `continue_change_subscription_portal_session` GET `:178` — all correct.
- `customer_subscription` `:606`; `ap` `:607`; unconditional `ap current_organization.stripe_subscription` `:608`;
  nil branch `:609`/`:611`; happy `:614`; rescue `:615`/Sentry `:616`/logger `:617`/render `:618`; calls
  `stripe_subscription` twice (`:608`,`:614`); no `authorize` — all correct.
- `prices` `:535`; authorize `:536`; `Stripe::Price.list({active:true,limit:20,...})` `:537`; render `:540` — correct.
- `change_subscription_portal_session` `:268`; authorize `:269`; `ap` `:270`; guards `:272-274`;
  `ValidateSubscriptionChange.call` `:277-281`; `unless result.success?` `:283`/`render_general_errors` `:284`/`return` `:285`;
  `subscription_item_id = params[:subscription_item_id]` `:288`; options block `:290-304` (comments `:298`/`:300`);
  `Stripe::BillingPortal::Session.create` `:306`/`ap` `:307`/`:308`; `PosthogTrackJob.perform_later` `:311`;
  `render json: { redirectUrl: session.url }` `:313`; rescues Pundit `:314`(Sentry), Stripe `:320`(Sentry),
  StandardError `:324`(NO Sentry) — all correct.
- `determine_price_id` def `:630`; `params.key?(:price_id)` `:631` → `params[:price_id]` `:632` (String);
  else `Stripe::Price.list({...limit:10...})` `:634` → `prices.data.find {…lookup_key == DEFAULT_PRICE_LOOKUP_KEY}` `:637`
  (Stripe::Price object); `DEFAULT_PRICE_LOOKUP_KEY` `:7`. Call sites `:50,:198,:252,:279,:299,:311,:343,:643`
  (8 total, def `:630` correctly excluded); 3× in change action (`:279,:299,:311`); 1× in payment-method action (`:343`) — all correct.
- `update_payment_method_and_subscription_portal_session` `:331-380`; authorize `:332`; `ap` `:333`;
  guards `:335-337`; `subscription_item_id` `:339`; `final_return_path … || '/account'` `:340`; `final_return_url` `:341`;
  `target_price_id = determine_price_id` `:343`; continue_url `:346-349`; options `:351-361`
  (`redirect: { return_url: continue_url }` `:357`, top-level `return_url: final_return_url` `:360`);
  create `:363`/`ap` `:364`/`:365`; render `:367`; rescues Pundit `:368`(Sentry `:369`/logger `:370`/render `:371`),
  Stripe `:372`(Sentry `:373`), StandardError `:376`(Sentry `:377`) — all correct, including the
  StandardError-calls-Sentry vs change-action-StandardError-no-Sentry structural difference.
- `continue_change_subscription_portal_session` `:385-470`; no authorize; `ap` `:386`;
  customer-blank `:390`/logger `:391`/raw-`params[:return_url]` redirect `:392`;
  subscription-blank `:395`/logger `:396`/raw redirect `:397`; `subscription_item_id`/`target_price_id` params `:400`/`:401`;
  `return_url` `:403-407`; third guard `:409`/redirect `:411`; `ValidateSubscriptionChange.call(action_type:'change', target_price_id: param)` `:418`;
  `unless result.success?` `:424`/escaped redirect `:427`/`return` `:428`; options `:433-447`; create `:452`;
  `redirect_to session.url` `:457`; rescues Stripe `:458`(Sentry)/redirect `:463`, StandardError `:464`(Sentry)/redirect `:469` — all correct.
- `change_subscription` UNUSED `:237-263`; `# UNUSED` `:238`; cancel `:241`; create `:258`; `sync_with_stripe` `:260` — correct.
- Policy `change_subscription?` `billing_policy.rb:24` → `is_org_admin?` `application_policy.rb:50` — correct.
- `render_general_errors` `application_controller.rb:40` — correct.
- `PosthogTrackJob#perform` `posthog_track_job.rb:6`; `User.find_by(id:)` `:7`; `Posthog::Track#track` `:10` — correct.
- Controller superclass `Api::V1::BillingController < Api::V1::BaseController` `:3` — correct.
