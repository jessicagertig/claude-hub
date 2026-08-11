# Round 3 — Adversarial audit: MODEL + SERVICES/INTERACTORS segment

Reviewer: model-services. Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Segment scope: `Organization#stripe_subscription` / `#sync_with_stripe` / `#assign_plan_name_from_lookup_key` / `#stripe_customer`, `ValidateSubscriptionChange`, `PlanFeatureGate`, `Stripe::SubscriptionStatusChecker`, `BillingPolicy`/`ApplicationPolicy`.

Chains traced (terminal-verified):
- ValidateSubscriptionChange.rb → Organization#assign_plan_name_from_lookup_key (organization.rb:678) → Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key (subscription_status_checker.rb:113) → PLAN_LOOKUP_MAPPING (:16, frozen hash, terminal) → PLAN_LOOKUP_MAPPING[plan_key] / @organization.plan (organizations.plan enum, organization.rb:94 / schema 1052 default 101, DB terminal)
- ValidateSubscriptionChange.rb:34 → PlanFeatureGate.all_plan_rules (plan_feature_gate.rb:72) → new(OpenStruct...).send(:plan_rules) (:73) → initialize (:25-28) → plan_rules (:142, hardcoded hash, terminal) → [:job_limit] (:43)
- ValidateSubscriptionChange.rb:42 → organization.jobs.where(status:'published').count (jobs table, status column, DB terminal)
- ValidateSubscriptionChange.rb:15 → Stripe::Price.retrieve (stripe-ruby gem boundary, STRIPE terminal)
- Organization#stripe_subscription (organization.rb:474) → Stripe::Subscription.retrieve (:477, STRIPE terminal)
- Organization#sync_with_stripe (organization.rb:520) → update(changes_to_make) (:600, DB terminal) → PlanFeatureGate.new(self).monthly_ai_credit_allocation (:604 → plan_feature_gate.rb:134 → MINIMUM_AI_CREDIT_ALLOCATION=25, terminal) → organization_ai_credit_balance.update_columns (:605, DB terminal)
- BillingPolicy#change_subscription? (billing_policy.rb:24) → ApplicationPolicy#is_org_admin? (:50) → is_org_owner? (:46) → is_god_admin? (:42, terminal)

Overall: the model/services segment of the trace is highly accurate. Line numbers and identifiers verified to terminal. Discrepancies below are the deviations found.

---

## Discrepancy 1 — call site does NOT pass `subscription_nil: false`

TRACE SAYS: (item 24 / line 78) `organization.assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)` (`:26`), characterizing the ValidateSubscriptionChange call as passing `subscription_nil: false`, and asserts it is "the only traced caller passing `subscription_nil` non-default" is `sync_with_stripe` — implying this call passes it explicitly as `false`.

ACTUAL CODE: line 26 is `organization_alias_for_target_plan = organization.assign_plan_name_from_lookup_key(lookup_key: target_lookup_key)`. The call passes ONLY `lookup_key:`. `subscription_nil` is NOT supplied at the call site; it falls back to the method default (`subscription_nil: false`). The trace's shorthand `(lookup_key:, subscription_nil: false)` misrepresents the call site as explicitly passing the keyword when it relies on the default.

file:line — `app/interactors/validate_subscription_change.rb:26`

---

## Discrepancy 2 — trace omits the interactor's context-variable unpacking (load-bearing variables)

TRACE SAYS: (item 24) the `ValidateSubscriptionChange#call` body begins at `Stripe::Price.retrieve(target_price_id)` (`:15`). It never documents where `organization`, `target_price_id`, and `action_type` originate.

ACTUAL CODE: before line 15, `call` unpacks three load-bearing variables from the interactor context: `organization = context.organization` (`:10`), `target_price_id = context.target_price_id` (`:11`), `action_type = context.action_type` (`:12`). These are the variables every later step (`organization.assign_plan_name_from_lookup_key`, `organization.jobs`, `Stripe::Price.retrieve(target_price_id)`, `case action_type`) reads. The trace traces `action_type`'s branch behavior but never shows it being assigned from `context.action_type`; same for `organization`/`target_price_id`. (Controller passes them in at billing_controller.rb:277-281 as `organization:`, `target_price_id:`, `action_type:` keys.)

file:line — `app/interactors/validate_subscription_change.rb:10-12`

---

## Discrepancy 3 — `stripe_customer` reads inside `sync_with_stripe` are omitted

TRACE SAYS: (subject header) lists `Organization#stripe_customer` as in-scope. The body never traces `#stripe_customer` and the `sync_with_stripe` note (line 112) enumerates only `:573` plan assignment, `:600` update, `:603-605` AI allocation. It does not mention any `stripe_customer` callpoint.

ACTUAL CODE: `sync_with_stripe` invokes `Organization#stripe_customer` (organization.rb:469 → `Stripe::Customer.retrieve(...)`, STRIPE terminal) at three points the trace omits: `return if stripe_customer.respond_to?(:deleted)` (`:530`, an early-return guard), `if stripe_customer.invoice_settings.default_payment_method.nil? && ...` (`:578`), and `attributes['stripe_default_payment_method_on_file'] = !stripe_customer.invoice_settings.default_payment_method.nil?` (`:580`). The `:580` read is what computes the `stripe_default_payment_method_on_file` value written by `update(changes_to_make)` — a load-bearing data source the trace's DB-write list names as a written column but never sources. `stripe_customer` is listed as a segment subject yet has zero callpoints documented.

file:line — `app/models/organization.rb:469`, called at `:530`, `:578`, `:580`

---

## Discrepancy 4 — `sync_with_stripe` upstream reads (`stripe_customer_subscriptions`, lookup-key derivation) omitted

TRACE SAYS: (line 112) `sync_with_stripe` "Body now traced to its DB-write terminals." Lists only `:573`, `:600`, `:603-605`.

ACTUAL CODE: the value flowing into `:573`'s `assign_plan_name_from_lookup_key(lookup_key: current_subscription_lookup_key, ...)` is derived by an untraced upstream block: `subscriptions = stripe_customer_subscriptions.data` (`:538`, via `Organization#stripe_customer_subscriptions` organization.rb:481 → `Stripe::Subscription.list(...)`, STRIPE terminal), `plan_subscriptions` reject-by-lookup-key (`:539-542`, filters out `credit`/`plato` lookup keys), `current_subscription` selection by status trialing/active/first (`:543-545`), `current_subscription_price` (`:550`), and `current_subscription_lookup_key = current_subscription_price.present? ? current_subscription_price["lookup_key"] : "no_lookup_key_found"` (`:555`). The trace's claim that the body is "traced to its terminals" skips the entire origin of the `lookup_key` argument and the `subscription_nil: current_subscription.nil?` argument it then highlights as the only non-default `subscription_nil` caller.

file:line — `app/models/organization.rb:538-555` (`stripe_customer_subscriptions` def `:481`)

---

## Discrepancy 5 — `assign_plan_from_lookup_key`'s `subscription_nil` branch is genuinely reachable via the only non-default caller, but trace frames it as never-taken without noting that caller is `sync_with_stripe`

TRACE SAYS: (item 24 / line 78) `return 'plan_simple_ats_free' if subscription_nil` (`:114`, "never taken here since `subscription_nil` defaults to `false`"). Framed purely from the ValidateSubscriptionChange path.

ACTUAL CODE: correct for the ValidateSubscriptionChange path (line 26 passes no `subscription_nil`, so it defaults false and `:114` is not taken). This is accurate as far as it goes; recording it only to confirm no defect at subscription_status_checker.rb:114 for this segment. NOT a code-vs-trace discrepancy — included for completeness of the audit; the `subscription_nil: true` branch is exercised only by `sync_with_stripe` (`:573`) when `current_subscription` is nil, which the trace does acknowledge at line 112/150.

file:line — `app/services/stripe/subscription_status_checker.rb:114` (no defect)

---

## Verified-correct claims (no discrepancy) for this segment

- ValidateSubscriptionChange: `def call` `:6`; `Stripe::Price.retrieve` `:15`; `target_lookup_key` `:16`; guards `:23`/`:31`/`:40`; `assign_plan_name_from_lookup_key` `:26`; `all_plan_rules` `:34`; `target_plan_rules` `:35`; `current_published_count` `:42`; `target_job_limit` `:43`; `if current_published_count > target_job_limit` `:53`; `'create'` branch `:58`; `'change'`/"Cannot downgrade" `:67`; `context.fail!` `:72`; `context.success!` `:76`; rescues `:77`/`:79` and `:80`/`:82`. Five `context.fail!` exits (`:23`,`:31`,`:40`,`:72`,`:79`/`:82`) — all correct.
- Stripe::SubscriptionStatusChecker: `assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)` `:113`; `:114`; `:115`; find `:117`; mapping `PLAN_LOOKUP_MAPPING` `:16`; `:118` fallback `@organization.plan`; `in_good_standing?` `:90`. Correct.
- PlanFeatureGate: `all_plan_rules` `:72-74`; `initialize` `:25-28`; `plan_rules` `:142`; `monthly_ai_credit_allocation` `:134`. Correct.
- Organization: `stripe_subscription` `:474` (guard `:475`, retrieve `:477`); `assign_plan_name_from_lookup_key` `:678`; `stripe_subscription_in_good_standing` `:673`→`in_good_standing?`; `sync_with_stripe` `:520`, plan assign `:573`, `update` `:600`, AI alloc `:604`/`:605`; enum `plan` `:94`; `DEFAULT_PRICE_LOOKUP_KEY` `:176` = `plan_simple_ats_per_job_tiered`; schema plan default 101 `:1052`, stripe_subscription_id `:1056`. Correct.
- BillingPolicy#change_subscription? `:24` → ApplicationPolicy#is_org_admin? `:50` (→ is_org_owner? `:46` → is_god_admin? `:42`). Correct.
