# Review Angles: Plato AI Review Tab

## Subsystems touched

### New files (3)
| File | Purpose |
|---|---|
| `app/javascript/ats/src/components/shared/PlatoMark.tsx` | SVG glyph (3 variants) + gradient chip component |
| `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` | Full Plato tab page with 6-state machine |
| `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx` | Compact callout card for Overview feed |

### Modified files (4)
| File | What changes |
|---|---|
| `app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx` | Add `/ai` route + `"ai"` to `possiblePaths` array + `FeatureFlipper` wrapping + `PlatoTab` import |
| `app/javascript/ats/src/views/jobApplications/JobApplicationSidebar.tsx` | Custom `PlatoNavItem` styled component + `PlatoChip` import + `FeatureFlipper` wrapping |
| `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` | Remove `AiJobApplicationSummaryFeedItem` and `AiSummaryState` imports; add `PlatoOverviewCallout` rendering; wire `onOpen` to navigate to `/ai` |
| `app/javascript/shared/types/aiJobApplicationSummary.ts` | Add `AiAssessment` interface; narrow `assessment` from `any` to `AiAssessment` |

### Files NOT changed (confirmed by spec)
- `NavItem.tsx` -- not modified; custom Plato nav item is built separately in sidebar
- `AiJobApplicationSummaryFeedItem.tsx` -- not deleted, just no longer imported
- `AiSummaryState.tsx` -- not deleted, just no longer imported
- All backend files -- no changes (frontend-only feature)

### Hooks / data layer consumed (unchanged, not modified)
- `useGenerateAiSummary` from `shared/queryHooks/useAiJobApplicationSummary.ts`
- `useAiJobApplicationSummary` from same file
- `useOrganizationAiCreditBalance` from `shared/queryHooks/useOrganizationAiCreditBalance.ts`
- `useToastContext` from `shared/context/ToastContext`
- `useModalContext` from `shared/context/ModalContext`
- `useCurrentSession` from `ats/src/context/CurrentSessionContext`
- WebSocket handler at `ats/src/websockets/WebsocketGlobalChannelHandler.tsx` (lines 212-228, `AI_SUMMARY_COMPLETE` event)

---

## Full-stack analog

The analog is the **current inline AI summary display** in the Overview tab. This is the feature being replaced. Same domain, same data, same hooks, same feature flag, same authorization. The new feature restructures the UI from "inline feed item" to "dedicated tab + compact callout."

### Analog pipeline (file paths)

| Layer | Analog file | Lines |
|---|---|---|
| Empty state component | `ats/src/views/jobApplications/AiSummaryState.tsx` | Full file (222 lines) |
| Display component | `ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` | Full file |
| Mount point (Overview tab) | `ats/src/views/jobApplications/JobApplicationActivity.tsx` | Lines 10-11 (imports), 395-404 (FeatureFlipper block) |
| Generate mutation hook | `shared/queryHooks/useAiJobApplicationSummary.ts` | Lines 8-23 |
| Full data query hook | `shared/queryHooks/useAiJobApplicationSummary.ts` | Lines 25-45 |
| Credit balance hook | `shared/queryHooks/useOrganizationAiCreditBalance.ts` | Full file |
| WebSocket handler | `ats/src/websockets/WebsocketGlobalChannelHandler.tsx` | Lines 212-228 |
| Feature flag | `ats/src/components/shared/FeatureFlipper.tsx` | Line 128 (`AI_APPLICANT_SUMMARY`) |
| TypeScript types | `shared/types/aiJobApplicationSummary.ts` | Full file (49 lines) |

### Tab structure analog (how other tabs work)

| Layer | Analog file | Lines |
|---|---|---|
| Tab container pattern | `ats/src/views/jobApplications/JobApplicationActivity.tsx` | Styled.Container (447-455), Styled.Title (457-469), Styled.Feed (493-502) |
| Sidebar navigation | `ats/src/views/jobApplications/JobApplicationSidebar.tsx` | Lines 79-93 (NavItem list) |
| NavItem component | `ats/src/components/shared/NavItem.tsx` | Full file (119 lines), especially `linkStyles` (56-95) |
| Route registration | `ats/src/views/jobApplications/JobApplicationContainer.tsx` | Lines 151 (`possiblePaths`), 224-275 (Switch/Route block) |
| Activity feed connectors | `ats/src/views/jobApplications/JobApplicationActivity.tsx` | Styled.Event `::after` (671-681), Styled.QuestionResponses `::after` (522-533) |

### Eyebrow styling analog

The spec's eyebrow style should follow the `SectionTitle` pattern already established in `AiJobApplicationSummaryFeedItem.tsx` lines 317-326:
```
text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600;
color: ${t.dark ? t.color.gray[400] : t.color.gray[500]};
```
with `t.text.xs` for size.

---

## Review angles

### Angle 1: Routing, navigation, and feature-flag gating

**Concern:** The new `/ai` route, sidebar nav item, and Overview callout must all be correctly gated behind `AI_APPLICANT_SUMMARY`, the route must be recognized by `possiblePaths`, and the custom `PlatoNavItem` must visually match existing `NavItem` instances. When the flag is off, navigating to `/ai` must redirect to `/overview` (not render a blank pane or throw).

**Files to check:**
- `JobApplicationContainer.tsx` -- route addition, `possiblePaths` array, FeatureFlipper wrapping, redirect behavior
- `JobApplicationSidebar.tsx` -- Plato nav item insertion, FeatureFlipper wrapping, `PlatoNavItem` styled component
- `NavItem.tsx` -- the `linkStyles` function that the custom nav item must replicate (lines 56-95)
- `FeatureFlipper.tsx` -- the `AI_APPLICANT_SUMMARY` enum value, `useFeatureFlipper` hook

**Analog comparison:** How do existing NavItems + Routes pair up? Does each existing NavItem have a matching Route? Does the Plato nav item follow the same pattern?

**Spec-specific checks:**
- `"ai"` is added to `possiblePaths` (line 151) so direct URL navigation works
- The `FeatureFlipper` around the route handles the flag-off redirect case
- The custom `PlatoNavItem` copies `linkStyles` exactly (40px height, `radii.sm`, same margins, same `.active` and `:hover` states)
- The nav item uses `NavLink` from `react-router-dom` for proper keyboard navigation and `aria-current`
- The nav item's `chevron-right` icon matches the existing pattern

**Cursor rules context:** `cursor_rules/frontend/_base.md`, `cursor_rules/frontend/reference_patterns.md` (React Router v5 patterns)

---

### Angle 2: State machine correctness -- 6 states in PlatoTab + 6 states in PlatoOverviewCallout

**Concern:** Both `PlatoTab` and `PlatoOverviewCallout` implement a 6-way state switch on the AI summary status. The conditions must be mutually exclusive, exhaustive, and ordered correctly. The wrong state rendering for any condition is a user-facing bug (e.g., showing "Generate" when a summary is in progress, or showing the succeeded layout when the summary failed).

**Files to check:**
- `PlatoTab.tsx` -- the state machine body switch (succeeded, pending/in_progress/extracted, textract_processing, failed, no-summary+hasResume, no-summary+no-resume)
- `PlatoOverviewCallout.tsx` -- the state-dependent copy table (6 rows: no-review+has-resume, succeeded+not-stale, succeeded+stale, no-resume, failed, generating)
- `AiJobApplicationSummaryFeedItem.tsx` lines 82-112 (analog's state handling)
- `AiSummaryState.tsx` lines 49-108 (analog's empty/no-resume/no-credits rendering)

**Analog comparison:** The analog splits state handling across two components (`AiJobApplicationSummaryFeedItem` for when a summary exists, `AiSummaryState` for when it doesn't). The new feature unifies all 6 states into each of `PlatoTab` and `PlatoOverviewCallout`. Verify no states are lost in the merge.

**Spec-specific checks:**
- The order of conditions matters -- `status === "succeeded"` must come before the "no summary" check to avoid false-matching succeeded summaries
- The `stale` flag is orthogonal to `status` -- it only applies when `status === "succeeded"` but the stale banner must appear in both the tab and the callout
- The callout's "Generate" CTA (no-review+has-resume) is a label only; clicking the card navigates to the Plato tab, it does NOT trigger the generate mutation from the callout
- `textract_processing` gets its own distinct state (not grouped with `pending`/`in_progress`/`extracted`)

**Cursor rules context:** `cursor_rules/frontend/boolean_variables_and_naming.md`, `cursor_rules/frontend/reference_patterns.md` (lookup objects for 4+ case conditionals)

---

### Angle 3: Succeeded layout data consumption and structured data access

**Concern:** The succeeded state is the most complex render path -- it reads from 10+ distinct fields across `aiSummary` (shallow) and `structuredData` (full fetch). Every field access must use the correct path, the correct camelCase key, and handle null/undefined gracefully (sections must be omitted when data is absent, not crash).

**Files to check:**
- `PlatoTab.tsx` -- the succeeded layout (10 sections: provenance, stale banner, headline, domain label, fit-for-role card, notable achievements, relevant experience, gaps, skills, footer disclaimer)
- `shared/types/aiJobApplicationSummary.ts` -- the `AiAssessment` interface addition, `AiResumeStructuredData` fields
- `shared/queryHooks/useAiJobApplicationSummary.ts` -- what `useAiJobApplicationSummary` actually returns
- `AiJobApplicationSummaryFeedItem.tsx` -- how the analog accesses structured data

**Analog comparison:** The analog accesses `structuredData.workExperience`, `structuredData.education`, `structuredData.skills`, `structuredData.certifications`. The new feature accesses different fields: `structuredData.roleAnalysis`, `structuredData.applicableExperience`, `structuredData.gaps`, `structuredData.skills`, `structuredData.assessment.primaryDomain.name`, `structuredData.assessment.secondaryDomain.name`, `structuredData.assessment.keySkills`, `structuredData.assessment.standoutAccomplishments`. Confirm these are all present in the API response and correctly typed.

**Spec-specific checks:**
- Backend returns `snake_case`; the API layer auto-transforms to `camelCase`. Verify every field name is the camelCase form (e.g., `roleAnalysis` not `role_analysis`, `primaryDomain` not `primary_domain`, `keySkills` not `key_skills`, `standoutAccomplishments` not `standout_accomplishments`)
- The `assessment` field is currently typed as `any` (line 31). The spec adds `AiAssessment` -- verify the new interface matches what the API actually returns
- `structuredData.roleAnalysis` falls back to `aiSummary.summaryText` if absent -- this fallback must be implemented
- Sections with empty/falsy data must be omitted entirely (notable achievements with empty array, relevant experience with falsy string, gaps with falsy string, skills with empty array)
- The key-skills-to-front sorting logic in the Skills section: `assessment.keySkills` determines which chips from `skills[]` are emphasized

**Cursor rules context:** `cursor_rules/core_critical_rules.md` (rule 7: backend snake_case, frontend camelCase; rule 9: never deliberately set undefined), `cursor_rules/frontend/_base.md` (do NOT use nullish coalescing `??`)

---

### Angle 4: Emotion styling fidelity -- theme tokens, dark mode, and the accent gradient

**Concern:** The spec has precise pixel values for every element. The implementation must use the correct theme tokens (preferring `theme.poly.color.*` over raw values), handle dark mode correctly for every styled component, and never misuse Emotion theme utilities (e.g., `t.text.xs` is a complete CSS declaration, not a raw value).

**Files to check:**
- `PlatoMark.tsx` -- the gradient chip must use `colors.gray[900]` for glyph color in both modes; the gradient is mode-invariant
- `PlatoTab.tsx` -- all styled components (header bar, provenance line, headline, domain label, fit-for-role card, eyebrow labels, skill chips, footer disclaimer)
- `PlatoOverviewCallout.tsx` -- card border, hover state, text colors
- `JobApplicationSidebar.tsx` -- the custom `PlatoNavItem` must match `linkStyles` exactly
- `shared/styles/lightTheme.ts` -- the canonical poly color token definitions (loudText, secondaryText, placeholderText, border, borderHover, wellCanvas, cardCanvas, chipBorder)
- `ats/styles/theme.ts` -- gray scale values, spacing, text utilities, radii

**Analog comparison:**
- `AiSummaryState.tsx` styled components (lines 129-221) -- the `Styled.*` namespace, `label:` convention, `t.dark` ternaries
- `AiJobApplicationSummaryFeedItem.tsx` SectionTitle (lines 317-326) -- the eyebrow style pattern
- `NavItem.tsx` `linkStyles` (lines 56-95) -- the nav item CSS

**Spec-specific checks:**
- The accent gradient `linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)` does NOT change between light/dark mode
- The glyph inside PlatoChip is always `colors.gray[900]` (#171717), regardless of mode
- `t.text.xs`, `t.text.sm` etc. are complete CSS declarations (include `font-size:`) -- must be used standalone, not inside `font-size:` (Known Failure Pattern #1)
- Every styled component has a `label:` property following `ParentComponentName_StyledElementName` format
- Dark mode for skill chips: key-skill fill is `colors.gray[700]` in dark mode (vs `colors.gray[100]` in light)
- The spec uses explicit px values (23px headline, 13.5px fit-for-role label, 15px body text, 14px item text, etc.) -- verify these map to theme tokens or are used as raw values where no token exists

**Cursor rules context:** `cursor_rules/frontend/ui_styling.md` (Emotion conventions, dark mode, theme utilities), `cursor_rules/core_critical_rules.md` (rule 2: check theme.ts before using colors)

---

### Angle 5: Generate/regenerate mutation and credit balance lifecycle

**Concern:** The generate, regenerate, and try-again actions all call `useGenerateAiSummary` with `{ jobApplicationId }`. The credit balance must be checked, the zero-credits case must show the admin-link or non-admin-modal pattern, and the mutation's success/error callbacks must produce the correct toasts.

**Files to check:**
- `PlatoTab.tsx` -- generate/regenerate/try-again handlers, credit balance display, zero-credits handling
- `PlatoOverviewCallout.tsx` -- the "Generate" CTA label (NOT a mutation trigger -- it navigates to the tab)
- `shared/queryHooks/useAiJobApplicationSummary.ts` -- the generate mutation definition and its `onSuccess` invalidation
- `shared/queryHooks/useOrganizationAiCreditBalance.ts` -- the credit balance query
- `AiSummaryState.tsx` -- the analog's handleClick (lines 31-47), credit check (lines 58-91)

**Analog comparison:** The analog at `AiSummaryState.tsx` lines 31-47 fires the mutation and shows success/error toasts. The new feature must replicate this exactly. The analog at lines 58-91 checks `totalCreditsRemaining` and shows the admin-link/non-admin-modal pattern. The new feature must replicate this for the Empty and Failed states.

**Spec-specific checks:**
- Success toast: "Summary generation queued"
- Error toast: `error?.data?.errors?.general?.[0] || "Failed to queue summary"` with `kind: "warning"` and `delay: 10000`
- Credit hint layout: stacked below the centered button (column, 8px gap, centered) -- NOT inline beside it
- Credit hint copy: "Uses 1 credit . N remaining" (empty state), "Uses 1 credit" (failed state), "Regenerate . 1 credit" (stale banner)
- When credits are zero: admin sees `<Button type="internalLink" link="/hire/settings/ai-billing">`, non-admin sees the `CenterModal`
- The `useOrganizationAiCreditBalance` query returns `{ data: creditData, isError, isLoading }` -- use `creditError ? 0 : creditData?.totalCreditsRemaining || 0`
- After generation succeeds, the WebSocket handler at `WebsocketGlobalChannelHandler.tsx` lines 212-228 invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, and `["organizationAiCreditBalance"]` queries -- no additional WebSocket handling needed in the new components

**Cursor rules context:** `cursor_rules/frontend/react_hooks.md` (hook usage patterns), `cursor_rules/frontend/_base.md` (no nullish coalescing)

---

### Angle 6: CSS animations (shimmer + dots) and accessibility

**Concern:** The generating state has two CSS keyframe animations. These must use Emotion `keyframes`, respect `prefers-reduced-motion: reduce`, and not cause layout shifts. The clickable callout card must be keyboard-accessible. All icons must have `aria-hidden="true"`.

**Files to check:**
- `PlatoTab.tsx` -- shimmer skeleton bars, pulsing dots pill, `@keyframes` definitions, `prefers-reduced-motion` media query
- `PlatoOverviewCallout.tsx` -- must use `<button>` or `role="button"` + `tabIndex={0}` + keyboard event handling
- `PlatoMark.tsx` -- SVG icons must have `aria-hidden="true"`
- `ats/src/components/shared/Button/index.js` -- analog for `keyframes` usage (lines 349-357)
- `ats/src/components/shared/LoadingIndicator/index.js` -- analog for loading animation patterns

**Spec-specific checks:**
- Shimmer: `linear-gradient(90deg, gray[100], gray[200], gray[100])`, `background-size: 600px 100%`, `animation: 1.4s ease-in-out infinite`
- Dots: three 5px circles, `colors.gray[500]`, staggered 0.16s delays, pulsing opacity + slight Y translation over 1.1s
- Both must have: `@media (prefers-reduced-motion: reduce) { animation: none; }`
- The callout card is clickable -- it must be semantically accessible (not just an `onClick` on a `div`)
- The Plato tab nav item must be a `NavLink` for screen reader and keyboard support
- All Feather icons in the new components must have `aria-hidden="true"` (the `Icon` component does this automatically, but any manually rendered SVG must do it explicitly)

**Cursor rules context:** `cursor_rules/frontend/ui_styling.md` (transitions, animations)

---

### Angle 7: TypeScript type safety -- AiAssessment interface

**Concern:** The spec adds a proper `AiAssessment` interface to replace `assessment?: any`. This must match the actual API response shape, and the field names must be camelCase (the API layer auto-transforms). This is a non-breaking refinement, but if the interface is wrong, the Plato tab will crash at runtime.

**Files to check:**
- `shared/types/aiJobApplicationSummary.ts` -- the new `AiAssessment` interface and the updated `AiResumeStructuredData`
- `PlatoTab.tsx` -- every access to `assessment.*` fields
- Backend serializer: `app/serializers/api/v1/ai_job_application_summary_serializer.rb` -- what the API actually sends (read-only, to verify the TS type matches)

**Spec-specific checks:**
- The spec's `AiAssessment` interface has: `primaryDomain`, `secondaryDomain`, `keySkills`, `standoutAccomplishments`, `careerNarrative?`, `experienceClassifications?`
- Verify these camelCase names match the snake_case fields from the backend after auto-transformation (`primary_domain` -> `primaryDomain`, `key_skills` -> `keySkills`, etc.)
- The `primaryDomain` and `secondaryDomain` fields have `.name` sub-fields -- verify the backend serializer includes these nested objects
- The change from `any` to `AiAssessment` must not break existing code that currently accesses `assessment` as `any` (specifically `AiJobApplicationSummaryFeedItem` if it touches `assessment`)

**Cursor rules context:** `cursor_rules/core_critical_rules.md` (rule 7: backend snake_case, frontend camelCase), `cursor_rules/frontend/_base.md` (use `any` pragmatically for legacy objects)

---

## Always-on checks

These apply to every review round regardless of angle:

1. **Known Failure Pattern #1 (Emotion theme utilities):** Every usage of `t.text.xs`, `t.text.sm`, etc. must be standalone, not inside a `font-size:` property. Grep for `font-size:.*t\.text\.` to catch violations.

2. **Known Failure Pattern #3 (test requirements):** The spec includes a test requirements section. Verify the implementation creates or updates tests as specified. The only existing frontend test is `Button.test.tsx`. No existing tests cover `AiJobApplicationSummaryFeedItem`, `AiSummaryState`, or the `AI_APPLICANT_SUMMARY` feature flag in a frontend context. Backend-only test references: `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb`, `spec/jobs/generate_ai_job_application_summary_job_spec.rb`.

3. **Import cleanup:** `JobApplicationActivity.tsx` must remove the `AiJobApplicationSummaryFeedItem` and `AiSummaryState` imports (lines 10-11) and add the `PlatoOverviewCallout` import. Dead imports are a lint failure.

4. **No nullish coalescing (`??`):** The codebase prohibits `??`. Use `||` instead. Grep new files for `??`.

5. **No deliberately set `undefined`:** Check for `condition ? value : undefined` patterns or `value || undefined`. Use `''` or `null` if a default is needed.

6. **`label:` on every styled component:** Every `Styled.*` definition must include a `label:` property for Emotion debugging. Format: `ParentComponentName_StyledElementName`.

7. **Backward compatibility:** The old `AiJobApplicationSummaryFeedItem` and `AiSummaryState` files are NOT deleted -- they remain in the codebase, just unused. Verify no import of these files is added back accidentally.

8. **Spec-implementation mismatch is HIGH:** If the spec says X and the implementation does Y, that is HIGH even if Y is "functionally equivalent." The user decides whether deviations are acceptable.
