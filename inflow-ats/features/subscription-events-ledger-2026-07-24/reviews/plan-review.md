# PLAN REVIEW — subscription-events-ledger (Phase 4, single pass per harness profile)

## VERDICT: APPROVED

**The amended `plan.md` in this directory is canonical.** Three MED findings were amended inline during this pass; zero BLOCKER, zero HIGH, no D-ruling contradictions, no unaddressed MEDs. Findings files: `reviews/plan-review/pass-1/` (one per REVIEW-ANGLES angle + the always-on compliance sweep).

Fact-check basis: every file:line anchor in the plan was verified against the live tree at `attribution-work-qa` @ `a0d59115d` (branch and HEAD confirmed; working tree clean except the known unstaged `db/schema.rb` corruption).

## Per-angle summary

| Angle (findings file) | BLOCKER | HIGH | MED | LOW (note-only) |
|---|---|---|---|---|
| 1 Webhook-delicacy audit (`webhook-delicacy-audit.md`) | 0 | 0 | 0 | 0 |
| 2 Conversion-predicate correctness (`conversion-predicate-correctness.md`) | 0 | 0 | 0 | 0 |
| 3 Ledger integrity (`ledger-integrity.md`) | 0 | 0 | 0 | 1 |
| 4 Fan-out contract (`fan-out-contract.md`) | 0 | 0 | 1 (MED-2, amended) | 0 |
| 5 PostHog payload integrity (`posthog-payload-integrity.md`) | 0 | 0 | 1 (MED-3, amended) | 1 |
| 6 Behavior preservation (`behavior-preservation.md`) | 0 | 0 | 0 | 0 |
| 7 Test coverage and ghost tests (`test-coverage-and-ghost-tests.md`) | 0 | 0 | 1 (MED-1, amended) | 1 |
| Always-on compliance (`claude-md-compliance.md`) | 0 | 0 | 0 | 0 |

## Delicacy audit result (D11)

The plan's Tasks 7 and 8 specify EXACTLY the two sanctioned SPEC §5 insertions and nothing else in `app/jobs/stripe_webhook_handler_job.rb`. Both verbatim blocks verified line-by-line against the live branch structure: insertion 1 appends after line 297 inside the `invoice.paid` else-branch (288–298), insertion 2 appends after line 210 inside the `subscription.deleted` else-branch (204–211); each is additive with its own `begin/rescue StandardError` that logs with context and never re-raises, keeping the existing rescue tiers (299–309; 212–215) blind to ledger failures. Both justification tables account for every planned line. No other plan step touches the file (Task 9.1 is explicitly read-only for it). Tasks 8.3/10.1 enforce the exactly-two-hunks diff invariant.

## Amendments applied (verified by re-read + stale-reference sweep)

1. **MED-1 (rule 31):** Tasks 9.1 and 9.2 now explicitly require the `:test` queue-adapter around-block in their setup (9.3/9.4 already had it). 9.1 asserts job ENQUEUES (impossible under `:inline`) and, after Task 4, every `SubscriptionEvent` creation in 9.1/9.2 fires the fan-out — under the suite's `:inline` default, real Discord sends and `Notification::PaidSubscriptionDeletedJob`'s real Slack webhook would execute inside examples.
2. **MED-2 (source accuracy):** structural-manifest analog registration anchor corrected `organization.rb:58` → `organization.rb:59` (both occurrences).
3. **MED-3 (source accuracy):** organizations attribution-column citation completed — `google_click_id` lives at schema.rb:1081, outside the previously cited 1092–1103 range (the all-13-exist claim itself was true; users 1300–1312 was exact).

## Deliberately-left MEDs

None. (All three MEDs were amended.)

Deliberately-left LOWs, for the record: Task 3.3 places the uniqueness guard before the 5-minute dedupe where SPEC §6 only requires before-build (harmless strictness); track.rb citation "25–32" vs actual 24–31 (content claim accurate); 9.1's duplicate-delivery example is guard-vs-dedupe ambiguous but guard-specific falsifiability is carried by 9.2's cross-type examples.

## Notable verifications (clean)

- Both migration analogs exist live and match what the plan copies: `20260723222212_add_adroll_click_id_to_users.rb` (bare `add_column`), `20260408040501_create_organization_ai_credit_purchases.rb:25–29` (the `add_index unique:/where:/name:` partial-unique shape). Index name 48 chars; `IN (2, 8)` matches the planned enum; NULL-distinct semantics consistent with the §6 guard.
- §4 predicate encoding: amount guard spec-verbatim; trial_end from the branch's EXISTING `stripe_subscription` local (line 283) — no second retrieve, no status, no billing_reason; duplicate → graceful interactor no-op; positioned after the `CustomStripeSubscriptionMissingError` guard (289).
- Interactor guard-order fix preserves all existing behavior: sole production caller at organization.rb:1237 passes `organization: self`; `ap` lines still run for present organizations; 5-minute dedupe untouched; conditional param merge keeps `assigned_free_plan*` dedupe semantics identical.
- Fan-out: `assigned_free_plan*` rows enqueue NOTHING; `return unless organization&.owner` bail-out; Discord-deleted enqueue skipped when `subscription_canceled_at` absent (`.to_i` inside the `present?` guard — no 1970 fabrication); `attribution_value` is the D10 shape exactly (full if/elsif/else, `present?`, explicit nil else, no `.presence`). Three Discord enqueue sites grep-confirmed as the only ones; arities verified; Task 6 removal shape verified against the live job file.
- Completeness: every SPEC §9 item planned; nothing planned that §10 excludes; all §11 risks carried; §11.6 planned AS WRITTEN and left open for Jessica.
