# Round 5 — Fix Log (AI-credit subscription-renewal analog audit)

Audit reported 2 deviations, both classified FORCED / no-analog (whitelist candidates). I verified each against LIVE code in the pinned worktree (`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`), confirmed both are genuinely forced by the product/data-model difference, made NO code changes, and appended both to `AGENT-WHITELIST-subscription-renewal.md`.

Note: the trace's "OURS" sections describe stale prior state. The FIXABLE-looking items the trace mentioned (uncaptured `.update` return value, misleading "first invoice" description string, `update_columns` for notification flags, missing failure logging) are ALREADY fixed in live code — `handle_subscription_credit_pack_invoice_paid` (`stripe_webhook_handler_job.rb:448-466`) captures and logs the `.update` return value, and `apply_subscription` (`apply_ai_credit_purchase.rb:24-80`) wraps writes in a transaction, captures every `.update` return, logs all failures via `fail_with_record_invalid`, uses `balance.update` (not `update_columns`), and the ledger description is now `"Credit pack subscription grant for #{stripe_price_lookup_key}"`. The audit did not list any of these as remaining deviations.

---

## Deviation 1 — Stripe default-payment-method sync omitted

**WHITELISTED** (appended as AGENT-WHITELIST entry #2).

- Analog: `stripe_webhook_handler_job.rb:269` calls `organization.stripe_update_default_payment_method`, chaining Stripe API calls (`Subscription.retrieve` `organization.rb:477`, `PaymentMethod.retrieve` `:517`, `PaymentMethod.list` `:620-623`, `Customer.update` `:630-632`) to set the org-level `invoice_settings.default_payment_method` on the Stripe Customer.
- OURS: `handle_subscription_credit_pack_invoice_paid` (`stripe_webhook_handler_job.rb:448-466`) + `ApplyAiCreditPurchase#apply_subscription` (`apply_ai_credit_purchase.rb:24-80`) make ZERO Stripe API calls beyond the shared `Stripe::Subscription.retrieve`; no PM sync.
- Rationale for FORCED: `invoice_settings.default_payment_method` is a single org-level Stripe Customer field owned by the MAIN plan. `stripe_update_default_payment_method` derives `pm_id` from `organization.stripe_subscription` (the main-plan subscription, via `organizations.stripe_subscription_id`), NOT from the credit-pack subscription. Calling it on a credit-pack renewal would overwrite (or fail/no-op for orgs with no main-plan subscription) the org default PM using the wrong subscription. No credit-pack-specific org-level default-PM field exists to sync. Forced by the product/data-model difference. NOT whitelisted for convenience.

## Deviation 2 — Additive `addon_subscription` grant instead of reset-style `:monthly` allocation

**WHITELISTED** (appended as AGENT-WHITELIST entry #3).

- Analog: `organization.organization_ai_credit_balance&.reset_ai_credits` → `ResetAiCredits` (`reset_ai_credits.rb:34-77`) zero-then-resets the `:monthly` bucket (`:plan_monthly_reset_debit` of `-monthly_credits_remaining` `:40-49`, then `:plan_monthly_allocation_credit` of `new_allocation` `:52-63`), sets `last_reset_at` and clears both notification timestamps + both `sent_*_since_increase` booleans (`:65-71`).
- OURS: `apply_ai_credit_purchase.rb:64-72` inserts a single `:subscription_credit_pack_purchase_credit` row, bucket `:addon_subscription`, amount `subscription_credits_per_period`, additive (no zero-out debit); clears only the two `sent_*_since_increase` booleans (`:74-77`), does not set `last_reset_at`, does not clear the two notification timestamps.
- Rationale for FORCED: the credit-pack subscription is a different product whose credits live in the `:addon_subscription` bucket, which `ResetAiCredits` explicitly leaves untouched (`reset_ai_credits.rb:17`: "The addon and addon_subscription buckets are intentionally untouched."). Adopting the reset mechanism would zero and re-allocate the MAIN plan's `:monthly` bucket, destroying the main plan's allocation. `last_reset_at` and the `*_notification_sent_at` timestamps are `:monthly`-bucket lifecycle fields owned by the main-plan reset; the addon_subscription grant has no equivalent monthly-reset semantics. Forced by the product/data-model difference. NOT whitelisted for convenience.

---

## Summary

- FIXED: 0
- WHITELISTED: 2 (both genuinely forced by the credit-pack-subscription-vs-main-plan product/data-model difference)
- Code changes to source: NONE
