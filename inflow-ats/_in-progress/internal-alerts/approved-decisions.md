# Approved Decisions — Internal Discord/Slack Alerts (free trial + LinkedIn)

## 1. Event #1 "free trial signup" — trigger point

Add a named predicate helper `subscription_started_trial_after_commit?` to `Organization`, matching the existing `subscription_became_active_after_commit?` / `subscription_became_past_due_after_commit?` / `subscription_became_canceled_after_commit?` convention. It guards on `saved_changes.key?('stripe_subscription_status')`, reads `previous_status, current_status = saved_changes['stripe_subscription_status']`, and returns true only when `previous_status.nil? && current_status == 'trialing'` (was nil, now trialing). Inside `handle_subscription_status_change_after_commit`, dispatch the free-trial-signup Slack and Discord alert jobs when `subscription_started_trial_after_commit?` is true. This is distinct from the existing account-creation alerts (`NotifyNewOrganizationJob` / `Discord::NotifyNewOrganizationJob`). The alert reports the paid tier chosen at checkout (the new `plan` value, e.g. `plan_ats_tier_starter_v2`).

## 2. Event #2 "trial converts to paid" — trigger point

Add a named predicate helper `trial_converted_to_paid_after_commit?` to `Organization`, matching the same `subscription_became_*_after_commit?` convention. It guards on `saved_changes.key?('stripe_subscription_status')`, reads `previous_status, current_status = saved_changes['stripe_subscription_status']`, and returns true only when `previous_status == 'trialing' && current_status == 'active'`. Inside `handle_subscription_status_change_after_commit`, dispatch the trial-converted-to-paid Slack and Discord alert jobs when `trial_converted_to_paid_after_commit?` is true. Scoped strictly to this transition — deliberately excludes `'past_due' → 'active'` (already handled by `Notification::PastDueSubscriptionPaidJob` / `Discord::NotifyPastDueSubscriptionPaidJob`) and `'trialing' → 'past_due'`. The `plan` does not change across this transition, so the alert reports the current paid tier (`plan`).

## 3. Event #3 "LinkedIn Company ID saved or changed" — trigger point

Add a named predicate helper `linkedin_company_id_added_or_changed_after_commit?` to `Organization`. It guards on `saved_changes.key?('linkedin_company_id')`, reads `previous_value, current_value = saved_changes['linkedin_company_id']`, and returns true only when `current_value.present? && current_value != previous_value` — i.e. it fires on `nil → value` (added) and `value → different value` (changed), and does not fire on `value → nil` (cleared). Add a new handler method `handle_linkedin_company_id_change_after_commit` to `Organization`, called from `handle_after_commit_on_update` alongside `handle_subscription_status_change_after_commit`, `handle_plan_change_after_commit`, and `handle_name_change_after_commit`; it dispatches the LinkedIn Slack and Discord alert jobs when `linkedin_company_id_added_or_changed_after_commit?` is true. The clear path (`value → nil`) is intentionally excluded because `BadActorOrganizationTakeover` (`app/services/bad_actor_organization_takeover.rb`) zeroes the field during fraud remediation, which should not raise this alert.

## 4. Channels and webhooks

All three alerts (free-trial signup, trial-converts-to-paid, LinkedIn Company ID saved/changed) post to the existing subscriptions destinations: Discord channel `Variables::DISCORD_SUBSCRIPTIONS_CHANNEL_ID` and Slack webhook `Variables::SLACK_SUBSCRIPTIONS_WEBHOOK`. No new channels, webhooks, or `Variables` entries are added. A dedicated LinkedIn channel/webhook is deferred (not built now); the subscriptions channel is low-traffic enough to absorb the LinkedIn alerts for the time being.

## 5. LinkedIn alert — colors, titles, and emoji placement

The LinkedIn Company ID alert detects "on a free trial" by `organization.stripe_subscription_status == 'trialing'` at the moment of the change, and distinguishes **added** (`nil → value`) from **changed** (`value → different value`). All four cases fire; no "HIGH PRIORITY" text anywhere. Each title below is used as both the Discord embed `title` and the lead of the Slack message:

| Case | Embed color | Title |
|---|---|---|
| Trial + added | deep pink `0xFF1493` | `🦄 LinkedIn Company ID added on free trial 🔮` |
| Trial + changed | deep pink `0xFF1493` | `👾 LinkedIn Company ID changed on free trial 🔮` |
| Non-trial + added | teal `0x1ABC9C` | `💎 LinkedIn Company ID added` |
| Non-trial + changed | teal `0x1ABC9C` | `💎 LinkedIn Company ID changed` |

Trial cases (`stripe_subscription_status == 'trialing'`) place a leading emoji at the start and 🔮 at the end; non-trial cases (any other `stripe_subscription_status`: `'active'`, `'past_due'`, `'unpaid'`, `'incomplete'`, `'canceled'`, `nil`) use a single leading 💎 with no trailing emoji.

## 6. Free-trial signup alert (event #1) — color and title

The free-trial-signup alert uses Discord embed color pure yellow `0xFFFF00` (chosen to read as clearly distinct from the existing orange `0xFFA500`). The title `🌱 New Free Trial Started 🌟` is used as both the Discord embed `title` and the lead of the Slack message.

## 7. Trial-converts-to-paid alert (event #2) — color and title

The trial-converts-to-paid alert uses Discord embed color bright green `0x00ff00` — the same green as the existing legacy free→paid conversion alert (`Discord::NotifySubscriptionPlanChangedJob`), since it represents the same kind of event. The title `Trial Converted to Paid! 🎉🚀` (exclamation point, then party-popper, then rocket, both emojis at the end) is used as both the Discord embed `title` and the lead of the Slack message.

## 8. Alert body content (all three alerts)

All three alerts (free-trial signup, trial-converts-to-paid, LinkedIn added/changed) carry the same body fields. The Discord embed `description` is modeled on the existing `Discord::NotifySubscriptionPlanChangedJob` "-- Organization Info --" layout; the Slack message is plain text via `Slack::Notifier#ping` (no attachments or blocks — nothing special for Slack), leading with the alert's title line then the same fields. Fields:

- Organization name and `id` (the `id` serves as the rough age indicator — no separate signup date)
- Plan display name (via the same `get_plan_display_name` mapping used by the existing subscription jobs)
- Owner `full_name`
- Owner `email`
- Careers page URL (`careers_page_url`)
- Published jobs count (`published_jobs_count`; print the number, including `0`)
- LinkedIn company page link `https://www.linkedin.com/company/<linkedin_company_id>` — included only when `linkedin_company_id` is present (always present in the LinkedIn alert; included in the signup and conversion alerts only when the org has one)

The existing legacy free→paid alert (the `free_to_paid_conversion?` branch in `Notification::SubscriptionPlanChangedJob` and `Discord::NotifySubscriptionPlanChangedJob`) is left untouched — it still covers grandfathered free-plan plan-attribute conversions.
