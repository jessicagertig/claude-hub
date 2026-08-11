# Slice map: FE shared components / modals / forms / layouts touched by Plato AI

Scope: `app/javascript/ats/src/components/(shared|modals|forms)/` + `views/(layouts|admin)/`.
Two buckets: (A) NEW Plato-only presentational primitives (low regression risk), (B) EXISTING shared surfaces modified (regression risk to non-AI flows).

## B — EXISTING SHARED SURFACES MODIFIED (regression-relevant)

### BulkMoveModal.tsx  — SHARED, non-AI regression risk
- New prop `roleFit: Array<string>` threaded into the bulk-move mutation payload (`roleFit` field). This is the AI role-fit filter (candidate-list filter chips) so the backend move respects the active filter.
- Success handler now reads `data.movedCount` from the backend response instead of the client `candidatesCount` estimate for BOTH the analytics `trackEvent("bulk_move_completed")` `candidates_count` and the success toast text (`Moved N candidate(s) to <stage>`). Falls back to `candidatesCount` only if `movedCount == null`.
- USER-VISIBLE: after a bulk move (select-all or subset), the toast/count now reflects what the server actually moved (filter-aware), not the unfiltered stage total. Regression to verify: bulk move with NO filter active still shows correct count; select-all vs subset both correct; older backend responses without `movedCount` fall back gracefully.
- Shared surface: bulk move is a core non-AI candidate action. Every caller of `BulkMoveModal` must now pass `roleFit`.

### BulkMessageModal.tsx — SHARED, non-AI regression risk
- New prop `roleFit: Array<string>` added to the bulk-message mutation payload alongside `included/excludedJobApplicationIds`. Same AI role-fit filter passthrough so bulk messaging honors the active filter.
- USER-VISIBLE: bulk message recipient set is filter-aware. Verify unfiltered bulk message still targets the expected candidates. Every caller must pass `roleFit`.

### ConfirmationModal.tsx — SHARED, low risk
- `subcopy` prop type widened from `string` to `React.ReactNode`. Purely additive (allows rich subcopy for AI credit / Plato confirm modals). No behavior change for existing string callers.

### FormCheckbox (forms/FormCheckbox/index.tsx) — SHARED, low/medium risk
- New optional `description?: string` prop; renders a secondary `<Styled.Description>` line under the label and switches the row to `align-items: flex-start` / column label layout when present (`hasDescription`).
- Removed two dead comments; no logic change to `handleClick` (still guards `disabled`, calls `onChange(name, checked)`).
- USER-VISIBLE: checkboxes given a `description` (AI settings toggles) now show helper text. Regression to verify: existing checkboxes WITHOUT description render identically (single-row layout unchanged).

### NavItem.tsx — SHARED, medium regression risk (all left-nav items)
- New optional `rightContent?: React.ReactNode`. Right-side content (`count`, `rightContent`, `chevron`) now wrapped in a new `StyledRight` flex container.
- CSS selector for the hover/active icon reveal changed from `> svg` to `> *:last-child > svg` in `linkStyles` (three spots: base, `.active`, `:hover`). This is because the trailing icon is now nested inside `StyledRight`.
- REGRESSION RISK: this restructures every nav item's markup + the icon opacity-reveal rules. Verify across ALL left-nav items (not just AI/Plato nav): chevron/count still appear, hover reveals the chevron icon, active state styling intact. The `> *:last-child > svg` change is the highest-risk line in this slice for non-AI regression.

### DropdownMenu.tsx — SHARED, low risk
- New optional `badge?: React.ReactNode` slot rendered as absolutely-positioned `Styled.Badge` (top/right -3px, `pointer-events:none`, z-index 1) over the toggle. Additive; existing dropdowns without `badge` unaffected. Used by candidate-list filter to show active-filter count.

### views/admin/AdminDashboardCustomers.tsx — low risk
- Added `testid="organization-actions-menu"` to the org-actions `DropdownMenu`. Test-hook only, no behavior change.

### views/layouts/App.tsx — none
- Only reformatted the commented-out `ReactQueryDevtools` line. No behavior change.

### shared/FeatureFlipper.tsx — feature gate
- Adds enum value `AI_APPLICANT_SUMMARY = "AI_APPLICANT_SUMMARY"` to `Features`. This is the gate for the whole Plato AI applicant-summary UI. QA precondition: org must have this feature flag enabled to see Plato surfaces.

## A — NEW PLATO-ONLY PRESENTATIONAL PRIMITIVES (no existing behavior touched)
All brand-new files, imported only by Plato AI surfaces; no regression to non-AI:
- `shared/Accordion.tsx` — Accordion / AccordionRow / AccordionSection with react-spring Collapse (respects `prefers-reduced-motion`). Used for expandable AI review sections.
- `shared/CountBadge.tsx` — generic numeric overlay badge; renders null at count<=0, caps at `max` (default 9 → "9+"). Feeds DropdownMenu `badge` slot (active-filter count).
- `shared/PlatoCtaButton.tsx` — Overview-header entry into the Plato tab. `reviewed` toggles label "Ask Plato" vs "View Plato review"; `variant` outlined (default, chevron) vs fill (accent gradient).
- `shared/PlatoMark.tsx` — PlatoMark (sparkle/sparkles/wand icon, optional `spinning`) + PlatoChip gradient container.
- `shared/PlatoHourglass.tsx` — small hourglass icon (pending/processing indicator).
- `shared/WandIcon.tsx` — static wand SVG icon.

No pipeline/model/provider files in this slice.
