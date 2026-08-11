# Plan: `ai_job_application_summaries_count` counter cache (job-level only)

## Goal
A direct counter-cache column on `jobs` of job applications that have a succeeded AI job application summary (stale or not), read O(1) off the column — the `published_jobs_count` pattern (conditional `counter_culture`). Purpose: accurate pre-bulk credit estimates (within a few, with a caveat) for the whole-job bulk action.

## Scope decision — job level only, no hiring-stage counter
A per-`hiring_stage` counter is **not** viable with counter_culture alone. The count is bucketed by `hiring_stage`, but `hiring_stage_id` lives on the in-between `job_application` record, not on the counted AI record — so when a candidate changes stages, counter_culture (anchored on `AiJobApplicationSummaryStatus`) can't see the move, and the stage count drifts. Candidates change stages constantly, so the only fixes are hand-rolled SQL or native `counter_cache` — both ruled out (no hand-rolling; native can't do a condition). `published_jobs_count` never hits this because a Job doesn't move between organizations.

The **job** level does work: counter_culture keeps the count live-correct in-app on the status transition (no manual reconcile to depend on). The count never drifts in normal operation — the only drift path is the weird, rare case of an already-summarized candidate moved to a *different job* (counter_culture can't see the `job_id` change on `job_application`), and even that may self-correct if a job move re-scores the summary. For the per-stage bulk estimate, use a live scoped query over that one stage (cheap, exact) — not a cache.

## What is counted, and why this anchor
The count = job applications whose `AiJobApplicationSummaryStatus.status` is `current` or `regenerating` (both imply a succeeded summary exists). Anchored on `AiJobApplicationSummaryStatus` because it is 1:1 with the job application (its own `status` column is the condition, and the grain is one increment per candidate). Anchoring on `AiJobApplicationSummary` would over-count — a job application can have several succeeded summaries (stale + current after a regen).

### Verified counter_culture behavior (3.8.1)
- Declaring `counter_culture` injects `after_create`/`after_update`/`before_destroy` on the model (extensions.rb:16-29) — the declaration *is* the wiring.
- Those are AR callbacks; `update_columns`/`update_all` bypass them — so the write that sets `status` to `current` must be a real `update` to be seen.
- `change_counter_cache` skips a `nil` column (counter.rb:54) — the `none`/`initial_summary_pending` case is a clean no-op.
- `counter_culture_fix_counts` does a full from-truth recompute (grouped `COUNT` with the `column_names` SQL condition, overwriting each target) — the reconcile mechanism `published_jobs_count` relies on (recurring_tasks.rake:76).

---

## Code changes

### 1. Schema migration — column on `jobs`
New file `db/migrate/<ts>_add_ai_job_application_summaries_count_to_jobs.rb`:

```ruby
# frozen_string_literal: true

class AddAiJobApplicationSummariesCountToJobs < ActiveRecord::Migration[6.1]
  def change
    add_column :jobs, :ai_job_application_summaries_count, :integer, default: 0, null: false
  end
end
```

### 1b. One-time backfill — data migration (runs on deploy, not a manual call)
Existing job applications that already have a `current`/`regenerating` status record won't be counted by the new column until backfilled once. A data migration handles this automatically in the release step (`rake data:migrate`), not by hand. Data migrations use the `data_migrate` gem (7.0.2), live in `db/data/`. Direct analog: `db/data/20220228030527_add_counter_culture_fix_for_organization_users.rb`.

New file `db/data/<ts>_add_counter_culture_fix_for_ai_job_application_summaries.rb`:
```ruby
# frozen_string_literal: true

class AddCounterCultureFixForAiJobApplicationSummaries < ActiveRecord::Migration[6.1]
  def up
    AiJobApplicationSummaryStatus.counter_culture_fix_counts
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

After this one-time backfill, the count is maintained live in-app by counter_culture (§3) — nothing depends on a manual reconcile for normal operation.

But add our model to the existing `reset_counters` task (recurring_tasks.rake:65-83) as the same safety net every other counter already has, so that drift from *outside* the app (e.g. a manual production DB edit) gets cleaned alongside the rest:
```ruby
    Job.counter_culture_fix_counts
    ChannelMessage.counter_culture_fix_counts
    OrganizationUser.counter_culture_fix_counts # fixes Organization.users_count
    AiJobApplicationSummaryStatus.counter_culture_fix_counts # fixes Job.ai_job_application_summaries_count
```
This is consistency, not a dependency — normal operation never relies on it.

### 2. The counter — `app/models/ai_job_application_summary_status.rb`
One declaration, below the `belongs_to` lines, mirroring `published_jobs_count` (job.rb:29):
```ruby
counter_culture [:job_application, :job], column_name: proc { |model| (model.status_current? || model.status_regenerating?) ? 'ai_job_application_summaries_count' : nil }, column_names: { ['ai_job_application_summary_statuses.status IN (?)', [2, 3]] => 'ai_job_application_summaries_count' }
```
Same single-line shape, `proc { |model| ... }`, conditional `column_name`, `column_names` SQL hash for `fix_counts`. Forced differences vs. the analog: the two-hop relation `[:job_application, :job]` and the two-state `current`/`regenerating` condition (no single predicate for two enum states). `2, 3` = the `current`/`regenerating` enum integers.

### 3. Make the status update fire a callback — one `update_columns` → `update`
The `none`/`initial_summary_pending → current` write at `ai_job_application_summary.rb:74` is what increments the count. It currently uses `update_columns`, which bypasses counter_culture's callback. Swap it for `update`, `ap` on success, error in `else`, mirroring `get_resume_text_from_textract.rb:31-37`:
```ruby
    if ai_job_application_summary_status.update(
      ai_job_application_summary_id: id,
      status: 'current',
      score_percentage: score_percentage,
      headline: headline,
      integrated_role_analysis: integrated_role_analysis
    )
      ap "AiJobApplicationSummaryStatus updated to current for JobApplication #{job_application.id}"
    else
      Rails.logger.error "Failed to update AiJobApplicationSummaryStatus #{ai_job_application_summary_status.id}: #{ai_job_application_summary_status.errors.full_messages.join(', ')}"
      ap ai_job_application_summary_status.errors.full_messages
    end
```
(Dropped the manual `updated_at: Time.current` — `update` sets it. The existing `ai_summary_succeeded` broadcast below this block is not ours to touch and stays unchanged.)

The status record has no callbacks and only a `job_application_id` uniqueness validation (excludes self on update), so this is low blast radius. `regenerating` (find_or_create:15) and `set_initial_summary_pending` (textract_result.rb:104) stay `update_columns` — `current → regenerating` is net-zero (both counted) and `initial_summary_pending` isn't counted, so neither needs the callback.

Transition coverage (all via the single line-74 conversion):
- `none → current`: proc(old) = `nil`, proc(new) = column → increment.
- `initial_summary_pending → current`: proc(old) = `nil`, proc(new) = column → increment.
- `regenerating → current`: proc(old) = column, proc(new) = column → net zero.

### 4. Reading the count
Direct column read — no method, no sum:
- `job.ai_job_application_summaries_count`

O(1), same as `job_applications_count` / `published_jobs_count`.

---

## Open verification (optional, would tighten the one drift case)
Cross-job moves are the only drift path (counter_culture won't move the count on a `job_id` change). It's a rare, weird case we don't otherwise handle. But it may not be a drift path at all: if a job move **resets or re-scores** the candidate's summary — a real `status` update — counter_culture catches it live and the count stays correct. Worth checking what a `job_application` job-move does to its `AiJobApplicationSummaryStatus` to confirm whether cross-job drift is even possible.

## Not in this plan
- Hiring-stage counter (dropped — see scope decision).
- Per-stage bulk estimate consumption (live scoped query, separate).
- Wiring the job count into the bulk-modal credit estimate.
- Specs.
