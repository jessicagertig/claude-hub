# Investigation — Note #3: refund picks earliest credit row

## File chain
`stripe_webhook_handler_job.rb:269` (charge.refunded) → `handle_charge_refunded` (408-434) → `ApplyAiCreditRefund.call(purchase:)` (433) → `apply_ai_credit_refund.rb` → credit rows from `apply_ai_credit_purchase.rb` (first invoice, line 114-119) + `stripe_webhook_handler_job.rb:464-472` (renewals)

## Note's premise: DOES NOT HOLD
- Note claims earliest row's amount ≠ renewal amount, so refund under-debits.
- `subscription_credits_per_period` written ONCE at creation (`apply_ai_credit_purchase.rb:105`); never mutated (only other reference is a read at `stripe_webhook_handler_job.rb:469`).
- Renewal credit rows use `amount: existing.subscription_credits_per_period` — same constant for every period.
- ∴ all `subscription_credit_pack_purchase_credit` rows on a purchase have EQUAL amount; same bucket (`addon_subscription`). Earliest vs latest → identical amount. No inflation.

## Real adjacent gap (different from note's mechanism)
- `ApplyAiCreditRefund` ignores the actual Stripe refunded amount. `handle_charge_refunded` checks only `charge.refunded == true`; passes nothing about amount. Interactor always reverses one full period grant (capped by bucket balance). PARTIAL Stripe refunds over-reverse.
- Interactor isn't passed the refunded charge/invoice → cannot match precisely. First-invoice credit rows carry NO `metadata.stripe_invoice_id`; only renewal rows do (`:471`), so per-invoice matching is only partially possible anyway.

## Cross-links
- #33 (silent drop: `return unless purchase` at `:431`) — same method.
- #32 (`&.reload` at `apply_ai_credit_refund.rb:21`) — same interactor.

## For Jessica
Note #3 as written is not a real bug. Decide: drop it, OR re-scope to the actual gap (amount-aware / partial-refund handling), possibly merged with #33 since both live in `handle_charge_refunded`.
