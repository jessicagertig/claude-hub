# Round 2 — Model + Services/Interactors segment audit

Reviewer: model-services. Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Segment scope: `Organization#stripe_subscription` / `#sync_with_stripe` / `#assign_plan_name_from_lookup_key` / `#stripe_customer`, `ValidateSubscriptionChange`, `PlanFeatureGate`, `Stripe::SubscriptionStatusChecker`, `BillingPolicy`/`ApplicationPolicy`.

Chains traced to terminal for this segment:
- `validate_subscription_change.rb:15` → `Stripe::Price.retrieve` (STRIPE terminal, gem boundary)
- `validate_subscription_change.rb:26` → `organization.rb:678` `assign_plan_name_from_lookup_key` → `subscription_status_checker.rb:113` `assign_plan_from_lookup_key` → `PLAN_LOOKUP_MAPPING` `:16` (hardcoded hash, terminal)
- `validate_subscription_change.rb:34` → `plan_feature_gate.rb:72` `all_plan_rules` → `:73` `new(OpenStruct...).send(:plan_rules)` → `initialize :25-28` → `plan_rules :142` (hardcoded hash, terminal)
- `validate_subscription_change.rb:42` → `organization.jobs.where(status: 'published').count` (DATABASE terminal — `jobs` table, `status` column)
- `billing_policy.rb:24` `change_subscription?` → `application_policy.rb:50` `is_org_admin?` → `:46` `is_org_owner?` → `:42` `is_god_admin?` → `user.current_organization_user&.*` (gem/Devise boundary)
- `organization.rb:474` `stripe_subscription` → `:477` `Stripe::Subscription.retrieve` (STRIPE terminal, gem boundary)

Overall the segment is HIGHLY accurate. Every file, method, and line number the trace cites for this segment matches the actual code. Discrepancies found are completeness/precision gaps in how the trace describes the interactor body, not wrong line numbers.

---

## Discrepancy 1 (LOW — omitted callpoints inside ValidateSubscriptionChange)

TRACE SAYS: Item 24 summarizes the whole interactor body as `current_published_count = organization.jobs.where(status: 'published').count (:42 ... ) vs target_job_limit → context.fail! (:72) or context.success! (:76)`. It does not mention the two early validation guards or the rescue handlers.

ACTUAL CODE: `validate_subscription_change.rb` has additional callpoints/branches the trace omits:
- `:23` `return context.fail!(message: 'Invalid price ID provided') unless target_lookup_key` (early guard on missing lookup_key)
- `:31` `return context.fail!(message: 'Invalid plan key provided') unless organization_alias_for_target_plan` (early guard)
- `:40` `return context.fail!(message: 'Invalid plan key provided') unless target_plan_rules` (early guard)
- `:77-79` `rescue Stripe::InvalidRequestError => e` → `Rails.logger.error e` + `context.fail!(message: 'Invalid price ID provided')`
- `:80-82` `rescue StandardError => e` → `Rails.logger.error e` + `context.fail!(message: 'An error occurred while validating the subscription change')`

So there are FIVE `context.fail!` exit points (`:23`, `:31`, `:40`, `:72`, `:79`/`:82`), not the single `:72` the trace implies. file:line — `app/interactors/validate_subscription_change.rb:23,31,40,72,77-82`.

---

## Discrepancy 2 (LOW — omitted organization reads inside the interactor)

TRACE SAYS: The interactor trace (item 24) lists only `assign_plan_name_from_lookup_key`, `PlanFeatureGate.all_plan_rules`, and `organization.jobs.where(...).count` as the org/service touchpoints.

ACTUAL CODE: The `'create'` branch of the error-message `case action_type` reads two more Organization methods:
- `:58` `organization.stripe_subscription_status.present?` (DB column read — `stripe_subscription_status`)
- `:58` `!organization.stripe_subscription_in_good_standing` → `organization.rb:673` → `Stripe::SubscriptionStatusChecker.new(self).in_good_standing?` (`subscription_status_checker.rb:90`)

These are not reached on the `action_type: 'change'` happy path (the path under audit), so they are dead for the portal flow — but they exist in the method body and are within this segment's named services (`Organization`, `Stripe::SubscriptionStatusChecker`). The trace does not note that `Stripe::SubscriptionStatusChecker#in_good_standing?` is reachable from this interactor at all. file:line — `app/interactors/validate_subscription_change.rb:58` → `app/models/organization.rb:673` → `app/services/stripe/subscription_status_checker.rb:90`.

---

## Discrepancy 3 (LOW — `assign_plan_name_from_lookup_key` keyword signature understated)

TRACE SAYS: Item 24 / price-model row: `organization.assign_plan_name_from_lookup_key(lookup_key:)` and `assign_plan_from_lookup_key` taking `lookup_key`.

ACTUAL CODE: Both methods take a SECOND keyword `subscription_nil:` (default `false`):
- `app/models/organization.rb:678` `def assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)`
- `app/services/stripe/subscription_status_checker.rb:113` `def assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)`

On the ValidateSubscriptionChange call (`:26`) `subscription_nil` defaults to `false`, so the `return 'plan_simple_ats_free' if subscription_nil` guard (`subscription_status_checker.rb:114`) is never taken on this path — but the trace's signature is incomplete. The trace does cite `:114` for the `subscription_nil` branch elsewhere (item 24), so the branch is acknowledged; only the call-side signature understates the parameter. file:line — `app/models/organization.rb:678`, `app/services/stripe/subscription_status_checker.rb:113`.

---

## Discrepancy 4 (INFO — `sync_with_stripe` body untraced but DOES touch this segment's services / DATABASE)

TRACE SAYS: Unresolved-identifiers note (line 135): "`sync_with_stripe` — mentioned in the analog action comment as running on the user's return, but NOT invoked within `change_subscription_portal_session`; body not traced for this path." Price-model summary (line 124): "`PlanFeatureGate` keys all limits/features/AI-credit allocations off that alias string."

ACTUAL CODE: `sync_with_stripe` (`app/models/organization.rb:520-610`) is the method that actually PERSISTS the plan alias and grants credits — it is the DATABASE-write terminal the change flow ultimately depends on, and it lives inside this segment's `Organization` model:
- `:573` `attributes['plan'] = assign_plan_name_from_lookup_key(lookup_key: current_subscription_lookup_key, subscription_nil: current_subscription.nil?)` (this is where `subscription_nil` is passed non-default — the only traced caller that exercises that param)
- `:600` `update(changes_to_make)` (DATABASE write — `organizations` row, incl. `plan`, `stripe_subscription_status`, `stripe_subscription_id`, `stripe_current_period_end_at`, `stripe_default_payment_method_on_file`)
- `:603-605` on `plan` change: `PlanFeatureGate.new(self).monthly_ai_credit_allocation` (`plan_feature_gate.rb:134`) → `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` (DATABASE write — `organization_ai_credit_balances`)

This is the concrete callpoint behind the trace's abstract claim that "PlanFeatureGate keys all AI-credit allocations off that alias." The trace stops short of `monthly_ai_credit_allocation` (`plan_feature_gate.rb:134`) and the `update_columns` DB terminal. Not strictly on the `change_subscription_portal_session` request (which the trace correctly says does NOT call `sync_with_stripe`), so this is INFO, but it is the missing terminal for the price-model claim. file:line — `app/models/organization.rb:520,573,600,603-605` → `app/services/plan_feature_gate.rb:134`.

---

## Verified-correct claims (no discrepancy) for this segment

- `Organization#stripe_subscription` `:474`, guard `:475`, `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` `:477` — EXACT.
- `Organization#stripe_customer` `:469` (`Stripe::Customer.retrieve`) — EXACT (file location confirmed; not on change path, trace does not claim it is).
- `Organization#assign_plan_name_from_lookup_key` `:678` — EXACT line.
- `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key` `:113`; `:114` subscription_nil guard; `:115` lookup_key.nil? guard; `:117` `PLAN_LOOKUP_MAPPING.keys.find { |key| lookup_key.include?(key) }`; `:118` `plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan`; mapping `:16` — ALL EXACT.
- `PlanFeatureGate.all_plan_rules` `:72`; `:73` `new(OpenStruct.new(plan: nil, stripe_subscription_in_good_standing: true)).send(:plan_rules)`; `initialize :25-28`; `plan_rules :142` — ALL EXACT.
- `ValidateSubscriptionChange`: `Stripe::Price.retrieve(target_price_id)` `:15`; `target_lookup_key = target_price.lookup_key` `:16`; `assign_plan_name_from_lookup_key(lookup_key:)` `:26`; `PlanFeatureGate.all_plan_rules` `:34`; `current_published_count = organization.jobs.where(status: 'published').count` `:42`; `target_job_limit = target_plan_rules[:job_limit]` `:43`; `context.fail!` `:72`; `context.success!` `:76` — ALL EXACT.
- `BillingPolicy#change_subscription?` `:24` → `is_org_admin?` — EXACT.
- `ApplicationPolicy#is_org_admin?` `:50`, `is_org_owner?` `:46` (called by `:51`), short-circuit-on-org-admin-true claim — EXACT.
- `organizations.plan` enum `app/models/organization.rb:94` (`plan_no_plan: 101`), schema `db/schema.rb:1052` `t.integer "plan", default: 101` — EXACT.
- `DEFAULT_PRICE_LOOKUP_KEY` duplicate at `organization.rb:176` (`"plan_simple_ats_per_job_tiered"`) — EXACT; trace's "possibly dead/legacy, not read by traced path" is consistent with the segment code.
- `stripe_subscription_id` column `db/schema.rb:1056` — EXACT.
