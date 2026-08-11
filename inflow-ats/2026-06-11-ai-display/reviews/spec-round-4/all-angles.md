# Spec Review Round 4 -- All Angles

## Verified dimensions

### 1. Implementation completeness

Every component (PlatoMark, PlatoTab, PlatoOverviewCallout), every modified file (JobApplicationContainer, JobApplicationSidebar, JobApplicationActivity, aiJobApplicationSummary.ts), and every TypeScript type change is fully specified with props, types, styling values, and behavioral rules. The spec provides enough detail for an implementing agent to build all 7 files without guessing on any MED+ concern.

### 2. Data flow correctness

Traced the full data flow:
- `jobApplication.aiJobApplicationSummary` (shallow, `AiJobApplicationSummary | null`) provides `id`, `status`, `headline`, `summaryText`, `stale`, `createdAt` for status checks and callout display
- `useAiJobApplicationSummary({ jobApplicationId, aiJobApplicationSummaryId })` fetches full `AiJobApplicationSummaryFull` with `structuredData` for the succeeded layout
- `aiJobApplicationSummaryId` comes from `jobApplication.aiJobApplicationSummary.id` -- not explicitly stated in the spec but unambiguously implied by the analog pattern (AiJobApplicationSummaryFeedItem.tsx lines 33-36) and the type definitions
- `useOrganizationAiCreditBalance()` provides `totalCreditsRemaining` for credit hints
- `useGenerateAiSummary()` provides the mutation for generate/regenerate/retry
- WebSocket handler invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, and `["organizationAiCreditBalance"]` queries on completion -- verified at WebsocketGlobalChannelHandler.tsx lines 212-228

All field names verified as camelCase in the TypeScript types: `primaryDomain`, `secondaryDomain`, `keySkills`, `standoutAccomplishments`, `roleAnalysis`, `applicableExperience`, `gaps`, `skills`.

### 3. Edge cases

- `aiSummary.headline` null: only consumed in succeeded layout (item 3) and callout subtitle for succeeded states. Type is `string | null` but headline is always populated when status is `succeeded`. No spec guidance needed -- an implementing agent would render the `<h1>` (empty if null, which won't happen in practice).
- `structuredData.roleAnalysis` absent AND `aiSummary.summaryText` null: the spec explicitly provides a fallback chain ("falls back to `aiSummary.summaryText` if absent" in item 5). If both are null/absent, the card body would be empty. This is a theoretical edge case (succeeded summaries always have at least summaryText).
- `assessment` undefined: the spec types it as `assessment?: AiAssessment`. Domain label (item 4), notable achievements (item 6), and skills (item 9) consume assessment fields. Items 6 and 9 already say "omit if empty array." Item 4 (domain label) doesn't specify omission, but an implementing agent would use optional chaining per the TypeScript type and render nothing if absent. LOW ambiguity.
- `skills` empty AND `assessment.keySkills` empty: item 9 says "omit if empty array." Clear.

### 4. Cross-file consistency

- Feature flag: all three surfaces (route in JobApplicationContainer, nav item in JobApplicationSidebar, callout in JobApplicationActivity) use `AI_APPLICANT_SUMMARY`. Container additionally uses `useFeatureFlipper` for conditional `possiblePaths` inclusion. Consistent.
- `match` prop: JobApplicationContainer passes `{...renderProps}` which includes `match`. Spec correctly identifies that JobApplicationActivity.tsx needs `match: any` added to Props and destructuring. Verified match is NOT currently in Props (lines 34-39) or destructuring (line 40). Correct.
- `possiblePaths` gating: spec correctly identifies the infinite loop risk when `"ai"` is unconditionally in `possiblePaths` but the route is FeatureFlipper-gated, and provides the conditional array pattern. Verified `possiblePaths` is inside a `useEffect` (lines 150-158) and `redirector()` at lines 185-191 redirects to `currentViewPath`.

### 5. Codebase convention compliance

- `Styled.*` namespace: spec uses this pattern throughout. Verified.
- `label` property: spec mandates `ParentComponentName_StyledElementName` format. Matches codebase convention.
- React Router v5: `<Route path={...} render={...}>` pattern matches existing routes at lines 225-275. Verified.
- `linkStyles` verbatim copy: spec correctly references lines 56-95 of NavItem.tsx. Verified these lines contain the full `linkStyles` function including `text-decoration: none`, `${breakpoint.sm}` responsive gate, and `> svg` opacity transitions.
- `StyledLabel` wrapper: spec correctly references lines 103-118. Verified this is `styled(Box)` with `Text` targeting and `svg` margin rules.
- `isPropValid` on `shouldForwardProp`: spec correctly references this pattern from NavItem.tsx line 97/101.

### Always-on checks

1. **Known Failure Pattern #1 (Emotion theme utilities):** spec explicitly warns against using `t.text.xs` inside a `font-size:` property and provides the correct standalone pattern. The eyebrow style section (line 79) includes a detailed explanation and cross-reference.
2. **No `??`:** no nullish coalescing operator used in the spec. Credit fallback uses `|| 0` matching the analog pattern.
3. **No deliberately set undefined:** none found.
4. **Label convention:** spec mandates `label: ParentComponentName_StyledElementName` on every styled component.
5. **Import cleanup:** spec explicitly removes `AiJobApplicationSummaryFeedItem` and `AiSummaryState` imports from JobApplicationActivity.tsx and adds `PlatoOverviewCallout`. Imports for new dependencies (FeatureFlipper, useFeatureFlipper, Features, PlatoChip, isPropValid, Box, Text) are listed for each modified file.
6. **Backward compatibility:** spec explicitly states old components are not deleted, just no longer imported. Safe to revert.

## LOW findings (informational, no amendment needed)

- F1 [LOW] PlatoTab / `useAiJobApplicationSummary` conditional fetching / The spec says to fetch "only when a summary exists and status is succeeded" but `useAiJobApplicationSummary` doesn't expose an `enabled` option. The implementing agent would need to add `enabled` to the `useQuery` call or modify the hook. The codebase has precedent for `enabled` in other hooks (useOrganizationDataExport, useWhatJobsListing, useChannelMessageTemplate, etc.). Intent is clear; mechanism is implementation detail.

- F2 [LOW] PlatoTab header bar / kebab icon button for non-succeeded states / The spec mentions "a kebab icon button (otherwise)" in the header but doesn't describe what actions it contains when clicked. For generating/processing states there's no meaningful action. An implementing agent would need to decide behavior or ask for clarification. Minor UI element; body content sections provide the actual actions.

- F3 [LOW] Succeeded layout / `structuredData` null guard / The type is `AiResumeStructuredData | null` but the succeeded layout accesses fields without mentioning null handling. In practice, structuredData is always populated when status is succeeded. An implementing agent would use optional chaining per TypeScript guidance.

- F4 [LOW] Provenance timestamp / "about" prefix / `distanceInWords` wraps `formatDistanceToNow` which produces "about 3 hours ago" for times near rounding boundaries. Already noted in Round 3 as acceptable UX.

## Verdict

**PASS -- zero new findings at MED or above.**

All claims verified against the codebase. Line numbers accurate. Data flow complete. Feature flag gating consistent across all three surfaces. Edge cases handled or have clear implementation paths. Codebase conventions followed. Four LOW informational findings noted for implementing agent awareness but none requiring spec amendment.
