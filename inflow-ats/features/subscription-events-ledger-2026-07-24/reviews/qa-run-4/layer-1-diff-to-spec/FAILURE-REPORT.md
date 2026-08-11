# QA run 4 — Layer 1 FAILURE REPORT

**Nine HIGH findings to fix (a tenth, r4-l1-a9-005, is consolidated into r4-l1-a9-002). ALL fixes are test-only, confined to the four existing new spec files. NO app code changes. NO new files.**

Full evidence: `reviews/qa-run-4/layer-1-diff-to-spec/round-1/consolidated.json` and the per-agent JSONs (agent-9.json carries the 55-row mechanism matrix).

## Fixes by file

### spec/jobs/stripe_webhook_handler_subscription_events_spec.rb
1. **r4-l1-a3-001** — nil-org example: add `allow(Rails.logger).to receive(:error).and_call_original` in setup and `expect(Rails.logger).not_to have_received(:error).with(<the §5.3 insertion's subscription.deleted ledger-error message matcher>)` — read the exact message from the committed webhook file's §5.3 block and use the same distinguishing-regex approach 549039a0c used for invoice.paid.
2. **r4-l1-a9-002** (also closes a9-005) — add a subscription.deleted ledger-failure example mirroring the invoice.paid one: `CreateSubscriptionEvent` stubbed to raise; assert both job enqueues + `subscription_canceled_at` write + `sync_with_stripe` still happen; `expect(CreateSubscriptionEvent).to have_received(:call)`; logger spy asserting the §5.3 block's own ledger-error message fired.
3. **r4-l1-a9-004** — pin the `stripe_subscription_id` argument SOURCE: (a) in one invoice.paid matrix example, set the event's `subscription` field to a value DIFFERENT from `organization.stripe_subscription_id` (keep the `Stripe::Subscription.retrieve` stub keyed to the event value) and assert the created row's `stripe_subscription_id` equals the event-sourced value; (b) add a subscription.deleted stale-subscription example — event object `id` different from `organization.stripe_subscription_id` — asserting the row records the EVENT id and `sync_with_stripe` is NOT called (the branch's equality condition fails).
4. **r4-l1-a7-001** — add an example that performs `Notification::PaidSubscriptionDeletedJob` directly (`:test` queue adapter active; stub the job's Slack posting dependency — read the job to find it, e.g. the `slack` method's notifier — so nothing real fires) and asserts `Discord::NotifySubscriptionDeletedJob` is NOT enqueued by it. This pins the §2 removal against restoration (production would double-notify).

### spec/interactors/create_subscription_event_spec.rb
5. **r4-l1-a5-001** — in the two check-first guard examples: logger spy + `expect(Rails.logger).not_to have_received(:error).with(<the RecordNotUnique rescue's message matcher>)` — pins the check-first guard as the acting layer (its deletion would route through the backstop, whose log line is its only distinct observable).
6. **r4-l1-a9-003** — one example asserting the exact full enum mapping: `expect(SubscriptionEvent.event_types).to eq('assigned_free_plan_on_creation' => 0, 'assigned_free_plan' => 1, 'converted_to_paid' => 2, 'canceled_subscription' => 3, 'downgraded_to_free' => 4, 'upgraded_plan' => 5, 'downgraded_plan' => 6, 'trial_started' => 7, 'trial_converted_to_paid' => 8)` (verify names/values against the committed model, do not trust this report). Place it in whichever of the two model-adjacent spec files fits the file's existing describe structure best (interactor spec or fanout spec) — one location only.

### spec/models/subscription_event_fanout_spec.rb
7. **r4-l1-a6-001** — add an example: create a row (any fan-out type), `clear_enqueued_jobs`, then `update!` some attribute and `destroy!` the row; assert zero jobs enqueued. Pins `on: :create`.
8. **r4-l1-a6-002** — extend the attribution example(s): populate ALL 13 attribution columns — owner columns with distinct values, organization columns with different distinct values, at least one field nil on owner + set on org (fallback pin) and one set on both (owner-wins pin) — and assert every one of the 13 payload keys carries the expected source's value.

### spec/models/organization_subscription_events_spec.rb
9. **r4-l1-a9-001** — in the nil→'trialing' example: stub + `have_received(:reset_ai_credits)` on the organization's `organization_ai_credit_balance`, mirroring the webhook spec's pattern from 7574df408.

## Hard constraints on the fix agent

- Change ONLY the four spec files listed. NOTHING beyond these findings (pipeline rules 10/23). No app code. No new spec files. No spec/support changes.
- `app/jobs/stripe_webhook_handler_job.rb` two-hunk invariant is INVIOLABLE — READ it for log-message text; never edit it.
- Never stage `db/schema.rb` (unstaged corruption stays unstaged).
- Run all four spec files green before committing: `RAILS_ENV=test bundle exec rspec spec/jobs/stripe_webhook_handler_subscription_events_spec.rb spec/interactors/create_subscription_event_spec.rb spec/models/subscription_event_fanout_spec.rb spec/models/organization_subscription_events_spec.rb`
- Commit local only, never push. Detached commit (pre-commit runs full Cypress ~10-20 min; nohup-detached, never under a killable timeout, immediate retry on kill). Poll for landing INLINE in your own turns (git log + hook log every ~60-90s) — do NOT arm Monitor watchers.
