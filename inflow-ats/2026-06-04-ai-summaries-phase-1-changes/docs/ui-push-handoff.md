# UI Push Handoff — AI Summaries Phase 1 v2

**Branch:** `feature-ai-credits-summaries-scoring-v2`
**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Backend reference:** `docs/textract-ai-summary-map.md` in this directory — complete trace of every Textract and AI summary code path, all triggers, data model, WebSocket actions, feature gates

---

## What's been done (backend complete, UI needs work)

All backend changes from Phase 1 are implemented and reviewed:
- Controller restructuring (`OrganizationAiCreditBalanceController`, `OrganizationAiCreditPurchasesController`)
- Stripe webhook hardening (checkout handshake, top-up via invoice metadata, `handle_charge_refunded` intact)
- Enum renames (`auto_generate_ai_summaries`, values `default`/`enabled`/`disabled`)
- Bulk job notifications (`BulkJobApplicationAiSummaryResultMailer`, `notify_complete`/`notify_failure`)
- No-TextractResult path fix (kicks off Textract when none exists, retry exhaustion cleanup)
- `textract_result_id` nullable on `AiJobApplicationSummary`
- All tests pass (RSpec + Cypress)

The Plato AI container exists (`AccountPlatoAiContainer.tsx`) with 3 sub-tabs (Settings/Billing/Usage) following the `AccountIntegrationsContainer` pattern. It works but the UI needs redesign.

---

## UI work needed

### 1. Plato AI settings page redesign

**Current state:** `OrganizationAiSettings.tsx` — 3 sections with checkboxes:
- Auto-generate summaries (org-wide toggle)
- Hiring team credit control (single boolean — can non-admins consume credits?)
- Notifications (low credits, zero credits)

**Problems:**
- Sub-nav labels (Settings/Billing/Usage) are vague and underwhelming
- "Settings" doesn't describe what's in there — it's really credit usage rules and alert preferences
- Candidate labels: "Credit usage settings and alerts", "Permissions", "Credit usage rules"
- The hiring team credit control is too coarse — needs to split into 3 separate permissions:
  1. Toggle auto-generate on a job (low risk, just flips a switch)
  2. Generate one summary manually (1 credit per action)
  3. Bulk generate for a hiring stage (can drain balance fast)
- These are JSONB settings keys, no migration needed

### 2. Billing/credit balance display redesign

**Current state:** `AccountBillingAiCredits.tsx` — shows Monthly/Purchased/Total credit balance, Subscribe button, Top-up button

**Problems:**
- Mixes balance display with billing actions
- Credit category breakdown (Monthly/Purchased/Total) — unclear if this is the right way to present it
- "Go to AI billing" link from Plan & Billing page exists but looks bad
- Non-admin credit balance visibility is completely undesigned (Note #17 deferred)

### 3. Usage tab — may not justify its own tab

**Current state:** `OrganizationAiUsage.tsx` — credit balance (duplicated from billing), usage bar, reset date

**Open question:** merge into billing tab? Or keep separate with better content?

### 4. AI Summary display per candidate — move to own tab

**Current state:** AI summary is crammed into the Overview tab in the candidate view (`AiJobApplicationSummaryFeedItem.tsx`)

**Desired state:**
- Dedicated tab in the candidate view (column 3 tabs: Overview, Resume, Messages, Files, Private notes — add AI Summary or similar)
- CTA in the Overview tab linking to the AI Summary tab
- Needs to look good — the summary has: headline, summary_text, structured_data (work experience, education, skills, certifications, role_analysis, applicable_experience, gaps, overlap_summary)

**Status display states** (from `AiJobApplicationSummaryFeedItem.tsx:82-105`):
- `textract_processing` → "Resume is being processed. Summary will generate automatically."
- `pending` / `in_progress` / `extracted` → "Generating summary..."
- `failed` → "Summary could not be generated. No credits were used." + retry button or buy credits
- `succeeded` → full summary display

### 5. Non-admin credit balance visibility (deferred from Phase 1)

No design exists. Jessica needs design help before deciding where/how to show it. The `AiCreditBalanceDisplay` widget exists but was built for the full settings page (progress bar, sections) — nothing suitable for a compact non-admin view.

---

## Key files for UI work

| File | What it does |
|---|---|
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AccountPlatoAiContainer.tsx` | Plato AI container with sub-nav |
| `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx` | Settings tab content |
| `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx` | Billing tab content |
| `app/javascript/ats/src/views/accountAdmin/OrganizationAiUsage.tsx` | Usage tab content (may merge) |
| `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx` | Parent container — Plato AI route lives here |
| `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` | Current AI summary display in Overview tab |
| `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | Consolidated credit purchase hooks |
| `app/javascript/shared/queryHooks/useOrganizationAiCreditBalance.ts` | Credit balance hook |
| `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` | WebSocket handlers for AI_SUMMARY_COMPLETE, AI_SUMMARY_FAILED, etc. |

## Pattern to follow

`AccountIntegrationsContainer.tsx` — two-column layout, styled components, `useAuthorization({ adminOnly: true })`, internal `NavItem` sidebar, `Switch`/`Route`/`Redirect`. The Plato AI container already copies this pattern but the content inside needs design work.

## Candidate view layout reference

From `qa-config.yml` navigation section:
- Column 1: Hiring stages (never changes)
- Column 2: Candidate list for selected stage
- Column 3: Candidate header — contact info, action buttons, and tabs (Overview, Resume, Messages, Files, Private notes)
- Column 4: Content area for whichever tab is selected in column 3

The new AI Summary tab would be added to column 3's tab list, with content rendering in column 4.
