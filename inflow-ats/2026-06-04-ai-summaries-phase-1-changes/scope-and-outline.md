# Scope & Outline — AI Change Spec (NON-AUTHORITATIVE reference)

> This file is reference material to map the territory, NOT approved decisions.
> Approved decisions live only in `approved-decisions.md`. The change spec is assembled from that file.

## Vague scope

Phase 1 of `docs/ai-change-spec-session-directions.md`: produce a change-only spec covering the 37 prioritized items in `docs/ai-jessicas-notes-on-changes.md`, in their existing order, in imperative voice with exact identifiers. Not a rewrite of the system — only what is added/fixed/renamed and where.

## Code-as-is baseline

`docs/ai-system-spec.md` is the authoritative as-built record of the current code (per Jessica). Treat it as the model of the current codebase. It is less focused and less complete than the 37-item notes list. Deep-investigate the actual code only where a decision needs a detail the as-built spec does not pin down.

## Process constraints (from directions doc — binding)

- Work the 37 notes in their existing priority order. Do NOT re-triage or regroup the walk.
- Capture decisions one at a time (restate → confirm → write).
- Imperative voice; exact identifiers; no partial enumerations; no code blocks; no dated model strings; no churn-prone counts.
- Cross-references use note numbers.
- The grouping below is for orientation ONLY — it does not change the order of the decision walk.

## Territory map (orientation only — walk stays in numeric order)

- **Notifications / mailer:** #1 (is_admin? bug), #13 (bulk-completion email), #20 (Mailgun templates)
- **Frontend types:** #2 (AiResumeStructuredData drift)
- **Refund correctness:** #3 (earliest-row pick), #32 (.reload), #33 (unmatched-refund silent drop)
- **Stripe webhook routing:** #4 (mode:payment discriminator), #33 (overlaps refunds)
- **Enum rename:** #5 (auto_generate_ai_summaries_setting → auto_generate_ai_summaries) — DECIDED
- **File/location moves & dead code:** #6 (credit packs → model; delete role_category_groups), #22 (remove AiRelevanceBenchmark), #26 (prompt_text debug), #35 (saved_change_to_id?)
- **No-change / resolved:** #7 (cancellation no refund — RESOLVED)
- **Daily credits gating:** #8 (keep infra, config-controlled), #29 (daily reset idempotency)
- **Frontend consolidation:** #9 (query hooks), #16 (Plato AI tabs), #17 (non-admin balance visibility), #21 (re-upload confirm modal)
- **Doc consistency:** #10 (policy methods in diagram), #37 (misleading plan_feature_gate comment)
- **Pending-review investigations:** #11 (two serializers), #12 (rename ConsumeAiCredits), #14 (table review)
- **Scoring (informational/future):** #15
- **Credit allocation / PlanFeatureGate:** #18 (trial-to-paid), #28 (allocation constants), #31 (unknown-plan fallback), #36 (PlanFeatureGate doesn't gate summaries)
- **Ops / cron:** #19 (Heroku Scheduler + tasks README), #23 (reconcile cron)
- **Background job:** #24 (bump max runtime)
- **Pipeline error handling:** #25 (swallowed exceptions skip retries), #30 (silent create_ai_credit_state_if_needed)
- **Constants cleanup:** #27 (OVERDUE_RESET_GRACE)
- **WebSocket / error messaging:** #34 (AI_CREDITS_EXHAUSTED action name mismatch)
