# empty-state-and-callout-logic

## Checked

1. `PlatoOverviewCallout` four-state logic:
   - `current` -> return null (PlatoGeneratedReviewCallout renders instead)
   - `regenerating` -> return null (same)
   - `none`/absent + hasResume -> "ask"
   - `none`/absent + !hasResume -> "noResume"
   - Fallback: "ask" (covers unexpected values)
   Matches spec. Correct.

2. `PlatoOverviewCallout` -- removed `processing`, `failed`, `noCredits` states. Removed `PROCESSING_STATUSES`, `InlineLink`, `linkHref`. Correct per spec.

3. `PlatoTabEmptyState` -- `processing` icon changed from `"file-text"` to `"plato"`. Correct.

4. `PlatoTabEmptyState` -- `noResume` branch replaced `DragAndDropResumeUploader` with `JobApplicationTabEmptyState` + CTA. `DragAndDropResumeUploader` import removed. `onCompleteDirectUpload`/`onStartDirectUpload` props removed. Correct.

5. `PlatoTab.tsx` -- `handleNavigateToResumeTab` added, uses `history.push` with resume route. Passed as `onClick` for noResume state. Correct.

6. `JobApplicationActivity.tsx` -- routing: `current`/`regenerating` -> `PlatoGeneratedReviewCallout`, everything else -> `PlatoOverviewCallout`. Matches spec.

7. `PlatoTabEmptyState` -- `linkHref` prop removed from interface and `resolveStatus` opts. Styled components section (InlineLink) removed. Correct.

## Findings

None.
