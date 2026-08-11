# Slice: Run-Plato CTA cards / modals, bulk generate modal, jobSetup

All files below are NEW except `JobSetupAutomations.tsx` (1 blank line, no-op), `JobSetupContainer.tsx`, and `JobSetupDescription.tsx` (modified). Everything is gated behind the `AI_APPLICANT_SUMMARY` feature flag at its mount points.

## What changed (behavior)

### Run Plato CTA cards + routing hook
- **`RunPlatoCtaCardV1.tsx` / `RunPlatoCtaCardV2.tsx`** — two visual variants of a "Run Plato" CTA card (V1 centered disc + description + button; V2 header row "Plato review" title + left-aligned description + button). Both render a single `Run Plato` button wired to `handleOnClickRunPlato` from the shared hook. Purely presentational difference; identical behavior.
- **`useRunPlatoCtaModals.tsx`** — the routing brain for the CTA. Props: `jobId`, `jobApplicationsCount`, `jobApplicationsSummaryCount`, `autoGenerateEnabled`, `jobDescription?`. On click, decides which modal to open, in this order:
  1. `!jobDescription` (empty/undefined) → `RunPlatoAddDescriptionModal` (posthog `run_plato_no_description_shown`).
  2. `jobApplicationsCount === 0` → `RunPlatoNoCandidatesModal` (posthog `run_plato_no_candidates_shown`, carries `auto_generate_enabled`).
  3. else → `RunPlatoReviewAllModal` (posthog `run_plato_review_all_clicked`, carries `candidates_count`).
  Note: description gate wins over the no-candidates gate — a job with no description AND no candidates shows the Add-Description modal.

### Modals
- **`RunPlatoAddDescriptionModal.tsx`** — informational. "Edit job description" primary button is an internalLink to `/jobs/{jobId}/setup/description`; Cancel/onClick both call `onCancel` (removeModal). No API calls.
- **`RunPlatoNoCandidatesModal.tsx`** — informational, branches on `autoGenerateEnabled`:
  - ON: reassures auto-review will score applicants; shows single "write a specific job description" tip.
  - OFF: shows two steps — (1) turn on automatic review, with inline links to org settings `/hire/settings/plato-ai/settings` and this job's `/jobs/{jobId}/setup/ai`; (2) write a specific description.
  - "Edit description" internalLink → `/jobs/{jobId}/setup/description`; Dismiss → onCancel. No API calls.
- **`RunPlatoReviewAllModal.tsx`** — the actionable "review whole job" modal. Uses `useBulkGenerateAllStagesAiSummaries` → `POST /bulk_ai_job_application_summaries/all_stages` with `{ jobId, rescoreRequested }`. Server resolves candidates (no client-side ID array). 
  - Count math: `candidatesToScoreCount = rescore ? candidatesCount : max(candidatesCount - summaryCount, 0)`. Rescore checkbox (default off) re-reviews already-scored candidates.
  - Credit balance from `useOrganizationAiCreditBalance` (`available = isError ? 0 : totalCreditsRemaining || 0`). `shortfall = max(0, candidatesToScoreCount - available)`; shortfall banner shown when shortfall>0 and count>0.
  - Validation via `validateBulkGenerateAiSummaries({ availableCredits })` before submit.
  - Submit button disabled when `isLoading || candidatesToScoreCount === 0`. Loading prop set from mutation `isLoading` (read live inside modal, not frozen — modal opens in own render).
  - Success toast composed from `queuedCount` / `skippedCount` / `anyTextractPending`; posthog `run_plato_review_all_confirmed`. Says hiring team gets an email with the final count.
- **`BulkGenerateAiSummariesConfirmModal.tsx`** — the per-stage bulk selection confirm (used from a candidate list with checkboxes, not from the CTA hook). Uses `useBulkGenerateAiSummaries` → `POST /bulk_ai_job_application_summaries` with `{ jobId, hiringStageId, includedJobApplicationIds/excludedJobApplicationIds (from idsArrayType), roleFit }`. Server-side ID resolution (included/excluded pattern — matches bulk-move/bulk-message analog).
  - Instructions text branches on `candidatesCount===0` / `processableCount===0` / `isProcessableCountExact` (exact vs "up to" estimate for Select-All).
  - Credit math same shape as ReviewAll: `shortfall = max(0, processableCount - available)`. Caveat shown for inexact Select-All counts.
  - Generate button disabled when `isLoading || processableCount === 0`. Success toast + `resetList()` (clears selection) + posthog `bulk_generate_ai_summaries_completed`.

### jobSetup
- **`JobSetupContainer.tsx`** — adds nav item "Plato AI settings" (`{url}/ai`) and a `Route` at `{path}/ai` rendering new `JobSetupAiSettings`, both gated by `AI_APPLICANT_SUMMARY`. `setIsDirty` threaded in.
- **`JobSetupAiSettings.tsx`** (NEW page) — per-job auto-generation setting. `FormSelect` bound to `job.autoGenerateAiSummaries` (default `"default"`), options `jobAutoGenerateAiSummariesOptions`. Save calls `useUpdateJob` with `{ id, autoGenerateAiSummaries }`; success/error toasts; marks dirty on change.
- **`JobSetupDescription.tsx`** — adds a "Plato tip" sidebar block (`PlatoChip` mark + copy) gated by `AI_APPLICANT_SUMMARY`. Sidebar CSS changed `display: block` → `display: flex; flex-direction: column` at `lg` breakpoint, plus `line-height: 1.5` on `p`.
- **`JobSetupAutomations.tsx`** — cosmetic only (one blank line added). No behavior change.

## User-visible / actions enabled
- New "Run Plato" CTA button (V1 or V2 card) that, per job state, either educates the user (missing description / no candidates) or opens the bulk-review confirm.
- New per-job "Plato AI settings" tab in Job Setup to control auto-generation per job.
- New "Plato tip" in the job description setup sidebar.
- Two bulk generation entry points that queue AI summaries and show queued/skipped/textract-pending toasts, gated on credit balance.

## States / edge cases to QA
- CTA gate ordering: no-description beats no-candidates beats review-all.
- `autoGenerateEnabled` branch in NoCandidatesModal (two different layouts + link sets).
- Credit shortfall banner (available < needed) in both ReviewAll and BulkConfirm; `isError` on balance query forces `available=0` → full shortfall.
- Rescore checkbox recomputes count (`candidatesCount` vs `candidatesCount - summaryCount`); disables Generate when resulting count is 0.
- Select-All inexact count path in BulkConfirm ("up to N", caveat shown).
- Singular/plural copy throughout (1 credit vs N credits, doesn't/don't).
- `jobAutoGenerateAiSummariesOptions` default value "default" round-trips through `useUpdateJob`.

## SHARED / non-AI surfaces touched (regression risk)
- **`JobSetupContainer.tsx`** — shared job-setup shell: new nav item + route inserted before the `god_admin` polymerAdmin route. Risk: route order / nav rendering for jobs where flag is OFF (must not show tab or 404). Verify non-AI orgs see unchanged Job Setup nav.
- **`JobSetupDescription.tsx`** — shared description editor sidebar; changed sidebar `display: block → flex column` at `lg`. Risk: sidebar layout regression for ALL orgs (flag only gates the tip content, not the CSS change — the `display:flex` change applies unconditionally). Check description-page sidebar spacing with flag OFF.
- **`useBulkGenerateAiSummaries.ts`** — invalidates shared React Query caches `jobApplicationsForStage`, `jobApplication`, `job`, `organizationAiCreditBalance` on success; could trigger refetch/flicker of the candidate list and job header after bulk generate.
- `useUpdateJob` (shared job mutation) now carries a new `autoGenerateAiSummaries` field.

## Pipeline/model/provider
None in this slice — all frontend. No LLM models, prompts, or scoring call-order here; the two modals only POST to `/bulk_ai_job_application_summaries` and `/bulk_ai_job_application_summaries/all_stages` (backend controllers are in another slice).
