# Pass 2 -- Angle 5: Generate/Regenerate Mutation and Credit Balance Lifecycle

## Pass 1 Verification

No findings from Pass 1.

## Fresh Scrutiny

### Regenerate button in header -- credit check missing?

Plan Task 4.6 shows the header's Regenerate button: `<Button styleType="text" onClick={handleGenerate}>`. This button appears when `status === "succeeded"`. The `handleGenerate` function (Task 4.4) calls the mutation directly without checking credits.

The spec says: "When credits are zero and a generate action would be shown, show the existing buy-credits pattern." The regenerate button in the header fires without checking credits. Is this a problem?

Looking at the analog: `AiJobApplicationSummaryFeedItem.tsx` lines 114-119 show the regenerate button also fires `handleRetry` directly without credit checks. The credit check is only in the empty/failed states (where the user hasn't yet paid for a summary). The regenerate case assumes the user has already seen and used the feature, so the backend handles the credit deduction and returns an error if credits are zero.

The spec's "when credits are zero" guidance applies to the empty/failed states where the Generate/Try again buttons are shown. The header Regenerate button and stale banner Regenerate both fire directly. This is consistent with the analog. NOT a finding.

### Stale banner regenerate -- also no credit check

Plan Task 4A.2: "Clicking triggers `handleGenerate`." Same reasoning as above -- the stale banner shows the "Regenerate . 1 credit" text hint but fires the mutation directly. If credits are zero, the backend returns an error and the error toast shows. ACCEPTABLE.

### isLoading guard on generate button

The analog at `AiSummaryState.tsx` lines 96-101 passes `loading={buttonLoading}` and `disabled={buttonLoading}` to the Generate button. The plan's empty state (Task 4E.1) and failed state (Task 4D.1) show `<Button onClick={handleGenerate}>` without `loading`/`disabled` props. The plan does not mention `isGenerating` from `useGenerateAiSummary` or `isLoadingCredits` as disabled guards on the action buttons.

However, looking at the spec: it does not specify loading/disabled states for the buttons. The analog adds them for UX polish (prevent double-click). This is a missing UX detail but not a spec-implementation mismatch. LOW -- the implementer should add loading/disabled guards per the analog pattern.

### isAdmin check for buy-credits

Plan Tasks 4D.1 and 4E.1 reference `currentOrganizationUser.isAdmin`. VERIFIED: `useCurrentSession` returns `{ currentOrganizationUser }` and `isAdmin` is a property on it (used in AiSummaryState.tsx line 65 and JobApplicationSidebar.tsx line 57). CORRECT.

## Findings

### F1 [LOW] Plan omits loading/disabled props on Generate/Try again buttons

**Where:** Plan Tasks 4D.1 and 4E.1
**What:** The analog at `AiSummaryState.tsx` passes `loading={buttonLoading}` and `disabled={buttonLoading}` to prevent double-clicks during mutation. The plan's Generate/Try again buttons have `onClick` but no loading/disabled guards.
**Evidence:** AiSummaryState.tsx lines 96-101.
**Fix:** Implementer should add `loading` and `disabled` props to Generate/Try again buttons, mirroring the analog pattern. This is UX polish, not a spec requirement.
