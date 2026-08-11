# FAILURE REPORT -- Implementation Review Round 1

## Issues Requiring Fix

### 1. [HIGH] Committed `generate_ai_job_application_summary_job.rb` has dictation garbage (F1)

**File:** `app/jobs/generate_ai_job_application_summary_job.rb` line 1 (committed version at HEAD 4a7040c0b)

**What's wrong:** The committed version of this file starts with: `Okay, so I think the reason why I don't know that is because I'm looking at the job right now, and it looks like a native. It looks like it's native to Sidekick.# frozen_string_literal: true`. This is dictation text prepended to the magic comment.

**What to change:** The working tree already has the correct version (`# frozen_string_literal: true`). Commit the working tree version.

---

### 2. [HIGH] `AiJobApplicationSummaryStatus` never created for auto-triggered evaluations (F5)

**File:** `app/interactors/create_ai_summary_generation.rb` (lines 57, 73) -- only creation points for the status record.

**What's wrong:** The `AiJobApplicationSummaryStatus` record is only created in `CreateAiSummaryGeneration` (the manual/bulk trigger interactor). The auto-trigger path (`TextractResult after_commit -> queue_ai_summary_job -> GenerateAiJobApplicationSummaryJob -> generate_ai_summary_with_credit_flow -> Orchestrate -> Summary::Generate`) creates the `AiJobApplicationSummary` directly in `Summary::Generate` line 35-40 WITHOUT going through `CreateAiSummaryGeneration`. Auto-triggered evaluations (the most common path) will never have a status record.

**Impact:** `ShallowJobApplicationSerializer` will serialize `ai_job_application_summary_status` as `null` for auto-triggered applications. The frontend cannot detect that a completed evaluation exists.

**What to change:** Add an `after_commit :create_status_record, on: :create` callback to `AiJobApplicationSummary`:

```ruby
after_commit :create_status_record, on: :create

def create_status_record
  AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application) do |status_record|
    status_record.regenerating = false
  end
end
```

This catches ALL summary creation paths (manual, bulk, AND auto). The `find_or_create_by` ensures idempotency. The existing `CreateAiSummaryGeneration` calls to `find_or_create_by` become redundant but harmless (they would find the existing record).

---

### 3. [HIGH] Three core service specs missing (F7)

**Missing files:**
- `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb`
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb`
- `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb`

**What's wrong:** The three core scoring services have zero test coverage. These services make AI calls, parse JSON responses, handle errors, and manage status transitions -- all critical paths that need tests.

**What to change:** Create specs for all three services following the plan's Phase J.3 test requirements. At minimum, test:
- Happy path with stubbed AI calls
- Error handling (CustomErrorAiSummary -> retrying + re-raise, JSON::ParserError -> failed, StandardError -> failed)
- Status transitions
- Guard clauses
- For `ExtractCriteria`: heading tier override, deduplication
- For `ScoreJobApplication`: criteria-absent path (awaiting_job_criteria)

---

## What NOT To Change

- **Four frozen prompt files** (`job_description_structured_data.rb`, `job_description_criteria_extraction.rb`, `job_application_scoring.rb`, `scoring_display.rb`) -- do not modify.
- **Orchestrator resume logic** -- correctly implements spec Section 5 resume points.
- **`Summary::Generate` status transitions** -- correctly uses `extracting`/`summarizing`/`retrying`/`failed` (no `succeeded`).
- **`ExtractCriteria` use of `update` (not `update_columns`) for `succeeded`** -- correctly fires `after_commit` callback.
- **`reload` usage in orchestrator** -- documented deviation, necessary.
- **Bulk controller server-side ID resolution** -- correctly follows existing bulk move/message pattern (Known Failure Pattern #14).
- **Frontend changes** -- spec says "frontend is out of scope" but the bulk controller changes required corresponding frontend changes. These are pre-work changes committed before the implementation began and are correctly scoped to the bulk action refactor.

## cursor_rules/ Violations

None found. All cursor rules checked:
- `core_critical_rules.md`: No begin blocks, no bang methods, guard clauses with bare return, save/update return values checked.
- `backend/_base.md`: Method-level rescue, specific exception classes, `ap` + `Rails.logger.error`, no unnecessary `reload`.
- `backend/services.md`: No "Service" in class names, descriptive public method names, IDs from jobs / objects from request cycle.
- `backend/background_jobs.md`: IDs passed, `find_by` with guard clauses, exhaustion blocks on retry.
- `backend/serializers.md`: No redundant method definitions, snake_case attributes.
- `backend/migrations.md`: Boolean `regenerating` column (no verb prefix, but `regenerating` is descriptive -- this is a gerund acting as an adjective, matching the `stale` precedent on `ai_job_application_summaries`).
