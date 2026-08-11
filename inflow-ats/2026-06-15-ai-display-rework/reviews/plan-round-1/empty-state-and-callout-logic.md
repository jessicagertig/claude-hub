# empty-state-and-callout-logic -- Round 1

## Fact Check

**Plan claim C.4.1: `PlatoOverviewCalloutProps` currently has `summaryStatus?: string | null`**
- Verified: line 13 is `summaryStatus?: string | null;`.

**Plan claim C.4.2: current `deriveCalloutStatus` checks for `succeeded`, `failed`, `PROCESSING_STATUSES`**
- Verified: lines 54-61 check `succeeded` (return null), `failed`, PROCESSING_STATUSES membership, then `hasResume` branching.

**Plan claim C.4.4: `PlatoCalloutStatus` currently includes `"processing"` and `"failed"`**
- Verified: line 10 is `export type PlatoCalloutStatus = "ask" | "processing" | "failed" | "noResume" | "noCredits";`.

**Plan claim C.6.1: `processing` icon is `"file-text"` at line 39**
- Verified: line 39 of `PlatoTabEmptyState.tsx` is `icon: "file-text"`.

**Plan claim C.6.2: `noResume` branch renders `DragAndDropResumeUploader` at lines 106-115**
- Verified: lines 106-114 render `DragAndDropResumeUploader` when `props.status === "noResume"`.

**Plan claim C.6.3: `DragAndDropResumeUploader` import at line 8**
- Verified: line 8 is `import DragAndDropResumeUploader from "@ats/src/components/DragAndDropResumeUploader";`.

**Plan claim C.6.4: `onCompleteDirectUpload` and `onStartDirectUpload` in props at lines 16-17**
- Verified: lines 16-17 are `onCompleteDirectUpload?: any;` and `onStartDirectUpload?: any;`.

**Plan claim C.5.1: `PlatoGeneratedReviewCallout` accepts `headline`, `roleFit`, `scorePct`, `generatedAgo`, `onClick`**
- Verified: lines 12-16 define the interface with exactly these props.

## Completeness

Spec requirements this angle covers:
1. Five states in `PlatoOverviewCallout` -- plan C.4.2
2. `PlatoGeneratedReviewCallout` reads from status record -- plan C.5
3. `PlatoTabEmptyState` all icons to `"plato"` -- plan C.6.1
4. `PlatoTabEmptyState` noResume: stop rendering `DragAndDropResumeUploader`, use `JobApplicationTabEmptyState` with CTA -- plan C.6.2
5. No inline uploading from the Plato tab -- plan C.6.2, C.6.3
6. `JobApplicationActivity` routing -- plan C.3.1

All covered.

## Findings

- F1 [MED] Plan C.4.3 identifies that `PlatoOverviewCallout` needs credit information but does not prescribe a specific implementation. The spec states a `noCredits` state in the overview. The plan raises this as "Open Question #3" with two options. This is an open question that needs user resolution but is correctly flagged.

- F2 [MED] Plan C.3.2 identifies that `generatedAgo` is not available on `AiJobApplicationSummaryStatus`. The spec says `PlatoGeneratedReviewCallout` reads from the status record, but the status record does not have `createdAt`. Plan correctly raises this as "Open Question #2". Needs user resolution.

## Amendments Applied

None.
