# Investigation — Internal Discord/Slack Alerts (free trial + LinkedIn)

Non-authoritative reference. Branch: free-trial-and-linkedin-internal-alerts

## Existing internal-alert infrastructure (the pattern to copy)

- **Discord**: jobs under `app/jobs/discord/` post via `DiscordNotifierBot.new(channel_id:).send_message(content:, embed:)` (`app/services/discord_notifier_bot.rb`). Bot token from credentials. Rich embeds with `title`, `description`, `color`.
- **Slack**: jobs under `app/jobs/notification/` and `app/jobs/slack/` post via `Slack::Notifier.new(webhook_url, username: 'Polymer').ping(message)`.
- **Config**: `config/initializers/01_variables.rb`
  - Discord channels (lines 78–82): `DISCORD_SUBSCRIPTIONS_CHANNEL_ID`, `DISCORD_NEW_ORGANIZATIONS_CHANNEL_ID`, `DISCORD_DATA_ISSUES_CHANNEL_ID`, `DISCORD_NEW_PUBLISHED_JOBS_CHANNEL_ID`, `DISCORD_DAILY_SUMMARY_CHANNEL_ID`
  - Slack webhooks (lines 68–71): `SLACK_SUBSCRIPTIONS_WEBHOOK`, `SLACK_BILLING_WEBHOOK`, `SLACK_NEW_PUBLISHED_JOBS_WEBHOOK`, `SLACK_3RD_PARTY_PURCHASES_WEBHOOK`
- **Embed color conventions in use**: `0x3498db` blue (regular), `0x00ff00` green (free→paid conversion), `0xFFA500` orange (downgrade), `0xff0000` red (failure).
- **Template to copy**: `app/jobs/discord/notify_subscription_plan_changed_job.rb` and `app/jobs/notification/subscription_plan_changed_job.rb` — both take `(organization_id, previous_plan, current_plan)` and branch on `free_to_paid_conversion?`.

## Free trial model (current, post reinstate-free-trial)

- `plan` enum on Organization (`app/models/organization.rb` ~84): includes `plan_no_plan` (101), `plan_simple_ats_free` (10/default-ish), `plan_ats_tier_free_v2` (40, DEFAULT_FREE_PLAN), `plan_ats_tier_starter_v2` (41), `plan_ats_tier_growth_v2` (42), `plan_ats_tier_scale_v2` (43), `plan_ats_tier_enterprise` (1000).
- **No app-level trial column.** Trial is a Stripe concept. `stripe_subscription_status` ∈ {nil, 'trialing', 'active', 'past_due', 'unpaid', 'incomplete', 'canceled'}.
- **Signup flow**: new org → `set_default_plan` sets `plan_simple_ats_free`, NO Stripe subscription. The trial begins later.
- **Trial start**: `app/controllers/api/v1/billing_controller.rb:93` — checkout session sets `trial_period_days: stripe_subscription_status.present? ? nil : TRIAL_PERIOD_DAYS`. So a first-time org choosing a PAID plan at checkout starts a 14-day trial: subscription created with `status = 'trialing'`, `plan` = chosen paid tier. Org gets `stripe_subscription_status: nil → 'trialing'` and `plan: plan_simple_ats_free → plan_ats_tier_*_v2` via `sync_with_stripe`.
- **Conversion to paid**: after 14 days Stripe charges → `stripe_subscription_status: 'trialing' → 'active'`. **Plan does NOT change** (already the paid tier during trial).

## Where each event is detectable (Organization after_commit on :update)

`handle_after_commit_on_update` (line 883) calls `handle_subscription_status_change_after_commit`, `handle_plan_change_after_commit`, `handle_name_change_after_commit`.

1. **Free trial signup**: `stripe_subscription_status` nil/canceled/incomplete → `'trialing'`. Detectable in `handle_subscription_status_change_after_commit`. Currently `subscription_became_active_after_commit?` (line 974) covers nil→trialing/active but only logs "No longer sending subscription created notifications" (line 957–959). This is the dead spot where the new trial-signup alert belongs.
2. **Trial → paid conversion**: `previous_status == 'trialing' && current_status == 'active'`. **No handler exists today.** Plan unchanged, so existing `SubscriptionPlanChangedJob` does NOT fire (and line 916 suppresses plan-change alerts when status also changed). Confirms user's note that the old free→paid alert "will no longer be applicable."
3. **LinkedIn Company ID save/change**: `saved_changes.key?('linkedin_company_id')`. No handler in `handle_after_commit_on_update` today. Column `organizations.linkedin_company_id` (bigint, nullable, unique). Set via user self-serve `PUT /api/v1/organizations/:id` (`organization_params` permits `:linkedin_company_id`). `before_update` already bumps `linkedin_basic_jobs_changed_at` when it changes (line ~876). On-free-trial detection for priority: `stripe_subscription_status == 'trialing'`.

## Old free→paid alert (existing, now stale for trials)
`free_to_paid_conversion?(prev, cur)` in both plan-changed jobs = prev plan includes 'free' AND cur plan does not, AND cur != plan_no_plan. Fires only on a plan-attribute change with no concurrent status change. Trial conversions are status changes with no plan change, so this never fires for them.

## SubscriptionEvent (analytics, separate from alerts)
`app/models/subscription_event.rb` enum: assigned_free_plan_on_creation, assigned_free_plan, converted_to_paid, canceled_subscription, downgraded_to_free, upgraded_plan, downgraded_plan. Created via `CreateSubscriptionEvent` interactor (5-min dup guard). `log_assigned_free_plan_event` (line 1012) only logs assigned_free_plan(_on_creation). `converted_to_paid` is defined but its creation site was not located — verify before relying on it.
