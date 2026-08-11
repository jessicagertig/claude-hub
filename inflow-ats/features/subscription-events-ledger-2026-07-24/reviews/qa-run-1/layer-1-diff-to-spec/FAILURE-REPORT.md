# QA run 1 — Layer 1 FAILURE REPORT

**One HIGH finding. Fix scope: one spec file, ~3 lines. Nothing else.**

## l1-a2-001 (HIGH) — Ledger-failure isolation test omits the reset_ai_credits assertion

- **Spec requirement (SPEC §9.1):** existing branch behavior byte-identical around the insertions — "the org update, payment-method call, `reset_ai_credits` still happen; a ledger failure does not break them."
- **Evidence:** `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb:131-140` — the example that makes `CreateSubscriptionEvent.call` raise asserts the org period-end update and `stripe_update_default_payment_method` survive, but omits the `organization_ai_credit_balance` `reset_ai_credits` assertion. The success-path example at lines 121-128 asserts all three behaviors.
- **Required fix (MINIMUM change):** add the `reset_ai_credits` assertion to the ledger-failure example, mirroring how the success-path example (lines 121-128) asserts it. Approximately 3 lines in this one spec file.

## Hard constraints on the fix agent

- Change ONLY `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb`. NOTHING beyond this finding (pipeline rules 10/23).
- `app/jobs/stripe_webhook_handler_job.rb` two-hunk invariant is INVIOLABLE — do not touch that file.
- Never stage `db/schema.rb` (unstaged corruption stays unstaged).
- Commit local only, never push. Detached commit procedure (pre-commit runs full Cypress ~10-20 min; nohup-detached, never under a killable timeout).
