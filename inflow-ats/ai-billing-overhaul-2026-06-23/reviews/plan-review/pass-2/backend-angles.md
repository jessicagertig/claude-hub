# Pass 2: Backend Angles (1-4) — Correction Verification + Fresh Scrutiny

## Correction verification

All 5 Pass 1 corrections verified as applied correctly:

| # | Correction | Location | Verified |
|---|-----------|----------|----------|
| 1 | `render_general_errors` calls pass arrays | A.2.2 step 8: `render_general_errors(['Unable to load...'])` | ✓ |
| 1 | Same | A.3.1 step 6: `render_general_errors([result.message \|\| '...'])` | ✓ |
| 1 | Same | A.3.1 step 8: `['Unable to change subscription...']` | ✓ |
| 2 | Sentry extra hash uses `org_id` + `:action` | A.2.2 step 8: `extra: { org_id: current_organization&.id, action: '...' }` | ✓ |
| 3 | Cancel action variable name corrected to `subscription` | Pattern Precedents, line 23 | ✓ |
| 4 | Structural manifest description corrected | Row reads: `"Credit pack subscription grant for #{...stripe_price_lookup_key}"` | ✓ |
| 5 | Spec file line count corrected to 193 | C.1.1 | ✓ |

No new inconsistencies introduced by corrections.

## Fresh scrutiny

### Routes (A.1)
Verified `config/routes.rb` lines 190-201. The three lines to remove (195, 196, 200) are exactly the portal routes. Lines between them (`put :cancel` at 197, `get :prices` at 198, `get :customer_subscription` at 199) are preserved. No collateral damage.

### Controller (A.2-A.4)
- `determine_price_id` callers: lines 254, 265 (in `change_subscription_portal_session`), and 301 (in `update_payment_method_and_subscription_portal_session`). ALL existing callers are in portal actions being removed. After removal, only the two new actions will call it. No issue — but confirms the method is not used elsewhere and won't be orphaned.
- `organization_ai_credit_purchase_params` and `checkout_purchase_params` private methods are still used by `show`/`checkout` respectively. No orphan risk.
- A.4.4 correctly notes to keep all private methods.

### Interactors (A.5-A.6)
- `context.purchase` key: spec says `context.purchase` (lines 150, 257, 274, 338), plan says `context.purchase` (A.3.1 step 6, A.6.2 step 1, A.6.2 step 5). Consistent.
- Controller passes `purchase: organization_ai_credit_purchase` (plan A.3.1 step 6, line 289). Interactor receives as `organization_ai_credit_purchase = context.purchase` (A.6.2 step 1). Consistent with analog (`cancel` passes `purchase: subscription`, `CancelAiCreditSubscription` receives `purchase = context.purchase`).

### Webhook handler (A.7)
- Line 489 verified as `ApplyAiCreditPurchase.call(invoice: invoice, kind: :subscription, purchase: organization_ai_credit_purchase)`. The plan's replacement code at A.7.2 passes `purchase: organization_ai_credit_purchase` to both `ApplyAiCreditUpgrade` and `ApplyAiCreditPurchase`. Variable naming consistent.
- Guard at line 477 fires before any branching. No guard ordering issue.

## Findings

**0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.**

All corrections applied correctly. No new issues found on fresh scrutiny.
