# Next Session Prompt

## Context

You are continuing work on the AI display feature for inflow-ats (Polymer ATS). This is an ongoing feature branch, not a fresh start.

**Branch:** `ai-feature-work-v5`
**Worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.ai-frontend-work`

## Read these first, in order

1. **Handoff doc:** `/Users/jessica/claude-hub/inflow-ats/2026-06-15-ai-display-rework/HANDOFF-SESSION-2.md` — full state of what's done, what's uncommitted, outstanding work, and hard-won context from the previous session
2. **Pre-demo scope:** `/Users/jessica/claude-hub/inflow-ats/2026-06-15-ai-display-rework/PRE-DEMO-SCOPE.md` — prioritized list of what to fix before stakeholder demo
3. **Rework spec:** `/Users/jessica/claude-hub/inflow-ats/2026-06-11-ai-display/REWORK-SPEC.md` — the spec for the display rework
4. **AI subscription status fix:** `/Users/jessica/claude-hub/inflow-ats/2026-06-15-ai-display-rework/AI-SUBSCRIPTION-STATUS-FIX.md` — webhook handler fix needed for billing
5. **Cost estimate:** `/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring/SCORING-COST-ESTIMATE.md` — per-call cost breakdown for pricing decisions
6. **Outstanding work items (V4):** `/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/OUTSTANDING-WORK-ITEMS.md` — older items list, some completed, some still relevant
7. **Repo CLAUDE.md:** `/Users/jessica/wrk/wrk-corp/inflow-ats.ai-frontend-work/.claude/CLAUDE.md`
8. **Pipeline CLAUDE.md:** `~/claude-hub/inflow-ats/CLAUDE.md`

## Critical context (read the handoff but these are the highlights)

- Two status systems: `AiJobApplicationSummaryStatus.status` (none/initial_summary_pending/current/regenerating) vs `AiJobApplicationSummary.status` (pipeline enum). Don't confuse them.
- `set_initial_summary_pending` lives in `textract_result.rb` after the interactor call — not in `CreateAiSummaryGeneration`
- `showPlatoLoading` state lives in `JobApplicationContainer` — survives tab switches
- `before_update :broadcast_status_change` only fires on `update`, not `update_columns` — grep the entire pipeline if adding broadcasts
- `sync_with_stripe` filters AI subscriptions by lookup key containing "credit" or "plato"
- Never run `npx webpack` directly — it corrupts the dev server's packs
- Never compile webpack without permission when working with Jessica
- Commit with `nvm use && git commit` chained, `dangerouslyDisableSandbox: true`

## Key files

### Backend
- `app/models/ai_job_application_summary.rb` — BROADCAST_STATUSES, before_update callback
- `app/models/ai_job_application_summary_status.rb` — enum: none(0), initial_summary_pending(1), current(2), regenerating(3)
- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow`, `set_initial_summary_pending`
- `app/interactors/create_ai_summary_generation.rb` — creates summary, enqueues job
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — creates/updates status record
- `app/services/ai_job_application_action/orchestrate.rb` — pipeline orchestrator
- `app/services/ai_job_application_action/summary/generate.rb` — extraction + summarization
- `app/services/ai_job_application_action/scoring/score_job_application.rb` — scoring
- `app/services/ai_job_application_action/scoring/extract_criteria.rb` — job criteria extraction

### Frontend
- `PlatoTab.tsx` — main Plato tab, showPlatoLoading from props
- `PlatoLoadingState.tsx` — 4-step checklist loader
- `PlatoSummary.tsx` — succeeded summary display
- `PlatoOverviewCallout.tsx` — overview feed callout (being removed from feed, keeping component)
- `PlatoGeneratedReviewCallout.tsx` — succeeded summary in overview feed
- `JobApplicationContainer.tsx` — parent, owns showPlatoLoading state
- `JobApplicationActivity.tsx` — overview tab
- `WebsocketJobChannelHandler.tsx` — ai_summary_status_change handler
- `WebsocketGlobalChannelHandler.tsx` — AI_SUMMARY_COMPLETE/FAILED handlers
