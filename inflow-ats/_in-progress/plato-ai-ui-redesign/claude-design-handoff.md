# Plato AI UI Redesign — Design Handoff

Two designs needed, implemented separately.

---

# Spec 1: Admin Settings Page

## What this page is
Admin settings page at `/hire/settings/plato-ai/` in an ATS (Applicant Tracking System) called Inflow/Polymer. Manages AI-powered candidate resume summaries. Admin-only.

## What needs designing
One combined page (Option B) with everything on a single scrollable view. Currently has 3 tabs (Settings/Billing/Usage) but content doesn't justify the separation.

## Credit plans structure
- **Subscription plans**: different quantities of credits per month at different prices. NOT feature-gated tiers — same product, different amounts. Plans come from Stripe with `lookupKey`, `name`, `credits`, `blurb`.
- **One-time top-ups**: buy additional credits that never expire. Also quantity-based packs from Stripe.
- 1 credit = 1 AI summary generated

## Data available on the page

**Credit balance** (from `OrganizationAiCreditBalance`):
- `monthlyCreditsRemaining` / `monthlyCreditAllocation`
- `addonCreditsRemaining` (purchased, never expire)
- `totalCreditsRemaining`
- `currentPeriodEndAt` (reset date)

**Subscription status** (from `OrganizationAiCreditPurchase`):
- `subscriptionStatus`: active / past_due / canceled / paused
- `subscriptionCreditsPerPeriod`
- `subscriptionCurrentPeriodStart` / `End`
- `subscriptionCanceledAt`
- `kind`, `stripePriceLookupKey`, `amountCentsPaid`, `currency`

**Settings** (JSONB on organization, no migration needed):
- `autoGenerateAiSummariesEnabled` — org-wide toggle
- `hiringTeamAiCreditsControlEnabled` — currently single boolean, splitting into 3:
  1. Toggle auto-generate on a job (low risk, flips setting)
  2. Generate single summary (1 credit)
  3. Bulk generate for a hiring stage (can drain balance)
- `lowAiCreditNotificationsEnabled` + `lowAiCreditNotificationThreshold`
- `zeroAiCreditNotificationsEnabled`

## Two states to design
1. **Subscribed** — has active credit plan, showing balance, usage, ability to change/cancel/top-up
2. **Unsubscribed** — no plan, needs to convert. Plan selection is the most important thing on the page

## Existing app patterns (for reference, not to copy blindly)
- **Container**: `AccountIntegrationsContainer.tsx` — two-column sidebar + content, Emotion styled components
- **Settings pages**: `SettingsContainer` → `FormSection` → `FormCheckbox` / `FormFieldset`
- **Plan & Billing page**: `AccountBillingPlans.tsx` / `AccountBillingPlansUnsubscribed.tsx` — plan cards with pricing. BUT these are feature-tiered plans, not credit quantity plans

## User feedback on attempts so far
- Credit balance cells alone are not compelling — "crushed up"
- Plan cards copying the existing feature-comparison pattern DON'T work — credits are quantities, not features
- Top-up option was too small/insignificant
- Unsubscribed state with empty balance cells won't convert
- This is a NEW product type that needs its own design, not a copy of existing patterns
- Plan selection is the most important element on the page

## Also in scope (but secondary to the layout)
- Fix the ugly link from Plan & Billing page (`AccountBilling.tsx:142-147`) — currently: `"AI credits are managed separately — go to AI billing →"` as tiny gray `t.text.sm` text

## Files involved
| File | Role |
|---|---|
| `AccountPlatoAiContainer.tsx` | Container with sub-nav (may simplify if going single-page) |
| `OrganizationAiSettings.tsx` | Settings tab content |
| `AccountBillingAiCredits.tsx` | Billing tab content |
| `OrganizationAiUsage.tsx` | Usage tab content |
| `AiCreditBalanceDisplay.tsx` | Reusable 3-cell balance widget |
| `AiCreditPurchaseModal.tsx` | Tier picker modal |
| `AccountBilling.tsx` | Main billing page (has the ugly link) |

---

# Spec 2: Candidate AI Summary Tab

## What this is
Dedicated tab in the candidate view (column 3 of the ATS). Currently AI summary is crammed into the Overview activity feed. Moving it to its own tab to give space for the rich data.

## What needs designing
- New tab in column 3 tab bar (alongside Overview, Resume, Messages, Files, Private notes)
- Tab naming is open — needs brainstorming ("Plato"? "AI Summary"? something else?)
- CTA in Overview tab replacing current summary display, linking to the new tab
- CTAs in other places TBD
- Non-admin credit balance visibility (design TBD)

## Data available to display

**Summary metadata** (from `AiJobApplicationSummary`):
- `status`: pending / in_progress / extracted / succeeded / failed / textract_processing
- `headline`: short headline from resume
- `summaryText`: generated text summary
- `stale`: boolean — true when resume updated after summary generated
- `createdAt`

**Structured data** (from `structuredData` JSONB — only on full serializer):
- `name`, `email`, `phone`, `location`
- `links`: array of URLs (portfolio, LinkedIn, etc.)
- `workExperience`: array of `{ company, title, startDate, endDate, description }`
- `education`: array of `{ institution, degree, fieldOfStudy, graduationYear }`
- `skills`: array of strings
- `certifications`: array of strings
- `totalMonthsExperience`: number
- `roleAnalysis`: AI analysis of candidate fit for the role (optional)
- `applicableExperience`: relevant experience summary (optional)
- `gaps`: experience gaps analysis (optional)
- `overlapSummary`: overlap with job requirements (optional)
- `monthsByDomain`: `{ [domain: string]: number }` — experience breakdown by domain (optional)
- `assessment`: flexible assessment data (optional)
- `comparison`: flexible comparison data (optional)

## Status display states
- `textract_processing` → resume being processed, summary will auto-generate
- `pending` / `in_progress` / `extracted` → generating summary
- `failed` → generation failed, no credits used, retry option
- `succeeded` → full summary display
- `stale === true` → resume updated since summary, regenerate option

## Actions available
- Generate summary (1 credit) — `useGenerateAiSummary` mutation
- Regenerate (when stale) — same mutation
- Bulk generate for a stage — `useBulkGenerateAiSummaries` mutation (from stage view, not candidate view)

## Candidate view layout
- Column 1: Hiring stages (fixed)
- Column 2: Candidate list for selected stage
- Column 3: Candidate header — contact info, action buttons, tab bar
- Column 4: Content for selected tab

Current tabs: Overview, Resume, Messages, Files, Private notes
New tab adds to this list. Content renders in column 4.

## Current implementation
- `AiJobApplicationSummaryFeedItem.tsx` — current summary display in Overview feed
- `JobApplicationSidebar.tsx` — tab bar with NavItems
- `JobApplicationContainer.tsx` — routing for tab content
- `JobApplicationActivity.tsx:395-404` — where summary currently renders in Overview

## Files involved
| File | Role |
|---|---|
| `JobApplicationSidebar.tsx` | Tab bar — add new tab here |
| `JobApplicationContainer.tsx` | Routing — add new route here |
| `JobApplicationActivity.tsx` | Overview tab — replace summary with CTA |
| `AiJobApplicationSummaryFeedItem.tsx` | Current summary component (reference/reuse) |
| `WebsocketGlobalChannelHandler.tsx` | WebSocket events for real-time status updates |
