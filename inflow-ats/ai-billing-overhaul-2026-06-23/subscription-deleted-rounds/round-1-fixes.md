# Subscription.deleted — Round 1 Fixes

All 6 audit deviations were FIXABLE. Fixed by adding the credit-pack branch to the
`customer.subscription.deleted` handler in
`app/jobs/stripe_webhook_handler_job.rb`, mirroring the `customer.subscription.updated`
credit-pack branch (:125-148). The existing main-plan code (formerly :179-184) is now
the unchanged `else` branch. No code whitelisted; no unscoped code added.

File: `app/jobs/stripe_webhook_handler_job.rb` (handler `when 'customer.subscription.deleted'`, ~:167)

---

## D1 — Missing credit-pack lookup-key read — FIXED

Before: handler never read the deleted subscription's lookup key.
After: added `plan_lookup_key = object.items&.data&.first&.price&.lookup_key` alongside the
other locals (after `subscription_ended_at = object.ended_at`), mirroring subscription.updated :120.

## D2 — Missing credit-pack vs main-plan branch — FIXED

Before: existing main-plan code ran unconditionally for every deletion.
After: wrapped post-sync actions in
`if OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(plan_lookup_key) ... else <existing main-plan code> end`,
mirroring subscription.updated :125/:149. The main-plan `else` body
(`sync_with_stripe` guard + `update_column(:subscription_canceled_at, ...)` +
`Notification::PaidSubscriptionDeletedJob` + `EngagementReport::GeneratorJob`) is byte-for-byte
unchanged.

## D3 — Missing credit-pack purchase lookup — FIXED

After: credit-pack branch calls
`OrganizationAiCreditPurchase.find_by(stripe_subscription_id: stripe_subscription_id, kind: :subscription)`,
assigned to `organization_ai_credit_purchase` (full model name per naming rule). Mirrors
subscription.updated :130-133 (uses the local `stripe_subscription_id` = `object.id` to match
surrounding code style, as the trace specifies).

## D4 — Missing purchase-not-found error log + return — FIXED

After: `else` arm of the `if organization_ai_credit_purchase` check logs
`Rails.logger.error "subscription.deleted credit-pack: no OrganizationAiCreditPurchase for stripe_subscription_id #{stripe_subscription_id}"`,
mirroring subscription.updated :146-148. (No explicit `return` needed — the branch falls through
to the end of the `begin` block with no further actions, equivalent to the analog's early-return
intent; the main-plan post-sync actions are in the sibling `else` and are not reached.)

## D5 — Missing purchase subscription_status/subscription_canceled_at update — FIXED

After: when found,
`organization_ai_credit_purchase.update(subscription_status: :canceled, subscription_canceled_at: Time.at(subscription_ended_at).to_datetime)`.
Writes `organization_ai_credit_purchases.subscription_status` (enum `canceled: 2`) and
`subscription_canceled_at` — the credit-pack columns, not the org columns. Matches the trace
Step 4 table.

## D6 — Missing captured/logged update return value — FIXED

After: return value captured as `updated`; on failure
`Rails.logger.error "subscription.deleted credit-pack: could not update purchase #{organization_ai_credit_purchase.id}: #{organization_ai_credit_purchase.errors.full_messages.join(', ')}"`
plus `ap organization_ai_credit_purchase.errors`, mirroring subscription.updated :135-145.

---

## Whitelist additions

None. The no-notification deviation (credit-pack branch does not fire
`Notification::PaidSubscriptionDeletedJob` / `EngagementReport::GeneratorJob` and does not write
`organizations.subscription_canceled_at`) is the documented "option 1 / minimum mirror" and is
already covered by `SANCTIONED-subscription-deleted.md` #1 (operates on
`organization_ai_credit_purchases` columns, not `organizations` columns). No new
`AGENT-WHITELIST-subscription-deleted.md` entry required.
