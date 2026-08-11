# Angle 6 — Behavior preservation: the reverse audit (spec round 1)

Spec-round application: verified the spec's untouched/modified inventories against live source (the diff itself does not exist yet; impl rounds re-run this angle against `git diff HEAD`).

## Verifications (clean)

- §2 Modified list is complete for the behavior described: every code change in §§5–7 lands in a file §2 names (subscription_event.rb, create_subscription_event.rb, stripe_webhook_handler_job.rb, organization.rb, notification/paid_subscription_deleted_job.rb, one migration). No hidden ripple site found: repo-wide grep shows exactly one enqueue site per moved Discord job and exactly one production `CreateSubscriptionEvent.call` caller (organization.rb:1237, untouched by the spec).
- §2 Untouched list checks out: the three Discord job FILES need no edits for the moves (signatures already accept what the fan-out passes — with the nil-`ended_at` handling now defined at the enqueue side per Angle 4 F1); Slack `Notification::*` enqueues live outside the changed line ranges except `Notification::PaidSubscriptionDeletedJob`, whose Slack path survives the Angle 4 F2 removal shape.
- The two organization.rb branches (1128–1134, 1136–1140) are the entire permitted surface, consistent with core_critical_rules "Do not automate edits to `app/models/organization.rb`" — the spec sanctions exactly these two edits and nothing else in the file.
- `assigned_free_plan*` path: `log_assigned_free_plan_event` → `CreateSubscriptionEvent` untouched; §7 maps those rows to no fan-out actions; §6 keeps their dedupe semantics byte-identical (params merged only when present).
- Webhook: all other branches (`checkout.session.completed`, `subscription.updated`, `charge.refunded`, credit-pack branches, schedule handlers) outside the two insertion coordinates — §2/§10 exclusions match the file's real structure.

## Findings

- F1 [LOW] SPEC §2 / new spec FILES not listed in the stack-scope section / §2's Created list names only the migration; the new `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb` (+ interactor/fan-out/callback spec additions) appear only in §9. Note-only — §9 is explicit and the hub "list all modified files" pattern is satisfied between the two sections. No amendment.
