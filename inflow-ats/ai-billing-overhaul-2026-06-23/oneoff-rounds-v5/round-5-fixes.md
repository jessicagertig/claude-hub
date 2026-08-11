# Round 5 Fixes — AI Credit One-Off Purchase Analog Audit

Audit reported 2 deviations. 1 fixed in code, 1 confirmed CANNOT-MATCH (already whitelisted; re-confirmed).

---

## Deviation 1 — `grant_credits` extra pre-delivery blank-companion guard (FIXED)

**File:** `app/models/organization_ai_credit_purchase.rb` — `grant_credits` (was line 207-208).

**Before:**
```ruby
balance = organization.organization_ai_credit_balance
return if balance.blank?

ai_credit_balance_transaction = AiCreditBalanceTransaction.new(
  organization_ai_credit_balance: balance,
  ...
```

**After:**
```ruby
balance = organization.organization_ai_credit_balance

ai_credit_balance_transaction = AiCreditBalanceTransaction.new(
  organization_ai_credit_balance: balance,
  ...
```

**Intent / analog match:** The analog `BoardWwrListing#create_on_wwr` (`board_wwr_listing.rb:173-200`) has ONLY the produce-once guard (`unless wwr_listing_id.blank?`) before delivering the product (`client.create_listing(job_listing)`). It fetches no companion record and has no blank-companion early-exit guard. OURS had an extra `return if balance.blank?` early-exit that the analog has no parallel for, and that is NOT covered by SANCTIONED-DEVIATIONS #9 (which sanctions only the `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)` flag-reset write, not a blank-balance guard).

Removed the `return if balance.blank?` early-exit. The `balance` fetch itself is retained — it is the delivery target (the `AiCreditBalanceTransaction.new(organization_ai_credit_balance: balance, ...)` grant is the credit-delivery mechanism, parallel to WWR's `client.create_listing`). `grant_credits` now matches the analog's structure: produce-once guard → deliver → completion tail, with the method's existing `rescue StandardError` catching any failure (mirroring `create_on_wwr`'s own `rescue StandardError`). If `balance` is ever nil, the `.save!` raises and is caught by the rescue — identical to how the analog's `client.create_listing` failure is caught.

No frontend change required (backend-only model method; no response key changed).

---

## Deviation 2 — `broadcast_event` channel/target/key differs from analog (CANNOT-MATCH; already whitelisted as W4)

**File:** `app/models/organization_ai_credit_purchase.rb` — `broadcast_event` (line 245-247).

**Current (unchanged):**
```ruby
GlobalChannel.broadcast_to(last_updated_by_organization_user_id.nil? ? organization.owner : last_updated_by_organization_user.user, action: event, payload: { organizationId: organization_id })
```

**Analog:** `BoardWwrListing#broadcast_event` (`board_wwr_listing.rb:267-269`):
```ruby
JobChannel.broadcast_to(job, event: event, payload: { jobId: job.id, boardWwrListingId: id, wwrSlug: wwr_slug, publishedAt: published_at })
```

**CANNOT-MATCH:** broadcast_event channel/target/key/payload: the analog's literal `JobChannel.broadcast_to(job, event:, ...)` cannot be replicated because:
- `JobChannel#subscribed` (`app/channels/job_channel.rb`) does `Job.find(params[:jobId]); stream_for job` — it can ONLY stream to a `Job`. The AI credit one-off purchase is org-scoped and has no `Job` (SANCTIONED #7: "No `job` association").
- The AI-credit frontend (`WebsocketGlobalChannelHandler.tsx`, mounted app-wide) subscribes to `GlobalChannel` (`stream_for current_user`), NEVER to any `JobChannel` (`WebsocketJobChannelHandler` is mounted only inside `JobContainer` with a `jobId`). Broadcasting on `JobChannel` would reach no consumer on the billing settings page.
- `GlobalChannel`'s `handleGlobalMessage` (`WebsocketGlobalChannelHandler.tsx:61`) guards on `data.action != null` and switches on `data.action`. The `event:`→`action:` key change is the consumer's payload contract, not a free choice — the sibling `broadcast_show_growl` on the same record uses the identical `GlobalChannel ... action:` form, and the frontend already consumes `action: "AI_CREDIT_TOP_UP_COMPLETE"` → `invalidateQueries(["organizationAiCreditBalance"])` (`WebsocketGlobalChannelHandler.tsx:212-214`).
- The analog's payload keys `wwrSlug`/`publishedAt` are WWR-listing columns OURS does not have.

The current code is already the closest possible match (a WebSocket data signal from the completion tail that refreshes the frontend, targeting the channel the consumer subscribes to, using that channel's key contract). No code change made.

This deviation was already documented as **W4** in `SUGGESTED-WHITELISTS.md` from prior rounds. Round 5 re-verified the position against live code and appended a round-5 confirmation note to W4. Position UNCHANGED.

---

## SUGGESTED-WHITELISTS additions

No new whitelist entries created (the broadcast deviation is already W4). Appended a round-5 re-confirmation note to the existing **W4** entry in `SUGGESTED-WHITELISTS.md` documenting the re-verification.

## Files changed

- `app/models/organization_ai_credit_purchase.rb` — removed `return if balance.blank?` early-exit guard in `grant_credits` (Deviation 1).
- `SUGGESTED-WHITELISTS.md` (scratchpad) — appended round-5 note to W4 (Deviation 2 re-confirmation).
