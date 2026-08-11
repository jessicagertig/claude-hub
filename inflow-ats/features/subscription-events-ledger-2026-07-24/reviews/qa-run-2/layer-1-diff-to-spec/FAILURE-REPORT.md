# QA run 2 — Layer 1 FAILURE REPORT

**One HIGH finding. Fix scope: one spec file, ~1 assertion line. Nothing else.**

## r2-l1-a3-001 (HIGH) — subscription.deleted example stubs sync_with_stripe but never asserts it

- **Spec requirement (SPEC §9.1):** existing branch behavior byte-identical around the insertions (load-bearing). The `customer.subscription.deleted` main branch's existing effects must still be verified to happen.
- **Evidence:** `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb:161` — `allow(organization).to receive(:sync_with_stripe)` with no `have_received(:sync_with_stripe)` anywhere in the file. Deleting `organization&.sync_with_stripe if stripe_subscription_id == organization&.stripe_subscription_id` from the branch would pass the entire suite. The branch's other three existing effects (two job enqueues, `subscription_canceled_at` write) are asserted.
- **Validated by:** agent 9 (tests-vs-spec), which also swept every `allow(...)` stub in all four new spec files and confirmed this is the ONLY stubbed-but-never-asserted existing behavior.
- **Required fix (MINIMUM change):** add one `expect(organization).to have_received(:sync_with_stripe)` assertion to the subscription.deleted example (the one that stubs it at ~line 161), matching the file's existing `have_received` assertion style (see the `stripe_update_default_payment_method` / `reset_ai_credits` assertions at ~127-128/141-142). Nothing else.

## Hard constraints on the fix agent

- Change ONLY `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb`. NOTHING beyond this finding (pipeline rules 10/23).
- `app/jobs/stripe_webhook_handler_job.rb` two-hunk invariant is INVIOLABLE — do not touch that file.
- Never stage `db/schema.rb` (unstaged corruption stays unstaged).
- Commit local only, never push. Detached commit procedure (pre-commit runs full Cypress ~10-20 min; nohup-detached, never under a killable timeout, immediate retry on kill).
