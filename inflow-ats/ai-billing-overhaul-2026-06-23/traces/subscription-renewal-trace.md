# Subscription Renewal (invoice.paid for recurring subscription) — Iota-for-Iota Structural Trace

Goal: an exact structural map of the ANALOG (main-plan subscription renewal via `invoice.paid`) and OURS (AI credit subscription renewal via `invoice.paid`), tracing every identifier from webhook entry to the final DB write and Stripe API call, so differences are visible at the iota level.

The ANALOG is the main-plan else branch in `invoice.paid` — the path that fires when a recurring main-plan subscription invoice is paid. OURS is the `handle_subscription_credit_pack_invoice_paid` path — the branch that fires when a recurring AI credit subscription invoice is paid.

---

## Shared entry point

Both paths share the same entry point and diverge at a routing branch inside `invoice.paid`.

Ordered identifier chain (Stripe webhook -> job -> routing branch):

1. `StripeWebhookHandlerJob#perform(event_id)` — `app/jobs/stripe_webhook_handler_job.rb:14`
2. `Stripe::Event.retrieve(event_id)` — `:20` (Stripe API call; rescued at `:21` `JSON::ParserError`, `:26` `Stripe::SignatureVerificationError`, `:31` `Stripe::InvalidRequestError`, `:35` `Stripe::APIConnectionError`)
3. `handle_stripe_event(event)` — `:41` -> `:44`
4. `object = event.data.object` — `:48` (the Stripe Invoice object for `invoice.paid`)
5. `log_stripe_changes(event)` — `:50` (logging only; no DB or Stripe writes; `:401`)
6. `case event.type` — `:52`; matches `'invoice.paid'` at `:198`

### Routing inside invoice.paid (lines 198-291)

Logging at entry: `ap 'INVOICE PAID'` (`:202`), `ap object` (`:203`), `Rails.logger.info 'Is this a WWR Job Invoice?'` (`:205`), `Rails.logger.info "Metadata keys: #{object.metadata&.keys&.inspect}"` (`:206`). No DB or Stripe writes.

7. `stripe_customer_id = object.customer` — `:208` (reads `invoice.customer` string)
8. `organization = Organization.find_by(stripe_customer_id: stripe_customer_id)` — `:209`

Early-return metadata branches (none apply to either renewal path):
- `:212` — `object.metadata&.[]('ai_credit_pack_top_up') == 'true'` -> one-off top-up path (returns)
- `:233` — `object.metadata&.[]('board_wwr_listing_id').present?` -> WWR listing (returns)
- `:246` — `object.metadata&.[]('board_what_jobs_listing_id').present?` -> WhatJobs listing (returns)

If none of the metadata branches return, execution reaches the Stripe retrieve + routing branch:

9. `stripe_subscription = Stripe::Subscription.retrieve(object.subscription)` — `:264` (**Stripe API call**: retrieves the subscription associated with this invoice; `object.subscription` is the `sub_xxx` id string on the Stripe Invoice)
10. `subscription_lookup_key = stripe_subscription.items.data.first&.price&.lookup_key` — `:265` (reads the lookup_key from the first subscription item's price)
11. `subscription_price = stripe_subscription.items.data.first&.price` — `:266` (the full Stripe Price object)

12. **Routing branch** — `:268`
    ```ruby
    if subscription_lookup_key && OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(subscription_lookup_key)
      handle_subscription_credit_pack_invoice_paid(object, subscription_price)  # OURS
    else
      # ... ANALOG (main-plan)
    end
    ```
    - `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(subscription_lookup_key)` — `app/models/organization_ai_credit_purchase.rb:63` -> `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[lookup_key]&.dig(:kind) == :subscription` (`:64`)
    - `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` — `organization_ai_credit_purchase.rb:4` (hash constant; subscription keys include `plato_ai_credit_subscription_small`, `plato_ai_credit_subscription_medium`, `plato_ai_credit_subscription_large`, and dev keys `ai_credit_pack_subscription_small_monthly`, `ai_credit_pack_subscription_large_monthly`)

**If the lookup_key matches an AI credit subscription key**: -> OURS path (`:269`)
**If it does NOT match (nil or a main-plan key)**: -> ANALOG path (`:270-280`)

---

## ANALOG — Main-plan subscription renewal (the else branch)

Ordered identifier chain from the routing branch to every DB write and Stripe API call:

### Step A1: Guard — raise if no main-plan subscription

13. `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` — `:271`
    - `organization.stripe_subscription_id` — column `organizations.stripe_subscription_id` (`db/schema.rb:1052`, type `string`)
    - `CustomStripeSubscriptionMissingError` — `app/errors/custom_stripe_subscription_missing_error.rb:3` (`< StandardError`, default msg `'Custom Stripe Subscription Error'`)
    - If raised: caught by `rescue Stripe::StripeError` at `:281`? NO — `CustomStripeSubscriptionMissingError < StandardError`, not `Stripe::StripeError`. It falls through to `rescue StandardError => e` at `:287` (logs + `ap e`). The invoice.paid handler has three rescue blocks: `Stripe::StripeError` (`:281`), `ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound` (`:284`), `StandardError` (`:287`).

### Step A2: Update organization period end

14. `organization.update(stripe_current_period_end_at: Time.at(stripe_subscription.current_period_end).to_datetime)` — `:273`
    - `stripe_subscription` — the Stripe::Subscription object retrieved at step 9 (`:264`)
    - `stripe_subscription.current_period_end` — integer Unix timestamp from Stripe
    - `Time.at(...).to_datetime` — converts to Ruby DateTime
    - **DB WRITE #1**: `organizations.stripe_current_period_end_at` (`db/schema.rb:1054`, type `datetime`)
    - `updated = ...` — return value checked at `:274`; on failure logs error (`:275`) + `ap` (`:276`), does NOT raise or return early

### Step A3: Update default payment method on Stripe

15. `organization.stripe_update_default_payment_method` — `:278` (called with NO argument; `payment_method_id = nil`)
    - `Organization#stripe_update_default_payment_method(payment_method_id = nil)` — `app/models/organization.rb:612`

    **Inside stripe_update_default_payment_method (no argument):**

    16. `pm_id = ...` — `:613-617`. Since `payment_method_id` is nil (no argument), takes the else branch:
        - `stripe_payment_method ? stripe_payment_method.id : nil` — `:616`
    17. `Organization#stripe_payment_method` — `organization.rb:513`
        - `@subscription ||= stripe_subscription` — `:514` (memoized; calls `Organization#stripe_subscription`)
        - `Organization#stripe_subscription` — `organization.rb:474`
        - `return if stripe_subscription_id.nil?` — `:475` (reads `organizations.stripe_subscription_id` column)
        - **Stripe API call #1 inside this method**: `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` — `:477`
        - Returns the Stripe::Subscription object (or nil if `stripe_subscription_id` nil)
    18. Back in `stripe_payment_method`: `Stripe::PaymentMethod.retrieve(@subscription.default_payment_method) unless @subscription.default_payment_method.nil?` — `:517`
        - **Stripe API call #2 inside this method**: `Stripe::PaymentMethod.retrieve(...)` (only if subscription has a `default_payment_method`)
        - Returns a Stripe::PaymentMethod object
    19. Back in `stripe_update_default_payment_method`: `pm_id` is now `stripe_payment_method.id` (or nil if no payment method)
    20. `return unless pm_id` — `:618` (early return if nil)
    21. **Stripe API call #3**: `Stripe::PaymentMethod.list({ customer: stripe_customer_id, type: 'card' })` — `:620-623`
        - `stripe_customer_id` — `organizations.stripe_customer_id` column (`db/schema.rb:1051`)
    22. `return unless payment_methods.collect { |pm| pm.id }.include?(pm_id)` — `:628` (guard: only update if pm_id is in the customer's card list)
    23. **Stripe API call #4**: `Stripe::Customer.update(stripe_customer_id, { invoice_settings: { default_payment_method: pm_id } })` — `:630-632`
        - **Stripe WRITE**: updates the Stripe Customer's default payment method
        - **No DB write** — this method writes to Stripe only, not to the local database

### Step A4: Reset AI credits for the new billing period

24. `organization.organization_ai_credit_balance&.reset_ai_credits` — `:279`
    - `Organization#organization_ai_credit_balance` — `has_one :organization_ai_credit_balance, dependent: :restrict_with_error` (`organization.rb:28`)
    - Safe-navigation `&.` — if no balance record exists, returns nil and does nothing
    - `OrganizationAiCreditBalance#reset_ai_credits` — `app/models/organization_ai_credit_balance.rb:28`
    - `ResetAiCredits.call(organization: organization)` — `:29`

    **Inside ResetAiCredits (interactor):**

    25. `ResetAiCredits#call` — `app/interactors/reset_ai_credits.rb:21`
    26. `organization = context.organization` — `:22`
    27. `balance = organization.organization_ai_credit_balance` — `:23`
    28. Guard: `if balance.nil?` -> `context.fail!(error: :missing_balance, ...)` — `:25-32` (`if` at `:25`, `context.fail!` at `:27-31`, `end` at `:32`; returns early via `Interactor` gem)
    29. `ApplicationRecord.transaction do` — `:34` (all writes inside a DB transaction)

    **Step A4a: Resolve new allocation**

    30. `new_allocation = resolve_allocation(organization, balance)` — `:36`
        - `ResetAiCredits#resolve_allocation(organization, balance)` — `:94`
        - `if balance.monthly_ai_credits_override.present?` — `:95`
          - `organization_ai_credit_balances.monthly_ai_credits_override` column (`db/schema.rb:950`, type `integer`, nullable)
          - If present: returns the override value
        - `else`: `PlanFeatureGate.new(organization).monthly_ai_credit_allocation` — `:98`
          - `PlanFeatureGate#monthly_ai_credit_allocation` — `app/services/plan_feature_gate.rb:134`
          - `plan_rules[@plan]&.dig(:monthly_ai_credit_allocation) || MINIMUM_AI_CREDIT_ALLOCATION` — `:135`
          - `MINIMUM_AI_CREDIT_ALLOCATION = 25` — `:128`
          - `@plan` — set by `PlanFeatureGate.new(organization)` constructor (reads `organization.plan` enum)
          - `plan_rules` — `:142` (hash keyed by plan alias string; each value has `:monthly_ai_credit_allocation`)
    31. `now = Time.current` — `:37`

    **Step A4b: Zero out previous monthly bucket (conditional)**

    32. `if balance.monthly_credits_remaining.positive?` — `:39`
        - `organization_ai_credit_balances.monthly_credits_remaining` column (`db/schema.rb:947`, type `integer`, default 0)
    33. **DB WRITE #2 (conditional)**: `AiCreditBalanceTransaction.new(...)` + `.save` — `:40-49`
        ```ruby
        AiCreditBalanceTransaction.new(
          organization_ai_credit_balance: balance,
          entry_type: :plan_monthly_reset_debit,
          bucket: :monthly,
          amount: -balance.monthly_credits_remaining,
          description: 'Anniversary reset — clear previous monthly bucket'
        )
        ```
        - `entry_type: :plan_monthly_reset_debit` — enum value `1` (`ai_credit_balance_transaction.rb:10`)
        - `bucket: :monthly` — enum value `0` (`ai_credit_balance_transaction.rb:37`)
        - `amount` — negative (debit); equals `-balance.monthly_credits_remaining`
        - On `.save`: `counter_culture` callback (`ai_credit_balance_transaction.rb:48-50`) atomically decrements `organization_ai_credit_balances.monthly_credits_remaining` by the amount (i.e., zeroes it out)
        - **DB WRITE #2a (automatic via counter_culture)**: `UPDATE organization_ai_credit_balances SET monthly_credits_remaining = monthly_credits_remaining + (<negative amount>) WHERE id = ...`

    **Step A4c: Grant new monthly allocation (conditional)**

    34. `if new_allocation.positive?` — `:52`
    35. **DB WRITE #3 (conditional)**: `AiCreditBalanceTransaction.new(...)` + `.save` — `:53-62`
        ```ruby
        AiCreditBalanceTransaction.new(
          organization_ai_credit_balance: balance,
          entry_type: :plan_monthly_allocation_credit,
          bucket: :monthly,
          amount: new_allocation,
          description: "Monthly credit grant for #{organization.plan}"
        )
        ```
        - `entry_type: :plan_monthly_allocation_credit` — enum value `0` (`ai_credit_balance_transaction.rb:9`)
        - `bucket: :monthly` — enum value `0`
        - `amount` — positive (credit); equals `new_allocation` from step 30
        - **DB WRITE #3a (automatic via counter_culture)**: `UPDATE organization_ai_credit_balances SET monthly_credits_remaining = monthly_credits_remaining + <new_allocation> WHERE id = ...`

    **Step A4d: Update balance metadata**

    36. **DB WRITE #4**: `balance.update(...)` — `:65-71`
        ```ruby
        updated = balance.update(
          last_reset_at: now,
          low_credit_notification_sent_at: nil,
          zero_credit_notification_sent_at: nil,
          sent_low_notification_since_increase: false,
          sent_zero_notification_since_increase: false
        )
        ```
        Columns updated on `organization_ai_credit_balances`:
        - `last_reset_at` (`schema.rb:951`, type `datetime`) — set to `Time.current`
        - `low_credit_notification_sent_at` (`schema.rb:952`, type `datetime`) — set to `nil`
        - `zero_credit_notification_sent_at` (`schema.rb:953`, type `datetime`) — set to `nil`
        - `sent_low_notification_since_increase` (`schema.rb:954`, type `boolean`) — set to `false`
        - `sent_zero_notification_since_increase` (`schema.rb:955`, type `boolean`) — set to `false`
        - On failure: `fail_with_record_invalid('balance period update', balance.errors)` — `:73`
        - `ResetAiCredits#fail_with_record_invalid(label, errors)` — `:82-90`: logs `"ResetAiCredits #{label} failed for org #{context.organization&.id}: ..."`, `ap errors`, then `context.fail!(error: :record_invalid, message: ..., organization_id: ...)`
    37. `context.balance = balance` — `:76` (exposes to caller; not used by webhook handler)

### ANALOG — Error handling

38. Rescue blocks around the entire `begin` block (`:211-291`):
    - `rescue Stripe::StripeError => e` — `:281` (logs org id, invoice id, subscription id, message; `ap e`)
    - `rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e` — `:284` (logs org id, invoice id, message; `ap e`)
    - `rescue StandardError => e` — `:287` (logs class, org id, invoice id, message; `ap e`)

### ANALOG — Complete ordered summary of writes

| Order | Target | Column(s) | Value(s) | file:line |
|---|---|---|---|---|
| 1 | `organizations` | `stripe_current_period_end_at` | `Time.at(stripe_subscription.current_period_end).to_datetime` | `stripe_webhook_handler_job.rb:273` |
| 2 | Stripe Customer (API) | `invoice_settings.default_payment_method` | `pm_id` (from subscription's `default_payment_method` or customer's card list) | `organization.rb:630-632` |
| 3 | `ai_credit_balance_transactions` (INSERT, conditional) | `entry_type`, `bucket`, `amount`, `description` | `:plan_monthly_reset_debit`, `:monthly`, `-monthly_credits_remaining`, `'Anniversary reset...'` | `reset_ai_credits.rb:40-49` |
| 3a | `organization_ai_credit_balances` (counter_culture) | `monthly_credits_remaining` | decremented to 0 | (automatic via counter_culture) |
| 4 | `ai_credit_balance_transactions` (INSERT, conditional) | `entry_type`, `bucket`, `amount`, `description` | `:plan_monthly_allocation_credit`, `:monthly`, `new_allocation`, `'Monthly credit grant for...'` | `reset_ai_credits.rb:53-62` |
| 4a | `organization_ai_credit_balances` (counter_culture) | `monthly_credits_remaining` | incremented by `new_allocation` | (automatic via counter_culture) |
| 5 | `organization_ai_credit_balances` | `last_reset_at`, `low_credit_notification_sent_at`, `zero_credit_notification_sent_at`, `sent_low_notification_since_increase`, `sent_zero_notification_since_increase` | `Time.current`, `nil`, `nil`, `false`, `false` | `reset_ai_credits.rb:65-71` |

### ANALOG — Complete ordered summary of Stripe API calls

| Order | Call | Arguments | file:line |
|---|---|---|---|
| 0 (shared) | `Stripe::Event.retrieve(event_id)` | `event_id` | `stripe_webhook_handler_job.rb:20` |
| 1 (shared) | `Stripe::Subscription.retrieve(object.subscription)` | `object.subscription` (invoice's subscription id string) | `:264` |
| 2 | `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` | org's `stripe_subscription_id` column | `organization.rb:477` (via `stripe_payment_method` at `:514` -> `stripe_subscription` at `:474`) |
| 3 | `Stripe::PaymentMethod.retrieve(@subscription.default_payment_method)` | subscription's `default_payment_method` | `organization.rb:517` |
| 4 | `Stripe::PaymentMethod.list({ customer: stripe_customer_id, type: 'card' })` | org's `stripe_customer_id` column | `organization.rb:620-623` |
| 5 | `Stripe::Customer.update(stripe_customer_id, { invoice_settings: { default_payment_method: pm_id } })` | org's `stripe_customer_id`, resolved `pm_id` | `organization.rb:630-632` |

Note: Stripe API call #2 (`Stripe::Subscription.retrieve` at `organization.rb:477`) retrieves the SAME subscription as shared call #1 (`stripe_webhook_handler_job.rb:264`) but from a DIFFERENT source: `:264` uses `object.subscription` (the `sub_xxx` string from the Stripe Invoice object), while `organization.rb:477` uses `organization.stripe_subscription_id` (the DB column on `organizations`). For a main-plan invoice these resolve to the same subscription, but the source is different. This is a redundant retrieve with different expand parameters: `:264` passes a bare string (no expand), while `organization.rb:477` passes `{ id: stripe_subscription_id, expand: ['items.data.price.tiers'] }`. The webhook handler already has the subscription object from `:264` but does not pass it to `stripe_update_default_payment_method`.

---

## OURS — AI credit subscription renewal

Ordered identifier chain from the routing branch to every DB write:

### Step O1: Dispatch to handler

39. `handle_subscription_credit_pack_invoice_paid(object, subscription_price)` — `:269`
    - `object` — the Stripe Invoice object (same as step 4)
    - `subscription_price` — `stripe_subscription.items.data.first&.price` (from step 11, `:266`); the full Stripe Price object

### Step O2: Find existing purchase record

40. `handle_subscription_credit_pack_invoice_paid(invoice, price)` — `:457` (private method)
    - Parameter names: `invoice` (= `object`), `price` (= `subscription_price`)
41. `existing = OrganizationAiCreditPurchase.find_by(stripe_subscription_id: invoice.subscription, kind: :subscription)` — `:458-461`
    - `invoice.subscription` — the `sub_xxx` string from the Stripe Invoice object
    - `OrganizationAiCreditPurchase#kind` — enum `{ one_off: 0, subscription: 1 }` (`organization_ai_credit_purchase.rb:81`)
    - Queries `organization_ai_credit_purchases` WHERE `stripe_subscription_id = <invoice.subscription>` AND `kind = 1`
    - Uses partial unique index `idx_org_ai_purchases_stripe_sub_id` (`schema.rb:987`)
42. `return unless existing` — `:462` (silent return if no matching purchase record; no error, no log)

### Step O3: Update purchase with payment info

43. **DB WRITE #1**: `existing.update(stripe_amount: invoice.amount_paid, currency: invoice.currency, stripe_invoice_item_id: invoice.lines.data.first&.id)` — `:464-468`
    - NOTE: return value is NOT captured or checked. Contrast with the analog's equivalent at step 14 where `updated = organization.update(...)` captures the return value and logs on failure (`:274-276`). A validation failure on this update would be silently swallowed.
    - `stripe_amount` — `organization_ai_credit_purchases.stripe_amount` column (renamed from `amount_cents_paid` by migration `20260611120002`; type `integer`, `null: false` inherited from original column; `db/schema.rb:972` still shows `amount_cents_paid` — schema.rb has not been regenerated after the migration)
    - Value: `invoice.amount_paid` — integer cents from Stripe Invoice
    - `currency` — `organization_ai_credit_purchases.currency` column (`schema.rb:973`, type `string`, default `"usd"`, `null: false`)
    - Value: `invoice.currency` — string from Stripe Invoice (e.g., `"usd"`)
    - `stripe_invoice_item_id` — `organization_ai_credit_purchases.stripe_invoice_item_id` column (added by migration `20260611120002`; type `string`; not yet in `db/schema.rb` — schema not regenerated)
    - Value: `invoice.lines.data.first&.id` — the first line item id from the Stripe Invoice (e.g., `"il_xxx"`)
    - This is a `.update` (not `update_columns`), so validations fire. The model validations at this point:
      - `validates :stripe_price_lookup_key, presence: true, inclusion: ...` (`:86-87`) — already set
      - `validates :kind, presence: true` (`:88`) — already `subscription`
      - `validates :stripe_subscription_id, presence: true, if: -> { subscription? && stripe_checkout_session_id.blank? }` (`:90-92`) — already set
      - `validates :subscription_credits_per_period, presence: true, numericality: { greater_than: 0 }, if: :subscription?` (`:93-96`) — already set
      - `validates :subscription_current_period_start, :subscription_current_period_end, presence: true, if: -> { subscription? && stripe_subscription_id.present? }` (`:97-100`) — these may or may not be set depending on whether this is a first or renewal invoice
      - `validates :stripe_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: -> { subscription? && stripe_subscription_id.blank? }` (`:101-104`) — being set now
      - `validates :currency, presence: true, unless: -> { subscription? && stripe_subscription_id.blank? }` (`:105-107`) — being set now

### Step O4: Call ApplyAiCreditPurchase interactor

44. `ApplyAiCreditPurchase.call(invoice: invoice, price: price, kind: :subscription)` — `:470`
    - `context.invoice` = Stripe Invoice object
    - `context.price` = Stripe Price object (from step 11)
    - `context.kind` = `:subscription`

    **Inside ApplyAiCreditPurchase#call:**

    45. `kind = context.kind` — `apply_ai_credit_purchase.rb:15` -> `:subscription`
    46. `case kind when :subscription` — `:19` -> calls `apply_subscription(context.invoice, context.price)` (`:20`)

    **Inside apply_subscription(invoice, price):**

    NOTE: the `price` parameter (Stripe Price object from step 11) is accepted at `:91` but is NEVER USED inside `apply_subscription`. The method body references only `invoice` (for subscription id, customer, lines, period) and `existing` (for `subscription_credits_per_period`). The credit amount comes from the persisted purchase record, not from the Stripe Price object.

    47. `stripe_subscription_id = invoice.subscription` — `:92` (the `sub_xxx` string)
    48. `organization = Organization.find_by(stripe_customer_id: invoice.customer)` — `:93`
        - Guard: `return context.fail!(error: :missing_organization, ...)` unless organization — `:94`
    49. `existing = OrganizationAiCreditPurchase.find_by(stripe_subscription_id: stripe_subscription_id, kind: :subscription)` — `:96`
        - **REDUNDANT LOOKUP**: same query as step 41 (`:458-461`). The handler already found this record and passed it implicitly via the invoice's subscription id, but the interactor re-queries independently.
        - Guard: `return context.fail!(error: :missing_purchase, ...)` unless existing — `:97-99`
    50. `context.purchase = existing` — `:101` (exposes to caller)

    **Step O4a: Idempotency guard**

    51. `return if existing.stripe_invoice_id == invoice.id` — `:103`
        - `organization_ai_credit_purchases.stripe_invoice_id` column (`schema.rb:970`, type `string`)
        - If this invoice was already processed (same `stripe_invoice_id`), returns early — no duplicate credit grant
        - NOTE: this is the structural grant-once guard for subscriptions. It compares the Stripe invoice id, not a ledger entry_type check (contrast with one-off path which checks `ai_credit_balance_transactions.exists?(entry_type: :one_off_credit_pack_purchase_credit)` at `:64`)

    **Step O4b: Find balance record**

    52. `balance = organization.organization_ai_credit_balance` — `:105`
        - Guard: `return context.fail!(error: :missing_balance, ...)` unless balance — `:106`

    **Step O4c: Update purchase record with period data**

    53. **DB WRITE #2**: `existing.update(subscription_status: :active, subscription_current_period_start: ..., subscription_current_period_end: ..., stripe_invoice_id: invoice.id)` — `:109-114`
        ```ruby
        existing.update(
          subscription_status: :active,
          subscription_current_period_start: period && Time.at(period.start).to_datetime,
          subscription_current_period_end: period && Time.at(period.end).to_datetime,
          stripe_invoice_id: invoice.id
        )
        ```
        Where:
        - `period = invoice.lines.data.first&.period` — `:108` (Stripe InvoiceLineItem period object with `.start` and `.end` Unix timestamps)
        - `subscription_status` — `organization_ai_credit_purchases.subscription_status` column (`schema.rb:978`, type `integer`); enum value `:active` = `0` (`organization_ai_credit_purchase.rb:82`)
        - `subscription_current_period_start` — `organization_ai_credit_purchases.subscription_current_period_start` column (`schema.rb:976`, type `datetime`)
        - `subscription_current_period_end` — `organization_ai_credit_purchases.subscription_current_period_end` column (`schema.rb:977`, type `datetime`)
        - `stripe_invoice_id` — `organization_ai_credit_purchases.stripe_invoice_id` column (`schema.rb:970`, type `string`); set to `invoice.id` (e.g., `"in_xxx"`); this is also the idempotency key checked at step 51
        - `activated = ...` — return value checked at `:115`; on failure calls `fail_with_record_invalid` (`:135-138`)

    **Step O4d: Finalize Stripe payment flag**

    54. `existing.finalize_stripe_payment` — `:117`
        - `OrganizationAiCreditPurchase#finalize_stripe_payment` — `organization_ai_credit_purchase.rb:167`
        - **DB WRITE #3**: `update_columns(stripe_invoice_paid: true)` — `:168`
        - `stripe_invoice_paid` — `organization_ai_credit_purchases.stripe_invoice_paid` column (added by migration `20260611120002`; type `boolean`, default `false`; not yet in `db/schema.rb` — schema not regenerated)
        - `update_columns` skips validations and callbacks

    **Step O4e: Create credit grant ledger row**

    55. **DB WRITE #4**: `AiCreditBalanceTransaction.new(...)` + `.save` — `:119-127`
        ```ruby
        AiCreditBalanceTransaction.new(
          organization_ai_credit_balance: balance,
          organization_ai_credit_purchase: existing,
          entry_type: :subscription_credit_pack_purchase_credit,
          bucket: :addon_subscription,
          amount: existing.subscription_credits_per_period,
          description: 'Credit pack subscription first invoice'
        )
        ```
        - `entry_type: :subscription_credit_pack_purchase_credit` — enum value `30` (`ai_credit_balance_transaction.rb:21`)
        - `bucket: :addon_subscription` — enum value `2` (`ai_credit_balance_transaction.rb:39`)
        - `amount` — positive (credit); equals `existing.subscription_credits_per_period` (`organization_ai_credit_purchases.subscription_credits_per_period` column, `schema.rb:974`, type `integer`; set at checkout time from `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`)
        - `organization_ai_credit_purchase: existing` — foreign key link to the purchase record
        - `description` — hardcoded `'Credit pack subscription first invoice'` (NOTE: this string says "first invoice" but this code path fires for EVERY renewal, not just the first)
        - On `.save`: `counter_culture` callback (`ai_credit_balance_transaction.rb:48-50`) atomically increments `organization_ai_credit_balances.addon_subscription_credits_remaining`
        - **DB WRITE #4a (automatic via counter_culture)**: `UPDATE organization_ai_credit_balances SET addon_subscription_credits_remaining = addon_subscription_credits_remaining + <amount> WHERE id = ...`
        - Guard: `fail_with_record_invalid('credit grant ledger row', ledger.errors) unless ledger.save` — `:127`

    **Step O4f: Clear notification flags**

    56. **DB WRITE #5**: `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)` — `:129-132`
        - `organization_ai_credit_balances.sent_low_notification_since_increase` (`schema.rb:954`, type `boolean`)
        - `organization_ai_credit_balances.sent_zero_notification_since_increase` (`schema.rb:955`, type `boolean`)
        - `update_columns` skips validations and callbacks

### OURS — Error handling

57. Inherits the same rescue blocks from the shared `begin` block (`:281-291`):
    - `rescue Stripe::StripeError => e` — `:281`
    - `rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e` — `:284`
    - `rescue StandardError => e` — `:287`

Additionally, `ApplyAiCreditPurchase` uses `context.fail!` (Interactor gem) for business-logic failures (`:94`, `:98`, `:106`, `:115/135-138`, `:127/135-138`). These do NOT raise exceptions — they set `context.failure? = true` and halt the interactor. The webhook handler at `:470` does NOT check `result.success?`, so interactor failures are **silently ignored** by the webhook handler.

### OURS — Complete ordered summary of writes

| Order | Target | Column(s) | Value(s) | file:line |
|---|---|---|---|---|
| 1 | `organization_ai_credit_purchases` | `stripe_amount`, `currency`, `stripe_invoice_item_id` | `invoice.amount_paid`, `invoice.currency`, `invoice.lines.data.first&.id` | `stripe_webhook_handler_job.rb:464-468` |
| 2 | `organization_ai_credit_purchases` | `subscription_status`, `subscription_current_period_start`, `subscription_current_period_end`, `stripe_invoice_id` | `:active`, period start datetime, period end datetime, `invoice.id` | `apply_ai_credit_purchase.rb:109-114` |
| 3 | `organization_ai_credit_purchases` | `stripe_invoice_paid` | `true` | `organization_ai_credit_purchase.rb:168` (via `finalize_stripe_payment`) |
| 4 | `ai_credit_balance_transactions` (INSERT) | `organization_ai_credit_balance_id`, `organization_ai_credit_purchase_id`, `entry_type`, `bucket`, `amount`, `description` | balance id, purchase id, `:subscription_credit_pack_purchase_credit`, `:addon_subscription`, `subscription_credits_per_period`, `'Credit pack subscription first invoice'` | `apply_ai_credit_purchase.rb:119-127` |
| 4a | `organization_ai_credit_balances` (counter_culture) | `addon_subscription_credits_remaining` | incremented by `subscription_credits_per_period` | (automatic via counter_culture) |
| 5 | `organization_ai_credit_balances` | `sent_low_notification_since_increase`, `sent_zero_notification_since_increase` | `false`, `false` | `apply_ai_credit_purchase.rb:129-132` |

### OURS — Complete ordered summary of Stripe API calls

| Order | Call | Arguments | file:line |
|---|---|---|---|
| 0 (shared) | `Stripe::Event.retrieve(event_id)` | `event_id` | `stripe_webhook_handler_job.rb:20` |
| 1 (shared) | `Stripe::Subscription.retrieve(object.subscription)` | `object.subscription` (invoice's subscription id string) | `:264` |

OURS makes ZERO additional Stripe API calls beyond the two shared ones. No payment method update, no customer update.

---

