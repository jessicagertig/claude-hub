# SPEC: Plato AI Review Tab

## Summary

Replace the inline AI summary display in the candidate review activity feed with a dedicated "Plato" tab in the candidate sidebar navigation. The current `AiJobApplicationSummaryFeedItem` (a card in the Overview tab's activity feed) and `AiSummaryState` (the generate-button empty state) are replaced by three things: (1) a new sidebar nav item that opens a full Plato tab, (2) a rich Plato tab page with 6 distinct states, and (3) a compact callout card on the Overview tab that links into the Plato tab.

This is a frontend-only change. No backend/API/model changes. The AI summary data already flows through the API via `AiJobApplicationSummaryShallowSerializer` (on `jobApplication`) and `AiJobApplicationSummarySerializer` (on the dedicated show endpoint). The structured data fields the new design consumes (`assessment.keySkills`, `assessment.primaryDomain.name`, `assessment.secondaryDomain.name`, `assessment.standoutAccomplishments`, `roleAnalysis`, `applicableExperience`, `gaps`, `skills`) are already present in `AiResumeStructuredData` and returned by the full serializer. (All field names are camelCase as received by the frontend after the API layer's automatic snake_case-to-camelCase transform.)

## Stack scope

**Frontend only.** Changes are within `app/javascript/ats/` and `app/javascript/shared/`.

No backend changes: no new controllers, serializers, models, routes, or migrations. The existing `useGenerateAiSummary` mutation, `useAiJobApplicationSummary` query, and `useOrganizationAiCreditBalance` query provide all needed data and actions.

## Data model changes

None.

## API changes

None.

## Frontend changes

### New files to create

#### 1. `PlatoMark` component

**Path:** `app/javascript/ats/src/components/shared/PlatoMark.tsx`

Two exports:
- `PlatoMark` -- the SVG star glyph. Props: `variant` (`"sparkle"` | `"sparkles"` | `"wand"`, default `"sparkle"`), `size` (number, default 16). Uses `currentColor` for stroke/fill. The SVG paths are provided in the design handoff at `claude-design-handoff/files/PlatoMark.jsx`. The SVG element must include `aria-hidden="true"` since this is a decorative icon (the existing `Icon` component does NOT add `aria-hidden` automatically -- this must be explicit).
- `PlatoChip` -- the star centered in a pink-to-peach accent-gradient rounded square. Props: `size` (number, default 28), `radius` (number, default 7), `variant` (same as PlatoMark, default `"sparkle"`). The gradient is `linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)` with an `inset 0 0 0 1px rgba(0,0,0,0.07)` hairline. The star size inside the chip is `Math.round(size * 0.62)`.

Must use Emotion styled components. The gradient must work in dark mode (same gradient in both modes -- it is a brand element, not a surface color). The glyph color inside the chip is always dark (`colors.gray[900]` / `#171717`), regardless of dark mode -- verified against the design.

**Pattern to follow:** `WandIcon` at `app/javascript/ats/src/components/shared/WandIcon.tsx` for inline SVG pattern. But `PlatoMark` is more complex (3 variants, parameterized size).

#### 2. `PlatoTab` component

**Path:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`

The main Plato tab page rendered in pane 4. Receives props:
- `jobApplication: any` -- the full jobApplication object (contains `aiJobApplicationSummary`, `hasResume`, `id`)

Internally fetches:
- Full structured data via `useAiJobApplicationSummary({ jobApplicationId, aiJobApplicationSummaryId })` -- only when a summary exists and status is `succeeded`
- Credit balance via `useOrganizationAiCreditBalance()`
- Generate/regenerate via `useGenerateAiSummary()` mutation

**Structure:** Follows the same container pattern as other tabs. The outer container is a flex column filling height. The top is a header bar (`.tab-title` equivalent) with the PlatoChip (26px) + "Plato" label on the left, and either a "Regenerate" ghost button (when succeeded) or a kebab icon button (otherwise) on the right. Below is a scrollable body with a 720px max-width centered column, `22px 28px 56px` padding.

**State machine -- body content switches on review status:**

The state machine has two levels: first check whether a summary exists, then branch on status. When a summary exists, status-based conditions apply (rows 1-4). When no summary exists, check `hasResume` (rows 5-6). Evaluate in the order listed -- first match wins.

| Condition | Body content |
|---|---|
| `status === "succeeded"` | `PlatoSucceeded` -- full rich layout (see below) |
| `status` is `"pending"` or `"in_progress"` or `"extracted"` | `PlatoGenerating` -- shimmer skeleton + animated dots pill |
| `status === "textract_processing"` | `PlatoProcessing` -- "Plato is waiting on the resume" zero-state |
| `status === "failed"` | `PlatoFailed` -- error state with "Try again" button |
| No summary exists AND `jobApplication.hasResume` is truthy | `PlatoEmpty` -- "Plato hasn't reviewed this candidate yet" with "Generate summary" button |
| No summary exists AND `jobApplication.hasResume` is falsy | `PlatoNoResume` -- "Plato needs a resume" with no action |

**Succeeded layout (top to bottom):**

1. **Provenance line** -- "Generated by Polymer Plato" + separator dot + relative timestamp from `aiSummary.createdAt`. Use `distanceInWords(aiSummary.createdAt)` from `@shared/lib/time` -- this is an already-exported helper that accepts ISO 8601 strings (via `new Date(date)`) and includes `{ addSuffix: true }` by default, producing "3 days ago" etc. **Do NOT use `timeAgoInWordsShort`** (expects Unix-seconds number, not ISO strings). The separator dot uses `theme.poly.color.border` (neutral-300 equivalent). The text uses `theme.poly.color.secondaryText`.
2. **Stale banner** (conditional on `aiSummary.stale === true`) -- a row with well background, alert-triangle icon, "The resume changed after Plato wrote this summary.", and a "Regenerate . 1 credit" text button on the right. Clicking triggers the generate mutation.
3. **Headline** -- `<h1>`, 23px, line-height 1.28, weight 600, letter-spacing -0.02em, `theme.poly.color.loudText`, `text-wrap: pretty`. Sourced from `aiSummary.headline`.
4. **Domain label** -- primary domain + secondary domain from `structuredData.assessment.primaryDomain.name` and `structuredData.assessment.secondaryDomain.name` (camelCase -- the API layer auto-transforms from backend snake_case). Primary is `loudText`, secondary is `secondaryText`. Separator is a 3px filled circle (`colors.gray[500]`), not a text dot. 16px bottom margin.
5. **"Fit for this role" card** -- a bordered card (1px `theme.poly.color.border`, 9px radius, `16px 20px 20px` padding) with a 3px accent-gradient bar on the left edge (absolutely positioned). Header: 15px PlatoMark (in `colors.gray[700]`) + "Fit for this role" label (13.5px/600/loudText). Body: the `structuredData.roleAnalysis` text (falls back to `aiSummary.summaryText` if absent). 15px / 24px line-height / `primaryText`.
6. **Notable achievements** -- eyebrow label "Notable achievements" + list of items from `structuredData.assessment.standoutAccomplishments` (camelCase). Each item: 15px `award` Feather icon + text (14px/21px lh/primaryText). 9px gap between items. Omit entire section if empty array.
7. **Relevant experience** -- eyebrow "Relevant experience" + prose paragraph from `structuredData.applicableExperience`. 14.5px/23px lh/primaryText, max-width 66ch. Omit if falsy.
8. **Gaps to probe** -- eyebrow "Gaps to probe" + prose from `structuredData.gaps`. Same styling. Omit if falsy.
9. **Skills** -- eyebrow "Skills" + chip cloud from `structuredData.skills`. Key skills (from `structuredData.assessment.keySkills`, camelCase) are sorted to the front and emphasized: `loudText` color, `${t.dark ? t.color.gray[700] : t.color.gray[100]}` fill (requires `t.dark` ternary -- no `chipCanvas` poly token exists). Non-key skills: `primaryText` color, transparent fill. Each chip: 13px, 1px `theme.poly.color.chipBorder`, 4px radius, `3px 10px` padding. Omit if empty array.
10. **Footer disclaimer** -- 30px top margin, 14px top padding, 1px divider top border. `info` icon (13px, `colors.gray[400]`) + "Plato can be wrong. Always confirm against the resume before deciding." (12px, `placeholderText`).

**Eyebrow style:** uppercase, small, tracked. The design references `.poly-eyebrow` but this CSS class does not exist in the codebase. Implement as a styled component: `text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; color: ${theme.poly.color.secondaryText}`. Spread `t.text.xs` standalone in an array (e.g., `${[t.text.xs]}`) -- do NOT use it inside a `font-size:` property, as `t.text.xs` is a complete CSS declaration that already includes `font-size:` (Known Failure Pattern #1). Follow the pattern already used in `AiJobApplicationSummaryFeedItem` `Styled.SectionTitle` (lines 317-326 of that file). Note: the analog uses `t.dark ? t.color.gray[400] : t.color.gray[500]` for color, while this spec intentionally upgrades to the Poly DS `secondaryText` token (`gray[600]` in light mode).

**Empty / Failed action layout:** The credit hint ("Uses 1 credit . N remaining" for empty, "Uses 1 credit" for failed) must be stacked below the centered button in a column layout with 8px gap, centered. NOT inline beside the button.

**Generating skeleton:** Pill with three pulsing dots (5px circles, `colors.gray[500]`, staggered 0.16s animation delays) + "Plato is reading the resume and writing the summary..." label. Below: shimmer bars using a CSS `@keyframes` animation (`linear-gradient(90deg, gray[100], gray[200], gray[100])` sweeping 1.4s). Both animations must have `@media (prefers-reduced-motion: reduce) { animation: none; }`.

**Generate / Regenerate / Try again actions:** All trigger `useGenerateAiSummary` mutation with `{ jobApplicationId: jobApplication.id }`. On success, the websocket handler (`WebsocketGlobalChannelHandler.tsx` lines 212-228) invalidates `["jobApplication"]` and `["aiJobApplicationSummary"]` queries, causing React Query to refetch and the UI to update automatically.

**Credit balance display:** Use `useOrganizationAiCreditBalance()` hook. Display `totalCreditsRemaining` in the hint copy. When credits are zero and a generate action would be shown, show the existing buy-credits pattern from `AiSummaryState.tsx` lines 58-91 (admin link to `/hire/settings/ai-billing`, non-admin modal).

**Pattern to follow:** The overall structure follows the same pattern as `JobApplicationActivity.tsx` (a `Styled.Container` flex column with a `Styled.Title` header bar and a scrollable body below). For state machine switching, follow the pattern in `AiJobApplicationSummaryFeedItem.tsx` lines 82-112.

#### 3. `PlatoOverviewCallout` component

**Path:** `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx`

A clickable card placed in the Overview tab activity feed. Props:
- `jobApplication: any`
- `onOpen: () => void` -- callback to navigate to Plato tab

**Structure:** A flex row card with: a 3px accent-gradient left bar (absolutely positioned), a PlatoChip (32px, 8px radius), a title + subtitle text column, and a right-aligned CTA label with `chevron-right` icon.

**State-dependent copy:**

Evaluate in the same order as PlatoTab: when a summary exists, check status first (rows 1-4); when no summary exists, check `hasResume` (rows 5-6). The table rows are listed in evaluation order -- first match wins. "No summary AND no resume" (row 6) must NOT match when a summary exists with a failed/generating status and hasResume is false -- those are covered by the status-based rows.

| State | Title | Subtitle | CTA |
|---|---|---|---|
| Succeeded, not stale | "Read what Plato thinks about this candidate" | `aiSummary.headline` | View |
| Succeeded, stale | "Plato's review is out of date" | `aiSummary.headline` | View |
| Failed | "Plato couldn't finish" | "No credit was used -- open to retry." | View |
| Generating (pending/in_progress/extracted/textract_processing) | "Plato is reading the resume..." | "This will be ready in a moment." | View |
| No summary AND has resume | "Ask Plato to review this candidate" | "Plato reads the resume for role fit, experience, skills and gaps." | Generate |
| No summary AND no resume | "Plato needs a resume" | "Add one to this candidate and Plato can review them." | View |

Clicking the entire card calls `onOpen()`. **All CTA labels are display-only text.** The card always navigates to the Plato tab on click; it never triggers the `useGenerateAiSummary` mutation directly. The "Generate" label for the no-summary+has-resume state is a visual hint, not an action -- the actual generate button lives inside the PlatoTab's empty state. The card has a connector tick below it (a 4px-wide, 24px-tall divider line, matching the feed connector pattern in `Styled.Event` `::after` pseudo-element at `JobApplicationActivity.tsx` lines 671-681).

**Styling:** Uses Emotion styled components. Card: 1px `theme.poly.color.border`, `theme.poly.radii.md` radius (7px), `theme.poly.color.cardCanvas` background. Hover: border changes to `borderHover`. Transition: `border-color 0.2s ease`. Title: 14px/600/loudText. Subtitle: 13px/secondaryText, single line with text overflow ellipsis.

### Existing files to modify

#### 4. `JobApplicationContainer.tsx` -- add Plato tab route

**Path:** `app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx`

**Changes:**
- Import `PlatoTab` component
- Import `FeatureFlipper`, `useFeatureFlipper`, and `Features` from `@ats/src/components/shared/FeatureFlipper`
- Add a new `<Route>` for path `${match.path}/ai` that renders `PlatoTab`, passing `jobApplication`. Place it inside the `<Switch>` block, after the `/notes` route (line 272) and before `{redirector()}` (line 275).
- Wrap the new route in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">`.
- Add `"ai"` to the `possiblePaths` array **conditionally**: use `useFeatureFlipper` to check `AI_APPLICANT_SUMMARY`, and only include `"ai"` in the array when the flag is on. This is critical -- if `"ai"` is unconditionally in `possiblePaths` but the Route is gated by FeatureFlipper, the `redirector()` function (lines 185-191) will redirect `/ai` back to `/ai` in an infinite loop when the flag is off. With conditional inclusion, when the flag is off `currentViewPath` will not be set to `"ai"`, and `redirector()` will fall through to redirect to `/overview`. Example: `const possiblePaths = ["overview", "resume", "messages", "files", "notes", ...(isAiEnabled ? ["ai"] : [])];` where `isAiEnabled` comes from `useFeatureFlipper()({ feature: Features.AI_APPLICANT_SUMMARY })` (use the `Features` enum, not a string literal -- this is the codebase convention for hook usage). Define `isAiEnabled` at the component top level (hooks cannot be called inside useEffect), then reference it inside the useEffect callback where `possiblePaths` is currently defined.

**Lines affected:** 150-158 (possiblePaths -- must be made dynamic), 273-275 (route insertion point).

#### 5. `JobApplicationSidebar.tsx` -- add Plato nav item

**Path:** `app/javascript/ats/src/views/jobApplications/JobApplicationSidebar.tsx`

**Changes:**
- Import `PlatoChip` from the new `PlatoMark` component
- Import `FeatureFlipper` from `@ats/src/components/shared/FeatureFlipper`
- Import `isPropValid` from `@emotion/is-prop-valid`, `Box` from `@shared/components/Box`, and `Text` from `@shared/components/Text` (needed for the `StyledLabel` inner wrapper pattern)
- After the last `NavItem` (line 92, Private notes), add a new Plato nav entry wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">`.

**The Plato nav item cannot use the standard `NavItem` component.** `NavItem` (at `app/javascript/ats/src/components/shared/NavItem.tsx`) renders icons via the `Icon` component which only accepts Feather icon name strings (line 31). The Plato entry requires a custom gradient chip, not a Feather icon.

Instead, create a custom `PlatoNavItem` styled component directly in `JobApplicationSidebar.tsx` (or extract to a small helper). It must:
- Wrap `NavLink` via `styled(NavLink, { shouldForwardProp: isPropValid })` using `isPropValid` from `@emotion/is-prop-valid` -- this matches `NavItem.tsx` line 101 and prevents custom props from leaking to the DOM.
- Link to `${match.url}/ai`
- Render `PlatoChip` (size 22, radius 6) in place of the icon slot
- Render "Plato" as the label text
- Render a `chevron-right` icon on the right
- Copy `linkStyles` from `NavItem.tsx` lines 56-95 **verbatim** and adapt only the icon slot. The linkStyles include properties the spec must not omit: `text-decoration: none`, a `${breakpoint.sm}` responsive gate that restricts `:hover` to sm+ breakpoints, and `> svg` base styles (`transition: opacity 0.2s ease; flex-shrink: 0; opacity: 0`) that control chevron visibility on hover/active. Copy the entire function rather than reconstructing it.
- Also replicate the `StyledLabel` inner wrapper pattern from `NavItem.tsx` lines 103-118, which provides `display: flex; align-items: center; overflow: hidden;` for the icon + text alignment, text truncation, and `svg { margin-right: 8px; flex-shrink: 0; }` for icon spacing.

#### 6. `JobApplicationActivity.tsx` -- replace inline AI display with callout

**Path:** `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx`

**Changes:**
- Remove import of `AiJobApplicationSummaryFeedItem` (line 10)
- Remove import of `AiSummaryState` (line 11)
- Add import of `PlatoOverviewCallout`
- Replace the `FeatureFlipper` block (lines 395-404) that currently renders either `AiJobApplicationSummaryFeedItem` or `AiSummaryState` with a `FeatureFlipper` block that renders `PlatoOverviewCallout`. The callout receives `jobApplication={jobApplication}` and `onOpen` that navigates to the Plato tab.

**Navigation from callout to Plato tab:** The `onOpen` callback must navigate to the `/ai` sub-path. Use `history.push(\`${match.url}/ai\`)`. The `history` prop is already typed and destructured (line 40), but `match` is not -- it arrives via `{...renderProps}` spread from the Route render callback (JobApplicationContainer.tsx line 230) but is not in the `Props` type (lines 34-38) and not destructured. **Add `match: any` to the `Props` type and add `match` to the function parameter destructuring** so it is explicitly available.

**Lines affected:** 10-11 (imports), 395-404 (FeatureFlipper block).

### TypeScript type changes

#### 7. Expand `AiResumeStructuredData.assessment` type

**Path:** `app/javascript/shared/types/aiJobApplicationSummary.ts`

The `assessment` field is currently typed as `any` (line 32). The Plato tab consumes specific fields from it. Add a proper interface:

```typescript
export interface AiAssessment {
  primaryDomain: { name: string; reasoning: string } | null;
  secondaryDomain: { name: string; reasoning: string } | null;
  tertiaryDomain: { name: string | null; reasoning: string } | null;
  keySkills: string[];
  standoutAccomplishments: string[];
  careerNarrative?: string;
  experienceClassifications?: any[];
}
```

Note: `tertiaryDomain` is not consumed by the Plato tab UI but is always present in the backend response. `reasoning` is required by the backend schema (not optional). The `| null` on `primaryDomain`/`secondaryDomain` is defensive -- both are always present in practice, but this guards against unexpected data.

Update `AiResumeStructuredData` to use `assessment?: AiAssessment` instead of `assessment?: any`.

This is a non-breaking type refinement -- existing code that accesses `assessment` as `any` will continue to work, and new code gets type safety.

## Authorization requirements

No new authorization requirements. The feature remains gated behind the `AI_APPLICANT_SUMMARY` FeatureFlipper (enum value at `FeatureFlipper.tsx` line 128), which is checked at three levels: global boolean, per-org actors, and plan-based groups. The same flipper gates the current inline display, so the same orgs that see the old UI will see the new one.

The generate/regenerate mutations use the existing `ValidateAiSummaryGeneration` interactor on the backend, which handles credit checking and authorization. No frontend authorization changes needed.

## Constraints and requirements

### Feature flag gating

All three new UI surfaces (nav item, tab, callout) must be wrapped in `FeatureFlipper` or gated via `useFeatureFlipper` checking `"AI_APPLICANT_SUMMARY"`. When the feature is disabled, the sidebar nav must show no Plato entry, the Overview tab must show no callout, and the `/ai` route must redirect to `/overview`.

### Dark mode

Every styled component must provide dark mode variants. The codebase uses two patterns:
- Old theme: `${t.dark ? t.color.gray[200] : t.color.black}` (ternary on `t.dark` boolean)
- Poly DS: `${t.poly.color.loudText}` (automatically resolves based on which theme is active)

Prefer Poly DS tokens where they exist (loudText, secondaryText, placeholderText, border, borderHover, wellCanvas, cardCanvas, chipBorder, etc.). Fall back to `t.dark` ternaries only for values that Poly DS does not cover (e.g., specific gray scale values like `gray[700]` for icon colors).

The accent gradient (`linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)`) is a brand color and does NOT change between light and dark mode. The glyph inside the chip is always `colors.gray[900]` (#171717) regardless of mode.

### Emotion styled component conventions

All styled components use the `Styled.*` namespace pattern:
```typescript
let Styled: any = {};
Styled.ComponentName = styled.div((props: any) => {
  const t: any = props.theme;
  return css`
    label: ParentComponent_ComponentName;
    // styles
  `;
});
```

Every styled component must have a `label` property for debugging. The label format is `ParentComponentName_StyledElementName`.

### Shimmer and dot animations

The generating state uses two CSS keyframe animations. Define both using Emotion `keyframes` (imported from `@emotion/react`). No existing `prefers-reduced-motion` pattern exists in this codebase, so this feature establishes the convention: nest `@media (prefers-reduced-motion: reduce) { animation: none; }` inside each animated styled component's `css` block (co-located with the animation declaration).

The shimmer animation keyframes sweep the background position:
```
@keyframes shimmer {
  0% { background-position: -600px 0; }
  100% { background-position: 600px 0; }
}
```
Applied via: `background-image: linear-gradient(90deg, gray[100] 0px, gray[200] 60px, gray[100] 120px); background-size: 600px 100%; animation: shimmer 1.4s ease-in-out infinite;`

The dot animation: three 5px circles with staggered 0.16s delays, pulsing opacity and slight Y translation over 1.1s.

### Button component compatibility

The existing `Button` component (`app/javascript/ats/src/components/shared/Button/index.js`) has two key props:
- `styleType` -- controls visual style. Values: `"primary"` (default), `"secondary"`, `"white"`, `"text"`. The design's "ghost" button variant maps to `styleType="text"`.
- `type` -- controls the rendered element. Values: `"internalLink"` (renders React Router `<Link>`), `"externalLink"` (renders `<a>`), default (renders `<button>`). The admin buy-credits button uses `type="internalLink"` with `link="/hire/settings/ai-billing"`.

It does NOT have an `iconLeft` prop. Icons must be rendered as children alongside text, not via a prop.

For the header bar Regenerate button: `<Button styleType="text" onClick={handleRegenerate}><Icon name="refresh-cw" /> Regenerate</Button>`. Style the icon inline within the button text.

For the Generate/Try again buttons in zero states: `<Button onClick={handleGenerate}>Generate summary</Button>` (primary is the default styleType).

### Real-time updates via WebSocket

When a summary generation completes, the `WebsocketGlobalChannelHandler` (`app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` lines 212-228) receives an `AI_SUMMARY_COMPLETE` event and invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, and `["organizationAiCreditBalance"]` queries. This causes React Query to refetch, and the Plato tab will re-render with the new data. No additional WebSocket handling is needed.

### Timestamp formatting

**Do NOT use `timeAgoInWordsShort` for the provenance timestamp.** That function expects a Unix-seconds number (it does `datetime * 1000`), but `aiSummary.createdAt` is an ISO 8601 string. Passing a string would produce `NaN` and crash. Use `distanceInWords(aiSummary.createdAt)` from `@shared/lib/time` instead -- it accepts ISO strings, includes `{ addSuffix: true }` by default, and is already exported.

### No `monthsByDomain` bar chart

The design spec explicitly removes the experience-by-domain bar chart. The `AiExpStrip` function exists in the prototype but is intentionally unused. Do not render `structuredData.monthsByDomain`, `structuredData.totalMonthsExperience`, or `structuredData.overlapSummary`.

### Backward compatibility

The old `AiJobApplicationSummaryFeedItem` and `AiSummaryState` components are not deleted -- they are simply no longer imported or rendered in `JobApplicationActivity.tsx`. They can be removed in a follow-up cleanup if desired, but leaving them in place means the change is safer to revert.

### Accessibility

- All icons must have `aria-hidden="true"`. **Note:** The existing `Icon` component does NOT add `aria-hidden` automatically (neither does `react-feather`). This is a pre-existing gap. For this feature, add `aria-hidden="true"` explicitly to all SVG elements in `PlatoMark.tsx`. Feather icons rendered via `<Icon>` in the new components inherit the existing (lacking) behavior -- fixing the `Icon` component is out of scope.
- The shimmer and dot animations must respect `prefers-reduced-motion: reduce` (see Shimmer section for the Emotion implementation pattern).
- The callout card must be a `<button>` element with reset CSS (`appearance: none; background: none; border: none; padding: 0; text-align: left; width: 100%; cursor: pointer; font: inherit;`), then apply the card styling on top. A native `<button>` gets keyboard handling for free (Enter and Space activation) without needing manual `onKeyDown` handling. This is a new pattern for the codebase (no existing card-as-button analog exists).
- The Plato tab nav item must be a proper `NavLink` for keyboard navigation and screen reader accessibility.

## Existing patterns to follow

### Tab container structure

Every tab in the candidate review follows this pattern (example: `JobApplicationActivity.tsx`):
```
Styled.Container (flex column, height: 100%)
  Styled.Title (header bar with border-bottom)
  Styled.Feed/Body (flex-grow: 1, overflow-y: auto)
```
The Plato tab must follow this exact structure.

### Styled component organization

Place styled components at the bottom of the file after the component definition, prefixed with `/* Styled Components */` comment. See every file in `app/javascript/ats/src/views/jobApplications/` for this pattern.

### NavItem styling

The custom Plato nav item must visually match existing `NavItem` instances. Copy the `linkStyles` function from `NavItem.tsx` lines 56-95 **verbatim** and the `StyledLabel` wrapper from lines 103-118. Adapt only the icon slot (renders `PlatoChip` instead of `<Icon>`). Do not reconstruct the styles from description -- `linkStyles` includes responsive hover gating (`${breakpoint.sm}`), `> svg` opacity transitions for chevron visibility, and other details that are easy to miss if paraphrased.

### Activity feed event connectors

The callout card on the Overview tab has a connector tick below it (a thin vertical line connecting it to the next feed item). This matches the `::after` pseudo-element pattern used on `Styled.Event` in `JobApplicationActivity.tsx` lines 671-681 and `Styled.QuestionResponses` lines 526-533. Use the same width (4px), color (`t.dark ? t.color.gray[800] : t.color.gray[200]`), and positioning.

### AI summary data fetching

The existing `AiJobApplicationSummaryFeedItem` fetches the full structured data lazily via `useAiJobApplicationSummary` (line 33-36). The Plato tab should do the same: use the shallow `aiJobApplicationSummary` from the `jobApplication` object for status checks, then fetch the full data only when status is `succeeded` and the rich layout needs rendering.

### Generate mutation pattern

Follow the exact pattern from `AiSummaryState.tsx` lines 31-47 for the generate action: call `useGenerateAiSummary()`, pass `{ jobApplicationId }`, show success toast "Summary generation queued", show error toast with the server error message.

### Credit balance and out-of-credits handling

Follow the pattern from `AiSummaryState.tsx` lines 49-108 for the zero-credits logic: check `totalCreditsRemaining`, when zero show the admin-link (`type="internalLink"` to `/hire/settings/ai-billing`) or non-admin-modal pattern. The `useOrganizationAiCreditBalance` hook returns `{ data: creditData, isError, isLoading }`. Use `creditData?.totalCreditsRemaining || 0` with the `isError` fallback. **Note:** The credit hint copy in this spec ("Uses 1 credit . N remaining", "Uses 1 credit", "Regenerate . 1 credit") is intentionally richer than the analog's simple "1 credit" label. Follow the spec copy, not the analog copy.

## Test requirements

### Existing tests to verify

Search the test suite for any tests covering `AiJobApplicationSummaryFeedItem`, `AiSummaryState`, or the `AI_APPLICANT_SUMMARY` feature flag in the context of the Overview tab. These tests may need updating since the Overview tab's AI content changes from the full inline display to a compact callout.

Run: `grep -rn "AiJobApplicationSummaryFeedItem\|AiSummaryState\|AI_APPLICANT_SUMMARY" spec/ cypress/` to enumerate affected test files.

### New test coverage needed

At minimum:
1. The Plato tab renders the correct state for each of the 6 statuses
2. The callout card renders the correct copy for each state
3. The nav item appears when `AI_APPLICANT_SUMMARY` is enabled and is hidden when disabled
4. Generate/regenerate actions call the mutation correctly
5. The `/ai` route renders the Plato tab
6. Navigation from callout to Plato tab works

The test infrastructure for this component area (Cypress vs RSpec feature specs vs Jest component tests) should be determined by checking what test tooling covers the existing `JobApplicationContainer` and its tabs.

## Files summary

### New files (3)
- `app/javascript/ats/src/components/shared/PlatoMark.tsx`
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
- `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx`

### Modified files (4)
- `app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx` -- add `/ai` route + import
- `app/javascript/ats/src/views/jobApplications/JobApplicationSidebar.tsx` -- add Plato nav item
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- replace inline AI display with callout
- `app/javascript/shared/types/aiJobApplicationSummary.ts` -- expand `assessment` type from `any` to `AiAssessment`

### Files NOT changed
- `app/javascript/ats/src/components/shared/NavItem.tsx` -- not modified; the custom Plato nav item is built separately
- `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` -- not deleted, just no longer imported
- `app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx` -- not deleted, just no longer imported
- All backend files -- no changes
