# Round 6 — model-services segment audit

Segment: Organization#stripe_subscription / #sync_with_stripe / #assign_plan_name_from_lookup_key / #stripe_customer, ValidateSubscriptionChange, PlanFeatureGate, Stripe::SubscriptionStatusChecker, BillingPolicy/ApplicationPolicy.

Worktree audited: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza

## Chains traced to terminal

- validate_subscription_change.rb:6 (call) → :15 Stripe::Price.retrieve (STRIPE) → :16 target_lookup_key → organization.rb:678 assign_plan_name_from_lookup_key → subscription_status_checker.rb:113 assign_plan_from_lookup_key → :117 PLAN_LOOKUP_MAPPING.keys.find (mapping :16) → :118 terminal value
- validate_subscription_change.rb:34 PlanFeatureGate.all_plan_rules → plan_feature_gate.rb:72 self.all_plan_rules → :73 new(OpenStruct(...)).send(:plan_rules) → initialize :25-28 → plan_rules :142 → :43 target_job_limit terminal (hardcoded job_limit ints)
- validate_subscription_change.rb:42 organization.jobs.where(status:'published').count → organization.rb:11 has_many :jobs → jobs table, status column (db/schema.rb:831/integer status) — DATABASE terminal
- validate_subscription_change.rb:58 organization.stripe_subscription_in_good_standing → organization.rb:673 → subscription_status_checker.rb:90 in_good_standing? (dead on 'change' path)
- organization.rb:520 sync_with_stripe → :471 Stripe::Customer.retrieve (STRIPE) / :482 Stripe::Subscription.list (STRIPE) → :600 update (DATABASE organizations) → :604 PlanFeatureGate.new(self).monthly_ai_credit_allocation (plan_feature_gate.rb:134) → :605 organization_ai_credit_balance.update_columns (DATABASE)
- billing_policy.rb:24 change_subscription? → application_policy.rb:50 is_org_admin? → :51 is_org_owner? → :47 is_god_admin? → framework boundary (Pundit / current_organization_user)

## Verification result

Every file:line, identifier name, signature, default value, branch structure, exit point, and terminal claim in the trace for this segment was checked against the actual code identifier-by-identifier and matches exactly.

Spot-confirmed specifics:
- ValidateSubscriptionChange line numbers (:6,:10-12,:15,:16,:23,:26,:31,:34,:35,:40,:42,:43,:53,:67,:72,:76,:77,:79,:80,:82) — all correct; six context.fail! points (:23,:31,:40,:72,:79,:82) with :79/:82 as two distinct exception-class exits — correct; context.success! at :76 runs unconditionally after the if (no else) — correct.
- Stripe::SubscriptionStatusChecker: assign_plan_from_lookup_key :113, subscription_nil guard :114, lookup_key.nil? :115, find :117, return :118, PLAN_LOOKUP_MAPPING :16, in_good_standing? :90 — all correct.
- PlanFeatureGate: all_plan_rules :72-74, initialize :25-28, plan_rules :142, monthly_ai_credit_allocation :134 — all correct.
- Organization: stripe_customer :469/:471, stripe_subscription :474/:475/:477, stripe_customer_subscriptions :481/:482, sync_with_stripe :520-610 (guards :528/:530, reads :538/:539-542/:543-545/:550/:555, conditional trio :567-571, plan :573, default_payment_method :578/:580, diff :585-595, update :600, AI-credit :603-605), assign_plan_name_from_lookup_key :678, stripe_subscription_in_good_standing :673, DEFAULT_PRICE_LOOKUP_KEY :176, enum plan :94 (plan_no_plan:101) — all correct.
- Policies: BillingPolicy#change_subscription? :24, ApplicationPolicy#is_org_admin? :50, is_org_owner? :46/:51 — all correct.
- Schema: organizations.plan default 101 db/schema.rb:1052, stripe_subscription_id db/schema.rb:1056 — both correct.

## Discrepancies

NONE. The trace is accurate for the model + services/interactors + policies segment.
