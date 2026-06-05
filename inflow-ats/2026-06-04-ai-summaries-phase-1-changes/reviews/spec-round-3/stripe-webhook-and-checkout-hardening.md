# angle-1: stripe-webhook-and-checkout-hardening — Round 3

Round 2 HIGH finding (`amount_cents_paid`/`currency` not populated by `handle_credit_pack_invoice_paid`) was amended.

Verified:
- Note #9B-5 now instructs adding `amount_cents_paid: invoice.amount_paid, currency: invoice.currency` to the `existing.update(...)` call
- Constraints section updated to include this requirement
- Validation relaxation note updated to reference "see below" for population timing

No new findings. All prior findings addressed.
