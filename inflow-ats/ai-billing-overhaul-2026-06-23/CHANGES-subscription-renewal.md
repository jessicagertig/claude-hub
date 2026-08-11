# Subscription Renewal (flow 2) — Changes Made

Loop converged at two consecutive clean rounds (rounds 6 and 7 = 0). Files changed: `app/interactors/apply_ai_credit_purchase.rb`, `app/jobs/stripe_webhook_handler_job.rb` (+59/-37). **Committed: NO — staged only** (Cypress pre-commit hook did not pass; the Rails test server booted fine, so the failing test is frontend Cypress, not these backend changes).

## Deviations fixed (to match the main-plan `invoice.paid` renewal analog)
- Pass the already-found `OrganizationAiCreditPurchase` into `ApplyAiCreditPurchase` — dropped the redundant re-lookup inside `apply_subscription`.
- Capture and log the `invoice.paid` `.update` return value (was uncaptured / silently swallowed).
- Wrap the grant writes in `ApplicationRecord.transaction` (mirrors `ResetAiCredits`).
- Error-logging / `context.fail!` parity: org id in messages, `ap errors`, `organization_id` in failure context.
- Raise `CustomStripeSubscriptionMissingError` on a missing purchase (was a silent `return`), matching the analog's raise pattern. **[judgment call — silent→raise behavior change to match analog]**
- Dropped the unused `price` param from `apply_subscription` and its caller.
- Fixed the misleading ledger description (`'…first invoice'` → `'…grant for <lookup_key>'`) — this path fires on every renewal, not just the first.
- Balance notification-flag reset uses `.update` with a failure check (was `update_columns`), matching the analog.

## Forced deviations whitelisted (detail in `AGENT-WHITELIST-subscription-renewal.md`)
1. `stripe_invoice_id` idempotency guard — additive `addon_subscription` grant needs it; the analog's zero-then-reset is self-idempotent.
2. No Stripe default-payment-method sync — the org-level default PM is owned by the main plan; syncing from a credit-pack renewal would overwrite it with the wrong subscription's PM.
3. Additive `addon_subscription` grant vs reset-style `:monthly` allocation — different product/bucket; `ResetAiCredits` explicitly leaves `addon_subscription` untouched.
