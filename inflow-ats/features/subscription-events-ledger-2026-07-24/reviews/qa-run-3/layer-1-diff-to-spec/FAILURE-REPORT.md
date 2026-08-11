# QA run 3 — Layer 1 FAILURE REPORT

**Two HIGH findings, both in `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb`. Fix scope: that one spec file only. Nothing else.**

## r3-l1-a4-001 (HIGH) — duplicate-delivery example vacuous w.r.t. the uniqueness invariant

- **Evidence:** the 'creates exactly one row across duplicate deliveries' example (~line 111) performs both deliveries within the interactor's 5-minute dedupe window with byte-identical `event_params`. With `conversion_duplicate_exists?` and the partial unique index BOTH deleted, the pre-existing dedupe still blocks the second row — every assertion passes. Production redeliveries >5 minutes apart are enforced ONLY by the §3 invariant, which this example therefore never exercises.
- **Required fix (minimum):** between the two deliveries, backdate the first created row's `created_at` beyond 5 minutes — e.g. `SubscriptionEvent.last.update_column(:created_at, 10.minutes.ago)` (update_column: no callbacks, no fan-out re-fire) — so the second delivery is outside the dedupe window and the invariant is the enforcing mechanism. Keep all existing assertions.

## r3-l1-a9-001 (HIGH) — ledger-failure example cannot distinguish the insertion's own rescue from the outer tier; raising stub never asserted

- **Evidence:** in the 'does not break the existing branch behavior when the ledger write raises' example, `not_to raise_error` is satisfied by the branch's pre-existing outer `rescue StandardError` log-and-swallow tier (stripe_webhook_handler_job.rb ~336-346) even if the insertion's own `begin/rescue` is deleted; the three existing-behavior assertions all precede the insertion point; and the raising `CreateSubscriptionEvent` stub has no `have_received(:call)` assertion, so deleting the ENTIRE insertion also passes.
- **Required fix (minimum):** in that example add (a) `expect(CreateSubscriptionEvent).to have_received(:call)` and (b) a `Rails.logger` spy (`allow(Rails.logger).to receive(:error).and_call_original` in setup) asserting `have_received(:error)` with the insertion's OWN ledger-error message (read the exact message text from the committed §5.2 block in `app/jobs/stripe_webhook_handler_job.rb` and match it precisely — this proves the insertion's rescue handled the failure, not the outer tier, whose message differs). Do not restructure the example.

## Hard constraints on the fix agent

- Change ONLY `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb`. NOTHING beyond these two findings (pipeline rules 10/23).
- `app/jobs/stripe_webhook_handler_job.rb` two-hunk invariant is INVIOLABLE — do not touch that file.
- Never stage `db/schema.rb` (unstaged corruption stays unstaged).
- Commit local only, never push. Detached commit procedure (pre-commit runs full Cypress ~10-20 min; nohup-detached, never under a killable timeout, immediate retry on kill).
