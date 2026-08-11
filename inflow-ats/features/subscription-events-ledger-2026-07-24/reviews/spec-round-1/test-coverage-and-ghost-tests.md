# Angle 7 — Test coverage and ghost tests (spec round 1)

Verified against `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` (exists at a0d59115d), `config/environments/test.rb` context per pipeline rule 31, SPEC §9.

## Verifications (clean)

- §4 predicate coverage REQUIRED and specified: §9.1 mandates the full matrix (`amount_paid` 0/positive × `trial_end` present/absent with `Stripe::Subscription.retrieve` stubbed), duplicate delivery → exactly one row, and the load-bearing assertion that existing branch behavior (org update, payment-method call, `reset_ai_credits`) still occurs and survives a ledger failure. This satisfies the harness-profile exception.
- Analog is real and named: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` exists; constructed-event style (`Stripe::Event.retrieve` stub, `perform_now`) is the right template.
- Rule 31 handled: §9.3 explicitly requires the `:test` queue-adapter around-block because `:inline` is the suite default and would fire real Discord/PostHog paths.
- Ghost-test bar stated in-spec: §9.3 "No ghost tests (assertions must fail if the feature is deleted — BLOCKER otherwise)" — matches pipeline rule 26.
- Falsifiability spot-check of the specified assertions: every §9 requirement is behavioral (rows created, jobs enqueued, properties shaped, branch side effects preserved) — none is a reflection-on-enum tautology. The fan-out assertions fail if the callback is deleted; the predicate matrix fails if the predicate is deleted. No ghost-test shapes specified.
- Cypress untouched; commit procedure (detached, ≥20 min) covered by harness profile.

## Findings

- F1 [LOW] SPEC §9.3 / add the nil-`subscription_canceled_at` fan-out case once Angle 4 F1's amendment lands / The Discord-skip branch introduced by that amendment needs one behavioral assertion (row with nil `subscription_canceled_at` → no `Discord::NotifySubscriptionDeletedJob` enqueue, PostHog still enqueued) so the new guard is falsifiable. / Folded into the Angle 4 F1 amendment (§9.3 line added in the same edit); recorded here as LOW because it is part of that amendment, not an independent defect.
