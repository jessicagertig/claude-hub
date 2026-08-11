# Round 2 — Subscription Renewal Analog Audit — Fix Log

3 deviations reported. All 3 judged FIXABLE (logging / fail-payload parity with the
analog `ResetAiCredits`; none are caused by the credit-pack-subscription product
difference). All fixed. Nothing whitelisted.

Target file: `app/interactors/apply_ai_credit_purchase.rb` (OURS).
Analog: `app/interactors/reset_ai_credits.rb`.

---

## Deviation 1 — missing_balance guard: error logging parity — FIXED

ANALOG `reset_ai_credits.rb:25-32` logs
`Rails.logger.error "ResetAiCredits: org #{organization.id} has no ai_credit_balance"`
BEFORE `context.fail!` for the missing-balance case. OURS had a bare one-line
`return context.fail!(error: :missing_balance, ...)` with no preceding log.

Fix (`apply_ai_credit_purchase.rb`, the `balance` guard inside `apply_subscription`):
expanded the one-line guard into a block that emits
`Rails.logger.error "ApplyAiCreditPurchase: org #{organization.id} has no ai_credit_balance"`
before the `context.fail!`, matching the analog's log-then-fail structure and message shape.

## Deviation 2 — fail! payload omits organization_id — FIXED

ANALOG passes `organization_id: organization.id` (missing_balance, `reset_ai_credits.rb:27-31`)
and `organization_id: context.organization&.id` (`fail_with_record_invalid`, `:85-89`) in the
`context.fail!` keyword payload. OURS's `missing_balance` fail and `fail_with_record_invalid`
carried only `error:` + `message:`.

Fix:
- missing_balance guard: added `organization_id: organization.id` to the `context.fail!`
  keyword payload (same block as Deviation 1).
- `fail_with_record_invalid`: added `organization_id: context.organization&.id` to its
  `context.fail!` payload. To make `context.organization` available (the analog references
  `context.organization&.id`), added `context.organization = organization` in
  `apply_subscription` immediately after the org is resolved — mirroring the analog, which
  reads the organization off the interactor context. This is parity scaffolding, not new
  product behavior.

## Deviation 3 — fail_with_record_invalid missing `ap errors` — FIXED

ANALOG `reset_ai_credits.rb:82-89` does `Rails.logger.error ...` then `ap errors` then
`context.fail!`. OURS's `fail_with_record_invalid` did the log then `context.fail!` with no
`ap errors`.

Fix (`apply_ai_credit_purchase.rb`, `fail_with_record_invalid`): added the `ap errors` debug
dump between the `Rails.logger.error` line and `context.fail!`, and updated the log line to
include the org id (`... failed for org #{context.organization&.id}: ...`) to match the
analog's message format.

---

WHITELISTED: none. No deviation was forced by the credit-pack-subscription product/data-model
difference; all three were logging / fail-payload parity gaps against the analog.
