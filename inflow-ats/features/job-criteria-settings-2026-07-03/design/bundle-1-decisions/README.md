# Handoff: Job criteria in Plato AI settings

## Overview
Adds a **Job criteria** section to the existing per-job **Plato AI settings** tab (`JobSetupAiSettings.tsx`). It exposes the scoring criteria Plato extracted from the job description, lets users view them in a full-height slide-over, and lets them manually regenerate extraction behind a confirmation modal. Two guard modals warn when extraction produces few (≤5) or zero criteria. A right sidebar explains the criteria tiers.

Out of scope for this handoff (designed later): internal criteria entry.

## About the Design Files
The files in this bundle are **design references created in HTML/JSX prototypes** — they show intended look and behavior, they are not production code to copy. The task is to **recreate this design inside the existing ATS React codebase** using its established components (`SettingsContainer`, `FormSection`, `FormSelect`, `Button`, `FullModal`, `Modal`, `useToastContext`, emotion styled-components) and patterns. `JobSetupAiSettings-34f2eed8.tsx` in this folder is the current production component this feature extends — treat it as the base.

## Fidelity
**High-fidelity.** Colors, type, spacing, and copy are final and follow the Polymer design tokens. Recreate pixel-perfectly with the codebase's existing primitives.

## What changes in `JobSetupAiSettings.tsx`
Keep everything that exists (title, description, Plato reviews FormSection with the auto-generation FormSelect, bottom-bar Save, dirty tracking, toasts). Add:

1. A second `FormSection` titled **"Job criteria"** below "Plato reviews".
2. A `sidebar` prop on `SettingsContainer` (the component already supports one) carrying the tier glossary.
3. Three overlays: the View criteria slide-over (FullModal), the Regenerate confirmation, and the low/zero guard modals.

## Screens / Views

### 1 · The Job criteria section

**Section intro** (`FormSection` intro text, standard `fs-introtext` styling):
> Each review scores a candidate against these, as they stand when it runs. To change them, edit your **job description**.

"job description" is an inline link (`--text-loud`, weight 500, underline on hover) that navigates to Job setup → Job description.

**The criteria card** (max-width 560px, 1px `--border`, radius `--radius-md` 7px, white bg, flex row):
- **Left cell** (flex 1, padding 14px 16px, flex row, gap 14, vertically centered):
  - **Plato disc**: 36×36 circle, background `--accent-gradient` (the pink→peach `linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)`), inset ring `0 0 0 1px rgba(0,0,0,0.07)`, containing the Plato mark at 20px in `--neutral-900`.
  - **Title**: "Job criteria" — 15px / weight 600 / `--text-loud`, margin 0.
  - **Description** (2px below title): "Plato extracted these from your job description {relative time}." — 12.5px / weight 400 / **line-height 1.3** / `--text-secondary`, tabular figures.
- **Right cell — count rail**: width 186px, `border-left: 1px solid --border`, padding 10px 16px, vertically centered `<ul>`:
  - One row per tier, 30px tall, space-between: left = icon (14px Feather, `currentColor`) + tier label, both 13px `--text-secondary`; right = count, 13px `--text-loud` weight 450, tabular figures.
  - **Icons (decided, "B2" set): Core = `check-circle`, Preferred = `plus-circle`, Bonus = `star`.** All Feather, 2px stroke.
  - **The Bonus row renders only when bonus criteria exist** (most jobs never have any).

**Action row** below the card (flex, gap 14px):
- `View criteria` — secondary Button. Hidden when there are zero criteria.
- `Regenerate criteria` — secondary Button; shows its loading state while extraction runs.
- **No timestamps or counts in this row** (they live in the card), and **never put variables in button labels**.

**Empty states** (replace the card; use the existing `EmptyState` component — standard, NOT `roomy`, NOT `borderless`):
- **Never extracted** (draft job, extraction has not run): `icon="file-text"`, `title="No job criteria have been generated"`, `message="Plato extracts scoring criteria when you publish the job, or you can generate them now."` Action row shows a single secondary button labeled **`Generate criteria`** (not Regenerate); no View button.
- **Extraction ran, found nothing**: `icon="alert-triangle"`, `title="No criteria found"`, `message="No scoring criteria were found in the job description. Plato won't review candidates until it has criteria to score against."` Action row: **`Regenerate criteria`** only; no View button. No reviews may run in this state.

Button label by state: never extracted → `Generate criteria` · otherwise → `Regenerate criteria`. `View criteria` renders only when criteria exist.

### 2 · Sidebar — tier glossary
Rendered via `SettingsContainer`'s sidebar. Follows the Team-roles aside register: h3 title, intro paragraph, then **bold heading + full description under each entry, no dividers**. Sidebar body text is 12px/1.5 `--text-secondary`; entry headings 13px/600 `--text-loud` with the tier icon at 13px; each description's lead sentence is weight 500 `--text-primary`.

- **Title:** Criteria tiers
- **Intro:** Plato extracts scoring criteria from the job description and sorts them into tiers. Section titles decide the tier; words inside an item can also signal it, but the title always wins.
- **Core** (check-circle): **Must-haves. These count most toward a candidate's score.** Plato takes them from sections titled Requirements or Must-haves, and from items with words like critical, required, or essential.
- **Preferred** (plus-circle): **Nice-to-haves. These also count toward the score, less than core criteria.** From sections titled Preferred or Nice to have. Criteria without a strong core or bonus signal land here.
- **Bonus** (star): **A small boost when a candidate has them.** Usually only from sections literally titled Bonus. Not every description produces them.

### 3 · View criteria — FullModal slide-over
Use the codebase's **FullModal** (the 50%-width right panel). Header: title **"Job criteria"** (22px / 600 / tracking -0.02em) with an **X icon button** top-right (28×28 hit area, Feather `x` 16px, `--text-secondary`, hover: `--hover-subtle` wash + `--text-loud`). No footer buttons. Esc and backdrop click also close.

Body (padding 20px sides):
- Description paragraph — **14px / weight 400 / line-height 1.6 / `--text-secondary`** (this exact combination matters; it matches production `SettingsContainer_Description`):
  > New reviews score candidates against these. To change them, edit the job description. Reviews that have already run keep the criteria they were scored against.
- **Criteria list**: one bordered container (1px `--border`, radius 7px). Per tier that has criteria:
  - Tier head row (padding 12px 14px 2px, flex gap 7): tier icon 13px `--text-secondary`, tier label 12px/600 `--text-loud`, count 12px `--text-secondary` tabular. Tiers after the first get a 1px top border and 6px top margin.
  - Tier hint line under the head (padding 0 14px 6px, 12px/1.5 `--text-secondary`): Core — "Must-haves. These count most toward a candidate's score." · Preferred — "Nice-to-haves. These also count toward the score, less than core criteria." · Bonus — "A small boost when a candidate has them."
  - Criterion rows: padding 7px 14px, 13.5px/1.45 `--text-primary`, 1px `--neutral-100` top border between rows. **Read-only — no hover states, no actions.**
- Empty tiers are omitted entirely.

### 4 · Regenerate confirmation modal
Center modal in the **Run Plato modal anatomy** (matches the DS `Modal`): 32rem wide, 24px padding, radius 7px, soft shadow. **Title-only head** (no Plato chip): "Regenerate job criteria?" — 24px / 600 / line-height 1.4.

- Lead paragraph (14/400/1.6 `--text-secondary`, 14px top margin) — this line varies by trigger; only the manual trigger ships now:
  - Manual: "Plato will re-extract scoring criteria from the current job description. Reviews that have already run keep the criteria they were scored against."
  - (Future, after-description-update trigger: "You just updated the job description. Plato can re-extract scoring criteria so new reviews use the latest version." — same modal, different lead and a "Keep current criteria" secondary.)
- **Advice in a bordered statement box** (the `cf-statement` pattern: 1px `--border`, radius 7px, padding 13px 15px, 20px top margin, flex gap 10, 13px/1.5 `--text-secondary`; `refresh-cw` icon 15px in `--text-placeholder`):
  > Regenerating works best when you have changed the parts of the description that affect scoring, like requirements or responsibilities. Keeping regenerations rare keeps scores comparable across candidates. If the criteria change significantly, you can also regenerate all candidate reviews.
- Footer (flex gap 10, 24px top margin): primary `Regenerate criteria`, secondary `Cancel`.

### 5 · Guard modals (after extraction completes)
Same modal shell as the confirmation. Fire based on the total criteria count returned:

- **≤5 criteria — warning (can continue):** title "Only {n} criteria found". Body ¶1: "Plato found only {n} scoring criteria for this job. That usually means the job description is missing a requirements or responsibilities section, or is too general to score against reliably." ¶2: "You can keep these criteria and reviews will run against them, but results may be less useful." Footer: primary `Edit job description` (→ Job setup · Description), secondary `Keep {n} criteria`.
- **0 criteria — hard stop:** title "No criteria found". Body ¶1: "Plato couldn't find any scoring criteria for this job. This can happen when the description only covers things like the company or benefits so far." ¶2: "Candidates won't be reviewed until this job has criteria to score against." Footer: primary `Edit job description`, secondary `Close`. The section shows the zero-criteria empty state, and **no reviews may run while the job has zero criteria**.

## Interactions & Behavior
- `View criteria` → opens the FullModal slide-over. Close via X, Esc, backdrop.
- `Regenerate criteria` → confirmation modal → on confirm, call the regenerate endpoint; button shows loading; on response, update card counts + relative time and fire the guard modal if n ≤ 5 or n = 0. Toast errors through `useToastContext` like the existing save path.
- Manual regeneration is the draft-time affordance; published jobs already re-extract automatically on description edits (existing backend behavior).
- The section is **read-only**: extracted criteria can never be edited or removed in the UI. The only path to change them is editing the job description (auditability requirement).
- Scoring is point-in-time: each review uses the criteria as they stand when it runs; regeneration never rewrites existing reviews. All copy in this design reflects that — do not write "candidates will be rescored".

## State Management
- Criteria payload: tiers keyed `tier_1` (core) / `tier_2` (preferred) / `tier_3` (bonus), each an array of criterion strings, plus an extracted-at timestamp for the card's relative time.
- Local UI state: `viewOpen`, `confirmOpen`, `guard: "low" | "none" | null`, `isRegenerating`.
- Reuse the existing dirty-tracking/save flow untouched; the criteria section performs its own immediate actions and does not participate in Save changes.

## Design Tokens
- Radii: 4 / 5 / **7** (cards, modals here) / 13. Borders: 1px `--border` (neutral-200); row separators `--neutral-100`.
- Type: 24px/600 modal titles · 22px/600 slide-over title · 15px/600 card title · **14px/400/1.6 `--text-secondary` for all description copy** · 13px UI text · 12–12.5px secondary/meta (card description line-height **1.3**). Weights 400/450/500/600 only. Tabular figures on all counts/timestamps.
- Colors: monochrome neutrals only, plus `--accent-gradient` on the Plato disc. No green/red status colors anywhere in this feature.
- Icons: Feather, 2px stroke, 13–16px: `check-circle`, `plus-circle`, `star`, `x`, `refresh-cw`, `alert-triangle`.

## Copy rules (binding)
- No em dashes anywhere. Sentence case everywhere. No emoji.
- Vocabulary: "extract", never "read"; "count most/less toward the score", never "weight/heaviest".
- Button labels are static — never interpolate counts into them.
- Timestamps ("2 hours ago", "just now") live in the card description, never beside buttons.

## Assets
- Plato mark: `PlatoMark.jsx` (bundled) — the sparkle mark used inside the gradient disc; production already has this asset.
- All icons are Feather (already in the codebase).

## Files
- `JobSetupAiSettings-34f2eed8.tsx` — **current production component; the base to extend.**
- `JobSetupAiSettings.reference.tsx` — **reference implementation of the extended component**: full TSX structure (state, handlers, hook suggestions) plus styled-components for the section intro, criteria card, Plato disc, count rail, action row, empty state, sidebar glossary, and guard modals.
- `JobCriteriaModals.reference.tsx` — **reference implementation of both modals** (ViewCriteriaModal + RegenerateCriteriaModal) with their styled-components. Verify prop names against the real FullModal/Modal/Button before shipping.
- `Job criteria - decisions.html` — the decided design, interactive and **self-contained** (open directly in a browser): section card (with/without bonus), both modals firing live, sidebar glossary.
- `JobSetupPlatoAI.jsx` + `setup.css` — the working HTML prototype implementation of the same design (React, uses prototype-local form primitives); closest reference for structure and exact CSS values (`.pai-*` rules at the end of setup.css).
- `PlatoMark.jsx` — the Plato mark SVG component.
