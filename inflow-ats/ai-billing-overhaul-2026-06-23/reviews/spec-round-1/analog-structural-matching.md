# Angle 7: Analog Structural Matching — Round 1

## Checks performed

1. Controller actions vs portal actions and cancel action — authorization, purchase lookup, guards, error handling, response pattern
2. `ApplyAiCreditUpgrade` vs `ApplyAiCreditPurchase` — structural manifest comparison
3. `ScheduleAiCreditSubscriptionDowngrade` vs `CancelAiCreditSubscription` — structural manifest comparison
4. Mutation hooks vs existing hooks — `apiPost`, `useMutation`, query invalidation
5. Modal component vs cancel/top-up modal — `CenterModal`, `Styled`, `Button` with `disabled`

## Structural Manifest: `ApplyAiCreditUpgrade` vs `ApplyAiCreditPurchase`

| Element | ApplyAiCreditPurchase (analog) | ApplyAiCreditUpgrade (spec) | Match? |
|---------|-------------------------------|----------------------------|--------|
| Include Interactor | YES | YES (implied by pattern) | SAME |
| `def call` entry | YES | YES | SAME |
| Balance lookup | `organization.organization_ai_credit_balance` | Same | SAME |
| Idempotency | `stripe_invoice_id == invoice.id` | Same | SAME |
| Transaction block | `ApplicationRecord.transaction` | Same | SAME |
| Stamp `stripe_invoice_id` | YES | YES | SAME |
| `finalize_stripe_payment` | YES | YES | SAME |
| Create `AiCreditBalanceTransaction` with `save` | YES | YES | SAME |
| Check save return, `fail_with_record_invalid` | YES | YES | SAME (but method unavailable — see C1) |
| Reset notification flags | YES | YES | SAME |
| Update `subscription_status` | YES (`active`) | NO | EXPECTED DIFFERENT |
| Update period dates | YES | NO | EXPECTED DIFFERENT |
| Credit amount source | `subscription_credits_per_period` | `credit_difference` | EXPECTED DIFFERENT |
| Variable naming | Uses `balance` shorthand | Same pattern | SAME |

**Deviation flagged:** `fail_with_record_invalid` unavailability (covered in C1 finding).

## Structural Manifest: `ScheduleAiCreditSubscriptionDowngrade` vs `CancelAiCreditSubscription`

| Element | CancelAiCreditSubscription (analog) | ScheduleAiCreditSubscriptionDowngrade (spec) | Match? |
|---------|-------------------------------------|----------------------------------------------|--------|
| Include Interactor | YES | YES (implied) | SAME |
| Stripe-first pattern | YES (Stripe call, then local update) | YES (Stripe call, no local update) | SAME |
| Rescue `Stripe::StripeError` | YES | YES | SAME |
| `context.fail!` with `:stripe_error` | YES | YES | SAME |
| Delegates to service wrapper | YES (`Stripe::CancelCreditPackSubscription`) | NO (Stripe calls directly in interactor) | DIFFERENT |
| Updates local purchase fields | YES (`subscription_status`, `subscription_canceled_at`) | NO (webhooks handle it) | EXPECTED DIFFERENT |
| Variable naming | Uses `purchase` (VIOLATION) | Uses `context.purchase` input name (TBD) | TBD |

**Service wrapper deviation:** The cancel flow delegates the Stripe API call to `Stripe::CancelCreditPackSubscription` service. The downgrade interactor makes Stripe calls directly. This is noted in the review angles (Angle 4) as a deviation to check. Given that the downgrade involves two Stripe API calls (`SubscriptionSchedule.create` then `SubscriptionSchedule.update`), keeping them in the interactor is reasonable — the cancel service is a single-call wrapper. This deviation is acceptable.

## Findings

No NEW findings beyond what's already captured in other angles. The structural matching is sound, with expected differences documented and justified.

## Verdict

0 new findings. PASS for this angle (noting C1 from Angle 3 applies to the structural manifest).
