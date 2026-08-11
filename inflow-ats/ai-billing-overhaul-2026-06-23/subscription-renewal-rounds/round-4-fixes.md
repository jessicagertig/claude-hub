# Round 4 Fixes — Subscription Renewal Analog Audit

## Deviation 1: Notification-flag reset write mechanism + uncaptured/unchecked return value — FIXED

**File:** `app/interactors/apply_ai_credit_purchase.rb:74-78` (in `apply_subscription`).

**Analog:** `reset_ai_credits.rb:65-73` — `updated = balance.update(...)` uses `.update` (validations + callbacks fire), captures the return value, and on failure calls `fail_with_record_invalid('balance period update', balance.errors) unless updated` (logs + `context.fail!`).

**Before (OURS):**
```ruby
balance.update_columns(
  sent_low_notification_since_increase: false,
  sent_zero_notification_since_increase: false
)
```
`update_columns` skips validations/callbacks; the return value was neither captured nor checked, so a failed write was silently swallowed — no log, no `context.fail!`, no transaction rollback.

**After (matches analog structure):**
```ruby
updated = balance.update(
  sent_low_notification_since_increase: false,
  sent_zero_notification_since_increase: false
)
fail_with_record_invalid('balance notification flag reset', balance.errors) unless updated
```
Now uses `.update` (validations + callbacks fire), captures the return value into `updated`, and on failure routes through the existing `fail_with_record_invalid` choke-point (which logs and calls `context.fail!`) — the same error-handling parity the analog has at `reset_ai_credits.rb:73`.

**Why FIXABLE, not whitelisted:** This is a pure error-handling-parity gap, not a product/data-model difference. The set of columns being cleared (`sent_low_notification_since_increase`, `sent_zero_notification_since_increase`) is unchanged and is the only thing sanctioned #2 covers. The write mechanism (`update_columns` vs `update`) and the dropped failure check were never sanctioned. Matching the analog here costs nothing and closes a silent-failure hole.

## Whitelist additions

None. The single deviation was FIXABLE and fixed.
