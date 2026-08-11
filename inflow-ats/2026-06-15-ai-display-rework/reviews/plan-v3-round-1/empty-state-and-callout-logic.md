# empty-state-and-callout-logic -- Round 1

## Fact Check

### PlatoOverviewCallout.tsx current state
- 5 states: `ask`, `processing`, `failed`, `noResume`, `noCredits` -- CONFIRMED (line 10 type, lines 20-50 entries)
- `PROCESSING_STATUSES` at line 52 -- CONFIRMED
- `deriveCalloutStatus` at line 54 -- CONFIRMED
- `inlineLink` field in `PlatoEmptyStateConfig` -- CONFIRMED (line 22 type)
- `linkHref` in props (line 17) -- CONFIRMED
- `Styled.InlineLink` styled component at line 210 -- CONFIRMED

### Spec four-state logic
- Spec: overview has 4 states. `current` -> PlatoGeneratedReviewCallout, `regenerating` -> same with refreshing, `none` + hasResume -> "ask", `none` + no resume -> "noResume"
- Plan C.5.1-C.5.6 covers full rewrite. Drops `noCredits`, `processing`, `failed`.
- Final `PlatoCalloutStatus`: `"ask" | "noResume"` -- CORRECT (current/regenerating return null to yield to PlatoGeneratedReviewCallout).

### PlatoTabEmptyState.tsx
- `processing` icon `"file-text"` at line 39 -- CONFIRMED
- Other states (`ready`, `failed`, `noCredits`) already use `icon: "plato"` -- CONFIRMED
- `noResume` branch renders `DragAndDropResumeUploader` at lines 106-114 -- CONFIRMED
- `DragAndDropResumeUploader` import at line 8 -- CONFIRMED
- `onCompleteDirectUpload` and `onStartDirectUpload` in props at lines 16-17 -- CONFIRMED

### JobApplicationActivity routing
- Line 399: `aiJobApplicationSummary?.status === "succeeded"` -- CONFIRMED
- Plan C.4.1 switches to `aiJobApplicationSummaryStatus?.status === "current" || ... === "regenerating"` -- matches spec

### JobApplicationTabEmptyState props
- Accepts `icon`, `title`, `message`, `buttonLabel`, `onClick`, `roomy` -- CONFIRMED
- Plan C.7.2 uses correct props for noResume replacement.

## Completeness

| Spec requirement | Plan step | Status |
|---|---|---|
| Overview: 4 states (drop noCredits, processing, failed) | C.5.1-C.5.4 | Covered |
| Overview: current/regenerating -> PlatoGeneratedReviewCallout | C.4.1 | Covered |
| PlatoTabEmptyState: all icons to "plato" | C.7.1 | Covered |
| PlatoTabEmptyState: remove DragAndDropResumeUploader | C.7.2, C.7.3 | Covered |
| PlatoTabEmptyState: noResume -> JobApplicationTabEmptyState CTA | C.7.2 | Covered |
| Remove uploader-related props | C.7.4 | Covered |
| Resume-tab navigation from PlatoTab | C.7.5 | Covered |
| Remove inlineLink rendering | C.5.5 | Covered |
| Remove linkHref prop | C.5.6 | Covered |

## Findings

No issues found.
