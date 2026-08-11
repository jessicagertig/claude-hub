# Proposal: Fix `regenerating` Flag + Orchestrate Stale Summary Bug

**Date:** 2026-06-15
**Branch:** `feature-ai-summaries-integrating-scoring-v4`
**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`

---

## Two problems, intertwined

### Problem 1: `regenerating` is never set to `true`

`AiJobApplicationSummaryStatus.regenerating` exists but is only ever `false`. The frontend cannot distinguish "stale review, user hasn't requested a new one" from "stale review, new one is being generated right now."

### Problem 2: Trigger D (auto-regeneration on resume replacement) is broken

When a resume is replaced and auto-generate is on:
1. `SubmitResumeToTextract` marks all summaries stale
2. Textract completes → `queue_ai_summary_job` fires → enqueues `GenerateAiJobApplicationSummaryJob`
3. `Orchestrate` finds the stale succeeded summary (query doesn't filter by `stale`) → hits `succeeded → return` → does nothing
4. `generate_ai_summary_with_credit_flow` fetches the same stale succeeded summary → passes `status_succeeded?` guard → consumes a credit for the OLD summary
5. No new summary is generated. A credit is wasted.

These two problems must be solved together because the `regenerating` flag only matters for paths where regeneration actually works.

---

## All trigger paths and what each needs

| Trigger | Path | Goes through CreateAiSummaryGeneration? | Regeneration possible? | What needs to change |
|---------|------|-----------------------------------------|------------------------|---------------------|
| A | Manual single generate | YES | YES — user clicks "Generate" on stale review | Set `regenerating = true` when marking old summary stale |
| B | Bulk generate | NO — calls `generate_ai_summary_with_credit_flow` directly | YES — bulk re-score of candidates with stale reviews | Set `regenerating = true` before pipeline call |
| C | Auto-generate (new candidate) | NO — enqueues job directly | NO — first-ever generation, no prior review exists | No change |
| D | Auto-regen (resume replaced) | NO — enqueues job directly | YES — **currently broken** | Fix Orchestrate + set `regenerating = true` |
| E | Textract processing handoff | NO — summary already exists | NO — continuation of in-progress generation | No change |

---

## Proposed changes

### Change 1: Fix Orchestrate to handle stale succeeded summaries

**File:** `app/services/ai_job_application_action/orchestrate.rb`
**Line 15**

Current:
```ruby
@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first
```

**Option A (recommended): Filter out stale summaries**
```ruby
@ai_job_application_summary = @job_application.ai_job_application_summaries
  .where(stale: false)
  .order(created_at: :desc)
  .first
```

If no non-stale summary exists, `@ai_job_application_summary` is nil → line 16 `return unless @ai_job_application_summary` exits. `Summary::Generate` (called by `run_summary`) has its own lookup and creates a new summary when needed — but Orchestrate would need to still call `run_summary` even when `@ai_job_application_summary` is nil.

This requires restructuring Orchestrate's flow: currently it reads status from the found summary to decide what to do. If no non-stale summary exists, it has no status to dispatch on.

**Proposed restructure:**
```ruby
def call
  return unless @textract_result

  @job_application = @textract_result.job_application
  @ai_job_application_summary = @job_application.ai_job_application_summaries
    .where(stale: false)
    .order(created_at: :desc)
    .first

  if @ai_job_application_summary.nil?
    # No active summary — start fresh (auto-regen or first generation)
    run_summary
    @ai_job_application_summary = @job_application.ai_job_application_summaries
      .where(stale: false)
      .order(created_at: :desc)
      .first
    return unless @ai_job_application_summary
    check_criteria_and_score
    return
  end

  # Existing active summary — dispatch based on status (unchanged from current)
  case
  when @ai_job_application_summary.status_pending?, ...
    # (rest unchanged)
  end
end
```

**Option B: Let Orchestrate find the stale summary but skip `succeeded`/`failed` when `stale: true`**
```ruby
when @ai_job_application_summary.status_succeeded?,
     @ai_job_application_summary.status_failed?
  if @ai_job_application_summary.stale?
    run_summary
    check_criteria_and_score
  else
    return
  end
```

Simpler change, but mixes "stale succeeded = start over" into the dispatch table. The stale summary stays as `@ai_job_application_summary` and `run_summary` → `Summary::Generate` creates a NEW one (because the existing one is `succeeded`, not in a reusable status). After `run_summary`, Orchestrate reloads and the NEW summary is now the latest — but `@ai_job_application_summary` still points to the old one. The reload at line 65 helps, but the local variable assignment is stale.

**Recommendation: Option A.** Filter by `stale: false` upfront. Cleaner mental model — Orchestrate only operates on active summaries.

### Change 2: Fix `generate_ai_summary_with_credit_flow` to filter by stale

**File:** `app/models/textract_result.rb`
**Line 70**

Current:
```ruby
ai_job_application_summary = ai_job_application_summaries.order(created_at: :desc).first
```

Must also filter by `stale: false`:
```ruby
ai_job_application_summary = ai_job_application_summaries.where(stale: false).order(created_at: :desc).first
```

Without this, even after Orchestrate is fixed, the credit consumption step finds the old stale succeeded summary and consumes a credit for it.

### Change 3: Refactor `create_status_record` off `AiJobApplicationSummary`

**Current location:** `app/models/ai_job_application_summary.rb` line 27 (after_commit on create)
**Problem:** Status record belongs to `job_application`, not to any particular summary. The `find_or_create_by` pattern only runs the block on creation — on regeneration (record already exists), nothing happens.

**Proposed:**

1. **Remove** `after_commit :create_status_record, on: :create` from `AiJobApplicationSummary`
2. **Remove** the duplicate `find_or_create_by` calls in `CreateAiSummaryGeneration` (lines 54-56 and 74-76)
3. **Add** to `JobApplication` model:

```ruby
has_one :ai_job_application_summary_status, dependent: :destroy

def find_or_create_ai_summary_status
  status_record = ai_job_application_summary_status
  unless status_record
    status_record = build_ai_job_application_summary_status(regenerating: false)
    status_record.save
  end
  status_record
end
```

4. **Call** `job_application.find_or_create_ai_summary_status` from `CreateAiSummaryGeneration` after saving the new summary (replaces the existing `find_or_create_by` calls).

5. **Optionally** create the status record eagerly on new job_application creation (callback on JobApplication). This means all future job_applications have one. Historical ones get created lazily on first AI summary generation.

### Change 4: Set `regenerating = true` — per trigger path

#### Trigger A: Manual regeneration

**File:** `app/interactors/create_ai_summary_generation.rb`
**Where:** Lines 36-38, where the active summary is found with a different `textract_result_id` and marked stale.

After `active_ai_summary.update_columns(stale: true)` at line 37, add:
```ruby
status_record = job_application.ai_job_application_summary_status
if status_record && status_record.ai_job_application_summary_id.present?
  associated_summary = AiJobApplicationSummary.find_by(id: status_record.ai_job_application_summary_id)
  if associated_summary&.status_succeeded?
    status_record.update_columns(regenerating: true)
  else
    status_record.update_columns(ai_job_application_summary_id: nil, regenerating: false)
  end
end
```

**Four branches:**
1. No status record → nothing (will be created later by `find_or_create_ai_summary_status`)
2. Status record exists, `ai_job_application_summary_id` present, that summary is `succeeded` → `regenerating: true`
3. Status record exists, `ai_job_application_summary_id` nil → no-op (previous never succeeded)
4. Status record exists, `ai_job_application_summary_id` present, that summary NOT `succeeded` → cleanup: nil out the ID, `regenerating: false`

#### Trigger D: Auto-regeneration

**File:** `app/models/textract_result.rb`
**Where:** `queue_ai_summary_job` else branch, lines 118-123. After validation succeeds, before enqueuing the job.

Add a new branch between the auto-generate guard and the job enqueue:
```ruby
else
  return unless job_application&.job&.should_auto_generate_ai_summaries?

  result = ValidateAiSummaryGeneration.call(job_application: job_application, organization: organization)

  if result.success?
    # Check if this is a regeneration (stale succeeded summary exists)
    status_record = job_application.ai_job_application_summary_status
    if status_record && status_record.ai_job_application_summary_id.present?
      associated_summary = AiJobApplicationSummary.find_by(id: status_record.ai_job_application_summary_id)
      if associated_summary&.status_succeeded?
        status_record.update_columns(regenerating: true)
      end
    end

    GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)
  end
end
```

#### Trigger B: Bulk regeneration

**File:** `app/jobs/bulk_generate_ai_summaries_job.rb`
**Where:** `each_iteration`, after validation succeeds (line 59-60), before `generate_ai_summary_with_credit_flow` (line 62).

Same check:
```ruby
status_record = job_application.ai_job_application_summary_status
if status_record && status_record.ai_job_application_summary_id.present?
  associated_summary = AiJobApplicationSummary.find_by(id: status_record.ai_job_application_summary_id)
  if associated_summary&.status_succeeded?
    status_record.update_columns(regenerating: true)
  end
end
```

### Change 5: `regenerating = false` — already handled

`AiJobApplicationSummary#update_summary_status_record` (line 69) already sets `regenerating: false` when a summary reaches `succeeded`. This fires for all paths. No change needed.

### Change 6: Extract the regeneration check into a helper (optional DRY)

The same 5-line check appears in Changes 4A, 4D, and 4B. Could extract to `AiJobApplicationSummaryStatus`:

```ruby
class AiJobApplicationSummaryStatus < ApplicationRecord
  def mark_regenerating_if_succeeded!
    return unless ai_job_application_summary_id.present?

    associated_summary = AiJobApplicationSummary.find_by(id: ai_job_application_summary_id)
    if associated_summary&.status_succeeded?
      update_columns(regenerating: true)
    else
      update_columns(ai_job_application_summary_id: nil, regenerating: false)
    end
  end
end
```

Then each call site becomes:
```ruby
status_record = job_application.ai_job_application_summary_status
status_record&.mark_regenerating_if_succeeded!
```

**Trade-off:** Cleaner call sites, but adds a method to the model. Given it's called in 3 places, the DRY seems justified.

---

## What NOT to change

- `Summary::Generate#generate` pre-pipeline logic (lines 30-40) — it correctly creates a new summary when the existing one is `succeeded`. Once Orchestrate stops bailing on stale succeeded summaries (Change 1), this logic works as intended.
- `AiJobCriteria#resume_waiting_summaries` — no regeneration concept here, these are awaiting-criteria summaries.
- The `update_summary_status_record` callback — already correct.

---

## Implementation order

1. **Change 1** (fix Orchestrate) — unblocks Trigger D entirely
2. **Change 2** (fix `generate_ai_summary_with_credit_flow` stale filter) — prevents credit waste
3. **Change 3** (refactor status record creation to JobApplication) — prerequisite for clean `regenerating` logic
4. **Change 4** (set `regenerating = true` in all 3 trigger paths) — the actual feature
5. **Change 6** (optional helper extraction) — cleanup

Changes 1 and 2 can ship independently as a bugfix (Trigger D is broken NOW, wasting credits). Changes 3-4 can follow as the `regenerating` feature.

---

## Open questions for Jessica

1. **Change 1 Option A vs B** — I recommend A (filter `stale: false` upfront). Does that match your instinct?
2. **Change 3 — eager vs lazy status record creation** — Should new job_applications get a status record on creation, or only when the first AI summary is generated? Eager means the table grows with every job_application. Lazy means historical ones get backfilled on first use.
3. **Change 6 — helper method** — Extract the regeneration check to a model method, or keep it inline in the 3 call sites?
4. **Should `regenerating` be set for bulk (Trigger B)?** Bulk can process hundreds of candidates — setting `regenerating` per-candidate before the pipeline call adds a DB write per candidate. Worth it for UI accuracy, or skip it for bulk?
