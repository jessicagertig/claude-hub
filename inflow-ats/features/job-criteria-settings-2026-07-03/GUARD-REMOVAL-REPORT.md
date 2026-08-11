# Zero-criteria guard removal + this-branch constant cleanup (2026-07-09)

**Worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`, branch `job-criteria-settings-qa`.
**All edits UNCOMMITTED — left for your review.**

## What was done

### 1. Removed the review-blocking zero-criteria guard (4 backend sites)
The guard (`context.fail!(...) if …zero_criteria_extraction_failure?` / `return if …`) is gone from:
- `app/interactors/validate_ai_summary_generation.rb`
- `app/interactors/validate_auto_ai_summary_generation.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/models/textract_result.rb` (`generate_ai_summary_with_credit_flow` funnel)

Plus the dead guard test cases in 5 specs (whole guard `context` blocks / the two controller `it`s).

**Behavior after removal:** a review on a zero-criteria job is no longer pre-blocked. It now follows the qa-refinements `awaiting_job_criteria` path — `ScoreJobApplication` sees the failed criteria row and fails the summary early (`status: failed`, `error_message` = criteria error), surfaced by `failed_due_to_no_job_criteria?`. **No credit is consumed** — `generate_ai_summary_with_credit_flow` only charges `if status_succeeded?` (textract_result.rb:86), same as every path.

### 2. Deleted the constants THIS branch created
Removed from `app/models/ai_job_criteria.rb` (added by my feature commit `90ae3fa03`):
- `ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE`
- `ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE`
- `ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE`
- `ZERO_CRITERIA_ERROR_MESSAGES`

Two consumers re-pointed to keep **identical behavior** and leave your qa-refinements code untouched:
- `AiJobCriteria#zero_criteria_failure?` — now checks the same 3 strings inline (feature predicate; still powers the serializer `zero_criteria_failure` attr + the WebSocket `zeroCriteriaFailure` flag → the "No criteria found" empty state + regenerate toast).
- `score_job_application.rb:48` — reverted to the literal `'Criteria array is empty'` (exactly what develop had before qa-refinements borrowed my constant).
- 6 spec references (across 4 files) swapped from the constant to the literal.

**Kept (qa-refinements / develop, NOT touched):** `AiJobApplicationSummary::JOB_CRITERIA_ERROR_MESSAGES`, `failed_due_to_no_job_criteria?`, `fail_waiting_summaries`, `resume_waiting_summaries`, `awaiting_job_criteria`, all `extract_criteria.rb` literal writers.

## Ownership map (from `git diff develop HEAD`)
- **develop (7168e6cb1):** none of the job-criteria error machinery. Has the `awaiting_job_criteria` enum status + `extract_criteria` literal writes only.
- **my feature commit 90ae3fa03:** `ZERO_CRITERIA_*` constants + `zero_criteria_failure?` — **deleted per your instruction.**
- **qa-refinements PR #3062 (bf65446fd):** `JOB_CRITERIA_ERROR_MESSAGES`, `failed_due_to_no_job_criteria?`, `fail_waiting_summaries`, split of the `score_job_application` fail/await branches — **kept.**

## Error-message inventory (you asked: which messages, how many of each, set where)

Four distinct job-criteria error strings. Locations where each is now SET/listed after cleanup:

| # | String | Written (source of truth) | Also listed in |
|---|--------|---------------------------|----------------|
| 1 | `Job description is blank` | `extract_criteria.rb:32` | `JOB_CRITERIA_ERROR_MESSAGES` — **2 places** |
| 2 | `No criteria sections found in job description` | `extract_criteria.rb:63` | `JOB_CRITERIA_ERROR_MESSAGES` + `zero_criteria_failure?` — **3 places** |
| 3 | `No criteria extracted from job description` | `extract_criteria.rb:124` | `JOB_CRITERIA_ERROR_MESSAGES` + `zero_criteria_failure?` — **3 places** |
| 4 | `Criteria array is empty` | `score_job_application.rb:48` (defensive; unreachable — a succeeded extraction always has criteria) | `zero_criteria_failure?` — **2 places** |

Two predicate lists remain, **deliberately different subsets** (they answer different questions):
- `AiJobCriteria#zero_criteria_failure?` = [no-sections, none-extracted, empty-array] — "did the latest *criteria extraction* come back empty?" → drives the criteria-section empty-state + regenerate toast. Excludes blank-desc; includes empty-array (your "just in case").
- `AiJobApplicationSummary::JOB_CRITERIA_ERROR_MESSAGES` = [blank, no-sections, none-extracted] — "did a *summary* fail for a job-criteria reason?" → drives the summary frontend. Includes blank-desc; excludes empty-array.

## Consolidation to ONE predicate list (DONE per your 2026-07-09 instruction)
"Get rid of the unused predicate list, add the missing one to mine."
- Added `'Criteria array is empty'` to `AiJobApplicationSummary::JOB_CRITERIA_ERROR_MESSAGES` → now 4 strings: [blank, no-sections, none-extracted, empty-array]. This is the single source of truth.
- `AiJobCriteria#zero_criteria_failure?` now reads `AiJobApplicationSummary::JOB_CRITERIA_ERROR_MESSAGES` (inline list removed).
- Both predicates (`zero_criteria_failure?`, `failed_due_to_no_job_criteria?`) now share the one list.
- The error strings are still written as literals by the source-of-truth writers (`extract_criteria` ×3, `score_job_application` ×1) — those DEFINE the messages; the constant is the detection list derived from them. Not touched.

**Behavioral change (intrinsic to unifying — flag if unwanted):**
- `zero_criteria_failure?` now also matches `'Job description is blank'`. A blank-description *criteria* failure now renders the "No criteria found" empty state (was "Criteria generation failed") and toasts "No criteria found in the job description" (was "Could not generate job criteria"). For a blank JD this reads correctly, but it is a change.
- `failed_due_to_no_job_criteria?` now also matches `'Criteria array is empty'` — negligible (that write is unreachable; a succeeded extraction always has criteria).

Two specs updated to match: `ai_job_criteria_spec` (`#zero_criteria_failure?` now iterates the shared constant, dropped the "false for blank" case), `ai_job_criteria_controller_spec` (the "other failures" case now uses a parse-error string instead of blank).

## Spec verification
Ran the 12 affected specs (`RAILS_ENV=test`), then re-ran the identical set against committed HEAD (my changes reverted to a saved patch, then restored) to get a clean baseline.

- **Guard removal + constant delete:** 136 examples, 15 failures.
- **Baseline (committed HEAD, no changes):** 149 examples, 15 failures — the **same 15 tests**.
- The 13-example delta = exactly the guard test cases I removed (they passed on baseline; correctly gone now).
- **After list consolidation** (13 files incl `ai_job_application_summary_spec`): 155 examples, the **same 15** failures — still zero new. The edited `ai_job_criteria_spec` / `ai_job_criteria_controller_spec` pass.

**Conclusion: my edits introduced zero new failures.** All feature specs (`ai_job_criteria_spec`, `job_ai_job_criteria_serializer_spec`, `extract_job_criteria_job_spec`, `ai_job_criteria_controller` GET, `extract_criteria_spec`) pass.

### The 15 failures are PRE-EXISTING on the merged branch (not mine, not in scope)
- 4× Flipper-off tests failing because `Flipper.disable(:AI_APPLICANT_SUMMARY)` isn't taking effect (test pollution / ordering): `validate_auto_ai_summary_generation_spec:40`, `queue_bulk_ai_summary_jobs_spec:93`, `bulk_ai_job_application_summaries_controller_spec:101`, `ai_job_criteria_controller_spec:150`.
- 1× `score_job_application_spec:131` — asserts develop's OLD "failed → extract_job_criteria" behavior that qa-refinements (`bf65446fd`) already replaced with "failed → fail the summary." qa-refinements didn't update this spec.
- 10× `bulk_generate_ai_summaries_job_spec` `#on_complete` / `retry_on`-`discard_on` — unrelated to job-criteria; pre-existing.

These will trip pre-commit. They're on the merge (0956bcd4a), independent of this cleanup — worth a look separately.

## WIP patch
Saved at `scratchpad/wip-guard-removal.patch` (used for the baseline diff; changes are restored in the worktree).
