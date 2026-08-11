# Round 8 — model-services segment audit

Segment: Organization#stripe_subscription / #sync_with_stripe / #assign_plan_name_from_lookup_key / #stripe_customer / #stripe_customer_subscriptions / #stripe_subscription_in_good_standing, ValidateSubscriptionChange, PlanFeatureGate, Stripe::SubscriptionStatusChecker, BillingPolicy / ApplicationPolicy.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Verdict

**0 discrepancies.** Every file, method, variable, constant, line number, and terminal claim in the model + services/interactors + policies segment matches the actual analog code exactly. Independent re-verification of round 7's 0-finding result; all rows re-checked against the live code, not copied from the prior round.

## Files traced (chains)

- `validate_subscription_change.rb` → `organization.rb#assign_plan_name_from_lookup_key` → `subscription_status_checker.rb#assign_plan_from_lookup_key` (terminal: `@organization.plan` / `PLAN_LOOKUP_MAPPING[plan_key]`)
- `validate_subscription_change.rb` → `plan_feature_gate.rb#all_plan_rules` → `plan_rules` (terminal: hardcoded `:job_limit` ints)
- `validate_subscription_change.rb#call` → `Stripe::Price.retrieve` (STRIPE boundary) ; `organization.jobs.where(status: 'published').count` (DATABASE terminal)
- `organization.rb#sync_with_stripe` → `stripe_customer_subscriptions` → `Stripe::Subscription.list` (STRIPE) ; → `update(changes_to_make)` (DATABASE write) ; → `PlanFeatureGate#monthly_ai_credit_allocation` → `organization_ai_credit_balance.update_columns` (DATABASE write)
- `billing_controller` authorize → `billing_policy.rb` → `application_policy.rb#is_org_user?`/`#is_org_admin?` (terminal: `current_organization_user&.org_*?`)
- `db/schema.rb` (organizations.plan 1052 default 101; stripe_subscription_id 1056)

## Row-by-row verification (all SAME)

ValidateSubscriptionChange (`validate_subscription_change.rb`):
- `call` def :6; context unpack `organization`/`target_price_id`/`action_type` :10-12; `Stripe::Price.retrieve(target_price_id)` :15 → `target_lookup_key = target_price.lookup_key` :16; guard `unless target_lookup_key` :23; `organization.assign_plan_name_from_lookup_key(lookup_key: target_lookup_key)` (only `lookup_key:` passed) :26; guard `unless organization_alias_for_target_plan` :31; `PlanFeatureGate.all_plan_rules` :34, `target_plan_rules = plan_rules[organization_alias_for_target_plan]` :35; guard `unless target_plan_rules` :40; `organization.jobs.where(status: 'published').count` :42 (DB), `target_job_limit = target_plan_rules[:job_limit]` :43; `if current_published_count > target_job_limit` :53; 'create' branch `:58` reads `organization.stripe_subscription_status.present? && !organization.stripe_subscription_in_good_standing`; 'change' downgrade string :67 → `context.fail!(message: error_message)` :72; NO `else`; `context.success!` :76 unconditional after `if`; rescue `Stripe::InvalidRequestError` :77 → :79, rescue `StandardError` :80 → :82. SIX `context.fail!` exits (:23,:31,:40,:72,:79,:82) — all confirmed.

Stripe::SubscriptionStatusChecker (`subscription_status_checker.rb`):
- `PLAN_LOOKUP_MAPPING` :16; `in_good_standing?` :90; `assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)` :113, `return 'plan_simple_ats_free' if subscription_nil` :114, `return @organization.plan if lookup_key.nil?` :115, `plan_key = PLAN_LOOKUP_MAPPING.keys.find { |key| lookup_key.include?(key) }` :117, `plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan` :118 — all confirmed.

PlanFeatureGate (`plan_feature_gate.rb`):
- `initialize` :25-28; `self.all_plan_rules` :72 → `new(OpenStruct.new(plan: nil, stripe_subscription_in_good_standing: true)).send(:plan_rules)` :73; `monthly_ai_credit_allocation` :134 → fallback `MINIMUM_AI_CREDIT_ALLOCATION` (=25, :128) :135; `plan_rules` :142, keyed by alias, `:job_limit` hardcoded ints — all confirmed.

Organization (`organization.rb`):
- `stripe_customer` :469, guard nil :470-471 → `Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] })` :471 (STRIPE); `stripe_subscription` :474, guard `return if stripe_subscription_id.nil?` :475 → `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` :477 (STRIPE); `stripe_customer_subscriptions` :481 → `Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' })` :482 (STRIPE).
- `sync_with_stripe` :520-610: guards :528 (`return unless stripe_customer_id.present?`) / :530 (`return if stripe_customer.respond_to?(:deleted)`); `subscriptions = stripe_customer_subscriptions.data` :538; reject credit/plato :539-542; `current_subscription` find(trialing)||find(active)||[0] :543-545; `current_subscription_price` :550; `"no_lookup_key_found"` fallback :555; conditional trio inside `if current_subscription.present?` :567-571 (id :568, status :569, period_end :570); `attributes['plan'] = assign_plan_name_from_lookup_key(lookup_key: current_subscription_lookup_key, subscription_nil: current_subscription.nil?)` :573; `stripe_update_default_payment_method(...)` :578; `attributes['stripe_default_payment_method_on_file'] = !stripe_customer.invoice_settings.default_payment_method.nil?` :580; diff-build `attributes.each` :585-595 (skip `current_value == value` :589-590); `if changes_to_make.any?` :597 → `update(changes_to_make)` :600 (DB write); AI-credit `if changes_to_make.key?('plan') && organization_ai_credit_balance` :603, `new_allocation = PlanFeatureGate.new(self).monthly_ai_credit_allocation` :604, `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` :605 (DB write) — all confirmed.
- `stripe_subscription_in_good_standing` :673 → `Stripe::SubscriptionStatusChecker.new(self).in_good_standing?` :674; `assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)` :678 → delegates :679 — confirmed.

Policies:
- BillingPolicy#prices? `is_org_user?` :4-6; #change_subscription? `is_org_admin?` :24-26 — confirmed.
- ApplicationPolicy#is_org_admin? `user.current_organization_user&.org_admin? || is_org_owner?` :50-52; #is_org_user? `... org_user? || is_org_admin?` :54-56 — confirmed.

Schema / enum / constants:
- organizations.plan integer enum default 101 `db/schema.rb:1052`; stripe_subscription_id `db/schema.rb:1056`; enum `organization.rb:94`, default 101 = `plan_no_plan` (`organization.rb:95`); `DEFAULT_PRICE_LOOKUP_KEY = 'plan_simple_ats_per_job_tiered'` duplicated at `billing_controller.rb:7` and `organization.rb:176` — confirmed.

## Notes (non-discrepancies)

- `ValidateSubscriptionChange#call` opens with `ap 'ValidateSubscriptionChange'` (:7) and `ap context` (:8) before the context unpack at :10-12, plus interleaved `ap` debug lines (:18-21, :28-29, :37-38, :45-50). The trace's "Context unpacking at the top of the body (:10-12)" does not enumerate these `ap` lines, unlike its treatment of the controller's `ap` lines. These are non-load-bearing awesome_print debug statements with no effect on data flow or terminals; they do not constitute a structural/identifier discrepancy in the traced happy path. Recorded for completeness only — NOT counted as a discrepancy.

No wrong file:line, no renamed/omitted identifier, no thread stopped short of its STRIPE/DATABASE/SCREEN terminal, no wrong terminal, no mismatched structural claim in this segment.
