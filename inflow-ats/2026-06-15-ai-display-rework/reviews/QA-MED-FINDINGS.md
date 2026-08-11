# QA MED Findings -- AI Display Rework

All MED findings collected across all layers and runs. These are reported for review but did not block QA.

## 1. JobApplicationNavItem checks "succeeded" instead of "current"

**File:** `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx` line 26
**Classification:** Pre-existing on `ai-frontend-work` base branch (commit c35809614)
**Impact:** The harvey dot fit indicator in the candidate nav list never renders because the status record uses `"current"` (not `"succeeded"`)
**Fix:** Change `summaryStatus === "succeeded"` to `summaryStatus === "current"` on line 26

## 2. Controller show action missing eager load

**File:** `app/controllers/api/v1/job_applications_controller.rb` line 52
**Classification:** Out of scope -- controller not in spec or plan
**Impact:** The show action includes `:latest_ai_job_application_summary` (dead, no longer used by serializer) but not `:ai_job_application_summary_status` (now used). One extra lazy-load query per show request.
**Fix:** Replace `.includes(:latest_ai_job_application_summary)` with `.includes(:ai_job_application_summary_status)`

## 3. Inconsistent broadcast coverage between pipeline services

**Classification:** Spec-compliant design choice
**Impact:** `score_job_application.rb` and `integrate_analysis.rb` use `update` (enabling broadcasts for failed/retrying statuses) while `generate.rb` uses `update_columns` (no broadcasts). Scoring/integration failures broadcast; generation failures do not.
**Note:** This is per spec -- `generate.rb` was intentionally excluded from the `update_columns` to `update` migration.

## 4. WebSocket handler doesn't invalidate jobApplicationsForStage

**Classification:** Supplementary handler
**Impact:** The `ai_summary_status_change` handler invalidates `jobApplication` and `aiJobApplicationSummary` but not `jobApplicationsForStage`. The existing `AI_SUMMARY_COMPLETE` handler on GlobalChannel covers this for final states.

## 5. PlatoLoadingState defaults to step 1

**Classification:** Intentional design per plan
**Impact:** When PlatoLoadingState first renders without a status, it defaults to step 1 ("Analyzing the candidate"), visually skipping step 0 ("Processing the resume"). This is intentional since textract processing is typically complete by the time the user opens the Plato tab.

## 6. PlatoTabEmptyState uses || undefined (Rule 9)

**File:** `app/javascript/ats/src/views/jobApplications/Plato/PlatoTabEmptyState.tsx` lines 82-83
**Classification:** Pre-existing code, not introduced by this feature
**Impact:** `config.buttonLabel || undefined` and `config.buttonIcon || undefined` deliberately set undefined

## 7. "regenerating" status is never set by backend

**Classification:** Pre-existing -- the `AiJobApplicationSummaryStatus` model has a `regenerating: 2` enum value but no code path ever sets it. The `find_or_create_by` in `CreateAiSummaryGeneration` returns the existing record without updating it. Frontend handles regenerating correctly but the backend path to trigger it is missing.

## 8. renderHeaderRight doesn't show regenerate button during regenerating status

**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` line 167
**Classification:** Depends on MED 7 (regenerating status never set)
**Impact:** During regenerating, the stale banner inside PlatoSummary says "Regenerate to update" but the header regenerate button is hidden because `renderHeaderRight` only checks `statusValue === "current"`. Moot until MED 7 is fixed.

## 9. distanceInWords with null updatedAt

**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` line 98
**Classification:** Defensive gap, practically unreachable
**Impact:** If `summaryStatus?.updatedAt` is null when status is current/regenerating, `distanceInWords(null)` would produce "over 56 years ago" (epoch date). In practice, `updatedAt` is always set by `update_summary_status_record`.

## 10. Pre-existing test failure in score_job_application_spec.rb:186

**File:** `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` line 186
**Classification:** Pre-existing on base branch (confirmed by running on ai-frontend-work)
**Impact:** "populates criteria_results with merged data" fails because `results.first['summary']` is nil
