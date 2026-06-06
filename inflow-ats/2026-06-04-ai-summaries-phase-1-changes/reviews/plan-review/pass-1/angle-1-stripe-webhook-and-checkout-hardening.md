# angle-1: stripe-webhook-and-checkout-hardening — Pass 1

## Fact Check

| Claim | Verification | Result |
|-------|-------------|--------|
| `checkout.session.completed` `mode == 'payment'` branch at lines 58-61 | Read stripe_webhook_handler_job.rb lines 58-62 | CORRECT — lines 58-61 |
| `apply_top_up_checkout` called at line 60 | Read line 60 | CORRECT |
| `invoice.paid` guard `raise CustomStripeSubscriptionMissingError` at line 204 | Read line 204 | CORRECT |
| `board_wwr_listing_id` / `board_what_jobs_listing_id` branches at lines 206-235 | Read lines 206-236 | CORRECT |
| Plan E.2.2: "These branches already `return` so they skip the guard correctly once moved above it" | Read lines 206-236 | INCORRECT — branches are if/elsif/else, no explicit `return` |
| `handle_credit_pack_invoice_paid` `else` branch at lines 483-488 | Read lines 483-489 | CORRECT (lines 483-489) |
| `existing.update(...)` in handle_credit_pack_invoice_paid | Read lines 453-458 | CORRECT — does NOT currently include `amount_cents_paid`/`currency` |
| `BillingController` line 113 records checkout session ID | Grep confirmed line 113 | CORRECT |
| `board_wwr_listings_controller.rb` `invoice_creation` at line 101 | Read lines 101-110 | CORRECT |
| `OrganizationAiCreditPurchase` current validations: `amount_cents_paid` unconditional (line 15), `currency` unconditional (line 16) | Read lines 15-16 | CORRECT |
| `stripe_subscription_id` presence if subscription (line 19-21) | Read lines 19-21 | CORRECT |
| Validation relaxation plan C.1.4 | Matches spec requirements | CORRECT |

## Completeness

Spec requirements covered by this angle:
- Note #4 (invoice creation, invoice.paid branch, remove mode=='payment') — plan steps E.1.1, E.2.1, D.3 purchase_top_up, C.7.4
- Note #9B-5 (two-step subscription handshake) — plan steps D.3 checkout, E.1.2, E.2.3, E.2.4, E.3, C.1.4
- Validation relaxation — plan step C.1.4

All spec requirements have corresponding plan steps.

## Findings

- F1 [HIGH] Plan E.2.2 claims listing branches "already `return`" — they do NOT. The `board_wwr_listing_id` (line 206) and `board_what_jobs_listing_id` (line 218) branches are if/elsif arms inside an if/elsif/else chain. They have no explicit `return`. When moved above the `raise CustomStripeSubscriptionMissingError` guard, they MUST add `return` after processing, or execution will fall through to the guard and raise `CustomStripeSubscriptionMissingError` for listing-only invoices. The plan's instruction to "move above the guard" is correct, but the claim that no code change is needed besides moving is wrong — each branch needs a `return` appended (or the structure must be converted to standalone if-return blocks).

## Amendments Applied

- plan.md E.2.2: Added clarification that `return` must be added to each listing branch when moving them above the guard.
