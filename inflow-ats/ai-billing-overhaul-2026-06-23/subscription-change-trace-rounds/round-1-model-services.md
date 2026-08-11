# Round 1 — Model + Services/Interactors segment audit

Reviewer: model-services. Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.
Trace under audit: `traces/subscription-change-analog-trace.md`.

Segment scope: `Organization#stripe_subscription` / `#sync_with_stripe` / `#assign_plan_name_from_lookup_key` / `#stripe_customer`; `ValidateSubscriptionChange`; `PlanFeatureGate`; `Stripe::SubscriptionStatusChecker`; `BillingPolicy`/`ApplicationPolicy`.

Chains traced:
- `ValidateSubscriptionChange.rb` -> `organization.rb` (`assign_plan_name_from_lookup_key`) -> `subscription_status_checker.rb` (`assign_plan_from_lookup_key` / `PLAN_LOOKUP_MAPPING`) -> terminal hash key
- `ValidateSubscriptionChange.rb` -> `plan_feature_gate.rb` (`all_plan_rules` -> `initialize` -> `plan_rules`) -> terminal literal hash
- `billing_policy.rb` (`change_subscription?`) -> `application_policy.rb` (`is_org_admin?` -> `is_org_owner?` -> `is_god_admin?`) -> framework (`user.current_organization_user`)
- `organization.rb` (`stripe_subscription`, `stripe_customer`, `sync_with_stripe`, `stripe_subscription_in_good_standing`) -> `subscription_status_checker.rb` / Stripe gem

Verdict: the segment is largely accurate. Most cited file:line pairs for ValidateSubscriptionChange, PlanFeatureGate, SubscriptionStatusChecker, BillingPolicy, ApplicationPolicy, and the Organization methods are correct. Findings below are the discrepancies.

---

## DISC-1 (HIGH) — wrong schema line for `organizations.plan` column

TRACE SAYS: "persisted plan alias | `organizations.plan` integer enum (default 101 = `plan_no_plan`) | `db/schema.rb:1048`" (price-model table, trace line 90).

ACTUAL CODE: the `organizations` table `t.integer "plan", default: 101` is at `db/schema.rb:1052`. Line 1048 is `t.string "clearbit_website_url"`.

file:line: `db/schema.rb:1052` (trace cites `:1048`).

---

## DISC-2 (MED) — `assign_plan_from_lookup_key` terminal omits the two `@organization.plan` fallback branches and the `subscription_nil` branch

TRACE SAYS (trace line 89 / price-model table): the lookup_key->alias chain terminates at `PLAN_LOOKUP_MAPPING.keys.find { |k| lookup_key.include?(k) }` -> `PLAN_LOOKUP_MAPPING[plan_key]`. Trace presents `PLAN_LOOKUP_MAPPING[plan_key]` as the sole terminal.

ACTUAL CODE (`subscription_status_checker.rb:113-119`):
```ruby
def assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)
  return 'plan_simple_ats_free' if subscription_nil      # branch 1 (line 114)
  return @organization.plan if lookup_key.nil?           # branch 2 (line 115)
  plan_key = PLAN_LOOKUP_MAPPING.keys.find { |key| lookup_key.include?(key) }
  plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan   # branch 3 fallback (line 118)
end
```
The method has THREE terminals, not one: `'plan_simple_ats_free'` (subscription_nil), `@organization.plan` (lookup_key nil), and the no-match fallback `@organization.plan`. The trace's structural map shows only the matched-key terminal and omits the no-match `@organization.plan` fallback that the same `find` line falls through to. (On the analog 'change' path subscription_nil is false and lookup_key is present, so only branch 3 is live — but the structural map claims to be exact.)

file:line: `app/services/stripe/subscription_status_checker.rb:113-119` (trace shows only `:118`-equivalent matched terminal).

---

## DISC-3 (MED) — `PlanFeatureGate.all_plan_rules` chain omits the `OpenStruct`/`initialize` hop

TRACE SAYS (trace line 48 + price-model table line 91): "`PlanFeatureGate.all_plan_rules` (`:72`) -> `plan_rules` (`:142`)". The chain jumps directly from `all_plan_rules` to `plan_rules`.

ACTUAL CODE (`plan_feature_gate.rb:72-74`): `all_plan_rules` does NOT call `plan_rules` directly. It constructs `new(OpenStruct.new(plan: nil, stripe_subscription_in_good_standing: true))` then `.send(:plan_rules)`. The `initialize` (lines 25-28) runs `@plan = organization.stripe_subscription_in_good_standing ? organization.plan : 'plan_no_plan'`, resolving `@plan = nil` for the OpenStruct. The trace skips both the `OpenStruct` construction and the `initialize` hop. (`plan_rules` itself does not read `@plan`, so the end hash is identical — the omission is structural, not behavioral.)

file:line: `app/services/plan_feature_gate.rb:72-74` and `:25-28` (omitted from the chain).

---

## DISC-4 (LOW) — ValidateSubscriptionChange structural map omits its Organization method reads in the `create` branch

TRACE SAYS (trace lines 45-49): the structural map of `ValidateSubscriptionChange` lists `Stripe::Price.retrieve`, `target_lookup_key`, `assign_plan_name_from_lookup_key`, `PlanFeatureGate.all_plan_rules`, and the published-count vs `job_limit` compare. It does not mention any other Organization reads.

ACTUAL CODE (`validate_subscription_change.rb:58`): the `action_type == 'create'` branch reads `organization.stripe_subscription_status.present?` and `organization.stripe_subscription_in_good_standing` (both Organization methods in this segment; `stripe_subscription_in_good_standing` -> `Stripe::SubscriptionStatusChecker#in_good_standing?`). The analog under audit is action_type `'change'`, so this branch is not exercised on the analog path, but the trace claims to be an "exact structural map" of the interactor and omits these two model callpoints entirely.

file:line: `app/interactors/validate_subscription_change.rb:58` (and `organization.rb:673`).

---

## DISC-5 (LOW) — `SubscriptionStatusChecker#assign_plan_from_lookup_key` find block variable

TRACE SAYS (trace line 89): `PLAN_LOOKUP_MAPPING.keys.find { |k| lookup_key.include?(k) }`.

ACTUAL CODE (`subscription_status_checker.rb:117`): block parameter is `|key|`, not `|k|`: `PLAN_LOOKUP_MAPPING.keys.find { |key| lookup_key.include?(key) }`. The trace also never cites the line of the `.find` call itself (line 117); it cites only `:113` (def) and `:16` (mapping constant).

file:line: `app/services/stripe/subscription_status_checker.rb:117` (renamed var; line not cited).

---

## Verified-correct claims (no discrepancy) for this segment

- `ValidateSubscriptionChange` def `:6`, `Stripe::Price.retrieve` `:15`, `target_lookup_key` `:16`, `assign_plan_name_from_lookup_key` call `:26`, published-jobs count `:42` — all correct.
- Call signature `ValidateSubscriptionChange.call(organization: current_organization, target_price_id: determine_price_id, action_type: 'change')` — correct (`billing_controller.rb:277-281`).
- `render_general_errors([result.message])` at `billing_controller.rb:284` — correct.
- `PlanFeatureGate.all_plan_rules` `:72`, `plan_rules` `:142` — line numbers correct.
- `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key` `:113`, `PLAN_LOOKUP_MAPPING` `:16` — correct.
- `Organization#stripe_subscription` def `:474` (Stripe call body line 477), `#stripe_customer` `:469`, `#sync_with_stripe` `:520`, `#assign_plan_name_from_lookup_key` `:678`, `#stripe_subscription_in_good_standing` `:673` — all correct.
- `BillingPolicy#change_subscription?` `:24` -> `is_org_admin?`; `is_org_admin?` at `application_policy.rb:50`; `is_org_owner?` at `:46-47` (correctly noted as not load-bearing on the true branch) — correct.
- `plan` enum at `organization.rb:94`, default 101 = `plan_no_plan` — correct.
- `DEFAULT_PRICE_LOOKUP_KEY = "plan_simple_ats_per_job_tiered"` at `organization.rb:176` and `billing_controller.rb:7` (duplicate constants); modal copies `= "plan_ats_tier_apollo_monthly"` — all correct.
- `interactor (3.1.2)` at `Gemfile.lock:251` — correct.
