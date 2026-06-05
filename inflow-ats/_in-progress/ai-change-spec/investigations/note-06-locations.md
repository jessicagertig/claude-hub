# Investigation — Note #6: AiCreditPacks move + RoleCategoryGroups deletion

## 6A — AiCreditPacks
- Defined in `config/initializers/ai_credit_packs.rb` as module `AiCreditPacks`: `CREDIT_PACKS_BY_LOOKUP_KEY` frozen hash (6 packs) + methods `registered_keys`, `lookup_by_key`, `subscription_key?`, `one_off_key?`, `credit_amount_for_key`.
- Callers (all backend; frontend mirrors tiers independently, no AiCreditPacks reference):
  - app/models/organization_ai_credit_purchase.rb (validation inclusion)
  - app/jobs/stripe_webhook_handler_job.rb (subscription_key?)
  - app/interactors/apply_ai_credit_purchase.rb (credit_amount_for_key)
  - app/controllers/api/v1/ai_credits_controller.rb (one_off_key?)
  - app/controllers/api/v1/ai_credit_subscriptions_controller.rb (subscription_key?)
  - spec/interactors/apply_ai_credit_purchase_spec.rb (stub)
  - spec/initializers/ai_credit_packs_spec.rb (describes module)

## 6B — RoleCategoryGroups
- Only reference anywhere in app/lib/spec is the class definition `app/services/role_category_groups.rb`. Zero callers. Confirmed dead.

## Decisions: see approved-decisions.md Note #6A, #6B.
