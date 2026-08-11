# Outstanding Work Items — AI Scoring / Plato Display

**Date:** 2026-06-15
**Branch:** `feature-ai-summaries-integrating-scoring-v4`
**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Stash:** `stash@{0}` on this branch has all uncommitted UI + prompt changes
**Frontend work:** Needs a worktree — backend changes are unstaged on the main checkout

---

## Completed this session (2026-06-15)

- **Early return guard in `generate_ai_summary_with_credit_flow`** (textract_result.rb:66-67) — committed. Prevents pipeline + credit charge when a non-stale succeeded summary already exists. Fixes Trigger D credit waste bug.
- **`regenerating` boolean column removed** from `ai_job_application_summary_statuses` table. Replaced by `status` enum: `none: 0, current: 1, regenerating: 2`. Migration rolled back, edited, re-migrated. 17 existing records restored with `status: :current`.
- **`AiJobApplicationSummaryStatus` model** — enum changed from 10 pipeline-mirroring values to 3 meaningful values (`none`, `current`, `regenerating`).
- **`update_summary_status_record`** — sets `status: 'current'` instead of `regenerating: false` + `AiJobApplicationSummaryStatus.statuses['succeeded']`.
- **`create_status_record`** — removed `regenerating = false` from `find_or_create_by` block.
- **`CreateAiSummaryGeneration`** — removed `regenerating = false` from both `find_or_create_by` blocks.
- **Status serializer** — removed `regenerating` attribute.
- **`BulkGenerateAiSummariesJob`** — cleaned up `.statuses[:failed]` to `'failed'` (string).
- **Map updated** — `textract-ai-summary-map-6-6-2026.md` overhauled with orchestrate layer, scoring pipeline, status table, Gaps 7+8. Reviewed by 6 adversarial agents, findings fixed.

---

## Must do before committing (blockers)

### 1. Revert TEMP hardcode in PlatoTab renderBody

PlatoTab has an early return that forces the noCredits empty state for testing. Must be removed before commit or it breaks the entire tab for everyone.

**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` — `renderBody` method
**Action:** Remove the early return. The real status-based rendering underneath is correct.
**Where:** Frontend (worktree)

### 2. Fix `hasContent` references to non-existent statuses

`PlatoTab.tsx` line 49 references `in_progress` and `extracted` — these statuses no longer exist in the enum. Current enum: `pending`, `textract_processing`, `extracting`, `summarizing`, `awaiting_job_criteria`, `scoring`, `integrating`, `succeeded`, `retrying`, `failed`.

**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx:49`
**Action:** Replace `in_progress` and `extracted` with the correct current statuses that indicate "content is being generated" — likely `extracting`, `summarizing`, `awaiting_job_criteria`, `scoring`, `integrating`.
**Where:** Frontend (worktree)

---

## Polish items (can ship with or after initial commit)

### 3. Resume tab — replace generic EmptyState

Replace the generic `EmptyState` component with `JobApplicationTabEmptyState` in the Resume tab, matching what was already done for Messages tab and Plato tab.

**File:** Find the Resume tab component (likely in `app/javascript/ats/src/views/jobApplications/`)
**Pattern:** Same refactor done for Messages tab — see `ChannelMessageList.tsx` changes in stash for reference.
**Where:** Frontend (worktree)

### 4. PlatoGeneratedReviewCallout — replace Styled.Tag with PlatoScoreTag

The activity feed callout still uses the old black-outline `Styled.Tag` instead of the new `PlatoScoreTag` component.

**File:** `app/javascript/ats/src/views/jobApplications/Plato/PlatoGeneratedReviewCallout.tsx`
**Action:** Replace `Styled.Tag` with `PlatoScoreTag` — same component used in `PlatoSummary.tsx`.
**Where:** Frontend (worktree)

### 5. Add no-pronouns rule to remaining prompt files

Only `job_application_scoring.rb` has the no-pronouns instruction in its SYSTEM_PROMPT. 8 more prompt files need it.

**Files to update (all under `app/services/ai_job_application_action/`):**
- `summary/prompts/resume_structured_data.rb`
- `summary/prompts/resume_assessment.rb`
- `summary/prompts/resume_comparison.rb`
- `summary/prompts/resume_summary.rb`
- `scoring/prompts/scoring_display.rb`
- `scoring/prompts/integrated_analysis.rb`
- `scoring/prompts/extract_criteria.rb` (if it exists)
- Any other prompt file under these directories

**Action:** Add the same no-pronouns instruction from `job_application_scoring.rb` SYSTEM_PROMPT to each.
**Where:** Backend (main checkout)

---

## Regenerating lifecycle (separate session)

### 6. FindOrCreateAiJobApplicationSummaryStatus interactor

Full proposal at: `~/claude-hub/inflow-ats/2026-06-08-ai-scoring/PROPOSAL-regenerating-and-orchestrate-fix.md`

**Schema work done:** `regenerating` boolean removed, replaced by `status` enum (`none: 0, current: 1, regenerating: 2`). Migration updated. `update_summary_status_record` sets `status: 'current'` on success.

**Still needed:**
- Create `FindOrCreateAiJobApplicationSummaryStatus` interactor — owns find-or-create logic with hand-rolled pattern
- Add `find_or_create_ai_job_application_summary_status` helper on `JobApplication` that calls the interactor
- Wire helper into `JobApplication` after_commit setup callback (eager creation for new job_applications, lazy backfill for historical ones)
- Set `status: :regenerating` in trigger paths A (manual — `CreateAiSummaryGeneration`), B (bulk — `BulkGenerateAiSummariesJob`), D (auto — `queue_ai_summary_job`)
- Remove `create_status_record` callback from `AiJobApplicationSummary` (replaced by the interactor)
- Remove `find_or_create_by` calls from `CreateAiSummaryGeneration` (replaced by the interactor)

**Invoke brainstorming-plus** at the start of this session.
**Where:** Backend (main checkout)

---

## Larger features (separate sessions, separate scope)

### 7. AI settings redesign

Extracting from claude.ai/design. Separate UI work.

### 8. Filtering by fit band

Filter candidates by fit band (Excellent/Good/Mixed/Weak/Poor/Unscored). Needs backend + frontend.

### 9. Sorting

Sort by score (unscored at bottom), alphabetical (A-Z/Z-A), by date (added/application received). Needs backend + frontend.

---

## Reference

- **Updated map:** `~/claude-hub/inflow-ats/_in-progress/ai-scoring-feature-design/textract-ai-summary-map-6-6-2026.md` — updated 2026-06-15 with orchestrate layer, scoring pipeline, status table, Gaps 7+8, reviewed by 6 adversarial agents
- **Handoff doc:** `~/claude-hub/inflow-ats/2026-06-08-ai-scoring/HANDOFF-v4-session-recovery.md`
- **Proposal:** `~/claude-hub/inflow-ats/2026-06-08-ai-scoring/PROPOSAL-regenerating-and-orchestrate-fix.md`
- **Test candidates:** JA IDs 6797, 6728, 6771, 6837, 6864, 6763 (all org 3, requested_by_organization_user_id: 4)
