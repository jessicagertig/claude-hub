# Plan review pass 1 — Angle 1: Webhook-delicacy audit (D11)

Verified against live `app/jobs/stripe_webhook_handler_job.rb` at `attribution-work-qa` @ a0d59115d.

## Coordinate verification (all confirmed live)

| Plan claim | Live source | Verdict |
|---|---|---|
| `invoice.paid` else-branch currently 288–298 | `else` 288, `raise CustomStripeSubscriptionMissingError` 289, `organization.update(...)` 291, unless-block 292–295, `stripe_update_default_payment_method` 296, `reset_ai_credits` 297, `end` 298 | CORRECT |
| Insertion 1 position: after line 297, before 298 | confirmed | CORRECT |
| Three-tier rescue 299–309 (`Stripe::StripeError` / `RecordInvalid, RecordNotFound` / `StandardError`) | confirmed at 299/302/305 | CORRECT |
| `stripe_subscription` local retrieved at 283 (`Stripe::Subscription.retrieve(object.subscription)`) — in scope at insertion 1 | confirmed; insertion sits inside the same `begin` (238) / else (288) scope | CORRECT |
| `subscription.deleted` else-branch currently 204–211 | `else` 204, `sync_with_stripe` guard 205, `update_column(:subscription_canceled_at, ...)` 208, `Notification::PaidSubscriptionDeletedJob` 209, `EngagementReport::GeneratorJob` 210, `end` 211 | CORRECT |
| Insertion 2 position: after line 210, before 211 | confirmed | CORRECT |
| Single rescue 212–215 | confirmed | CORRECT |
| `Organization.find_by` miss possible at 174; surrounding lines use `organization&.` | confirmed (174; `organization&.` at 205, 208–210) | CORRECT |
| `stripe_subscription_id` local at 173 | confirmed | CORRECT |

## Sanctioned-insertion audit

- Task 7 block: additive only, own `begin/rescue StandardError => e` with contextual `Rails.logger.error` + `ap e`, never re-raises. Justification table covers every line (rescue frame, amount guard, `subscription_event_type` if/else, interactor call args). Indentation matches branch body (10 spaces). No other line in the file planned.
- Task 8 block: additive only, own `begin/rescue`, `if organization` guard justified verbatim from amended SPEC §5.3, interactor call args per spec. Justification table covers every line.
- Task 8.3 enforces the exactly-two-hunks invariant (`git diff` check) — the §11.5 Layer-1 delicacy property.
- Task 9.1 explicitly marks the file read-only for the test task.
- No plan step anywhere else touches this file. Task 10.1's diff audit re-asserts "EXACTLY two additive hunks — D11."
- `Interactor::Failure` cannot escape: `.call` (non-bang) swallows it; the own-rescue is defense in depth as the plan states.
- Nil-organization trap (angle brief): resolved both sides — `if organization` in insertion 2 AND the Task 3.1 interactor guard-order fix (live file confirms `ap organization.stripe_subscription_in_good_standing` at create_subscription_event.rb:12 runs before `return unless organization` at :13).

## Findings

None. The plan's Tasks 7 and 8 specify exactly the two SPEC §5 insertions and nothing else; every planned line traces to the spec.
