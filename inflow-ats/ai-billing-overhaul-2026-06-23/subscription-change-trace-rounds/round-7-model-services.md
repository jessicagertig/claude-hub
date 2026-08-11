# Round 7 — model-services segment audit

Segment: Organization#stripe_subscription / #sync_with_stripe / #assign_plan_name_from_lookup_key / #stripe_customer / #stripe_customer_subscriptions / #stripe_subscription_in_good_standing, ValidateSubscriptionChange, PlanFeatureGate, Stripe::SubscriptionStatusChecker, BillingPolicy / ApplicationPolicy.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Verdict

**0 discrepancies.** Every file, method, variable, constant, line number, and terminal claim in the model + services/interactors + policies segment matches the actual analog code exactly.

## Files traced

- `app/interactors/validate_subscription_change.rb`
- `app/services/stripe/subscription_status_checker.rb`
- `app/services/plan_feature_gate.rb`
- `app/policies/billing_policy.rb`
- `app/policies/application_policy.rb`
- `app/models/organization.rb` (#stripe_customer 469, #stripe_subscription 474, #stripe_customer_subscriptions 481, #sync_with_stripe 520, #stripe_subscription_in_good_standing 673, #assign_plan_name_from_lookup_key 678, plan enum 94, DEFAULT_PRICE_LOOKUP_KEY 176)
- `db/schema.rb` (organizations.plan 1052 default 101; stripe_subscription_id 1056)

## Verified claims (sample of the row-by-row check)

ValidateSubscriptionChange (`validate_subscription_change.rb`):
- `call` def :6; context unpack :10-12; `Stripe::Price.retrieve(target_price_id)` :15 → `target_price.lookup_key` :16; guard `unless target_lookup_key` :23; `assign_plan_name_from_lookup_key(lookup_key:)` :26; guard `unless organization_alias_for_target_plan` :31; `PlanFeatureGate.all_plan_rules` :34, `target_plan_rules = plan_rules[...]` :35; guard `unless target_plan_rules` :40; `organization.jobs.where(status: 'published').count` :42 (DB terminal), `target_job_limit` :43; `if current_published_count > target_job_limit` :53; create branch `:58` reads `stripe_subscription_status.present? && !stripe_subscription_in_good_standing`; change branch downgrade string :67 → `context.fail!` :72; `context.success!` :76; rescues :77→:79, :80→:82. SIX fail! exits (:23,:31,:40,:72,:79,:82) — all confirmed. NO `else` branch on the if; `end` at :73 — confirmed.

Stripe::SubscriptionStatusChecker (`subscription_status_checker.rb`):
- `PLAN_LOOKUP_MAPPING` constant begins :16; `in_good_standing?` :90; `assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)` :113, `return 'plan_simple_ats_free' if subscription_nil` :114, `return @organization.plan if lookup_key.nil?` :115, `plan_key = PLAN_LOOKUP_MAPPING.keys.find {...}` :117, `plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan` :118 — all confirmed.

PlanFeatureGate (`plan_feature_gate.rb`):
- `initialize` :25-28 (`@plan = organization.stripe_subscription_in_good_standing ? organization.plan : 'plan_no_plan'` :27); `self.all_plan_rules` :72-74 (`new(OpenStruct.new(plan: nil, stripe_subscription_in_good_standing: true)).send(:plan_rules)` :73); `monthly_ai_credit_allocation` :134; `plan_rules` :142 — all confirmed.

Organization (`organization.rb`):
- `stripe_customer` :469 → `Stripe::Customer.retrieve({ id:, expand: ['subscriptions'] })` :471 (STRIPE); `stripe_subscription` :474, guard `return if stripe_subscription_id.nil?` :475 → `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` :477 (STRIPE); `stripe_customer_subscriptions` :481 → `Stripe::Subscription.list({ customer:, limit: 3, status: 'all' })` :482 (STRIPE).
- `sync_with_stripe` :520-610: guards :528/:530; `subscriptions = stripe_customer_subscriptions.data` :538; reject credit/plato :539-542; `current_subscription` find chain :543-545; `current_subscription_price` :550; lookup_key `"no_lookup_key_found"` fallback :555; conditional trio inside `if current_subscription.present?` :567-571; `attributes['plan'] = assign_plan_name_from_lookup_key(..., subscription_nil: current_subscription.nil?)` :573; `stripe_update_default_payment_method` :578; `stripe_default_payment_method_on_file` :580; diff-build :585-595 (skip on `current_value == value` :589-590); `update(changes_to_make)` :600 (DB write); AI-credit allocation `if changes_to_make.key?('plan') && organization_ai_credit_balance` :603, `PlanFeatureGate.new(self).monthly_ai_credit_allocation` :604, `organization_ai_credit_balance.update_columns(monthly_credits_remaining:)` :605 (DB write) — all confirmed.
- `stripe_subscription_in_good_standing` :673 → `Stripe::SubscriptionStatusChecker.new(self).in_good_standing?`; `assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)` :678 → delegates to checker — confirmed.

Policies:
- BillingPolicy#prices? `is_org_user?` :4-6; #change_subscription? `is_org_admin?` :24-26 — confirmed.
- ApplicationPolicy#is_org_admin? :50; #is_org_user? :54-56 — confirmed.

Schema:
- organizations.plan integer enum default 101 `db/schema.rb:1052`; enum `organization.rb:94`; default 101 = `plan_no_plan` (`organization.rb:95`) — confirmed.

No wrong file:line, no renamed identifier, no omitted callpoint, no thread stopped short of terminal, no wrong terminal in this segment.
