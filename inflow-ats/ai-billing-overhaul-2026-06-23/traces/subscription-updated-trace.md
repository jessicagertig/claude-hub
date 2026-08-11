# customer.subscription.updated Webhook Handler -- Iota-for-Iota Structural Trace

Goal: an exact structural map of the ANALOG (main-plan subscription.updated handler) and OURS (credit-pack subscription.updated handler), both inside `StripeWebhookHandlerJob#handle_stripe_event`, so the two paths can be compared structurally.

---

## Shared entry point

Both paths share an entry point and a routing decision. Traced here once.

Ordered identifier chain (Stripe event arrival -> branch selection):

1. `StripeWebhookHandlerJob#perform(event_id)` -- `app/jobs/stripe_webhook_handler_job.rb:14`
2. `Stripe::Event.retrieve(event_id)` -- `:20` -> `event`
3. Error rescues: `JSON::ParserError` (`:21`), `Stripe::SignatureVerificationError` (`:26`), `Stripe::InvalidRequestError` (`:31`), `Stripe::APIConnectionError` (`:35`) -- all `return` (no re-raise, no Sentry)
4. `handle_stripe_event(event)` -- `:41`
5. `object = event.data.object` -- `:48`. For `customer.subscription.updated`, `object` is a Stripe Subscription object (`sub_xxx`)
6. `log_stripe_changes(event)` -- `:50` -> private method `:401`. Reads `event.data.previous_attributes.to_hash`, logs old/new for each changed key. No side effects.
7. `case event.type` -- `:52` -> matches `'customer.subscription.updated'` at `:111`

### Shared reads before the branch

8. `stripe_current_period_end_at = Time.at(object.current_period_end).to_datetime` -- `:117`. Reads `object.current_period_end` (Stripe Subscription field, Unix timestamp). Variable name is `stripe_current_period_end_at` (matches the Organization column name, but used for both paths).
9. `organization = Organization.find_by(stripe_customer_id: object.customer)` -- `:119`. Reads `object.customer` (Stripe customer ID string). This lookup runs before the branch decision but only the ANALOG path uses the `organization` variable (at `:149` guard and `:153-159` handler). The OURS path does NOT use `organization` -- it finds its record via `object.id` directly. If `organization` is nil (customer not found), the ours path still runs normally; only the analog guard at `:149` is affected (`organization&.stripe_subscription_id` returns nil).
10. `plan_lookup_key = object.items&.data&.first&.price&.lookup_key` -- `:120`. Reads the lookup_key of the first subscription item's price. This is the routing key.

### Branch decision

11. `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(plan_lookup_key)` -- `:125`
    - Definition: `app/models/organization_ai_credit_purchase.rb:63` -> `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[lookup_key]&.dig(:kind) == :subscription`
    - `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` -- `organization_ai_credit_purchase.rb:4` -- 10-entry hash; 5 entries have `kind: :subscription`: `plato_ai_credit_subscription_small` (`:21`), `plato_ai_credit_subscription_medium` (`:26`), `plato_ai_credit_subscription_large` (`:31`), `ai_credit_pack_subscription_small_monthly` (`:47`), `ai_credit_pack_subscription_large_monthly` (`:52`)
    - If `true` -> OURS (credit-pack path, `:126-148`)
    - If `false` -> falls to `elsif` at `:149`

12. `elsif object.id == organization&.stripe_subscription_id` -- `:149`. If the Stripe Subscription id matches the Organization's `stripe_subscription_id` column (`db/schema.rb:1052`) -> ANALOG (main-plan path, `:150-160`).
    - If neither branch matches (credit lookup_key not recognized AND subscription id does not match org's main-plan sub), NEITHER branch runs. No error, no logging -- silent no-op.

### Shared error handling

13. `rescue StandardError => e` -- `:161`
    - `ap 'Stripe Webhook Error - subscription.updated'` -- `:162`
    - `ap e` -- `:163`
    - `Rails.logger.error e` -- `:164`
    - No Sentry capture. No re-raise.

---

## ANALOG -- main-plan subscription.updated handler

Lines `:149-160`. Entered when `object.id == organization&.stripe_subscription_id` (the event is for the org's main-plan Stripe subscription, not a credit-pack subscription).

Ordered identifier chain:

### A1. Organization columns updated directly

14. `organization.update(...)` -- `:153-157`. The update hash:

```ruby
{
  stripe_current_period_end_at: stripe_current_period_end_at,   # from shared :117
  stripe_subscription_status: object.status,                     # Stripe Subscription status string
  stripe_cancel_at_period_end: object.cancel_at_period_end       # boolean
}
```

Columns written on `organizations`:
- `stripe_current_period_end_at` (datetime, `db/schema.rb:1054`) -- set to `Time.at(object.current_period_end).to_datetime`
- `stripe_subscription_status` (string, `db/schema.rb:1061`) -- set to `object.status` (Stripe status string: `active`, `past_due`, `canceled`, `trialing`, etc.)
- `stripe_cancel_at_period_end` (boolean, `db/schema.rb:1080`) -- set to `object.cancel_at_period_end`

This is a standard `update` (runs validations, callbacks, sets `updated_at`).

### A2. stripe_update_default_payment_method

15. `organization.stripe_update_default_payment_method(object.default_payment_method) if object.default_payment_method` -- `:158`
    - Condition: `object.default_payment_method` is truthy (non-nil). Reads the Stripe Subscription's `default_payment_method` field (a payment method ID string like `pm_xxx`, or nil).
    - Definition: `app/models/organization.rb:612`

16. `Organization#stripe_update_default_payment_method(payment_method_id = nil)` -- `organization.rb:612-633`. Full trace:
    - `:613-617` -- `pm_id` resolution:
      ```ruby
      pm_id = if payment_method_id
                payment_method_id
              else
                stripe_payment_method ? stripe_payment_method.id : nil
              end
      ```
      When called from `:158`, `payment_method_id` is `object.default_payment_method` (non-nil due to the `if` guard), so `pm_id = payment_method_id` directly. The `else` branch calls `stripe_payment_method` (`:513-517`, which calls `stripe_subscription` then `Stripe::PaymentMethod.retrieve`), but this branch is NOT taken in the webhook handler path.
    - `:618` -- `return unless pm_id` -- guard; `pm_id` is non-nil here.
    - `:620-623` -- Stripe API call:
      ```ruby
      payment_methods = Stripe::PaymentMethod.list({
        customer: stripe_customer_id,
        type: 'card'
      })
      ```
      Reads `self.stripe_customer_id` (`db/schema.rb:1051`). Returns all card payment methods for the customer.
    - `:628` -- `return unless payment_methods.collect { |pm| pm.id }.include?(pm_id)` -- guard: only proceed if the payment method ID is among the customer's known card methods. If the PM is not a card or not found, returns silently.
    - `:630-632` -- Stripe API call:
      ```ruby
      Stripe::Customer.update(stripe_customer_id, {
        invoice_settings: {
          default_payment_method: pm_id
        }
      })
      ```
      Updates the Stripe Customer's default payment method. No local DB write.

### A3. sync_with_stripe

17. `organization.sync_with_stripe` -- `:159`
    - Definition: `app/models/organization.rb:520-610`. Full line-by-line trace:

18. `:521-527` -- Debug logging (6 `ap` calls). Reads `stripe_customer_id`, `stripe_subscription_id`. No side effects.

19. `:528` -- `return unless stripe_customer_id.present?` -- guard: no Stripe customer, no sync.

20. `:530` -- `return if stripe_customer.respond_to?(:deleted)` -- guard: if `stripe_customer` returns a deleted customer object (has a `:deleted` method), stop. `stripe_customer` is `Organization#stripe_customer` (`organization.rb:469-471`):
    ```ruby
    def stripe_customer
      return Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] }) unless stripe_customer_id.nil?
    end
    ```
    Stripe API call: `Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] })`.

21. `:538` -- `subscriptions = stripe_customer_subscriptions.data`
    - `stripe_customer_subscriptions` -- `organization.rb:481-483`:
      ```ruby
      def stripe_customer_subscriptions
        Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' }) unless stripe_customer_id.nil?
      end
      ```
    Stripe API call: `Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' })`. Returns up to 3 subscriptions of any status.

22. `:539-542` -- **Credit-subscription rejection filter**:
    ```ruby
    plan_subscriptions = subscriptions.reject do |subscription|
      lookup_key = subscription.items&.data&.[](0)&.price&.lookup_key.to_s
      lookup_key.include?('credit') || lookup_key.include?('plato')
    end
    ```
    For each subscription, reads `items.data[0].price.lookup_key`. If the lookup_key contains `'credit'` OR `'plato'`, the subscription is REJECTED (excluded). This is how `sync_with_stripe` explicitly filters out credit-pack subscriptions -- any lookup_key containing either substring is not considered a "plan subscription."

    Matching keys from `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`: ALL 10 keys contain either `'credit'` or `'plato'` (or both):
    - `plato_ai_credit_top_up_small` -- contains both `'plato'` and `'credit'`
    - `plato_ai_credit_top_up_medium` -- both
    - `plato_ai_credit_top_up_large` -- both
    - `plato_ai_credit_subscription_small` -- both
    - `plato_ai_credit_subscription_medium` -- both
    - `plato_ai_credit_subscription_large` -- both
    - `ai_credit_pack_top_up_small` -- contains `'credit'`
    - `ai_credit_pack_top_up_large` -- contains `'credit'`
    - `ai_credit_pack_subscription_small_monthly` -- contains `'credit'`
    - `ai_credit_pack_subscription_large_monthly` -- contains `'credit'`

    All credit-pack subscriptions are filtered out. The filter works via substring match on two keywords.

23. `:543-545` -- Select the "current" main-plan subscription:
    ```ruby
    current_subscription = plan_subscriptions.find { |subscription| subscription.status == 'trialing' } ||
                           plan_subscriptions.find { |subscription| subscription.status == 'active' } ||
                           plan_subscriptions[0]
    ```
    Priority: trialing > active > first-in-list. If `plan_subscriptions` is empty (no non-credit subscriptions), `current_subscription` is `nil`.

24. `:550` -- `current_subscription_price = current_subscription&.items&.data&.[](0)&.price` -- reads first item's price from the selected subscription.

25. `:555` -- `current_subscription_lookup_key = current_subscription_price.present? ? current_subscription_price["lookup_key"] : "no_lookup_key_found"` -- extracts the lookup_key string; falls back to `"no_lookup_key_found"` if no price.

26. `:565-571` -- Build `attributes` hash:
    ```ruby
    attributes = {}
    if current_subscription.present?
      attributes['stripe_subscription_id'] = current_subscription&.id
      attributes['stripe_subscription_status'] = current_subscription&.status
      attributes['stripe_current_period_end_at'] = current_subscription.present? ? Time.at(current_subscription.current_period_end).to_datetime : nil
    end
    ```
    Columns potentially written: `stripe_subscription_id` (`schema.rb:1052`), `stripe_subscription_status` (`schema.rb:1061`), `stripe_current_period_end_at` (`schema.rb:1054`).

    NOTE: these are the SAME three columns the direct `organization.update` at `:153-157` already wrote. `sync_with_stripe` may overwrite them with values from a DIFFERENT subscription (the one `sync_with_stripe` considers "current" after filtering), or with the same values.

27. `:573` -- Plan assignment:
    ```ruby
    attributes['plan'] = assign_plan_name_from_lookup_key(lookup_key: current_subscription_lookup_key, subscription_nil: current_subscription.nil?)
    ```
    - `assign_plan_name_from_lookup_key` -- `organization.rb:678-679`:
      ```ruby
      def assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)
        Stripe::SubscriptionStatusChecker.new(self).assign_plan_from_lookup_key(lookup_key: lookup_key, subscription_nil: subscription_nil)
      end
      ```
    - `assign_plan_from_lookup_key` -- `app/services/stripe/subscription_status_checker.rb:113-118`:
      ```ruby
      def assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)
        return 'plan_simple_ats_free' if subscription_nil
        return @organization.plan if lookup_key.nil?
        plan_key = PLAN_LOOKUP_MAPPING.keys.find { |key| lookup_key.include?(key) }
        plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan
      end
      ```
    - `PLAN_LOOKUP_MAPPING` -- `subscription_status_checker.rb:16-47` -- 16-entry hash mapping Stripe lookup_key substrings to internal plan enum strings (e.g., `'apollo' => 'plan_ats_tier_apollo'`, `'starter_v2' => 'plan_ats_tier_starter_v2'`).
    - Column written: `plan` (integer enum, `db/schema.rb:1048`, default `101`). Enum definition at `organization.rb:94`.

28. `:578` -- Conditional payment method sync inside `sync_with_stripe`:
    ```ruby
    stripe_update_default_payment_method(current_subscription&.default_payment_method) if stripe_customer.invoice_settings.default_payment_method.nil? && !current_subscription&.default_payment_method.nil?
    ```
    Calls `stripe_update_default_payment_method` (same method as A2 above, `organization.rb:612`) ONLY if the Stripe Customer has no default PM in `invoice_settings` AND the current subscription does have one. This is a SECOND potential call to `stripe_update_default_payment_method` -- the first was at `:158` (unconditional on `object.default_payment_method` being present), this one is conditional on the Stripe Customer lacking one.

    NOTE: `stripe_customer` at `:578` and `:580` is the SAME Stripe API call from step 20 (`organization.rb:469-471`). Ruby does NOT memoize it -- each call to `stripe_customer` is a fresh `Stripe::Customer.retrieve`. So this is a second Stripe API call to retrieve the customer.

29. `:580` -- `attributes['stripe_default_payment_method_on_file'] = !stripe_customer.invoice_settings.default_payment_method.nil?`
    - Column: `stripe_default_payment_method_on_file` (boolean, `db/schema.rb:1062`). Set to `true` if the Stripe Customer has a default payment method, `false` otherwise.
    - THIRD call to `stripe_customer` (third `Stripe::Customer.retrieve`).

30. `:583-609` -- Diff-and-update:
    ```ruby
    changes_to_make = {}
    attributes.each do |key, value|
      current_value = public_send(key)
      if current_value == value
        # skip
      else
        changes_to_make[key] = value
      end
    end
    if changes_to_make.any?
      update(changes_to_make)
      if changes_to_make.key?('plan') && organization_ai_credit_balance
        new_allocation = PlanFeatureGate.new(self).monthly_ai_credit_allocation
        organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)
      end
    end
    ```
    - Only writes attributes that actually changed (compares via `public_send`).
    - `update(changes_to_make)` -- standard AR update (validations + callbacks).
    - `:603-606` -- If `plan` changed AND the org has an `organization_ai_credit_balance` (association at `organization.rb:28`, `has_one :organization_ai_credit_balance`):
      - `PlanFeatureGate.new(self).monthly_ai_credit_allocation` -- `app/services/plan_feature_gate.rb:134-136`:
        ```ruby
        def monthly_ai_credit_allocation
          plan_rules[@plan]&.dig(:monthly_ai_credit_allocation) || MINIMUM_AI_CREDIT_ALLOCATION
        end
        ```
        Reads the plan rules table (`plan_feature_gate.rb:142+`) keyed by `@plan` (the org's plan string). Returns the credit allocation for the new plan.
      - `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` -- overwrites monthly credits with the new plan's allocation. `update_columns` skips validations/callbacks.

### A4. Organization callbacks triggered by update

Both `organization.update(...)` at `:153` and `sync_with_stripe`'s `update(changes_to_make)` at `organization.rb:600` trigger Organization model callbacks:

31. `before_update :handle_before_update` -- `organization.rb:57` -> `organization.rb:976-985`. Unconditional side effects:
    - `:978` -- `update_column(:website_url, nav_url(website_url)) unless website_url.nil?` -- rewrites the website URL column on every update (formatting normalization).
    - `:980` -- `update_column(:linkedin_basic_jobs_changed_at, DateTime.current) if linkedin_company_id_changed?` -- not triggered by subscription fields.
    - `:982` -- `update_column(:x_hiring_changed_at, DateTime.current) if enable_x_hiring_changed?` -- not triggered by subscription fields.
    - Rescue: `StandardError => e` -> `Sentry.capture_exception(e)` (`:983-984`).

32. `after_commit :handle_after_commit_on_update, on: [:update]` -- `organization.rb:59` -> `organization.rb:987-992`. Dispatches to 5 sub-handlers based on `saved_changes`:
    - `handle_subscription_status_change_after_commit` (`organization.rb:1067`) -- fires when `stripe_subscription_status` changed. Side effects: `handle_stripe_subscription_past_due` (`:1078`, fires `StripeSubscriptionMailer.past_due.deliver_later` and `Notification::PaidSubscriptionPastDueJob`), `update_column(:can_send_bulk_messages, true)` and `update_column(:can_enable_linkedin, true)` when status becomes `'active'` (`:1081-1084`), Notification/Discord jobs for past_due->active (`:1086-1090`), trial started (`:1092-1096`), trial converted (`:1098-1102`). `subscription_became_active_after_commit?` (`:1104-1106`) logs but fires NO jobs. `subscription_became_canceled_after_commit?` (`:1108-1117`) calls `handle_automations_on_downgrade` -> `DisableAutomationsOnDowngrade.call` (`organization.rb:1219-1224`).
    - `handle_plan_change_after_commit` (`organization.rb:1036`) -- fires when `plan` changed. Side effects: Notification/Discord plan-changed jobs, `log_assigned_free_plan_event`, `handle_automations_on_downgrade`.
    - `handle_name_change_after_commit` (`organization.rb:1028`) -- fires when `name` changed. Side effects: `update_stripe_customer`. Not triggered by the subscription.updated handler.
    - `handle_linkedin_company_id_change_after_commit` (`organization.rb:995`) -- not triggered by subscription fields.
    - `handle_cancellation_scheduled_after_commit` (`organization.rb:1009`) -- fires when `stripe_cancel_at_period_end` transitions from `false` to `true` (checked by `subscription_cancellation_scheduled_after_commit?` at `organization.rb:1177-1183`; does NOT fire on any other change). Side effects: Notification/Discord cancellation-scheduled jobs, EngagementReport job.

    NOTE: The ours path's `purchase.update(...)` does NOT trigger any callbacks -- `OrganizationAiCreditPurchase` has no `before_update`/`after_commit` callbacks defined. This is a structural difference: the analog's update has cascading side effects (notifications, automation disabling, engagement reports); ours has none.

### ANALOG: complete list of Stripe fields read from `object` (the Subscription)

| Stripe field | Line | Used for |
|---|---|---|
| `object.current_period_end` | `:117` | `stripe_current_period_end_at` on Organization |
| `object.customer` | `:119` | `Organization.find_by(stripe_customer_id:)` |
| `object.items.data.first.price.lookup_key` | `:120` | Branch routing + plan assignment |
| `object.id` | `:149` | Guard: must match `organization.stripe_subscription_id` |
| `object.status` | `:155` | `stripe_subscription_status` on Organization |
| `object.cancel_at_period_end` | `:156` | `stripe_cancel_at_period_end` on Organization |
| `object.default_payment_method` | `:158` | Passed to `stripe_update_default_payment_method` |
| `object.current_period_start` | NOT READ | Not used by the analog |

### ANALOG: complete list of Organization columns written

| Column | Writer | Line |
|---|---|---|
| `stripe_current_period_end_at` | `organization.update(...)` | `:154` |
| `stripe_subscription_status` | `organization.update(...)` | `:155` |
| `stripe_cancel_at_period_end` | `organization.update(...)` | `:156` |
| `stripe_subscription_id` | `sync_with_stripe` -> `update(changes_to_make)` | `organization.rb:568`, `:600` |
| `stripe_subscription_status` | `sync_with_stripe` -> `update(changes_to_make)` | `organization.rb:569`, `:600` |
| `stripe_current_period_end_at` | `sync_with_stripe` -> `update(changes_to_make)` | `organization.rb:570`, `:600` |
| `plan` | `sync_with_stripe` -> `update(changes_to_make)` | `organization.rb:573`, `:600` |
| `stripe_default_payment_method_on_file` | `sync_with_stripe` -> `update(changes_to_make)` | `organization.rb:580`, `:600` |
| `monthly_credits_remaining` (on `organization_ai_credit_balances`) | `sync_with_stripe` -> `update_columns` | `organization.rb:605` (only if plan changed) |
| `website_url` | `handle_before_update` callback -> `update_column` | `organization.rb:978` (unconditional unless website_url nil) |
| `can_send_bulk_messages` | `handle_subscription_status_change_after_commit` -> `update_column` | `organization.rb:1082` (only when status becomes `'active'` and column is currently false) |
| `can_enable_linkedin` | `handle_subscription_status_change_after_commit` -> `update_column` | `organization.rb:1083` (only when status becomes `'active'` and column is currently false) |

NOTE: `stripe_current_period_end_at`, `stripe_subscription_status` are written TWICE -- once at `:153-157` from the webhook `object`, then again by `sync_with_stripe` from a freshly-retrieved subscription list. The second write may produce different values if `sync_with_stripe` selects a different subscription as "current."

### ANALOG: complete list of Stripe API calls

| Call | Line | Purpose |
|---|---|---|
| `Stripe::PaymentMethod.list(customer:, type: 'card')` | `organization.rb:620` | Validate PM belongs to customer (called 1-2x: once from `:158`, conditionally again from `organization.rb:578` inside `sync_with_stripe`) |
| `Stripe::Customer.update(stripe_customer_id, invoice_settings: ...)` | `organization.rb:630` | Set default PM on Stripe Customer (called 1-2x, same as above) |
| `Stripe::Customer.retrieve({ id:, expand: ['subscriptions'] })` | `organization.rb:471` (via `stripe_customer`, called 3x in sync) | Get customer object |
| `Stripe::Subscription.list({ customer:, limit: 3, status: 'all' })` | `organization.rb:482` (via `stripe_customer_subscriptions`) | Get all subscriptions for filtering |

NOTE: `stripe_update_default_payment_method` is called at `:158` (always, if `object.default_payment_method` is truthy) AND conditionally at `organization.rb:578` inside `sync_with_stripe` (if the Stripe Customer has no default PM and the current subscription has one). In the worst case, both calls execute, giving a maximum of 8 Stripe API calls total (2x PaymentMethod.list + 2x Customer.update + 3x Customer.retrieve + 1x Subscription.list).

### ANALOG: complete list of methods called

| Method | Source | Line called |
|---|---|---|
| `Organization#stripe_update_default_payment_method` | `organization.rb:612` | `:158` |
| `Organization#sync_with_stripe` | `organization.rb:520` | `:159` |
| `Organization#stripe_customer` | `organization.rb:469` | `organization.rb:530, 578, 580` |
| `Organization#stripe_customer_subscriptions` | `organization.rb:481` | `organization.rb:538` |
| `Organization#assign_plan_name_from_lookup_key` | `organization.rb:678` | `organization.rb:573` |
| `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key` | `subscription_status_checker.rb:113` | `organization.rb:679` |
| `PlanFeatureGate#monthly_ai_credit_allocation` | `plan_feature_gate.rb:134` | `organization.rb:604` |
| `Organization#handle_before_update` (callback) | `organization.rb:976` | triggered by `organization.update` at `:153` and `organization.rb:600` |
| `Organization#handle_after_commit_on_update` (callback) | `organization.rb:987` | triggered by `organization.update` at `:153` and `organization.rb:600` |
| `Organization#handle_subscription_status_change_after_commit` | `organization.rb:1067` | `organization.rb:988` (if `stripe_subscription_status` changed) |
| `Organization#handle_stripe_subscription_past_due` | `organization.rb:1214` | `organization.rb:1078` (if subscription became past_due) |
| `StripeSubscriptionMailer.past_due(id).deliver_later` | (mailer) | `organization.rb:1215` (inside `handle_stripe_subscription_past_due`) |
| `Organization#handle_plan_change_after_commit` | `organization.rb:1036` | `organization.rb:989` (if `plan` changed) |
| `Organization#log_assigned_free_plan_event` | `organization.rb:1193` | `organization.rb:1056` (inside `handle_plan_change_after_commit`) |
| `Organization#handle_automations_on_downgrade` | `organization.rb:1219` | `organization.rb:1061` (inside `handle_plan_change_after_commit`) and `organization.rb:1114` (inside `handle_subscription_status_change_after_commit` on canceled) |
| `DisableAutomationsOnDowngrade.call` | (interactor) | `organization.rb:1220` (inside `handle_automations_on_downgrade`) |
| `Organization#handle_cancellation_scheduled_after_commit` | `organization.rb:1009` | `organization.rb:992` (if `stripe_cancel_at_period_end` changed `false` -> `true`) |

---

## OURS -- credit-pack subscription.updated handler

Lines `:125-148`. Entered when `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(plan_lookup_key)` returns `true` (the subscription item's lookup_key is recognized as a credit-pack subscription key).

Ordered identifier chain:

### O1. Find the local purchase record

33. `purchase = OrganizationAiCreditPurchase.find_by(stripe_subscription_id: object.id, kind: :subscription)` -- `:130-133`
    - Reads `object.id` (Stripe Subscription ID, e.g. `sub_xxx`).
    - Matches against `stripe_subscription_id` column (`db/schema.rb:968`) AND `kind` enum = `:subscription` (value `1`, `organization_ai_credit_purchase.rb:81`).
    - The `stripe_subscription_id` column has a unique partial index (`idx_org_ai_purchases_stripe_sub_id`, `schema.rb:987`, `WHERE stripe_subscription_id IS NOT NULL`).
    - Returns `nil` if no match.

### O2. Guard: purchase found?

34. `if purchase` -- `:134`. If `nil`, falls to `else` at `:146`.
    - `:146-148` (else branch):
      ```ruby
      Rails.logger.error "subscription.updated credit-pack: no OrganizationAiCreditPurchase for stripe_subscription_id #{object.id}"
      ```
      Logs the error and returns (no re-raise, no Sentry).

### O3. Update the purchase record

35. `updated = purchase.update(...)` -- `:135-141`. The update hash:

```ruby
{
  stripe_price_lookup_key: plan_lookup_key,
  subscription_credits_per_period: OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(plan_lookup_key),
  subscription_status: object.status,
  subscription_current_period_start: Time.at(object.current_period_start).to_datetime,
  subscription_current_period_end: stripe_current_period_end_at
}
```

Each field traced:

36. `stripe_price_lookup_key: plan_lookup_key` -- `:136`
    - `plan_lookup_key` from shared step 10 (`:120`): `object.items.data.first.price.lookup_key`.
    - Column: `stripe_price_lookup_key` (`db/schema.rb:971`, string, NOT NULL).
    - Validation: `validates :stripe_price_lookup_key, presence: true, inclusion: { in: ->(_) { OrganizationAiCreditPurchase.ai_credit_lookup_keys } }` (`organization_ai_credit_purchase.rb:86-87`). The lookup_key must be one of the 10 keys in `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`.

37. `subscription_credits_per_period: OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(plan_lookup_key)` -- `:137`
    - `ai_credit_allocation_for_lookup_key` -- `organization_ai_credit_purchase.rb:71-76`:
      ```ruby
      def self.ai_credit_allocation_for_lookup_key(lookup_key)
        pack = AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[lookup_key]
        return unless pack
        pack[:credits] || pack[:credits_per_period]
      end
      ```
      Returns `credits_per_period` for subscription keys (e.g., 500 for `plato_ai_credit_subscription_small`, 2000 for `ai_credit_pack_subscription_large_monthly`).
    - Column: `subscription_credits_per_period` (`db/schema.rb:974`, integer).
    - Validation: `validates :subscription_credits_per_period, presence: true, numericality: { greater_than: 0 }, if: :subscription?` (`organization_ai_credit_purchase.rb:93-96`).

38. `subscription_status: object.status` -- `:138`
    - Reads `object.status` (Stripe Subscription status string).
    - Column: `subscription_status` (`db/schema.rb:978`, integer -- enum).
    - Enum: `enum subscription_status: { active: 0, past_due: 1, canceled: 2, paused: 3, trialing: 4, incomplete: 5, incomplete_expired: 6, unpaid: 7 }, _prefix: true` (`organization_ai_credit_purchase.rb:82-84`).
    - NOTE: `object.status` is a Stripe string (e.g. `"active"`). Rails enum assignment accepts string keys, so `subscription_status: "active"` resolves to integer `0`.

39. `subscription_current_period_start: Time.at(object.current_period_start).to_datetime` -- `:139`
    - Reads `object.current_period_start` (Stripe Subscription field, Unix timestamp).
    - Column: `subscription_current_period_start` (`db/schema.rb:976`, datetime).
    - Validation: `validates :subscription_current_period_start, :subscription_current_period_end, presence: true, if: -> { subscription? && stripe_subscription_id.present? }` (`organization_ai_credit_purchase.rb:97-100`).
    - NOTE: the ANALOG does NOT read `object.current_period_start` at all. This is an EXTRA field read by ours.

40. `subscription_current_period_end: stripe_current_period_end_at` -- `:140`
    - `stripe_current_period_end_at` from shared step 8 (`:117`): `Time.at(object.current_period_end).to_datetime`.
    - Column: `subscription_current_period_end` (`db/schema.rb:977`, datetime).

This is a standard `update` (runs validations, callbacks, sets `updated_at`).

NOTE: Additional validations fire during this `update` that the handler does NOT set values for:
- `validates :stripe_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: -> { subscription? && stripe_subscription_id.blank? }` (`organization_ai_credit_purchase.rb:101-104`). For a subscription purchase with `stripe_subscription_id` present, the `unless` evaluates to `false`, so the validation fires. The existing `stripe_amount` value (set at record creation or by `handle_subscription_credit_pack_invoice_paid`) must pass.
- `validates :currency, presence: true, unless: -> { subscription? && stripe_subscription_id.blank? }` (`organization_ai_credit_purchase.rb:105-107`). Same condition -- fires on this update. The existing `currency` value (defaulted to `'usd'` at DB level, `schema.rb:973`) must pass.

These validations do not block the update in practice because both columns have values by the time `subscription.updated` fires (the DB column `stripe_amount` -- renamed from `amount_cents_paid` by migration `20260611120002` -- is `NOT NULL`, and `currency` defaults to `'usd'`). But they are part of the validation surface the update passes through.

### O4. Guard: update succeeded?

41. `unless updated` -- `:142`
    - `:143-145`:
      ```ruby
      Rails.logger.error "subscription.updated credit-pack: could not update purchase #{purchase.id}: #{purchase.errors.full_messages.join(', ')}"
      ap purchase.errors
      ```
    - Logs the validation errors. Does NOT re-raise, does NOT return early -- execution continues normally through the `end` statements and exits the `begin` block without hitting the `rescue` at `:161` (the rescue only fires if an exception is raised).

### OURS: complete list of Stripe fields read from `object` (the Subscription)

| Stripe field | Line | Used for |
|---|---|---|
| `object.current_period_end` | `:117` | `subscription_current_period_end` on purchase |
| `object.customer` | `:119` | `Organization.find_by(stripe_customer_id:)` (shared, but org is NOT used by ours beyond the initial find) |
| `object.items.data.first.price.lookup_key` | `:120` | Branch routing + `stripe_price_lookup_key` + credit allocation lookup |
| `object.id` | `:131` | `OrganizationAiCreditPurchase.find_by(stripe_subscription_id:)` |
| `object.status` | `:138` | `subscription_status` on purchase |
| `object.current_period_start` | `:139` | `subscription_current_period_start` on purchase |
| `object.cancel_at_period_end` | NOT READ | Not used by ours |
| `object.default_payment_method` | NOT READ | Not used by ours |

### OURS: complete list of OrganizationAiCreditPurchase columns written

| Column | Writer | Line |
|---|---|---|
| `stripe_price_lookup_key` | `purchase.update(...)` | `:136` |
| `subscription_credits_per_period` | `purchase.update(...)` | `:137` |
| `subscription_status` | `purchase.update(...)` | `:138` |
| `subscription_current_period_start` | `purchase.update(...)` | `:139` |
| `subscription_current_period_end` | `purchase.update(...)` | `:140` |
| `updated_at` | (implicit from `update`) | -- |

### OURS: complete list of Stripe API calls

NONE. The ours path makes zero Stripe API calls. It reads only from the `object` (the Stripe Subscription already provided by the webhook event) and from the local DB.

### OURS: complete list of methods called

| Method | Source | Line called |
|---|---|---|
| `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?` | `organization_ai_credit_purchase.rb:63` | `:125` |
| `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key` | `organization_ai_credit_purchase.rb:71` | `:137` |

No other methods called. No `sync_with_stripe`, no `stripe_update_default_payment_method`, no plan assignment, no credit balance reset.

---

## sync_with_stripe explicitly rejects credit subscriptions

The mechanism is at `organization.rb:539-542`:

```ruby
plan_subscriptions = subscriptions.reject do |subscription|
  lookup_key = subscription.items&.data&.[](0)&.price&.lookup_key.to_s
  lookup_key.include?('credit') || lookup_key.include?('plato')
end
```

This runs inside `sync_with_stripe` (step 22 above). It fetches ALL of the customer's subscriptions via `Stripe::Subscription.list`, then rejects any whose first item's price lookup_key contains the substring `'credit'` or `'plato'`. Every credit-pack lookup_key in `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` matches at least one of these substrings (verified in step 22).

The effect: `sync_with_stripe` will NEVER select a credit-pack subscription as the "current" main-plan subscription. It will never write a credit-pack lookup_key into `organizations.plan`. It will never update `organizations.stripe_subscription_id` to a credit-pack subscription's ID. Credit-pack subscriptions are invisible to the main-plan sync.

The guard at `:149` (`object.id == organization&.stripe_subscription_id`) provides a SECOND layer of protection: even if `sync_with_stripe` were not called, the analog branch only runs when the event's subscription ID matches the org's main-plan subscription ID. A credit-pack subscription ID would never match because it is stored on `organization_ai_credit_purchases.stripe_subscription_id`, not on `organizations.stripe_subscription_id`.

---
