# AI Scoring + Display — Session Recovery Handoff (2026-06-14)

## Branch: `feature-ai-summaries-integrating-scoring-v4` at `/Users/jessica/wrk/wrk-corp/inflow-ats`

## What was done overnight (Jun 13-14)

9 modified files + 2 new files, all uncommitted:

**Backend (3 files):**
- Added `integrated_role_analysis` to shallow serializer (overview callout needs it)
- Added `summary_status` + `summary_score_percentage` delegates to status serializer (nav Harvey ball needs it)
- Updated controller eager loading to avoid N+1

**Frontend (6 modified + 2 new):**
- **PlatoSummary.tsx** (new) — full review body with FitStars, ScoringDetail, skills, domains, role fit card
- **PlatoTab.tsx** (rewritten) — succeeded → PlatoSummary, non-succeeded → PlatoTabEmptyState, kept shimmer for generating
- **PlatoGeneratedReviewCallout.tsx** (placed previous session) — overview callout for succeeded
- **JobApplicationActivity.tsx** — wired PlatoGeneratedReviewCallout for succeeded status
- **JobApplicationNavItem.tsx** — added FitHarvey indicator
- **JobApplicationListContainer.tsx** — passes score data to nav items
- **ScoringDetail.tsx** — fixed `criterion_text` → `criterionText` (latent bug from cherry-pick)
- **aiJobApplicationSummary.ts** — added scoring fields to TypeScript types

## What Jessica fixed after returning

Replaced serializer delegates with **denormalized columns** on `ai_job_application_summary_statuses` table: `status`, `score_percentage`, `headline`, `integrated_role_analysis`. New migration added.

## Issues found after the column change

1. **Name mismatch (will break Harvey balls):** `JobApplicationListContainer.tsx` still reads `.summaryStatus` and `.summaryScorePercentage` (old delegate names). Serializer now exposes `.status` and `.scorePercentage` directly. Both will be `undefined`.

2. **Controller eager loading can simplify:** `ai_job_application_summary_status: :ai_job_application_summary` can revert to just `:ai_job_application_summary_status` — status no longer delegates through the association.

3. **PlatoTab border fix applied:** Conditional border on Header via `hasContent` prop (same pattern as Messages tab's `messagesExist`). Shows border for succeeded + generating states, no border for empty states.

## Outstanding: after_commit callback design

Need a callback on `AiJobApplicationSummary` to update the status table's denormalized columns when summary succeeds.

**Pattern from investigation:**
- Organization model uses `saved_changes.key?('column_name')` in after_commit handlers
- The explicit equality guard (`return if old == new`) is ONLY for Stripe-synced fields where webhooks repeatedly write same value — not needed here
- Existing callback `update_summary_status_record` already fires `after_commit on: :update`, guarded by `saved_change_to_status? && status_succeeded?`
- That callback currently only updates `ai_job_application_summary_id` and `regenerating` — needs the 4 new columns added

**Design decision still open:** Whether to check specifically for transition TO succeeded (not-succeeded → succeeded) or just `saved_change_to_status? && status_succeeded?` (the existing guard).

## BIG DISCOVERY: `regenerating` is never set to `true`

The `regenerating` column on `ai_job_application_summary_statuses` is only ever set to `false` — on creation and on success. The "set to true" half was never built. This is broken/incomplete implementation.

## Completed in Jun 14 polish session

### Styling & spacing
- **PlatoScoreTag** — height 24→26px, font 12→13px (`0.8125rem`)
- **FitStars** — size 19→24px in PlatoSummary
- **PlatoTab Content** — padding `p(4)`→`p(5)` (20px all sides)
- **PlatoSummary vertical spacing** — Score `mb(3)`→`mb(4)`, Headline margin `spacing[2]`→`spacing[3]`, Domains `mb(4)`→`mb(5)`, RoleFit `mb(5)`→`mb(6)`, Block `mb(5)`→`mb(6)` + added `mt(3)`
- **RoleFit body** — font size 14→15px (`0.9375rem`), line-height 1.55→1.6
- **RoleFit heading** — sparkle icon (`PlatoMark variant="sparkle" size={16}`) replaces PlatoChip
- **Accordion RowBody** — top padding `pt(1)`→`pt(3)` (12px)
- **Accordion SectionLabel** — added `border-top` divider between sections, with Body `:first-child > :first-child` exception to prevent double border at top
- **Accordion RowButton** — vertical padding `py(2)`→`py(3)` (done in prior turn)
- **Accordion Count** — `gray[400]` dark mode (was `gray[500]`)
- **ScoringDetail TIERS** — renamed "Core"→"Core criteria", "Preferred"→"Preferred criteria", "Bonus"→"Bonus criteria"
- **ScoringDetail icons** — replaced custom SVGs with feather `check-circle`, `minus-circle`, `x-circle` via Icon component. Light mode color `gray[500]`.
- **ScoringDetail tally numbers** — `gray[300]` dark / `gray[700]` light
- **SecondaryDomain** — `gray[400]` dark mode (was `gray[600]` both modes)
- **PlatoScoreTag variants** — weak/poor now use medium (black border) instead of light. `fitTagVariant` simplified to return "medium" or "linear" only.
- **Notable achievements** — award ribbon icon (`Icon name="award"`) per achievement in flex row, icon color matches text, gap `spacing[3]`
- **Dark mode fixes** — PlatoOverviewCallout + PlatoGeneratedReviewCallout + RoleFit card: `transparent` border, `gray[800]` background. Activity feed connector bars added to both callouts.
- **Stale banner** — updated wording: "The resume has changed since this review was generated. Regenerate to update." Background `gray[700]`/`gray[200]`, text `gray[200]`/`gray[700]`, padding `py(3)`.

### Functional changes
- **Regenerate button** — only shows when `aiSummary.stale` is true
- **AI summary cache invalidation** — `useUpdateJobApplication` now invalidates `aiJobApplicationSummary` queries on success (resume upload triggers stale refresh)
- **No-pronouns rule** — added to `job_application_scoring.rb` SYSTEM_PROMPT

### Empty state improvements
- **Messages tab** — replaced all 3 `EmptyState` usages with `JobApplicationTabEmptyState`
- **JobApplicationTabEmptyState refactored** — removed `data-*` attribute pattern (Claude convention, not codebase). Props (`borderless`, `roomy`) destructured directly in styled component functions with inline conditionals.
- **Empty state icon** — svg sized to 24x24
- **DragAndDropResumeUploader** — added optional `title` and `message` props; Plato tab passes custom copy
- **PlatoTabEmptyState** — CTA renamed "Generate summary"→"Generate review". Footnote for failed state now shows credits remaining.
- **noCredits state** — PlatoChip icon, admin gets "Buy credits" as `internalLink` to `/hire/settings/plato-ai/billing`, member gets disabled "Buy credits" button. Inline link removed from message text. Role-conditional messaging.
- **Button icon sizing** — 18x18 in empty state ButtonContent
- **Roomy Actions** — `mt(8)` for more space between message and CTA
- **Footnote** — `gray[400]` dark mode (was `gray[500]`)

### NavItem
- **rightContent prop** — Harvey ball passed via `rightContent` instead of absolute positioning
- **Chevron selector** — `> *:last-child > svg` targets chevron inside StyledRight without affecting Harvey ball SVG

## Still outstanding

- **TEMP hardcode in PlatoTab renderBody** — early return showing noCredits state. MUST REVERT before committing.
- **`hasContent` references non-existent statuses** — `in_progress`, `extracted` in PlatoTab line 49. Need to verify these are real status values.
- **`regenerating` column never set to `true`** — needs design decision
- **Resume tab** — replace generic `EmptyState` with `JobApplicationTabEmptyState`
- **PlatoGeneratedReviewCallout `Styled.Tag`** — still uses old black-outline tag, not PlatoScoreTag
- **Add no-pronouns rule to remaining 8 prompt files** — only `job_application_scoring.rb` done so far
- **AI settings redesign** — separate session
- **Filtering by fit band** — separate session
- **Sorting** — separate session

## Key context

- Numeric scores are NOT exposed to users. Only fit band labels.
- `FitStars` = 5 Plato twinkles mapping to 5 bands
- `FitHarvey` = 3-state Harvey ball: full (good/excellent), half (mixed), outline (weak/poor), absent (unscored)
- `allKeysToCamel` deep-converts JSONB column keys — snake_case in DB becomes camelCase in frontend
- `||` not `??` (build doesn't support nullish coalescing)
- Optional chaining `?.` IS supported
- No `React.useId()` (React 16.14)
- `t.text.sm` etc are complete CSS declarations, not raw values
- Pass props directly and destructure in styled component functions — no `data-*` attributes for conditional styling
- Buy credits path: `/hire/settings/plato-ai/billing`

## Test candidates

JA IDs: 6797, 6728, 6771, 6837, 6864, 6763 (all org 3, requested_by_organization_user_id: 4)
