# customer.subscription.deleted — Iota-for-Iota Structural Trace

Goal: an exact structural map of the ANALOG (main-plan `customer.subscription.deleted` handler) and what currently happens when a credit-pack subscription deletion fires through the same handler. No credit-pack branch exists yet. This trace documents (a) the analog line by line, (b) the current incorrect behavior for credit-pack deletions, and (c) what SHOULD exist to mirror the analog.

---

## Analog — full skeleton (main-plan `customer.subscription.deleted`)

Handler entry: `app/jobs/stripe_webhook_handler_job.rb:167`

Ordered identifier chain (Stripe event → org lookup → sync → column write → notification jobs):

1. `StripeWebhookHandlerJob#perform` — `app/jobs/stripe_webhook_handler_job.rb:14` → `Stripe::Event.retrieve(event_id)` (`:20`) → `handle_stripe_event(event)` (`:41`)
2. `handle_stripe_event` — `stripe_webhook_handler_job.rb:44` → `object = event.data.object` (`:48`) → `log_stripe_changes(event)` (`:50`) → `case event.type` (`:52`)
3. `when 'customer.subscription.deleted'` — `stripe_webhook_handler_job.rb:167`
4. `stripe_customer_id = object.customer` — `:170` (reads the Stripe Subscription object's `customer` field)
5. `stripe_subscription_id = object.id` — `:171` (the Stripe subscription id from the deleted subscription object)
6. `organization = Organization.find_by(stripe_customer_id: stripe_customer_id)` — `:172`
7. `Organization#stripe_customer_id` (column) — `db/schema.rb:1051`
8. `subscription_ended_at = object.ended_at` — `:173` (the Unix timestamp when Stripe ended the subscription)
9. `begin` block — `:174`
10. Debug logging — `:175-177` (`ap object`, `ap "Deleted At Time: ..."`, `ap "Subscription ID: ..."`)

### Guard: sync_with_stripe only for main-plan subscription

11. `organization&.sync_with_stripe if stripe_subscription_id == organization&.stripe_subscription_id` — `:179`
    - GUARD: `stripe_subscription_id == organization&.stripe_subscription_id` compares the deleted subscription's id (`object.id`) against the org's `stripe_subscription_id` column (`db/schema.rb:1052`). This guard is the ONLY thing preventing `sync_with_stripe` from firing on credit-pack deletion events.
    - `Organization#stripe_subscription_id` (column) — `db/schema.rb:1052` (the main-plan subscription id, NOT the credit-pack subscription id)

### sync_with_stripe — traced

12. `Organization#sync_with_stripe` — `app/models/organization.rb:520`
13. Guard: `return unless stripe_customer_id.present?` — `organization.rb:528`
14. Guard: `return if stripe_customer.respond_to?(:deleted)` — `organization.rb:530`
15. `Organization#stripe_customer` — `organization.rb:469` → `Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] })` (`:471`)
16. `Organization#stripe_customer_subscriptions` — `organization.rb:481` → `Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' })` (`:482`)
17. Subscription filtering (CRITICAL for credit-pack) — `organization.rb:539-542`:
    ```ruby
    plan_subscriptions = subscriptions.reject do |subscription|
      lookup_key = subscription.items&.data&.[](0)&.price&.lookup_key.to_s
      lookup_key.include?('credit') || lookup_key.include?('plato')
    end
    ```
    `lookup_key` is a block-local variable derived per-subscription from the first item's price lookup key. This **rejects** credit-pack subscriptions from the plan list.
18. `current_subscription` selection: trialing > active > first — `organization.rb:543-545`
19. Attributes built: `stripe_subscription_id`, `stripe_subscription_status`, `stripe_current_period_end_at` — `organization.rb:565-571`
20. `attributes['plan'] = assign_plan_name_from_lookup_key(...)` — `organization.rb:573`
21. `Organization#assign_plan_name_from_lookup_key` — `organization.rb:678` → `Stripe::SubscriptionStatusChecker.new(self).assign_plan_from_lookup_key(...)` (`:679`) → `app/services/stripe/subscription_status_checker.rb:113` → `PLAN_LOOKUP_MAPPING` substring match (`:16`)
22. `stripe_update_default_payment_method` conditional — `organization.rb:578`
23. `attributes['stripe_default_payment_method_on_file']` — `organization.rb:580`
24. Diff check (only update changed attrs): `organization.rb:583-609`
25. `update(changes_to_make)` — `organization.rb:600`
26. Credit allocation update on plan change: `PlanFeatureGate.new(self).monthly_ai_credit_allocation` → `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` — `organization.rb:603-606`

After sync_with_stripe, the Organization's `stripe_subscription_id` will be updated to whatever the current active/trialing main-plan subscription is (or the first if none active). If the org had ONLY the one main-plan subscription that was deleted, after Stripe deletion `stripe_customer_subscriptions` returns `[{status: 'canceled', ...}]` and `sync_with_stripe` updates the org's subscription status/plan accordingly.

### Post-sync actions (unconditional — no guard)

27. `organization&.update_column(:subscription_canceled_at, Time.at(subscription_ended_at).to_datetime)` — `:182`
    - `Organization#subscription_canceled_at` (column) — `db/schema.rb:1055`
    - Uses `update_column` (singular) — skips validations and callbacks, writes directly to DB
    - Writes `Time.at(subscription_ended_at).to_datetime` — converts the Stripe Unix timestamp to a Ruby DateTime
28. `Notification::PaidSubscriptionDeletedJob.perform_later(organization&.id, subscription_ended_at)` — `:183`
29. `EngagementReport::GeneratorJob.perform_later(organization&.id, trigger: 'subscription_canceled')` — `:184`

### Error handling

30. `rescue StandardError => e` — `:185`
31. `ap 'Stripe Webhook Error - subscription.deleted'` — `:186`
32. `Rails.logger.error e` — `:187`

### Notification::PaidSubscriptionDeletedJob — traced

33. `Notification::PaidSubscriptionDeletedJob#perform(organization_id, ended_at)` — `app/jobs/notification/paid_subscription_deleted_job.rb:6`
34. `Organization.find_by_id(organization_id)` — `:7`; guard `return unless @organization` — `:8`
35. `slack` — `:12` → `Slack::Notifier.new(Variables::SLACK_SUBSCRIPTIONS_WEBHOOK, username: 'Polymer')` → `.post(attachments: ...)` — `paid_subscription_deleted_job.rb:26-27`. Separate rescue inside `slack` method (`:28-31`): `Rails.logger.error e`, `Sentry.capture_exception(e)` (`:30`)
36. `discord(organization_id, ended_at)` — `:13` → `Discord::NotifySubscriptionDeletedJob.perform_later(organization_id, ended_at)` — `:22`
37. Slack block content: "Subscription Deleted", company name (+ id), plan name, owner name, email, job board URL, published jobs count, LinkedIn URL (conditional on `linkedin_company_id.present?`, `:52`) — `:33-53`
38. `get_plan_display_name(plan_value)` — `:56-79` (maps plan enum to display name; references Polymer Hire plan names, NO credit-pack names)
39. Error rescue: `StandardError` → `Rails.logger.error` — `:14-17`

### Discord::NotifySubscriptionDeletedJob — traced

40. `Discord::NotifySubscriptionDeletedJob#perform(organization_id, ended_at)` — `app/jobs/discord/notify_subscription_deleted_job.rb:7`
41. `Organization.find_by_id(organization_id)` — `:8`; guard `return unless @organization` — `:9`
42. `channel_id = Variables::DISCORD_SUBSCRIPTIONS_CHANNEL_ID` — `:11`
43. Plan name detection: checks `organization.plan` for `gemini`/`apollo`/`artemis` → 'Polymer Hire', `simple` → 'Polymer Legacy', else 'Unknown' — `:17-23`. NO credit-pack detection.
44. Embed: "Subscription Deleted", env, plan name, org name, org id, job board URL, owner name, email — `:25-40` (description array `:28-38`, `color: 0x3498db` at `:39`, hash closes at `:40`)
45. `DiscordNotifierBot.new(channel_id: channel_id).send_message(content: message_content, embed: embed)` — `:42`
46. Error rescue: `StandardError` → `Rails.logger.error` — `:43-46`

### EngagementReport::GeneratorJob — traced

47. `EngagementReport::GeneratorJob#perform(organization_id, trigger:, new_plan_lookup_key: nil)` — `app/jobs/engagement_report/generator_job.rb:6`
48. `Organization.find_by(id: organization_id)` — `:9`; guard `return` — `:12`
49. `EngagementReport::ReportGenerator.new(organization: organization, trigger: trigger, new_plan_lookup_key: new_plan_lookup_key).generate` — `:15-19`
50. `trigger:` param receives `'subscription_canceled'` — from the caller at `stripe_webhook_handler_job.rb:184`
51. `EngagementReport::ReportGenerator` — `app/services/engagement_report/report_generator.rb` (service; reads org subscription_canceled_at at `:78`)
52. Error rescue: `StandardError` → log + backtrace — `:22-26`

---

## What currently happens when a credit-pack subscription.deleted fires

A credit-pack subscription has its `stripe_subscription_id` stored on `organization_ai_credit_purchases.stripe_subscription_id` (`db/schema.rb:968`), NOT on `organizations.stripe_subscription_id` (`db/schema.rb:1052`). They are different columns on different tables.

When Stripe fires `customer.subscription.deleted` for a credit-pack subscription, the handler at `:167` processes it with ZERO credit-pack awareness. Walk through line by line:

1. `:170` — `stripe_customer_id = object.customer` — correct; the Stripe customer is the org's customer regardless of subscription type.
2. `:171` — `stripe_subscription_id = object.id` — this is the CREDIT-PACK subscription id (e.g., `sub_creditpack_xxx`).
3. `:172` — `organization = Organization.find_by(stripe_customer_id: stripe_customer_id)` — finds the org. Correct.
4. `:173` — `subscription_ended_at = object.ended_at` — correct.
5. `:179` — **GUARD**: `stripe_subscription_id == organization&.stripe_subscription_id` — compares the credit-pack subscription id (`sub_creditpack_xxx`) against the org's main-plan subscription id (`sub_mainplan_xxx`). These are DIFFERENT. **Guard evaluates FALSE. `sync_with_stripe` does NOT run.** This is CORRECT behavior — `sync_with_stripe` should not run for a credit-pack deletion because `sync_with_stripe` manages main-plan fields only.

6. `:182` — **BUG**: `organization&.update_column(:subscription_canceled_at, Time.at(subscription_ended_at).to_datetime)` — this writes the credit-pack subscription's `ended_at` timestamp to `organizations.subscription_canceled_at` (`db/schema.rb:1055`). This OVERWRITES the Organization's main-plan cancellation timestamp with the credit-pack's end time. If the org's main-plan subscription is still active, this column now incorrectly says the org canceled.

7. `:183` — **BUG**: `Notification::PaidSubscriptionDeletedJob.perform_later(organization&.id, subscription_ended_at)` — fires Slack + Discord notifications claiming "Subscription Deleted" with the org's main-plan name. The notification text reads as a main-plan cancellation. The `get_plan_display_name` and Discord's plan-name detection have NO credit-pack branch; they will display the current main plan name as the "deleted" plan, which is wrong and misleading.

8. `:184` — **BUG**: `EngagementReport::GeneratorJob.perform_later(organization&.id, trigger: 'subscription_canceled')` — fires an engagement report with trigger `subscription_canceled`, which reads `organization.subscription_canceled_at` (`:78` in `report_generator.rb`). Since `:182` just wrote the credit-pack's ended_at into that column, the report will contain the wrong timestamp and implies a main-plan cancellation happened.

**Summary of current credit-pack behavior**: `sync_with_stripe` is correctly guarded (does not fire). But the three unconditional post-sync actions (lines 182-184) ALL fire incorrectly for credit-pack subscriptions:
- `update_column(:subscription_canceled_at, ...)` writes credit-pack end time onto the Organization row (wrong table, wrong column, clobbers main-plan data)
- `Notification::PaidSubscriptionDeletedJob` sends misleading Slack/Discord notifications referencing the main plan
- `EngagementReport::GeneratorJob` generates a report as if the main-plan was canceled

The `OrganizationAiCreditPurchase` row is NOT updated at all. Its `subscription_status` stays at whatever it was (e.g., `active` or `canceled` if a prior `subscription.updated` event set it). Its `subscription_canceled_at` column (`db/schema.rb:979`) is never written by the webhook handler.

---

## What SHOULD exist — credit-pack branch for subscription.deleted

Mirroring the `customer.subscription.updated` handler's credit-pack branch (`:125-148`) and the analog's structure.

### Branch detection pattern (mirror of subscription.updated)

The `customer.subscription.updated` handler at `:125` uses:
```ruby
if OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(plan_lookup_key)
```
where `plan_lookup_key = object.items&.data&.first&.price&.lookup_key` (`:120`).

For `subscription.deleted`, the same detection applies: `object` is a Stripe Subscription, and `object.items&.data&.first&.price&.lookup_key` will be the credit-pack lookup key (e.g., `plato_ai_credit_subscription_small`).

### Required structure — credit-pack branch

The handler at `:167` needs a branching structure before the post-sync actions. Matching the `subscription.updated` pattern:

**Step 1: Read the lookup key** (mirrors `:120`)
- `plan_lookup_key = object.items&.data&.first&.price&.lookup_key` — read from the Stripe Subscription object, same as `subscription.updated` does.

**Step 2: Branch on credit-pack vs main-plan** (mirrors `:125` / `:149`)

```
if OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(plan_lookup_key)
  # credit-pack branch
else
  # main-plan branch (existing code, lines 179-184)
end
```

**Step 3: Credit-pack branch — find the purchase row** (mirrors `:130-133`)
- `purchase = OrganizationAiCreditPurchase.find_by(stripe_subscription_id: stripe_subscription_id, kind: :subscription)` — mirrors `subscription.updated` `:130-133` (which uses `object.id` directly; here we use the local `stripe_subscription_id` variable set at `:171` to `object.id`, matching the surrounding code's style). `kind: :subscription`.
- `OrganizationAiCreditPurchase.find_by` — `app/models/organization_ai_credit_purchase.rb` (AR query)
- `kind: :subscription` — `enum kind: { one_off: 0, subscription: 1 }` — `organization_ai_credit_purchase.rb:81`
- Guard: if `purchase` is nil, log error and return (mirrors `:146-148` error pattern: `Rails.logger.error "subscription.deleted credit-pack: no OrganizationAiCreditPurchase for stripe_subscription_id #{stripe_subscription_id}"`)

**Step 4: Update the purchase row** — the analog writes:

| Analog action (line) | What it writes | Credit-pack mirror |
|---|---|---|
| `sync_with_stripe` → `attributes['stripe_subscription_status'] = current_subscription&.status` (`organization.rb:569`), then `update(changes_to_make)` (`:600`) | `stripe_subscription_status` on Organization | `purchase.subscription_status` (enum, `organization_ai_credit_purchase.rb:82`) — should be set to `:canceled` (value `2`) |
| `organization&.update_column(:subscription_canceled_at, ...)` (`:182`) | `organizations.subscription_canceled_at` (`schema.rb:1055`) | `purchase.subscription_canceled_at` (`schema.rb:979`) — should be set to `Time.at(object.ended_at).to_datetime` |

Specifically, the purchase update:
```ruby
purchase.update(
  subscription_status: :canceled,
  subscription_canceled_at: Time.at(subscription_ended_at).to_datetime
)
```

Columns involved:
- `organization_ai_credit_purchases.subscription_status` — `db/schema.rb:978` (integer enum; `canceled: 2` at `organization_ai_credit_purchase.rb:82`)
- `organization_ai_credit_purchases.subscription_canceled_at` — `db/schema.rb:979` (datetime)

Note: `CancelAiCreditSubscription` (the in-app cancel interactor at `app/interactors/cancel_ai_credit_subscription.rb:35`) already writes these same two columns: `subscription_status: :canceled, subscription_canceled_at: Time.current`. The webhook handler is the Stripe-side confirmation that the subscription is truly deleted — it should reconcile the local row to the same state. If the user canceled via the app, `CancelAiCreditSubscription` already set these fields; the webhook sets them again idempotently. If the subscription was deleted via Stripe dashboard or non-payment, the webhook is the ONLY writer.

**Step 5: Notification — decision point**

The analog fires two notification jobs unconditionally:
- `Notification::PaidSubscriptionDeletedJob.perform_later(organization&.id, subscription_ended_at)` — Slack + Discord
- `EngagementReport::GeneratorJob.perform_later(organization&.id, trigger: 'subscription_canceled')` — engagement report

For the credit-pack branch, these jobs are main-plan-specific:
- `Notification::PaidSubscriptionDeletedJob` references the org's main `plan` field for display names (`get_plan_display_name`, `organization.plan`). It has NO credit-pack awareness.
- `Discord::NotifySubscriptionDeletedJob` checks `organization.plan` for `gemini`/`apollo`/`artemis`/`simple`. NO credit-pack names.
- `EngagementReport::GeneratorJob` reads `organization.subscription_canceled_at` (the org column, not the purchase column).

Options:
1. **Do not fire these jobs for credit-pack deletions.** The credit-pack is an add-on, not the primary subscription. The existing jobs are structurally tied to main-plan data.
2. **Create credit-pack-specific notification/reporting jobs.** This is new infrastructure beyond the analog mirror.
3. **Add credit-pack branches to the existing jobs.** This modifies shared infrastructure.

The MINIMUM analog mirror is option 1: the analog's notification jobs reference main-plan fields; firing them for credit-pack deletions produces wrong data (as documented in the "current behavior" section above). NOT firing them is the safe default. Adding credit-pack notifications is an EXTRA beyond the analog mirror and should be a separate product decision.

**Step 6: Main-plan branch — no changes**

The existing code at lines 179-184 becomes the `else` branch. No modifications needed. The guard at `:179` (`stripe_subscription_id == organization&.stripe_subscription_id`) stays as-is within the main-plan branch.

---
