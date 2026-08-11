# Round 3 — routes + controller segment audit

Segment: `config/routes.rb` billing collection + every `BillingController` action in the flow (`customer_subscription`, `prices`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`) + `determine_price_id`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Chains traced:
- routes.rb:163-186 (billing collection) — every route line verified.
- billing_controller.rb:237-263 (`change_subscription` UNUSED), :268-327 (`change_subscription_portal_session`), :331-380 (`update_payment_method_and_subscription_portal_session`), :385-470 (`continue_change_subscription_portal_session`), :535-541 (`prices`), :606-621 (`customer_subscription`), :630-640 (`determine_price_id`).
- billing_controller.rb -> organization.rb:474-478 (`stripe_subscription`) -> Stripe gem boundary.
- billing_controller.rb -> billing_policy.rb:24 (`change_subscription?`) -> application_policy.rb:50 (`is_org_admin?`).
- billing_controller.rb -> application_controller.rb:40 (`render_general_errors`).
- `determine_price_id` call sites grep: :50, :198, :252, :279, :299, :311, :343, :643 (8 total) — matches trace exactly.

The trace is highly accurate for this segment. Route line numbers (168, 169, 170, 174, 177, 178), action line numbers, guard lines, render/redirect shapes, rescue lines, the options-block lines, and `determine_price_id` internals all verified correct. Discrepancies found are listed below.

---

## DISCREPANCY 1 — wrong "first executable statement" in `customer_subscription`

TRACE SAYS (item 6, line 20): "The FIRST executable statement is `ap current_organization.stripe_subscription` (`:608`), an awesome_print debug line that UNCONDITIONALLY invokes `Organization#stripe_subscription` ... BEFORE the nil-check".

ACTUAL CODE: The first executable statement of `customer_subscription` is `ap 'GETTING THE CUSTOMER SUBSCRIPTION'` at line 607. The `ap current_organization.stripe_subscription` call is the SECOND statement, at line 608. The substantive claim (that line 608 invokes `stripe_subscription` before the nil-check and produces a double call on the happy path) is correct, but "the FIRST executable statement is ...`:608`" is false — line 607 precedes it.

file:line — `app/controllers/api/v1/billing_controller.rb:607` (the actual first statement, omitted by the trace)

---

## DISCREPANCY 2 — `after_completion.redirect.return_url` mis-located to the `continue_url` build range

TRACE SAYS (item 18b, line 55): "builds a `payment_method_update` portal session whose `after_completion.redirect.return_url` (`continue_url`, `:346-349`) carries `subscription_item_id` + `target_price_id` ... + `return_url`".

ACTUAL CODE: Lines 346-349 build the local `continue_url` string. The `after_completion.redirect.return_url` field of the Stripe options hash is set at line 357 (`redirect: { return_url: continue_url }`), inside the `flow_data.after_completion` block (lines 355-358), NOT at :346-349. The trace conflates the `continue_url` construction (:346-349) with the `after_completion.redirect.return_url` assignment (:357).

file:line — `app/controllers/api/v1/billing_controller.rb:357` (the actual `after_completion.redirect.return_url`); :346-349 is only the `continue_url` build.

---

## DISCREPANCY 3 — `update_payment_method_and_subscription_portal_session` guards omitted

TRACE SAYS (item 18b, line 55): describes only the portal-session build (`continue_url`, options, `redirectUrl`) and the component callbacks; it does not enumerate the action's entry guards.

ACTUAL CODE: `update_payment_method_and_subscription_portal_session` has three `raise StandardError ... unless ... present?` guards at lines 335-337 (`stripe_customer_id`, `stripe_subscription_id`, `params[:subscription_item_id]`), structurally identical to `change_subscription_portal_session`'s guards at :272-274 that the trace DOES enumerate (item 22). These guards are part of "every guard" for this action and are missing from the trace.

file:line — `app/controllers/api/v1/billing_controller.rb:335-337`

---

## DISCREPANCY 4 — `final_return_path` / `final_return_url` construction omitted in the payment-method action

TRACE SAYS (item 18b): jumps from `determine_price_id` (`:343`) straight to the `continue_url` build (`:346-349`), describing `continue_url` as carrying "`return_url` to the continue endpoint".

ACTUAL CODE: Between determine_price_id (:343) and continue_url (:346-349) the action computes `final_return_path = params[:return_url].presence || '/account'` (:340) and `final_return_url = "#{Variables::AtsRootUrl}#{final_return_path}"` (:341). It is `final_return_url` (NOT a raw `params[:return_url]`) that is CGI-escaped into `continue_url`'s `return_url` query param (:349) AND set as the top-level `return_url` of the portal options (:360). The trace omits the `final_return_path`/`final_return_url` derivation and its `/account` fallback, and does not note that the top-level `return_url:` of the options hash is `final_return_url` (:360).

file:line — `app/controllers/api/v1/billing_controller.rb:340-341`, :349, :360

---

## DISCREPANCY 5 — `update_payment_method_and_subscription_portal_session` rescues omitted

TRACE SAYS (item 18b): no rescue clauses are documented for the payment-method action (contrast item 30, which fully enumerates `change_subscription_portal_session`'s rescues at :314/:320/:324).

ACTUAL CODE: `update_payment_method_and_subscription_portal_session` has three rescues: `rescue Pundit::NotAuthorizedError => e` (:368, Sentry + render_general_errors(['Only admins...'])), `rescue Stripe::InvalidRequestError => e` (:372, Sentry + render_general_errors([e.message])), `rescue StandardError => e` (:376, Sentry + render_general_errors(['Unable to start payment method update flow'])). Note this StandardError rescue DOES call `Sentry.capture_exception` (:377), unlike `change_subscription_portal_session`'s StandardError rescue (:324) which does not — a structural difference the trace's omission hides.

file:line — `app/controllers/api/v1/billing_controller.rb:368`, :372, :376-377

---

## DISCREPANCY 6 — `Rails.logger.error` lines inside the continue action's blank-guards omitted

TRACE SAYS (items 57-58): the first two guards in `continue_change_subscription_portal_session` are `if current_organization.stripe_customer_id.blank?` (:390) → `return redirect_to ...` (:392) and `if ...stripe_subscription_id.blank?` (:395) → `return redirect_to ...` (:397).

ACTUAL CODE: Each guard body has a `Rails.logger.error` line preceding the redirect that the trace skips: `Rails.logger.error "Missing Stripe customer ID for org #{current_organization.id}"` (:391) and `Rails.logger.error "Missing Stripe subscription ID for org #{current_organization.id}"` (:396). Minor omission (the redirect targets and line numbers the trace cites are correct).

file:line — `app/controllers/api/v1/billing_controller.rb:391`, :396
