# Implementation Plan: Plato AI Review Tab

**For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary

Replace the inline AI summary display in the candidate review Overview tab with a dedicated "Plato" tab. Three new components (`PlatoMark`, `PlatoTab`, `PlatoOverviewCallout`) and four modified files. Frontend-only -- no backend/API changes.

**Worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.ai-display`
**Branch:** `ai-display`
**Spec:** `/Users/jessica/claude-hub/inflow-ats/2026-06-11-ai-display/SPEC.md`

---

## Required Reading Before Starting

Read these cursor_rules files before writing any code:
- `cursor_rules/core_critical_rules.md` -- rules 2 (theme colors), 7 (camelCase), 9 (never set undefined)
- `cursor_rules/frontend/_base.md` -- rules 1 (no `??`), 2 (no undefined), 3 (trust API transform), 4 (pragmatic `any`)
- `cursor_rules/frontend/ui_styling.md` -- Emotion conventions, dark mode, label convention

---

## Pattern Precedents

These are existing files the implementer must study for patterns to replicate. Line numbers are current as of this plan.

### Styled component namespace pattern
Every file uses:
```typescript
let Styled: any;
Styled = {};
Styled.ComponentName = styled.div((props: any) => {
  const t: any = props.theme;
  return css`
    label: ParentComponent_ComponentName;
    // ...
  `;
});
```
**Analogs:** `AiSummaryState.tsx` lines 129-222, `JobApplicationActivity.tsx` lines 444-754

### Tab container structure
```
Styled.Container (flex column, height: 100%)
  Styled.Title (header bar with border-bottom)
  Styled.Body (flex-grow: 1, overflow-y: auto)
```
**Analog:** `JobApplicationActivity.tsx` -- `Styled.Container` (lines 447-455), `Styled.Title` (lines 457-469), `Styled.Feed` (lines 493-502)

### NavItem linkStyles
**File:** `NavItem.tsx` lines 56-95 -- the full CSS function that must be copied verbatim for the custom Plato nav item. Key properties: 32px height at `breakpoint.sm`, `radii.sm` border-radius, `.active` state with `subtleHover` background, `:hover` gated inside `${breakpoint.sm}`, `> svg` opacity transition for chevron.

### NavItem StyledLabel wrapper
**File:** `NavItem.tsx` lines 103-118 -- the `Box`-based flex container for icon + text alignment. Must be replicated for the Plato nav item.

### Dark mode with Poly DS tokens
**File:** `lightTheme.ts` lines 1-36 -- defines poly tokens: `loudText`, `primaryText`, `secondaryText`, `placeholderText`, `border`, `borderHover`, `wellCanvas`, `cardCanvas`, `chipBorder`.
**File:** `darkTheme.ts` lines 1-36 -- dark mode equivalents.
Use `theme.poly.color.*` tokens where they exist. Fall back to `t.dark` ternaries for values not covered (e.g., specific gray steps like `gray[700]` for icon colors).

### Eyebrow style
**File:** `AiJobApplicationSummaryFeedItem.tsx` lines 317-326 (`Styled.SectionTitle`):
```
${[t.mb(2), t.text.xs]}
font-weight: 600;
text-transform: uppercase;
letter-spacing: 0.05em;
color: ${t.dark ? t.color.gray[400] : t.color.gray[500]};
```
The spec upgrades color to `theme.poly.color.secondaryText` (`gray[600]` light / `gray[400]` dark).

### Generate mutation pattern
**File:** `AiSummaryState.tsx` lines 31-47 -- success toast "Summary generation queued", error toast with `error?.data?.errors?.general?.[0] || "Failed to queue summary"`, `kind: "warning"`, `delay: 10000`.

### Credit balance and out-of-credits pattern
**File:** `AiSummaryState.tsx` lines 58-91 -- check `totalCreditsRemaining`, admin gets `<Button type="internalLink" link="/hire/settings/ai-billing">`, non-admin gets `CenterModal`.

### Activity feed connectors (::after pseudo-element)
**File:** `JobApplicationActivity.tsx` lines 671-681 (`Styled.Event` `::after`) and lines 522-533 (`Styled.QuestionResponses` `::after`):
```
&:after {
  content: "";
  display: block;
  position: absolute;
  left: ${t.spacing[6]}; // or left: 1.75rem
  top: 100%;
  width: 4px;
  margin-left: -2px;
  height: ${t.spacing[6]};
  background-color: ${t.dark ? t.color.gray[800] : t.color.gray[200]};
}
```

### Emotion keyframes pattern
**File:** `Button/index.js` line 6: `import { css, keyframes } from "@emotion/react";`
**File:** `Button/index.js` line 349: `const loadingAnimation = keyframes\`...\``
Also: `GrowlNotification/index.js` lines 127-148, `LoadingIndicator/index.js` lines 84-93.

### FeatureFlipper usage
**File:** `FeatureFlipper.tsx` -- component wrapping (line 64) and `useFeatureFlipper` hook (line 95).
**Enum:** `Features.AI_APPLICANT_SUMMARY` at line 128.
Hook usage: `const isEnabled = useFeatureFlipper(); if (isEnabled({ feature: Features.AI_APPLICANT_SUMMARY })) { ... }`

### Inline SVG icon pattern
**File:** `WandIcon.tsx` -- simple inline SVG component. `PlatoMark` follows this pattern but is more complex (3 variants, parameterized size).

### Theme radii
**File:** `shared/styles/theme.ts`: `radii: { xs: "4px", sm: "5px", md: "7px", lg: "13px" }`

### Available gray scale
**File:** `shared/styles/colors.ts`: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900. No 150 exists in the shared colors file (the `ats/styles/theme.ts` has 150 but only in its local `baseColors`).

### Time helper
**File:** `shared/lib/time.ts` line 89: `distanceInWords(date, addSuffix = true)` -- accepts ISO strings via `new Date(date)`, returns "about 3 hours ago" etc. Do NOT use `timeAgoInWordsShort` (line 14) -- it expects Unix seconds and would crash on ISO strings.

---

## Files Summary

### New files (3)
1. `app/javascript/ats/src/components/shared/PlatoMark.tsx`
2. `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
3. `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx`

### Modified files (4)
4. `app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx`
5. `app/javascript/ats/src/views/jobApplications/JobApplicationSidebar.tsx`
6. `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx`
7. `app/javascript/shared/types/aiJobApplicationSummary.ts`

---

## Implementation Steps

### Task 1: Type definitions
**File:** `app/javascript/shared/types/aiJobApplicationSummary.ts`
**Read first:** `cursor_rules/core_critical_rules.md` (rule 7: camelCase)

- [ ] 1.1 Add the `AiAssessment` interface ABOVE the existing `AiResumeStructuredData` interface:
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

- [ ] 1.2 Change `assessment?: any;` (currently line 31) to `assessment?: AiAssessment;` in `AiResumeStructuredData`.

- [ ] 1.3 Verify: existing code that accesses `assessment` as `any` (in `AiJobApplicationSummaryFeedItem.tsx`) still compiles -- it does not access `assessment` at all, so no breakage.

---

### Task 2: PlatoMark component
**File:** `app/javascript/ats/src/components/shared/PlatoMark.tsx` (NEW)
**Read first:** `cursor_rules/frontend/ui_styling.md`, WandIcon.tsx for inline SVG pattern

- [ ] 2.1 Create the file with two exported components: `PlatoMark` and `PlatoChip`.

- [ ] 2.2 `PlatoMark` component:
  - Props: `variant` (`"sparkle" | "sparkles" | "wand"`, default `"sparkle"`), `size` (number, default 16), `color` (string, default `"currentColor"`)
  - Renders an inline `<svg>` with `viewBox="0 0 24 24"`, width/height from `size` prop
  - Three variants with exact SVG paths from the design handoff `PlatoMark.jsx`:
    - `"sparkle"` (default): single 4-point star, stroked, strokeWidth 2
    - `"sparkles"`: big star + dot filled, plus stroked cross
    - `"wand"`: Lucide wand-sparkles, all stroked
  - The SVG element must include `aria-hidden="true"` (the Icon component does NOT add this -- must be explicit)
  - Wrapper: `<span>` with `display: inline-flex; align-items: center; color: ${color}`

- [ ] 2.3 `PlatoChip` component:
  - Props: `size` (number, default 28), `radius` (number, default 7), `variant` (same as PlatoMark, default `"sparkle"`)
  - Renders a styled `<span>` containing `<PlatoMark>` centered
  - Star size inside chip: `Math.round(size * 0.62)`
  - Star color: always `colors.gray[900]` (`#171717`) regardless of dark mode -- import from `@shared/styles/colors`
  - Background: `linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)` -- same in both light and dark mode (brand element)
  - `box-shadow: inset 0 0 0 1px rgba(0,0,0,0.07)` hairline
  - `flex-shrink: 0`, `border-radius: ${radius}px`
  - `display: inline-flex; align-items: center; justify-content: center;`

- [ ] 2.4 Use Emotion `styled` for the chip wrapper and `css` for any inline styles. Both exported as named exports.

---

### Task 3: PlatoOverviewCallout component
**File:** `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx` (NEW)
**Read first:** `cursor_rules/frontend/ui_styling.md`, `cursor_rules/frontend/_base.md`

- [ ] 3.1 Create the file. Props interface:
```typescript
interface Props {
  jobApplication: any;
  onOpen: () => void;
}
```

- [ ] 3.2 Implement the state machine for copy. Evaluate in this order -- first match wins:
  1. Summary exists AND `status === "succeeded"` AND `stale === true` --> title: "Plato's review is out of date", subtitle: `aiSummary.headline`, CTA: "View"
  2. Summary exists AND `status === "succeeded"` AND NOT stale --> title: "Read what Plato thinks about this candidate", subtitle: `aiSummary.headline`, CTA: "View"
  3. Summary exists AND `status === "failed"` --> title: "Plato couldn't finish", subtitle: "No credit was used -- open to retry.", CTA: "View"
  4. Summary exists AND status is one of `"pending"`, `"in_progress"`, `"extracted"`, `"textract_processing"` --> title: "Plato is reading the resume...", subtitle: "This will be ready in a moment.", CTA: "View"
  5. No summary AND `jobApplication.hasResume` is truthy --> title: "Ask Plato to review this candidate", subtitle: "Plato reads the resume for role fit, experience, skills and gaps.", CTA: "Generate"
  6. No summary AND `jobApplication.hasResume` is falsy --> title: "Plato needs a resume", subtitle: "Add one to this candidate and Plato can review them.", CTA: "View"

  Access the summary as `jobApplication.aiJobApplicationSummary`. Access status as `aiSummary.status`.

- [ ] 3.3 Render structure:
  - The entire card is a `<Styled.Card>` which is `styled.button` -- native `<button>` element for keyboard accessibility (Enter/Space for free)
  - Apply button reset CSS: `appearance: none; background: none; border: none; padding: 0; text-align: left; width: 100%; cursor: pointer; font: inherit;`
  - Then apply card styling on top: `position: relative; display: flex; align-items: center; gap: 13px; padding: 14px 16px; border: 1px solid ${t.poly.color.border}; border-radius: ${t.poly.radii.md}; background: ${t.poly.color.cardCanvas}; overflow: hidden; transition: border-color 0.2s ease;`
  - Hover: `border-color: ${t.poly.color.borderHover}`
  - `onClick={onOpen}` on the card
  - Inside: gradient bar (absolute left), `PlatoChip` (size 32, radius 8), text column, CTA label + chevron icon

- [ ] 3.4 Gradient bar: `Styled.Bar` -- `position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%);`

- [ ] 3.5 Text column: `Styled.TextColumn` -- `flex: 1; min-width: 0;`
  - Title: `Styled.Title` -- `font-size: 14px; font-weight: 600; color: ${t.poly.color.loudText}; margin-bottom: 2px;`
  - Subtitle: `Styled.Subtitle` -- `font-size: 13px; color: ${t.poly.color.secondaryText}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;`

- [ ] 3.6 CTA: `Styled.Cta` -- `display: inline-flex; align-items: center; gap: 4px; flex-shrink: 0; font-size: 13px; font-weight: 500; color: ${t.poly.color.loudText};`
  - CTA label text + `<Icon name="chevron-right" />`
  - ALL CTA labels are display-only text. The card always navigates via `onOpen()` -- never triggers generate.

- [ ] 3.7 Connector tick below the card: `Styled.Card` `::after` pseudo-element:
```css
&::after {
  content: "";
  position: absolute;
  top: 100%;
  left: 28px;
  width: 4px;
  margin-left: -2px;
  height: ${t.spacing[6]};
  background-color: ${t.dark ? t.color.gray[800] : t.color.gray[200]};
}
```

- [ ] 3.8 Styled components at bottom of file with `/* Styled Components */` comment, `label:` on every one following `PlatoOverviewCallout_*` format.

- [ ] 3.9 Import `Icon` from `@ats/src/components/shared/Icon`, `PlatoChip` from `@ats/src/components/shared/PlatoMark`.

---

### Task 4: PlatoTab component
**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` (NEW)
**Read first:** `cursor_rules/frontend/ui_styling.md`, `cursor_rules/frontend/_base.md`, `cursor_rules/frontend/react_hooks.md`

This is the largest component. It renders the full Plato tab page with 6 states.

- [ ] 4.1 Create the file. Props:
```typescript
interface Props {
  jobApplication: any;
}
```

- [ ] 4.2 Imports needed:
```typescript
import React from "react";
import styled from "@emotion/styled";
import { css, keyframes } from "@emotion/react";
import Icon from "@ats/src/components/shared/Icon";
import Button from "@ats/src/components/shared/Button";
import { PlatoMark, PlatoChip } from "@ats/src/components/shared/PlatoMark";
import { useGenerateAiSummary, useAiJobApplicationSummary } from "@shared/queryHooks/useAiJobApplicationSummary";
import { useOrganizationAiCreditBalance } from "@shared/queryHooks/useOrganizationAiCreditBalance";
import { useToastContext } from "@shared/context/ToastContext";
import { useModalContext } from "@shared/context/ModalContext";
import { useCurrentSession } from "@ats/src/context/CurrentSessionContext";
import CenterModal from "@ats/src/components/modals/CenterModal";
import { distanceInWords } from "@shared/lib/time";
import colors from "@shared/styles/colors";
```

- [ ] 4.3 Hook setup at the top of the component function:
```typescript
const addToast = useToastContext();
const { currentOrganizationUser } = useCurrentSession();
const { openModal, removeModal } = useModalContext();
const { mutate: generate, isLoading: isGenerating } = useGenerateAiSummary();
const { data: creditData, isError: creditError, isLoading: isLoadingCredits } = useOrganizationAiCreditBalance();

const aiSummary = jobApplication.aiJobApplicationSummary;
const summaryExists = aiSummary != null;
const status = summaryExists ? aiSummary.status : null;

// Fetch full structured data only when succeeded
const { data: fullSummary } = useAiJobApplicationSummary({
  jobApplicationId: jobApplication.id,
  aiJobApplicationSummaryId: aiSummary?.id || 0,
  // Pass enabled option to only fetch when succeeded
});
// Note: useAiJobApplicationSummary does not currently accept an `enabled` option.
// The query will fire even when status !== "succeeded", but the data will just be unused
// for non-succeeded states. This matches the analog pattern in AiJobApplicationSummaryFeedItem
// which also fetches unconditionally (lines 33-36).

const structuredData = status === "succeeded" ? fullSummary?.structuredData : null;
const totalRemaining = creditError ? 0 : creditData?.totalCreditsRemaining || 0;
```

  **IMPORTANT:** The `useAiJobApplicationSummary` hook (in `shared/queryHooks/useAiJobApplicationSummary.ts`) requires `aiJobApplicationSummaryId` as a number. When no summary exists, `aiSummary` is null, so `aiSummary?.id` is undefined. The hook will be called with `aiJobApplicationSummaryId: 0` which will cause a 404 API call. This matches what the analog does -- `AiJobApplicationSummaryFeedItem` always receives a non-null `aiJobApplicationSummary` so this problem doesn't arise there, but `PlatoTab` handles the no-summary case too.

  **Conditional fetching workaround:** Guard the hook call. Since hooks must be called unconditionally, pass `aiJobApplicationSummaryId: aiSummary?.id || 0` and accept that when id is 0, the query will fail silently. The data will be `undefined` and `structuredData` will be `null`. Alternatively, the query could be wrapped with `enabled: summaryExists && status === "succeeded"` but `useAiJobApplicationSummary` doesn't currently pass options through. The simpler approach (let it 404) is acceptable -- React Query will not retry a 404 by default, and the UI guards on `structuredData` being null.

- [ ] 4.4 Generate handler -- copy exactly from `AiSummaryState.tsx` lines 31-47:
```typescript
const handleGenerate = () => {
  generate(
    { jobApplicationId: jobApplication.id },
    {
      onSuccess: () => {
        addToast({ title: "Summary generation queued", kind: "success" });
      },
      onError: (error: any) => {
        addToast({
          title: error?.data?.errors?.general?.[0] || "Failed to queue summary",
          kind: "warning",
          delay: 10000,
        });
      },
    },
  );
};
```

- [ ] 4.5 Buy credits modal handler -- copy from `AiSummaryState.tsx` lines 68-79:
```typescript
const handleBuyCredits = () => {
  openModal(
    <CenterModal headerTitleText="Admin access required" onCancel={removeModal}>
      <Styled.ModalBody>
        <p>Only admins can purchase more credits. Please contact an admin for your organization.</p>
        <Styled.ModalActions>
          <Button onClick={removeModal}>Close</Button>
        </Styled.ModalActions>
      </Styled.ModalBody>
    </CenterModal>
  );
};
```

- [ ] 4.6 Component structure:
```tsx
return (
  <Styled.Container>
    <Styled.Header>
      <Styled.HeaderLeft>
        <PlatoChip size={26} radius={7} />
        <span>Plato</span>
      </Styled.HeaderLeft>
      <Styled.HeaderRight>
        {status === "succeeded" ? (
          <Button styleType="text" onClick={handleGenerate}>
            <Icon name="refresh-cw" /> Regenerate
          </Button>
        ) : (
          <Styled.KebabButton>
            <Icon name="more-vertical" />
          </Styled.KebabButton>
        )}
      </Styled.HeaderRight>
    </Styled.Header>
    <Styled.Body>
      <Styled.BodyInner>
        {/* State machine render */}
      </Styled.BodyInner>
    </Styled.Body>
  </Styled.Container>
);
```

- [ ] 4.7 `Styled.Container`: flex column, height 100%. Same as `JobApplicationActivity.tsx` `Styled.Container` (lines 447-455).

- [ ] 4.8 `Styled.Header`: follows `Styled.Title` from `JobApplicationActivity.tsx` (lines 457-469) -- `pt(4), pb(4), px(4)`, border-bottom, flex row, justify-content: space-between, align-items: center.

- [ ] 4.9 `Styled.Body`: `flex-grow: 1; overflow-y: auto;`

- [ ] 4.10 `Styled.BodyInner`: `max-width: 720px; margin: 0 auto; padding: 22px 28px 56px;`

- [ ] 4.11 State machine in `Styled.BodyInner`. Evaluate in order:
  1. `summaryExists && status === "succeeded"` --> `<PlatoSucceeded />`
  2. `summaryExists && (status === "pending" || status === "in_progress" || status === "extracted")` --> `<PlatoGenerating />`
  3. `summaryExists && status === "textract_processing"` --> `<PlatoProcessing />`
  4. `summaryExists && status === "failed"` --> `<PlatoFailed />`
  5. `!summaryExists && jobApplication.hasResume` --> `<PlatoEmpty />`
  6. `!summaryExists && !jobApplication.hasResume` --> `<PlatoNoResume />`

  These can be inline sub-components within PlatoTab.tsx or extracted as separate functions within the same file.

#### Task 4A: Succeeded layout (PlatoSucceeded)

- [ ] 4A.1 **Provenance line**: flex row, gap 6px, `font-size: 12.5px`, `color: ${t.poly.color.secondaryText}`, margin-bottom 18px. Contains "Generated by Polymer Plato" + separator dot (`color: ${t.poly.color.border}`) + `distanceInWords(aiSummary.createdAt)`. Do NOT use `timeAgoInWordsShort`.

- [ ] 4A.2 **Stale banner** (conditional on `aiSummary.stale === true`): flex row, `background: ${t.poly.color.wellCanvas}`, border-radius 7px, padding `10px 12px`, margin-bottom 18px, gap 10px. Contains: `alert-triangle` icon (15px, `secondaryText`), message text (13px, `secondaryText`, flex: 1), regenerate text-button on right (13px, 500 weight, `loudText`, `refresh-cw` 13px icon, "Regenerate . 1 credit", background none, border none, cursor pointer). Clicking triggers `handleGenerate`.

- [ ] 4A.3 **Headline**: `<h1>`, font-size 23px, line-height 1.28, font-weight 600, letter-spacing -0.02em, `color: ${t.poly.color.loudText}`, `text-wrap: pretty`, margin `0 0 10px`. Source: `aiSummary.headline`.

- [ ] 4A.4 **Domain label**: flex row, gap 8px, margin-bottom 16px, flex-wrap wrap. Primary domain: 13px, weight 500, `loudText`. Separator: 3px filled circle (use a `<span>` with `width: 3px; height: 3px; border-radius: 50%; background: ${t.color.gray[500]};`), NOT a text dot. Secondary domain: 13px, weight 500, `secondaryText`. Capitalize first letter of each domain name. Source: `structuredData?.assessment?.primaryDomain?.name` and `structuredData?.assessment?.secondaryDomain?.name`. Skip entire section if neither domain is present.

- [ ] 4A.5 **Fit for this role card**: position relative, `border: 1px solid ${t.poly.color.border}`, border-radius 9px, padding `16px 20px 20px`, margin-bottom 24px, overflow hidden. Gradient bar: `position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%);`. Header row: flex, gap 8px, margin-bottom 10px, `<PlatoMark size={15} color={t.color.gray[700]} />` + label "Fit for this role" (13.5px, weight 600, `loudText`). Body: 15px, line-height 24px, `primaryText`, text-wrap pretty. Source: `structuredData?.roleAnalysis` falling back to `aiSummary.summaryText` if absent.

- [ ] 4A.6 **Notable achievements**: Omit entire section if `structuredData?.assessment?.standoutAccomplishments` is empty or absent. Eyebrow "Notable achievements" (use eyebrow style -- see 4A.10). List: flex column, gap 9px. Each item: flex row, gap 10px, align-items flex-start. `<Icon name="award" />` (15px, `color: ${t.dark ? t.color.gray[400] : t.color.gray[700]}`, margin-top 2px) + text span (14px, line-height 21px, `primaryText`).

  **Note on Icon size:** The `Icon` component at `app/javascript/ats/src/components/shared/Icon/index.js` hardcodes `height: 1.25em; width: 1.25em;` via its internal `css`. There is no `size` prop. The 15px size must be achieved by setting `font-size: 12px` on the icon's parent (since 1.25 * 12 = 15). Alternatively, wrap the `Icon` in a `<span>` with explicit `svg { height: 15px; width: 15px; }` overrides. The wrapping approach is more reliable. Follow the pattern from `Styled.Icon` in `JobApplicationActivity.tsx` (lines 561-573) but adjust the size.

- [ ] 4A.7 **Relevant experience**: Omit if `structuredData?.applicableExperience` is falsy. Eyebrow "Relevant experience". Prose paragraph: 14.5px, line-height 23px, `primaryText`, max-width 66ch, text-wrap pretty, margin 0.

- [ ] 4A.8 **Gaps to probe**: Omit if `structuredData?.gaps` is falsy. Eyebrow "Gaps to probe". Same prose styling as relevant experience.

- [ ] 4A.9 **Skills**: Omit if `structuredData?.skills` is empty or absent. Eyebrow "Skills". Chip cloud: flex row, flex-wrap, gap 6px. Each chip: `<span>`, font-size 13px, font-weight 450, line-height 20px, `border: 1px solid ${t.poly.color.chipBorder}`, border-radius 4px, padding `3px 10px`.

  Key skills (from `structuredData?.assessment?.keySkills`) are sorted to front and emphasized:
  - Key skill: `color: ${t.poly.color.loudText}`, `background: ${t.dark ? t.color.gray[700] : t.color.gray[100]}`
  - Non-key skill: `color: ${t.poly.color.primaryText}`, `background: transparent`

  Sorting logic: `[...skills].sort((a, b) => (isKeySkill(b) ? 1 : 0) - (isKeySkill(a) ? 1 : 0))` where `isKeySkill` checks if the skill is in the `keySkills` array (case-insensitive prefix match, following the prototype at `ai-tab.jsx` line 246: `keys.some((k) => x === k || x.toLowerCase().startsWith(k.toLowerCase()))`).

- [ ] 4A.10 **Eyebrow styled component** (`Styled.Eyebrow`): text-transform uppercase, letter-spacing 0.05em, font-weight 600, `color: ${t.poly.color.secondaryText}`, margin-bottom 8px. Spread `${[t.text.xs]}` standalone -- do NOT put it inside `font-size:`. This is `t.text.xs` which is a complete CSS declaration (`font-size: 0.75rem;`). Reference: Known Failure Pattern #1.

  Each section block: margin-bottom 22px.

- [ ] 4A.11 **Footer disclaimer**: margin-top 30px, padding-top 14px, `border-top: 1px solid ${t.poly.color.border}`. Flex row, gap 8px, align-items center. `info` icon (13px, `color: ${t.color.gray[400]}`). Text: font-size 12px, `color: ${t.poly.color.placeholderText}`, content: "Plato can be wrong. Always confirm against the resume before deciding."

#### Task 4B: Generating state (PlatoGenerating)

- [ ] 4B.1 Define keyframes using Emotion `keyframes`:
```typescript
const shimmer = keyframes`
  0% { background-position: -600px 0; }
  100% { background-position: 600px 0; }
`;

const dotPulse = keyframes`
  0%, 60%, 100% { opacity: 0.25; transform: translateY(0); }
  30% { opacity: 1; transform: translateY(-2px); }
`;
```

- [ ] 4B.2 **Dots pill**: inline-flex, gap 8px, margin-bottom 22px, padding `6px 12px`, border-radius 999px, `background: ${t.poly.color.wellCanvas}`.
  - Three dots: each `<span>`, width 5px, height 5px, border-radius 50%, `background: ${t.color.gray[500]}`, `animation: ${dotPulse} 1.1s ease-in-out infinite`. Staggered delays: 0s, 0.16s, 0.32s.
  - Label: font-size 13px, `secondaryText`, "Plato is reading the resume and writing the summary..."
  - Include `@media (prefers-reduced-motion: reduce) { animation: none; }` inside the dot styled component.

- [ ] 4B.3 **Shimmer bars**: each `<Styled.ShimmerBar>` with:
```css
background-image: linear-gradient(90deg, ${t.color.gray[100]} 0px, ${t.color.gray[200]} 60px, ${t.color.gray[100]} 120px);
background-size: 600px 100%;
animation: ${shimmer} 1.4s ease-in-out infinite;
border-radius: 4px;
@media (prefers-reduced-motion: reduce) { animation: none; }
```
  Layout (from prototype):
  - Bar: 92% width, 22px height, margin-bottom 10px
  - Bar: 70% width, 22px height, margin-bottom 20px
  - 4 bars: 100%, 97%, 99%, 58% width, 13px height, margin-bottom 9px each
  - Block: 100% width, 84px height, border-radius 8px, margin 16px 0 22px
  - Chip row: flex, gap 6px, flex-wrap. 6 chips with widths [64, 52, 78, 46, 70, 58]px, height 26px, border-radius 4px

#### Task 4C: Processing state (PlatoProcessing)

- [ ] 4C.1 Centered zero-state layout: flex column, align-items center, text-align center, padding `52px 24px 44px`.
  - Icon container: 40px square, border-radius 11px, `background: ${t.color.gray[100]}` (light) / `${t.color.gray[800]}` (dark), `border: 1px solid ${t.poly.color.border}`, centered `file-text` icon (18px, `secondaryText`).
  - Heading: `<h2>`, font-size 17px, weight 600, `loudText`, margin `16px 0 6px`, "Plato is waiting on the resume"
  - Body: font-size 14px, line-height 22px, `secondaryText`, max-width 360px, margin 0, "We're reading the resume file first. Plato will summarize automatically once it's ready -- no action needed."

#### Task 4D: Failed state (PlatoFailed)

- [ ] 4D.1 Same centered layout as Processing. Icon container with `alert-circle` (18px).
  - Heading: "Plato couldn't generate the summary"
  - Body: "Something went wrong while analyzing the resume. **No credit was used.** You can try again." (bold the "No credit was used." portion -- use `<strong>` with `color: ${t.poly.color.loudText}; font-weight: 500;`)
  - Below body (margin-top 18px): a column layout, centered, gap 8px:
    - If `totalRemaining > 0`: `<Button onClick={handleGenerate}>Try again</Button>` + credit hint "Uses 1 credit" (font-size 13px, `placeholderText`)
    - If `totalRemaining <= 0` and admin: `<Button type="internalLink" link="/hire/settings/ai-billing">Buy more credits</Button>`
    - If `totalRemaining <= 0` and not admin: `<Button onClick={handleBuyCredits}>Buy more credits</Button>`
  - The button + hint layout must be `flex-direction: column; align-items: center; gap: 8px;` -- stacked below, NOT inline.

#### Task 4E: Empty state (PlatoEmpty -- no summary, has resume)

- [ ] 4E.1 Same centered layout. PlatoChip at top: size 40, radius 11.
  - Heading: "Plato hasn't reviewed this candidate yet"
  - Body: "Plato will analyze the resume for role fit, relevant experience, skills, and gaps."
  - Below body (margin-top 18px): column, centered, gap 8px:
    - If `totalRemaining > 0`: `<Button onClick={handleGenerate}>Generate summary</Button>` + credit hint `"Uses 1 credit . ${totalRemaining} remaining"` (font-size 13px, `placeholderText`)
    - Zero credits: same admin/non-admin pattern as Failed state.

#### Task 4F: No resume state (PlatoNoResume)

- [ ] 4F.1 Same centered layout. PlatoChip at top: size 40, radius 11.
  - Heading: "Plato needs a resume"
  - Body: "Plato reviews a candidate from their resume. Add one to this candidate to get started."
  - No action button. No credit hint.

#### Task 4G: Styled components

- [ ] 4G.1 All styled components at bottom of file after the component function definition.
- [ ] 4G.2 Every styled component has `label: PlatoTab_*` format.
- [ ] 4G.3 Include `Styled.ModalBody` and `Styled.ModalActions` for the buy-credits modal (copy from `AiSummaryState.tsx` lines 205-221).
- [ ] 4G.4 Include `Styled.KebabButton` for the non-succeeded header (styled as a borderless icon button).

---

### Task 5: Modify JobApplicationContainer.tsx -- add Plato tab route
**File:** `app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx`
**Read first:** `cursor_rules/frontend/reference_patterns.md` (React Router v5)

- [ ] 5.1 Add imports at top of file:
```typescript
import PlatoTab from "@ats/src/views/jobApplications/PlatoTab";
import { useFeatureFlipper, Features } from "@ats/src/components/shared/FeatureFlipper";
```

- [ ] 5.2 Add the `useFeatureFlipper` hook call at component top level (before any useEffect, after the existing hook calls around line 46):
```typescript
const isFeatureEnabled = useFeatureFlipper();
const isAiEnabled = isFeatureEnabled({ feature: Features.AI_APPLICANT_SUMMARY });
```
  This must be at the top level because hooks cannot be called inside useEffect.

- [ ] 5.3 Modify the `possiblePaths` array inside the useEffect (currently line 151) to conditionally include `"ai"`:
```typescript
const possiblePaths = ["overview", "resume", "messages", "files", "notes", ...(isAiEnabled ? ["ai"] : [])];
```
  **CRITICAL:** `isAiEnabled` is referenced inside the useEffect callback. Add it to the dependency array of the useEffect (currently `[location]` at line 158). Change to `[location, isAiEnabled]`.

  **Why conditional:** If `"ai"` is unconditionally in `possiblePaths`, the `redirector()` function (lines 185-191) will redirect `/ai` back to `/ai` in an infinite loop when the flag is off (since the Route exists unconditionally in the Switch). With conditional inclusion, when the flag is off, `currentViewPath` will not be set to `"ai"`, and `redirector()` will fall through to redirect to `/overview`.

- [ ] 5.4 Add a new `<Route>` inside the `<Switch>` block. Place it after the `/notes` route (line 272, closing `/>` of the notes Route) and before `{redirector()}` (line 275). **Do NOT wrap in `<FeatureFlipper>`** -- React Router v5 `<Switch>` only inspects direct children for `path` props; a non-Route wrapper breaks path matching. This matches the codebase pattern in `AccountIntegrationsContainer.tsx` where feature-flagged routes (LinkedIn, Slack, etc.) are registered unconditionally in the `<Switch>` and only the sidebar nav items are gated. The flag-off redirect is handled by the conditional `possiblePaths` in Task 5.3.
```tsx
<Route
  path={`${match.path}/ai`}
  render={(renderProps) => (
    <PlatoTab
      {...props}
      {...renderProps}
      jobApplication={jobApplication}
    />
  )}
/>
```

---

### Task 6: Modify JobApplicationSidebar.tsx -- add Plato nav item
**File:** `app/javascript/ats/src/views/jobApplications/JobApplicationSidebar.tsx`
**Read first:** `cursor_rules/frontend/ui_styling.md`

- [ ] 6.1 Add imports:
```typescript
import isPropValid from "@emotion/is-prop-valid";
import { NavLink } from "react-router-dom";
import { PlatoChip } from "@ats/src/components/shared/PlatoMark";
import { FeatureFlipper } from "@ats/src/components/shared/FeatureFlipper";
import Box from "@shared/components/Box";
import Text from "@shared/components/Text";
import breakpoint from "@shared/styles/breakpoints";
```
  Note: `NavLink` is not currently imported in `JobApplicationSidebar.tsx` (the file uses `withRouter` for `match`). The `NavLink` import is needed for the custom nav item. `isPropValid`, `Box`, `Text`, `breakpoint` are also new imports for this file.

- [ ] 6.2 After the last `NavItem` (line 92, Private notes), add within `Styled.Nav`:
```tsx
<FeatureFlipper feature="AI_APPLICANT_SUMMARY">
  <PlatoNavItem to={`${match.url}/ai`} chevron>
    <PlatoNavLabel>
      <PlatoChip size={22} radius={6} />
      <Text>Plato</Text>
    </PlatoNavLabel>
    <Icon name="chevron-right" />
  </PlatoNavItem>
</FeatureFlipper>
```

- [ ] 6.3 Create `PlatoNavItem` and `PlatoNavLabel` styled components. These go in the styled components section at the bottom of the file.

  `PlatoNavItem` -- copy `linkStyles` from `NavItem.tsx` lines 56-95 **verbatim** and apply to a styled NavLink:
```typescript
const platoNavLinkStyles = (props) => `
  height: 40px;
  border-radius: ${props.theme.poly.radii.sm};
  margin-left: 0.375rem;
  margin-right: 0.375rem;
  padding-left: 0.625rem;
  padding-right: ${props.chevron ? "6px" : "10px"};
  margin-bottom: 2px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  text-decoration: none;
  transition: background-color 0.2s ease;

  > svg {
    transition: opacity 0.2s ease;
    flex-shrink: 0;
    opacity: 0;
  }
  &.active {
    color: ${props.theme.poly.color.loudText};
    background: ${props.theme.poly.color.subtleHover};
    > svg {
      opacity: 1;
    }
  }

  ${breakpoint.sm} {
    height: 32px;
    &:hover {
      color: ${props.theme.poly.color.loudText};
      background: ${props.theme.poly.color.loudHover};
      > svg {
        stroke: ${props.theme.poly.color.secondaryText};
        opacity: 1;
      }
    }
  }
`;

const PlatoNavItem = styled(NavLink, { shouldForwardProp: isPropValid })(platoNavLinkStyles);
```

  `PlatoNavLabel` -- copy the `StyledLabel` pattern from `NavItem.tsx` lines 103-118:
```typescript
const PlatoNavLabel = styled(Box)`
  display: flex;
  align-items: center;
  overflow: hidden;

  ${Text} {
    margin-right: 4px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  > span:first-of-type {
    margin-right: 8px;
    flex-shrink: 0;
  }
`;
```
  Note: The original `StyledLabel` uses `svg { margin-right: 8px; }` for the Feather icon. Since PlatoChip is a `<span>`, use `> span:first-of-type { margin-right: 8px; flex-shrink: 0; }` instead.

---

### Task 7: Modify JobApplicationActivity.tsx -- replace inline AI display with callout
**File:** `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx`
**Read first:** `cursor_rules/frontend/_base.md`

- [ ] 7.1 **Remove** the import of `AiJobApplicationSummaryFeedItem` (line 10) and `AiSummaryState` (line 11). These files are NOT deleted -- just no longer imported here.

- [ ] 7.2 **Add** import of `PlatoOverviewCallout`:
```typescript
import PlatoOverviewCallout from "@ats/src/views/jobApplications/PlatoOverviewCallout";
```

- [ ] 7.3 **Add `match: any`** to the `Props` type (currently lines 34-38):
```typescript
type Props = {
  jobApplication: any;
  orgAdminJobsListUrl: string;
  history: any;
  match: any;
};
```

- [ ] 7.4 **Add `match`** to the function parameter destructuring (line 40):
```typescript
function JobApplicationActivity({ jobApplication, orgAdminJobsListUrl, history, match }: Props) {
```

- [ ] 7.5 **Replace** the FeatureFlipper block (lines 395-404) that currently renders `AiJobApplicationSummaryFeedItem` / `AiSummaryState` with:
```tsx
<FeatureFlipper feature="AI_APPLICANT_SUMMARY">
  <PlatoOverviewCallout
    jobApplication={jobApplication}
    onOpen={() => history.push(`${match.url.replace(/\/[^/]+$/, "")}/ai`)}
  />
</FeatureFlipper>
```
  **Why `match.url.replace(...)`:** The `match` prop arrives from `{...renderProps}` spread at the overview Route's render callback (JobApplicationContainer.tsx line 230). This `match.url` includes the `/overview` segment (e.g., `/jobs/1/stages/2/applicants/3/overview`). The strip-last-segment regex removes `/overview` to get the base applicant URL, then appends `/ai`. Without this, the navigation would go to `/jobs/1/stages/2/applicants/3/overview/ai` (wrong).

  `history` was already destructured (line 40). `match` needs to be added (steps 7.3 and 7.4).

---

## Test Plan

- [ ] 8.1 **Existing tests:** Search backend tests with `grep -rn "AiJobApplicationSummaryFeedItem\|AiSummaryState\|AI_APPLICANT_SUMMARY" spec/ cypress/`. Only backend specs reference the feature flag (`spec/interactors/queue_bulk_ai_summary_jobs_spec.rb`, `spec/jobs/generate_ai_job_application_summary_job_spec.rb`). No frontend tests exist for the current inline AI display. No test updates needed.

- [ ] 8.2 **No existing frontend test infrastructure** covers `JobApplicationContainer` or its tabs. The only frontend test is `Button.test.tsx`. Establishing test infrastructure for this component area is out of scope for this feature.

- [ ] 8.3 **Manual test checklist:**
  - [ ] Feature flag ON: Plato nav item appears in sidebar, `/ai` route renders PlatoTab
  - [ ] Feature flag OFF: no Plato nav item, no callout in Overview, `/ai` redirects to `/overview` (no infinite loop)
  - [ ] All 6 Plato tab states render correctly (use `rails console` to set different summary statuses)
  - [ ] All 6 callout states render correct copy and CTA labels
  - [ ] Clicking callout navigates to Plato tab (does NOT trigger generate mutation)
  - [ ] Generate/regenerate/try-again trigger mutation and show success/error toasts
  - [ ] Zero credits: admin sees buy-credits link, non-admin sees modal
  - [ ] Dark mode: all components render correctly
  - [ ] Stale banner appears when `aiSummary.stale === true`
  - [ ] Skills section sorts key skills to front with emphasized styling
  - [ ] Animations play; respect prefers-reduced-motion
  - [ ] Callout card is keyboard-accessible (Tab to focus, Enter/Space to activate)

---

## Risks and Open Questions

### Risks
1. **Conditional query fetching:** `useAiJobApplicationSummary` is called even when no summary exists (passing id=0). This will produce a silent 404. If React Query retries on 404 or if the server returns a different status code, this could cause console noise. Mitigation: React Query defaults to 3 retries -- if the 404 is noisy, a follow-up could add `enabled: false` option passthrough to the hook.

2. **NavItem visual match:** The custom `PlatoNavItem` copies `linkStyles` verbatim, but the icon slot renders a `<span>` (PlatoChip) instead of an `<svg>` (Icon). The `> svg` selectors in `linkStyles` target the chevron, not the icon slot, so this should work. But verify the margin-right on PlatoChip matches what `StyledLabel`'s `svg { margin-right: 8px; }` provides for regular NavItems.

3. **Icon component size override:** The `Icon` component hardcodes `height: 1.25em; width: 1.25em;` with no size prop. For the 15px icons in achievements and fit-card header, the implementer must wrap the Icon or use CSS overrides on a parent. The plan notes this in Task 4A.6.

4. **`match` prop in JobApplicationActivity:** The `match` prop arrives via `{...renderProps}` spread from the Route render callback, but it is not in the `Props` type. Adding `match: any` and destructuring it is the cleanest approach. An alternative would be `useRouteMatch()` but that's not used elsewhere in this component area.

### Open Questions (LOW, from spec review)
1. `distanceInWords` output includes "about" for approximate durations ("about 3 hours ago"). Acceptable UX.
2. Kebab icon button actions in the tab header for non-succeeded states are not described. It renders but has no dropdown/action defined. Acceptable for v1.
3. `structuredData` can be null per TypeScript type but is always populated when status is succeeded. Use optional chaining per type guidance.

---

## Estimated Scope

| Task | Files | Complexity | Estimate |
|---|---|---|---|
| 1. Type definitions | 1 modified | Low | 5 min |
| 2. PlatoMark | 1 new | Medium | 20 min |
| 3. PlatoOverviewCallout | 1 new | Medium | 30 min |
| 4. PlatoTab (6 states) | 1 new | High | 90 min |
| 5. JobApplicationContainer | 1 modified | Medium | 15 min |
| 6. JobApplicationSidebar | 1 modified | Medium | 20 min |
| 7. JobApplicationActivity | 1 modified | Low | 10 min |
| 8. Manual testing | - | Medium | 30 min |
| **Total** | **3 new, 4 modified** | | **~3.5 hours** |

Recommended implementation order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8. Tasks 1 and 2 have no dependencies and could run in parallel. Tasks 5-7 modify existing files and should run sequentially to avoid merge conflicts.
