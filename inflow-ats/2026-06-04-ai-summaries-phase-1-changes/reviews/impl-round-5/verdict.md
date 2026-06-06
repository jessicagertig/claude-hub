# Verdict — Implementation Review Round 5

## Result: FAIL

## HIGH findings (blocking)

| # | File | Summary |
|---|---|---|
| angle-1 F1 | `apply_ai_credit_purchase.rb:84-130` | `apply_one_off_from_invoice` -- 46-line method NOT in spec, duplicates `apply_one_off` |
| angle-1 F2 | `organization_ai_credit_purchase.rb:53` | `stripe_checkout_session_id` validation relaxed for one-offs -- NOT in spec |
| angle-1 F3 | `stripe_webhook_handler_job.rb:285-289,424-455` | `charge.refunded` handler + `handle_charge_refunded` -- NOT in spec |
| angle-1 F4 | `stripe_webhook_handler_job.rb:114-136` | `customer.subscription.updated` AI credit branch -- NOT in spec |
| angle-1 F5 | `stripe_webhook_handler_job.rb:155-168` | `customer.subscription.deleted` AI credit branch -- NOT in spec |
| spec-compliance F6 | `stripe_webhook_handler_job.rb:456-515` | `handle_credit_pack_invoice_paid` rewritten from scratch -- NOT in spec |
| spec-compliance F7 | `stripe_webhook_handler_job.rb:517-527` | `subscription_status_for_stripe` helper -- NOT in spec |
| reinventing F1 | `apply_ai_credit_purchase.rb:84-130` | Duplicates listing inline pattern; existing `apply_one_off` already handles the work |
| reinventing F2 | `stripe_webhook_handler_job.rb:456-515` | `handle_credit_pack_invoice_paid` duplicates `apply_subscription` logic |

## MED findings (noted, does not block)

| # | File | Summary |
|---|---|---|
| angle-1 F6 | `controller:52` | `amount_cents_paid: 0` hardcoded at checkout |
| angle-1 F7 | `webhook:270-284` | Three-tier rescue restructured beyond spec |
| angle-1 F8 | `interactor:5-6` | Stale docstring references deleted call path |
| angle-2 F2 | `db/migrate/20260605*` | New migration despite "no new migrations" |
| angle-5 F2 | `bulk_job:95-100` | `self.class.send(:method)` bypasses access control |
| angle-6 F1 | `mailer:11,37` | Uses DEFAULT_EMAIL_FROM_ADDRESS vs pattern EMAIL_NOTIFICATIONS_ADDRESS |
| angle-7 F1 | `AccountContainer` | Plato AI behind feature flipper -- not in spec |
| angle-7 F2 | `AccountContainer` | Missing `exact={false}` on route |
| code-quality F1 | `interactor:5-6` | Stale docstring |
| code-quality F2,F3 | Multiple files | Missing trailing newlines |
| data-integrity F1 | `purchase model:53` | Ambiguous idempotency key for one-offs |
| data-integrity F2 | `webhook:211-220` | Wasted org lookup |
| operational F1 | `webhook:276-284` | Re-raise changes retry behavior |

## Core problem

The fix agent added approximately **200+ lines of out-of-spec code** to the Stripe webhook handler, including:
- `charge.refunded` handler with `handle_charge_refunded` (31 lines)
- `customer.subscription.updated` AI credit branch (22 lines)
- `customer.subscription.deleted` AI credit branch (13 lines)
- `handle_credit_pack_invoice_paid` rewritten from scratch (59 lines)
- `subscription_status_for_stripe` helper (11 lines)
- `apply_one_off_from_invoice` interactor method (46 lines)
- Validation relaxation on `stripe_checkout_session_id`
- New migration `20260605035312`

None of this was specified. The user's suspicion was correct: `apply_one_off_from_invoice` is unnecessary scope creep, and the same pattern used by listing purchases (inline processing in the webhook handler) would suffice for credit pack top-ups.

## What works correctly

The spec-specified changes are correctly implemented:
- All enum renames cascade cleanly (zero stale references)
- Controller restructuring follows the spec
- Hook consolidation is correct
- Mailer fixes (is_admin, template names) are correct
- Bulk job notifications work (retry/discard ordering, mailer calls with .deliver_later)
- Plato AI container matches the integration container analog
- All model/service cleanups verified
- Test coverage for spec-required items is adequate

## Recommended action

1. **Remove all out-of-spec webhook code:** `charge.refunded`, subscription.updated AI branch, subscription.deleted AI branch, rewritten `handle_credit_pack_invoice_paid`, `subscription_status_for_stripe`
2. **Remove `apply_one_off_from_invoice`:** Process top-up invoice.paid inline in the webhook handler (like listings), or parameterize `apply_one_off` to accept either a session or invoice
3. **Revert `stripe_checkout_session_id` validation** to unconditional `presence: true` for one-offs
4. **Delete migration `20260605035312`** -- the in-place edit to `20260408040701` is sufficient
5. **Add `exact={false}`** to the Plato AI route in `AccountContainer.tsx`
