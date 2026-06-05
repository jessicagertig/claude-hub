# angle-2: controller-restructuring-and-route-alignment — Round 1

## Finding 1

**[HIGH]** Missing ripple site: `AiCreditPacks.registered_keys` reference in `OrganizationAiCreditPurchase` validation

**Where:** `app/models/organization_ai_credit_purchase.rb` line 14; SPEC.md Note #6A

**What:** Note #6A lists ripple sites for `AiCreditPacks.*` → `OrganizationAiCreditPurchase.*` but omits the model's own validation on line 14:
```ruby
validates :stripe_price_lookup_key, presence: true,
                                   inclusion: { in: ->(_) { AiCreditPacks.registered_keys } }
```
When the `AiCreditPacks` initializer is deleted, this validation will raise `NameError`. The `AiCreditPacks.registered_keys` reference must be updated to the model's own class method.

**Evidence:** `organization_ai_credit_purchase.rb` line 14: `inclusion: { in: ->(_) { AiCreditPacks.registered_keys } }`

**Fix:** Add `app/models/organization_ai_credit_purchase.rb` to the Note #6A ripple sites list and specify: change `AiCreditPacks.registered_keys` to `OrganizationAiCreditPurchase.registered_keys` in the validation lambda.

## Finding 2

**[LOW]** Spec uses `resource` (singular) for `ai_credit_purchases` route — consider using `resources` (plural)

**Where:** SPEC.md routes section (Note #9A)

**What:** The spec defines:
```ruby
resource :ai_credit_purchases, only: [:show], controller: 'organization_ai_credit_purchases' do
```
Using `resource` (singular) generates `/ai_credit_purchases` as a single-resource route (no `:id` param). This is correct for the current use case (one active subscription per org), but the route name `:ai_credit_purchases` is plural while using singular `resource`. This matches the existing pattern (`resource :ai_credit_subscriptions`), so it is consistent.

No action needed — just confirming the existing pattern is followed.
