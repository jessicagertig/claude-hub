# Subscription.deleted — Agent-Sanctioned Whitelist (flow 4)

Forced / no-analog deviations the audit/fix loop discovered and the orchestrating agent whitelisted to unblock convergence while the owner was away. The audit reads this file alongside `SANCTIONED-subscription-deleted.md` and does not flag anything listed here.

**Bar for inclusion:** the deviation is forced by our domain / data model / a genuine product difference between the AI-credit-pack subscription and the main plan, AND there is no way to match the analog without breaking correct behavior. NEVER whitelisted because a fix is hard. Each entry cites the analog it diverges from and why no match is possible. For Jessica's later audit.

---

W1. **Credit-pack branch does NOT fire the main-plan notification/engagement jobs nor write `organizations.subscription_canceled_at`** — ANALOG (`stripe_webhook_handler_job.rb:182-184`) unconditionally calls `organization.update_column(:subscription_canceled_at, …)`, `Notification::PaidSubscriptionDeletedJob.perform_later(...)`, and `EngagementReport::GeneratorJob.perform_later(trigger: 'subscription_canceled')`. OURS' credit-pack branch does none of these — it only reconciles the purchase row to `:canceled`. Forced/no-analog: those jobs read the org's main `plan` (`get_plan_display_name`, Discord plan detection) and `organizations.subscription_canceled_at`, so firing them for a credit-pack add-on produces misleading "main-plan canceled" Slack/Discord/engagement output with the wrong plan name and timestamp. This is the trace's documented "option 1 / minimum mirror." Credit-pack-specific cancellation notifications would be NEW infrastructure and are a separate product decision, out of scope for the analog mirror.

> **PRODUCT DECISION FLAG for Jessica:** with this change, a credit-pack subscription cancellation produces **NO** Slack/Discord/engagement-report notification (vs the main plan, which does). If you want credit-pack cancellations surfaced, that's new, credit-pack-specific notification work — not part of this analog-mirror pass. (Orchestrator-added whitelist entry; the fix agent considered it covered by SANCTIONED #1.)
