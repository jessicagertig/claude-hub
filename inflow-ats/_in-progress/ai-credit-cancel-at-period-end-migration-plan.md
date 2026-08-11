# Migration Plan — `stripe_cancel_at_period_end` on `organization_ai_credit_purchases`

**Status: PROPOSED — awaiting Jessica's approval. Nothing run.**

## Why a migration is genuinely needed here

A credit-pack subscription cancelled "at period end" is **still active** until the period end (e.g. July 17, ~29 days out). The current code (`CancelAiCreditSubscription`) eagerly sets `subscription_status: :canceled` + `subscription_canceled_at: Time.current` at click time, so `#show`'s `subscription_status: [:active, :past_due]` filter drops it immediately and the UI hides a subscription the customer still has.

`subscription_canceled_at` cannot represent the pending state: semantically it is the **actual cancellation moment** (the analog sets the org's `subscription_canceled_at` from `customer.subscription.deleted`'s `ended_at`). "Cancellation scheduled but not yet effective" is a distinct concept. `subscription_status` has no "active-but-cancel-pending" member, and the period-end date does not indicate a cancellation. No existing column fits — so a dedicated boolean is required, mirroring the org's existing `stripe_cancel_at_period_end`.

This is the case the no-migration rule explicitly carves out: a migration that is genuinely necessary, documented in full first.

## The migration

```ruby
# db/migrate/<ts>_add_stripe_cancel_at_period_end_to_organization_ai_credit_purchases.rb
class AddStripeCancelAtPeriodEndToOrganizationAiCreditPurchases < ActiveRecord::Migration[6.1]
  def change
    add_column :organization_ai_credit_purchases, :stripe_cancel_at_period_end, :boolean, null: false, default: false
  end
end
```

- Additive only. No drop/reset/recreate. Safe on a populated table (`default: false`, `null: false` backfills existing rows to false).
- Apply with `bundle exec rails db:migrate` (dev) and `RAILS_ENV=test bundle exec rails db:migrate` (test). Never `db:reset`/`db:setup`/`db:schema:load`/`db:test:prepare`.
- Column name mirrors `organizations.stripe_cancel_at_period_end` for consistency with the main-plan analog.

## Behavior changes (webhook-driven, mirroring the analog)

1. **`CancelAiCreditSubscription`** — call `Stripe::CancelCreditPackSubscription.cancel` (sets Stripe `cancel_at_period_end: true`); **stop** setting `subscription_status: :canceled` / `subscription_canceled_at` locally. Let the webhook reconcile (matches how the main plan's cancel state is webhook-driven).
2. **`customer.subscription.updated` credit-pack branch** (`stripe_webhook_handler_job.rb`) — set `stripe_cancel_at_period_end = object.cancel_at_period_end`; keep `subscription_status` `active`/`past_due`. A subsequent un-cancel (`cancel_at_period_end: false`) flips it back to false. (Add this alongside the existing lookup_key/credits/period_end updates.)
3. **`customer.subscription.deleted` credit-pack branch (new)** — find the row by `stripe_subscription_id`; set `subscription_status: :canceled` + `subscription_canceled_at = Time.at(object.ended_at)`. This is the real cancellation moment, so `subscription_canceled_at` is now semantically correct. (Today this handler only touches the org — which is why cancel had to flip eagerly.)
4. **`#show`** — unchanged (`subscription_status: [:active, :past_due]`). A cancel-pending sub is still `active`, so it still returns and displays.
5. **Serializer** (`OrganizationAiCreditPurchaseSerializer`) — add `:stripe_cancel_at_period_end` → frontend `stripeCancelAtPeriodEnd`.
6. **UI** (`AiCreditSubscription.tsx` / `AiSubscriptionStatus`) — when `stripeCancelAtPeriodEnd` is true, keep the card and show "cancels on `subscriptionCurrentPeriodEnd`" (mirror the main-plan cancel-at-period-end banner).

## Specs
- Cancel interactor: asserts Stripe called with cancel; local status NOT flipped to canceled.
- `customer.subscription.updated`: `cancel_at_period_end: true` → row stays active, flag true; `false` → flag cleared.
- `customer.subscription.deleted` credit-pack branch: row → `:canceled` + `subscription_canceled_at` set.
- Serializer exposes the field; `#show` still returns a cancel-pending row.

## Data note (existing rows)
The sub Jessica just cancelled is already locally `subscription_status: :canceled` (old eager flow) though live until ~July 17. After the migration, that one row needs flipping back to `active` + `stripe_cancel_at_period_end: true` (+ clear the premature `subscription_canceled_at`) to reflect reality — via Rails console/runner — or, if it's just test data, reset it. No automatic backfill handles this (it's a pre-existing mis-set row, not a schema default concern).

## Scope summary
1 migration (additive boolean) + cancel interactor + 2 webhook branches (1 edited, 1 new) + serializer + UI banner + specs. No drop/reset. No `.env`. Nothing committed.
