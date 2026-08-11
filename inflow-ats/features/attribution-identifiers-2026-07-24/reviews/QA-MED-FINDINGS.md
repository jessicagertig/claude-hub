# QA — Consolidated MED findings (attribution-identifiers, qa-run-1)

One MED across all layers and runs after dedup.

## MED-1 — Pre-existing RSpec failure: `spec/models/organization_ai_credits_lifecycle_spec.rb:33`

- **What:** `monthly_credits_remaining` expected 25, got 0. The spec's organization has no Stripe subscription, so `PlanFeatureGate#initialize` resolves `@plan` to `'plan_no_plan'` (allocation 0; note `0 || MINIMUM` returns 0 because 0 is truthy in Ruby), the `allocation.positive?` guard in `Organization#create_ai_credit_state_if_needed` (organization.rb:192) skips `update_columns`, and the balance stays 0.
- **Why MED (not fixed in this QA):** pre-existing. `organization.rb`, `plan_feature_gate.rb`, and the spec file are all byte-identical on `b4cb4463a` (pre-feature); the failure is deterministic across seeds and in isolation; the attribution feature makes no model changes (SPEC §3). Chain: organization_ai_credits_lifecycle_spec.rb → organization.rb `create_ai_credit_state_if_needed` (line 192) → plan_feature_gate.rb `initialize` (line 29) / `monthly_ai_credit_allocation` (line 134) → config/initializers/01_variables.rb:125-126.
- **Where found:** Layer 4 regression, l4-001 (reviews/qa-run-1/layer-4-regression/round-1.json).

## Notes (LOW, no action)

- Layer 5 console noise, all pre-existing app-wide and none attribution-related: history deprecation warning, redux `combineReducers` warning, `heap-.js` 404, 401 on `/api/v1/me` while signed out, `darkModeAllowed` prop warning.
