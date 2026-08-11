# Plan: rename the conversion events

Branch: `attribution-work-qa`. One commit, alongside the Slack change.

## The change

Add two enum values to `SubscriptionEvent#event_type`:

- `converted_to_paid_subscription: 10`
- `trial_converted_to_paid_subscription: 11`

Add a short comment above the original two, `converted_to_paid: 3` and
`trial_converted_to_paid: 9`: only applies to events retroactively created and added to PostHog.

Then point every write and branch at the new names.

## Sites to edit

**app/models/subscription_event.rb**
- line 9 — `converted_to_paid: 3`, add the comment
- line 15 — `trial_converted_to_paid: 9`, add the comment, add the two new values after it
- line 43 — `when 'trial_converted_to_paid'` → new name
- line 46 — `when 'converted_to_paid'` → new name

**app/interactors/create_subscription_event_from_stripe.rb**
- line 107 — subscription-update invoice branch → new name
- line 133 — subscription-create invoice branch → new name
- line 159 — subscription-cycle invoice, the trial conversion → new name

**app/models/organization.rb**
- line 1138 — comment out the Slack `Notification::TrialConvertedToPaidJob` call, keep the
  surrounding branch and its log line

## Left alone deliberately

- `app/models/organization.rb` lines 1136 and 1197 — `trial_converted_to_paid_after_commit?` is a
  method about the `stripe_subscription_status` column, not the enum
- `db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb` — already
  run; its references record what it created

## Not needed

No schema migration. No spec changes — there are none referencing these event types.

## Verification

Site list is from a repo-wide grep. A six-agent sweep plus a completeness critic is still running;
if it surfaces anything not listed above, I'll add it before touching a file.
