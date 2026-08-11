# Round 5 — model-services segment audit

Segment: Organization model methods (`#stripe_subscription`, `#sync_with_stripe`, `#assign_plan_name_from_lookup_key`, `#stripe_customer`, `#stripe_subscription_in_good_standing`), `ValidateSubscriptionChange`, `PlanFeatureGate`, `Stripe::SubscriptionStatusChecker`, `BillingPolicy`/`ApplicationPolicy`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Result

DISCREPANCY COUNT: 0

Every identifier, line number, signature, control-flow claim, and terminal in the trace for this segment was verified against the actual code and matches exactly.

## Verification log (chain of files traced)

`validate_subscription_change.rb` → `organization.rb` → `subscription_status_checker.rb` → `plan_feature_gate.rb`; `billing_policy.rb` → `application_policy.rb`; `db/schema.rb`.

### Organization model (`app/models/organization.rb`)
- `#stripe_customer` `:469`; guard `return ... unless stripe_customer_id.nil?` `:470-471`; `Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] })` `:471` (STRIPE) — MATCHES (trace item, line 118 / 159).
- `#stripe_subscription` `:474`; `return if stripe_subscription_id.nil?` `:475`; `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` `:477` (STRIPE) — MATCHES (trace item 7).
- `#stripe_customer_subscriptions` `:481`; `Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' })` `:482` (STRIPE) — MATCHES (trace lines 116/159).
- `#sync_with_stripe` `:520`; entry guards `:528` (`return unless stripe_customer_id.present?`) and `:530` (`return if stripe_customer.respond_to?(:deleted)`); `subscriptions = stripe_customer_subscriptions.data` `:538`; reject credit/plato `:539-542`; `current_subscription` find trialing/active/[0] `:543-545`; `current_subscription_price` `:550`; `current_subscription_lookup_key` `:555`; `attributes['plan'] = assign_plan_name_from_lookup_key(lookup_key: current_subscription_lookup_key, subscription_nil: current_subscription.nil?)` `:573`; `stripe_update_default_payment_method(...)` `:578`; `attributes['stripe_default_payment_method_on_file'] = !stripe_customer.invoice_settings.default_payment_method.nil?` `:580`; `update(changes_to_make)` `:600` (DB write); AI-credit allocation `if changes_to_make.key?('plan') && organization_ai_credit_balance` `:603` → `PlanFeatureGate.new(self).monthly_ai_credit_allocation` `:604` → `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` `:605` (DB write) — ALL MATCH (trace lines 113-119, 159).
- `organization_ai_credit_balance` is `has_one` (`:28`) — singular, consistent with trace usage.
- `#stripe_subscription_in_good_standing` `:673` → `Stripe::SubscriptionStatusChecker.new(self).in_good_standing?` — MATCHES (trace item 24 dead-create branch reference).
- `#assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)` `:678` → delegates to `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key` `:679` — MATCHES (trace item 24, price-model table line 143).
- `DEFAULT_PRICE_LOOKUP_KEY = "plan_simple_ats_per_job_tiered"` `:176` (duplicate of billing_controller.rb:7) — MATCHES (trace unresolved-identifiers line 167).
- `enum plan` `:94` — MATCHES (price-model table line 144).

### Stripe::SubscriptionStatusChecker (`app/services/stripe/subscription_status_checker.rb`)
- `PLAN_LOOKUP_MAPPING` `:16` — MATCHES.
- `initialize(organization)` `:86`.
- `in_good_standing?` `:90` — MATCHES (trace item 24 reference).
- `assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)` `:113`; `return 'plan_simple_ats_free' if subscription_nil` `:114`; `return @organization.plan if lookup_key.nil?` `:115`; `plan_key = PLAN_LOOKUP_MAPPING.keys.find { |key| lookup_key.include?(key) }` `:117`; `plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan` `:118` — ALL MATCH (trace item 24, price-model table line 143).

### ValidateSubscriptionChange (`app/interactors/validate_subscription_change.rb`)
- `call` `:6`; context unpacking `organization` `:10`, `target_price_id` `:11`, `action_type` `:12`; `Stripe::Price.retrieve(target_price_id)` `:15`; `target_lookup_key = target_price.lookup_key` `:16`; guard `:23`; `assign_plan_name_from_lookup_key(lookup_key: target_lookup_key)` `:26` (passes ONLY `lookup_key:`); guard `:31`; `PlanFeatureGate.all_plan_rules` `:34`; `target_plan_rules = plan_rules[...]` `:35`; guard `:40`; `current_published_count = organization.jobs.where(status: 'published').count` `:42` (DB); `target_job_limit = target_plan_rules[:job_limit]` `:43`; `if current_published_count > target_job_limit` `:53`; `'change'` message `:67`; `context.fail!(message: error_message)` `:72`; `'create'` branch reads `organization.stripe_subscription_status.present?` + `!organization.stripe_subscription_in_good_standing` `:58`; `context.success!` `:76`; rescues `Stripe::InvalidRequestError` `:77` → fail `:79`; `StandardError` `:80` → fail `:82`. SIX `context.fail!` exits `:23/:31/:40/:72/:79/:82` — ALL MATCH (trace item 24).

### PlanFeatureGate (`app/services/plan_feature_gate.rb`)
- `initialize` `:25-28` (`@plan = organization.stripe_subscription_in_good_standing ? organization.plan : 'plan_no_plan'`) — MATCHES.
- `self.all_plan_rules` `:72`; `new(OpenStruct.new(plan: nil, stripe_subscription_in_good_standing: true)).send(:plan_rules)` `:73` — MATCHES (trace item 24, price-model table line 145).
- `monthly_ai_credit_allocation` `:134` — MATCHES (trace lines 119, 159).
- `plan_rules` `:142` — MATCHES (price-model table line 145).

### Policies
- `BillingPolicy#change_subscription?` `:24` → `is_org_admin?` — MATCHES (trace item 21).
- `ApplicationPolicy#is_org_admin?` `:50` → `user.current_organization_user&.org_admin? || is_org_owner?` — MATCHES (trace item 21); `is_org_owner?` `:46` (trace unresolved line 160).

### Schema (`db/schema.rb`)
- `t.integer "plan", default: 101` `:1052` — MATCHES (price-model table line 144).
- `t.string "stripe_subscription_id"` `:1056` — MATCHES (trace item 8).
- `t.datetime "stripe_current_period_end_at"` `:1058`, `t.string "stripe_subscription_status"` `:1065`, `t.boolean "stripe_default_payment_method_on_file", default: false` `:1066` — consistent with the columns the trace lists as written by `update(changes_to_make)`.

### Cross-referenced controller identifiers in price-model table (verified existence/lines)
- `DEFAULT_PRICE_LOOKUP_KEY` `billing_controller.rb:7`; `determine_price_id` `:630`; `determine_product_info` `:642`; `get_product_from_price_id` `:649`; `determine_lookup_key` `:663` — ALL MATCH (price-model table line 141, 146). (Controller segment, but table rows correct.)
