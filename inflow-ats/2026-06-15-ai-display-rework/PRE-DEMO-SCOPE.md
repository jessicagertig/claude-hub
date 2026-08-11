# Pre-Demo Scope

## Must fix

### 1. Overview redesign
- Remove three-dot menu from overview heading (`JobApplicationActivity`)
- Move Add/Edit hiring document action to `JobApplicationSidebarActions` (conditional: "Add" if blank/none, "Edit" if exists)
- Add Plato CTA to left side of overview heading: PlatoChip + "Ask Plato" button, navigates to Plato tab (`/ai`)
- Stop rendering `PlatoOverviewCallout` in the feed (don't delete the component)
- `PlatoGeneratedReviewCallout` stays in feed, positioned chronologically among activity items

### 2. Remove negative letter-spacing
- Grep all AI/Plato components for `letter-spacing` with negative values
- Remove any found — likely from Claude AI design handoff

### 3. Headline font size
- Change headline in `PlatoSummary` to 20px (use rem or theme equivalent)

### 4. Remove "queued" toast
- `PlatoTab.tsx` `handleGenerate` `onSuccess` — remove the `addToast` call

### 5. PlatoGeneratedReviewCallout tag
- Smaller size
- Match colors to Plato tab tags: `light` variant for mixed/weak/poor, `linear` for good/excellent

## Should fix if time

### 6. Delayed "keep working" text
- `PlatoLoadingState` — show "You can keep working" text only after 10 seconds
- `useEffect` + `setTimeout` with cleanup on unmount

### 7. PlatoGeneratedReviewCallout chronological positioning
- Currently pinned at top of feed above all activities
- Position it chronologically among activity items based on `updatedAt` from the status record
