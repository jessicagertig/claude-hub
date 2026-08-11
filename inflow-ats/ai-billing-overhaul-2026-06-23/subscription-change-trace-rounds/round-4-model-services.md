# Round 4 — model-services segment audit

Segment: `Organization#stripe_subscription / #sync_with_stripe / #assign_plan_name_from_lookup_key / #stripe_customer`, `ValidateSubscriptionChange`, `PlanFeatureGate`, `Stripe::SubscriptionStatusChecker`, `BillingPolicy`/`ApplicationPolicy`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Files traced (chain)

- `app/interactors/validate_subscription_change.rb`
  → `app/models/organization.rb` (`assign_plan_name_from_lookup_key` :678)
  → `app/services/stripe/subscription_status_checker.rb` (`assign_plan_from_lookup_key` :113, `PLAN_LOOKUP_MAPPING` :16)
  → `app/services/plan_feature_gate.rb` (`all_plan_rules` :72, `plan_rules` :142)
- `app/models/organization.rb` (`sync_with_stripe` :520-610, `stripe_customer` :469, `stripe_subscription` :474, `stripe_customer_subscriptions` :481, `stripe_subscription_in_good_standing` :673)
  → `app/services/stripe/subscription_status_checker.rb` (`in_good_standing?` :90)
  → `app/services/plan_feature_gate.rb` (`monthly_ai_credit_allocation` :134, `MINIMUM_AI_CREDIT_ALLOCATION` :128)
- `app/policies/billing_policy.rb` (`change_subscription?` :24)
  → `app/policies/application_policy.rb` (`is_org_admin?` :50, `is_org_owner?` :46, `is_god_admin?` :42)
- enum `plan` `app/models/organization.rb:94`; `DEFAULT_PRICE_LOOKUP_KEY` `organization.rb:176`

## Verification result

Every identifier, line number, variable, constant, and terminal claimed by the trace for this segment was checked against the live code to its base definition (hardcoded value, gem boundary, SCREEN/STRIPE/DATABASE terminal). All claims match.

Confirmed accurate (sample of the most load-bearing):

- `ValidateSubscriptionChange#call` context unpack :10-12; `Stripe::Price.retrieve(target_price_id)` :15; `target_lookup_key = target_price.lookup_key` :16; guard :23; `assign_plan_name_from_lookup_key(lookup_key:)` :26; guard :31; `PlanFeatureGate.all_plan_rules` :34; `plan_rules[organization_alias_for_target_plan]` :35; guard :40; `organization.jobs.where(status: 'published').count` (DB terminal) :42; `target_plan_rules[:job_limit]` :43; `if current_published_count > target_job_limit` :53; 'change' message :67 → `context.fail!` :72; 'create' dead branch reads `stripe_subscription_status.present? && !stripe_subscription_in_good_standing` :58; `context.success!` :76; rescues :77/:79 and :80/:82; FIVE fail! exits (:23, :31, :40, :72, :79/:82) — ALL MATCH.
- `Organization#assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)` :678 delegates to `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)` :113; `return 'plan_simple_ats_free' if subscription_nil` :114; `return @organization.plan if lookup_key.nil?` :115; `PLAN_LOOKUP_MAPPING.keys.find { |key| lookup_key.include?(key) }` :117; `plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan` :118; mapping :16 — ALL MATCH.
- `PlanFeatureGate.all_plan_rules` :72 → `new(OpenStruct.new(plan: nil, stripe_subscription_in_good_standing: true)).send(:plan_rules)` :73; `initialize` :25-28; `plan_rules` keyed-by-alias hash :142; `monthly_ai_credit_allocation` :134 — ALL MATCH.
- `Organization#sync_with_stripe` :520-610: guards :528/:530; `stripe_customer_subscriptions.data` :538 → `Stripe::Subscription.list({customer:, limit: 3, status: 'all'})` :482 (def :481); reject credit/plato :539-542; `current_subscription` trialing||active||[0] :543-545; `current_subscription_price` :550; `current_subscription_lookup_key` :555; `attributes['plan'] = assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: current_subscription.nil?)` :573; `stripe_update_default_payment_method` :578; `attributes['stripe_default_payment_method_on_file']` :580; `Organization#stripe_customer` :469 → `Stripe::Customer.retrieve({id:, expand: ['subscriptions']})` :471; `update(changes_to_make)` :600; AI-credit allocation `:603-605` (`PlanFeatureGate.new(self).monthly_ai_credit_allocation` :604 → `organization_ai_credit_balance.update_columns(monthly_credits_remaining:)` :605); DB-write columns plan/stripe_subscription_status/stripe_subscription_id/stripe_current_period_end_at/stripe_default_payment_method_on_file — ALL MATCH.
- `Organization#stripe_subscription` :474, guard :475, `Stripe::Subscription.retrieve({id:, expand: ['items.data.price.tiers']})` :477 — MATCH.
- `Organization#stripe_subscription_in_good_standing` :673 → `Stripe::SubscriptionStatusChecker#in_good_standing?` :90 — MATCH.
- `BillingPolicy#change_subscription?` :24 → `is_org_admin?` (`application_policy.rb:50`) → `is_org_owner?` :46 → `is_god_admin?` :42 — MATCH.
- enum `plan` `organization.rb:94`, default `plan_no_plan: 101` — MATCH.
- `DEFAULT_PRICE_LOOKUP_KEY = "plan_simple_ats_per_job_tiered"` `organization.rb:176` (the duplicated/legacy copy) — MATCH.

## Discrepancies

None. The trace is accurate for the model + services/interactors segment. Every line:number, identifier, variable, constant, and terminal (Stripe / DATABASE) checked resolves exactly to the live code in the worktree.
