# AI Display Rework — Session 2 Handoff

**Date:** 2026-06-16
**Branch:** `ai-display-rework-qa`
**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats.ai-frontend-work`

---

## Uncommitted changes (to be committed by Jessica)

Many files touched during live debugging. Key changes:

### Backend
- `app/models/ai_job_application_summary.rb` — `pending` added to `BROADCAST_STATUSES`
- `app/models/ai_job_application_summary_status.rb` — enum reordered: `none: 0, initial_summary_pending: 1, current: 2, regenerating: 3`
- `app/models/textract_result.rb` — captured interactor result, added `set_initial_summary_pending` helper
- `app/models/organization.rb` — `sync_with_stripe` filters out AI subscriptions (lookup key contains "credit" or "plato")
- `app/interactors/create_ai_summary_generation.rb` — removed `set_initial_summary_pending` (moved to textract_result)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — removed else branch that reset to none on non-succeeded summary
- `app/services/ai_job_application_action/summary/generate.rb` — `update_columns` → `update` for extracting status
- `app/services/ai_job_application_action/scoring/score_job_application.rb` — nil guard on `first_score`, empty criteria guard
- `app/services/ai_job_application_action/scoring/extract_criteria.rb` — fail if zero criteria extracted
- `app/interactors/validate_ai_summary_generation.rb` — job description check added
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` — added `:updated_at`
- `app/controllers/api/v1/job_applications_controller.rb` — includes swap to `ai_job_application_summary_status`

### Frontend
- `PlatoTab.tsx` — `showPlatoLoading`/`setShowPlatoLoading` from props (lifted to `JobApplicationContainer`), explicit pipeline status checks, `hasContent` only for current/regenerating
- `PlatoLoadingState.tsx` — default step 0 (processing resume)
- `PlatoOverviewCallout.tsx` — added `generating` and `initial_summary_pending` states, 4-state + generating
- `JobApplicationContainer.tsx` — `showPlatoLoading` state, passed to `PlatoTab` and `JobApplicationActivity`
- `WebsocketJobChannelHandler.tsx` — invalidates by specific summary ID + job application ID
- `WebsocketGlobalChannelHandler.tsx` — user-facing error messages (no internal errors), `jobApplicationsForStage` invalidation
- `FitIndicator.tsx` — mixed/weak/poor use `light` variant
- `PlatoSummary.tsx` — FitStars size 22, role fit padding py(5)
- `jobApplication.ts` — `initial_summary_pending` in status type
- `AiCreditMeter.tsx` — dark mode tones fixed
- `AiCreditSubscription.tsx` — `undefined` → `null`, subscription status banner with PlatoChip

---

## Outstanding work — not yet implemented

### Overview redesign
- Remove three-dot menu from overview heading (Add/Edit hiring document)
- Move hiring document action to `JobApplicationSidebarActions` (conditional: add if blank, edit if exists)
- Add Plato CTA to left side of overview heading — PlatoChip + button, "Ask Plato" for MVP, navigates to Plato tab
- Remove `PlatoOverviewCallout` from the feed (don't delete the component, just stop rendering it)
- `PlatoGeneratedReviewCallout` stays in feed but positioned chronologically among activity items
- `showPlatoLoading` not yet used by `JobApplicationActivity` — needs to be wired up (or may not be needed with the heading CTA approach)

### Styling (from Shelly / designer)
- Remove negative letter-spacing from all AI components (likely came from Claude AI design handoff)
- Headline font size → 20px (use rem equivalent for theme)
- PlatoGeneratedReviewCallout tag — smaller, match colors used in Plato tab tags (light variant for mixed/weak/poor, linear for good/excellent)
- Accordion styling changes — Shelly will provide details later, add to the work

### AI subscription status fix
- Documented in `AI-SUBSCRIPTION-STATUS-FIX.md`
- `checkout.session.completed` webhook needs to set `subscription_status: :active` on `OrganizationAiCreditPurchase`
- `customer.subscription.updated` webhook needs to route AI subscriptions to the purchase record, not the organization
- Sync method on `OrganizationAiCreditPurchase` as safety net

### Prompt / pipeline fixes
- No-pronouns instruction needs to be in ALL prompt files (only in `job_application_scoring.rb` currently)
- Investigate how the AI knows candidate gender — after extraction + anonymization, no name/gender info should reach downstream prompts. Find the leak.
- Add instruction to scoring display prompts: don't reference "the resume" directly in reasoning text
- Investigate/fix: AI included tier name at the beginning of every extracted criterion text (string cleanup function needed in criteria extraction)

### Backfill task
- Rake task to backfill job criteria extraction (`AiJobCriteria` via `extract_job_criteria`) for published jobs in paid organizations (same org scope as the existing Textract rake task)

### False failure toast during retry
- User saw a failure toast even though the pipeline retried and succeeded
- Investigate: is the `before_update` broadcast firing on `failed` status before retries exhaust? The `AI_SUMMARY_FAILED` GlobalChannel broadcast may be triggering prematurely
- The `retry_on` exhaustion block in `GenerateAiJobApplicationSummaryJob` should be the only place failure broadcasts happen — check if there's another path

### PlatoLoadingState — delayed "keep working" text
- The "You can keep working — Plato will finish in the background" text should only appear after 10 seconds
- If the loading completes in under 10 seconds, it never shows
- Use a `useEffect` with `setTimeout` — must include cleanup function to clear the timeout on unmount

### Remove "Summary generation queued" toast
- `PlatoTab.tsx` `handleGenerate` `onSuccess` — remove the toast. `showPlatoLoading` provides the feedback now.

### Plan & billing
- Update the AI callout styling on the Plan & billing tab (the link to AI billing)

### Filter by score
- Filter candidates by fit band (Excellent/Good/Mixed/Weak/Poor/Unscored) in the candidate list
- Needs backend + frontend

### Verify regenerating works for all trigger paths
- The interactor sets `regenerating` when a succeeded summary exists — verify this works for manual, bulk, and auto trigger paths

### Known data issues
- 17 status records bulk-updated to `current` — backfill done
- Org 3 (Stack 24) had AI subscription ID stored as plan subscription — fixed by `sync_with_stripe` filter
- `regenerating` enum value never set by any backend code path — needs trigger paths wired up

---

## Key decisions made this session

- `initial_summary_pending` enum value at position 1 (shifted current to 2, regenerating to 3)
- `before_update :broadcast_status_change` with `pending` in BROADCAST_STATUSES
- `showPlatoLoading` lifted to `JobApplicationContainer` — survives tab switches
- Loading state default step 0 ("Processing the resume")
- Loading state stays until `structuredData` exists (not just until succeeded)
- `set_initial_summary_pending` lives in `textract_result.rb` after the interactor call
- Overview callout going away from feed — replaced by heading CTA
- Mixed/weak/poor fit tags use `light` variant (gray, like non-key skill chips)
- User-facing error toasts: "Plato couldn't analyze [name]" — no internal error messages
- Empty criteria → fail extraction, not succeed with empty array
- No job description → validation error with user-facing message

---

## Context for next session — hard-won knowledge

1. **Two different status systems** — `AiJobApplicationSummaryStatus.status` (none/initial_summary_pending/current/regenerating) is the lightweight denormalized record on the job application. `AiJobApplicationSummary.status` (pending/extracting/summarizing/scoring/integrating/succeeded/failed/retrying) is the pipeline status on the full summary record. The frontend uses both for different purposes. The naming is close enough to confuse — be explicit about which one you mean.

2. **Where `set_initial_summary_pending` lives and why** — it's in `textract_result.rb` in `generate_ai_summary_with_credit_flow`, after the `FindOrCreateAiJobApplicationSummaryStatus` interactor call. NOT in `CreateAiSummaryGeneration`. The interactor only runs in the background job, not during the web request. The web request creates the summary record; the background job creates the status record and sets `initial_summary_pending`.

3. **`update_columns` vs `update` matters for broadcasts** — the `before_update :broadcast_status_change` callback only fires on `update`, not `update_columns`. `generate.rb` was a missing file in the original plan — it does the `extracting` transition. Any future status transition added as `update_columns` will silently skip the broadcast. Grep for `update_columns.*status` across the entire pipeline if adding new broadcasts.

4. **The `showPlatoLoading` gap** — covers the time between clicking Generate and the first websocket broadcast arriving. Lives in `JobApplicationContainer` (not `PlatoTab`) so it survives tab switches. Unsets when `fullSummaryStatus` arrives from `useAiJobApplicationSummary`. Needs to be wired into the overview heading CTA (not yet done).

5. **`sync_with_stripe` AI subscription filter — FIXED** — Stripe returns ALL subscriptions for a customer. Without the filter, the AI credit subscription can overwrite the plan subscription on the org record. Fixed: `sync_with_stripe` now rejects subscriptions whose lookup key contains "credit" or "plato". This depends on AI credit lookup keys always containing one of those strings — Jessica needs to ensure future lookup keys follow this convention.

## Files reference

- Spec: `/Users/jessica/claude-hub/inflow-ats/2026-06-11-ai-display/REWORK-SPEC.md`
- Plan: `/Users/jessica/claude-hub/inflow-ats/2026-06-15-ai-display-rework/plan.md`
- AI subscription fix: `/Users/jessica/claude-hub/inflow-ats/2026-06-15-ai-display-rework/AI-SUBSCRIPTION-STATUS-FIX.md`
- Cost estimate: `/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring/SCORING-COST-ESTIMATE.md`
- Outstanding work items (V4): `/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/OUTSTANDING-WORK-ITEMS.md`
