# Approved Decisions — Notify when plan changes are scheduled

Branch: `notify-when-plan-changes-scheduled`
Working dir: `~/claude-hub/inflow-ats/_in-progress/notify-scheduled-plan-changes/`

---

## Decision 1 — What `stripe_cancel_at_period_end` means and which code writes it

**Current state:**
- The `customer.subscription.updated` handler at `stripe_webhook_handler_job.rb:112–115` updates only `stripe_current_period_end_at` and `stripe_subscription_status`. It ignores `object.cancel_at_period_end`.
- The downgrade handler at `stripe_webhook_handler_job.rb:294` writes `organization.update(stripe_cancel_at_period_end: true)`.
- `stripe_cancel_at_period_end` is therefore only ever `true` for scheduled downgrades, never for scheduled cancellations.

**Approved change:**
- Add `stripe_cancel_at_period_end: object.cancel_at_period_end` to the `organization.update(...)` call in the `customer.subscription.updated` handler, so the column takes Stripe's value directly — `true` when a cancellation is scheduled, `false` when one is reversed.
- Remove the `organization.update(stripe_cancel_at_period_end: true)` line at `stripe_webhook_handler_job.rb:294`, so a scheduled downgrade no longer writes this column.

**Resulting behavior:** `stripe_cancel_at_period_end` mirrors Stripe's `cancel_at_period_end` flag and nothing else. In the `GOOGLE_DOWNGRADE_SHEET_ID` sheet, the `stripe_cancel_at_period_end` cell on a downgrade row reads `false` instead of `true`. The downgrade Discord alert, sheet routing, and `cancellation` data block are unaffected.

---

## Decision 2 — Detecting a scheduled cancellation

There's already a method, `handle_linkedin_company_id_change_after_commit`, that watches a single column and sends a Slack alert plus a Discord alert. Copy that same shape here.

Add two methods to `organization.rb`:

- `subscription_cancellation_scheduled_after_commit?` — returns true when `stripe_cancel_at_period_end` flips from `false` to `true`. That flip is the moment a customer schedules a cancellation.
- `handle_cancellation_scheduled_after_commit` — when that flip happens, enqueues the Slack job (`Notification::CancellationScheduledJob`) and the Discord job (`Discord::NotifyCancellationScheduledJob`).

Then add the new handler to `handle_after_commit_on_update`, alongside the existing four.

It fires once, only when a cancellation is scheduled. If the customer reverses it later, nothing fires.

---

## Decision 3 — The two alert jobs

Build them as copies of jobs we already have:

- Slack — `Notification::CancellationScheduledJob`, modeled on `Notification::SubscriptionPlanChangedJob` (same Block Kit layout and org fields). Color red, `#FF0000`.
- Discord — `Discord::NotifyCancellationScheduledJob`, modeled on `Discord::NotifyDowngradeScheduledJob`. Color red, `0xFF0000`.

Both show the usual org details plus the date the cancellation takes effect (`stripe_current_period_end_at`), and the title "Cancellation Scheduled 🚨".

---

## Decision 4 — Engagement report on cancellation

Enqueue an `EngagementReport::GeneratorJob` when a cancellation is scheduled, the same way the downgrade path does.

Use a new trigger, `cancellation_scheduled` (a scheduled cancellation is not a completed `subscription_canceled`). In `report_generator.rb`: add `cancellation_scheduled` to `TRIGGERS`, route it to `GOOGLE_DOWNGRADE_SHEET_ID` in `determine_sheet_id`, and include it in `cancellation_trigger?`. Enqueue the job from `handle_cancellation_scheduled_after_commit`, alongside the two alert jobs.

## Decision 5 — Editing organization.rb

Editing `app/models/organization.rb` directly is approved for the two new methods and the `handle_after_commit_on_update` wiring.
