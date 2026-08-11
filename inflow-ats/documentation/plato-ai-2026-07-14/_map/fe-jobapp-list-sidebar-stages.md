# Slice: FE — candidate list, sidebar, stage menus, filters (regression-relevant shared surfaces)

Files (all `app/javascript/ats/src/views/jobApplications/`):
FilterSortMenu.tsx (new), JobApplicationActivity.tsx, JobApplicationContainer.tsx, JobApplicationListContainer.tsx, JobApplicationNavItem.tsx, JobApplicationSidebar.tsx, JobApplicationSidebarActions.tsx, JobStageMenu.tsx, JobStagesContainer.tsx

All AI-gated additions are wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">` unless noted. The filter-by-fit control is NOT feature-gated (see regression risk).

## FilterSortMenu.tsx (NEW) — "Filter by fit" dropdown
- New candidate-list dropdown (icon `sliders`, label "Filter by fit", `CountBadge` = number of active filters).
- Checkbox rows from `FIT_BANDS` (Plato/FitIndicator) each with a `FitHarvey` swatch, plus a "Not yet scored" (`unscored`) row.
- Controlled by parent: toggling a checkbox calls `onChange(nextFilters:Set<string>)`; the list does NOT refetch until "Done" (`onSubmit`) is clicked. "Clear filters" calls `onChange(new Set())`. Rows + Clear `stopPropagation` (dropdown stays open); Done bubbles to close the dropdown.
- Filter keys stored are band `key` values (fit bands) + `unscored`.

## JobApplicationListContainer.tsx — filter state + AI columns on rows
- Adds two state sets: `activeFilters` (live dropdown selection) and `appliedFilters` (committed on Done). Query `useInfiniteJobApplicationsForStage` now passes `roleFit: appliedFilters.size ? Array.from(appliedFilters) : undefined`.
- On stage change (`currentStage.id`) effect now ALSO resets both filter sets to empty (each stage starts unfiltered) in addition to `deselectAll()`.
- Empty state is now filter-aware: with active filters shows "No matching candidates" / "No candidates match the current filters…"; otherwise the original "No candidates" copy.
- Passes new props to each `JobApplicationNavItem`: `summaryStatus`, `summaryScorePercentage`, `bulkAiSummaryProcessing` (from `jobApplication.aiJobApplicationSummaryStatus` + `bulkAiSummaryProcessing`).
- Header restructured: new `Styled.HeaderActions` wraps FilterSortMenu + JobStageMenu. Gating changed from `!isEmpty(jobApplicationsForStage)` to `currentStage?.jobApplicationsCount > 0` for BOTH the filter menu and JobStageMenu.
- `selectableCount = pages[0].meta.count` (filtered total) forwarded to JobStageMenu.

## JobApplicationNavItem.tsx — per-candidate fit indicator
- New right-content in the nav row: if status is `current`/`regenerating` AND score present → `FitHarvey` swatch with band label; else if `initial_summary_pending` OR `bulkAiSummaryProcessing` → `PlatoHourglass` ("Review in progress"); else nothing.
- Passes `rightContent` to shared `NavItem` (new prop consumption).

## JobStageMenu.tsx — bulk AI summaries + filter-aware selection
- New menu item "Generate AI summaries" (feature-gated) → opens `BulkGenerateAiSummariesConfirmModal` with jobId, hiringStageId, `idsArray`/`idsArrayType`, `roleFit`, `candidatesCount`, `processableCount`, `isProcessableCountExact`, `resetList`. Tracks `bulk_generate_ai_summaries_clicked`.
- `roleFit` = `Array.from(appliedFilters)` forwarded to Bulk Message and Bulk Move modals too (so Select-All on a filtered stage resolves to the filtered set server-side).
- Selection count math now uses `stageSelectableCount` = `selectableCount ?? currentStage.jobApplicationsCount` for allSelected and excluded-type counts (was raw `currentStage.jobApplicationsCount`). SHARED: affects bulk message/move candidate counts.
- `bulkSummaryProcessableCount(...)` computes how many selected candidates will actually be processed (excludes those with a `current` summary); `isExact` false for not-fully-loaded Select-All.

## JobApplicationContainer.tsx — Plato tab route
- Adds `"ai"` to `possiblePaths`; new `<Route path=".../ai">` renders `PlatoTab`. Non-gated at route level (tab visibility gated in sidebar).

## JobApplicationSidebar.tsx — Plato nav link
- New feature-gated `PlatoNavItem` (NavLink) → `${match.url}/ai`, showing `PlatoChip` + "Plato" label. New styled NavLink using `shouldForwardProp: isPropValid`.

## JobApplicationActivity.tsx — Overview header + Plato review feed entry
- SHARED CHANGE: the Overview header's "Overview options" DropdownMenu (which held Add/Edit hiring document) is REMOVED and replaced by a feature-gated `PlatoCtaButton` (→ pushes to `/ai`). The hiring-document action was relocated (see SidebarActions).
- New `platoReview` feed entry injected into the activity feed when summaryStatus is `current`/`regenerating`, rendered via `PlatoGeneratedReviewCallout` (headline, roleFit=integratedRoleAnalysis, scorePct, generatedAgo). Sorted into feed by `publishedAtTimestamp`.
- Now takes `match` prop; `HeaderActions`/`TitleWrapper` layout changed (justify-content, gap).

## JobApplicationSidebarActions.tsx — hiring document action relocated
- SHARED CHANGE: adds "Add hiring document"/"Edit hiring document" button (with `H` ShortcutKey) into the sidebar actions DropdownMenu, opening `SharedDocumentModal`. This is the action that was removed from JobApplicationActivity's Overview menu. NOT feature-gated.

## JobStagesContainer.tsx — Run Plato CTA card
- Feature-gated `RunPlatoCtaCardV1` added at the bottom of the job stages sidebar (jobId, jobApplicationsCount, aiJobApplicationSummariesCount, shouldAutoGenerateAiSummaries, description). Sidebar becomes flex-column with `margin-top:auto` CTA wrapper.

## SHARED / non-AI regression surfaces to QA
1. **Hiring document access moved** (NOT AI-gated end result): removed from Overview options menu (JobApplicationActivity), re-added to the candidate sidebar actions dropdown (JobApplicationSidebarActions). Verify Add/Edit hiring document + `H` hotkey still reachable and functional in every org, including AI-flag-OFF orgs (Overview options DropdownMenu no longer renders at all — confirm nothing else lived in it).
2. **JobStageMenu selection counts** now derive from `stageSelectableCount`/`meta.count` instead of `currentStage.jobApplicationsCount`. Bulk Message and Bulk Move candidate counts + Select-All/excluded math changed for ALL orgs. Verify counts correct with no filter applied (falls back to stage count) and that `roleFit=[]` when unfiltered doesn't alter existing bulk behavior.
3. **List header render gate** changed from `!isEmpty(jobApplicationsForStage)` to `currentStage?.jobApplicationsCount > 0` — affects when JobStageMenu (bulk actions) appears; check edge case where count>0 but the loaded page is empty, or count stale.
4. **FilterSortMenu is NOT feature-gated** — the "Filter by fit" control renders for all orgs whenever stage count>0. Confirm this is intended for non-AI orgs (fit filters would match nothing/unscored only).
5. **JobApplicationNavItem** now consumes a `rightContent` prop on shared `NavItem`; verify NavItem supports it and non-AI rows render unchanged.
6. `roleFit` forwarded into BulkMessageModal/BulkMoveModal signatures — shared modals gained a new prop.
