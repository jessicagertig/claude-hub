# Plan — bulk "Run Plato" rescore fix

Corrected version of the plan-mode file. Only DECIDED items (see `decisions.md`) are stated as settled; everything else is marked PROPOSED or OPEN. Do not implement OPEN items without a ruling.

## Root cause (verified)

The whole-job bulk run (`all_stages`) with re-score checked reported "succeeded: 11" while regenerating nothing. `rescore_requested` is consumed by `QueueBulkAiSummaryJobs` only to keep already-scored candidates in the working set; it is never placed in the `BulkGenerateAiSummariesJob.perform_later` payload. Downstream, `CreateBulkAiSummaryGeneration` returns each candidate's existing succeeded `AiJobApplicationSummary`, and `TextractResult#generate_ai_summary_with_credit_flow` returns early on:

```ruby
return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?
```

`each_iteration` then sets the bulk status row `:done` unconditionally → reported as succeeded.

## The decided flag path

Request param (required by strong params) → full params object into interactor context → primitive in job payload → virtual attribute assigned to the reloaded `JobApplication` → guard reads the attribute. No `stale` writes.

## Steps

### 1. `app/models/job_application.rb`
Add next to the existing virtual attributes:
```ruby
attribute :ai_summary_rescore_requested, :boolean, default: false
```
OPEN: the attribute name itself.

### 2. `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `bulk_ai_job_application_summary_params` — require the key, keep the permit list (PROPOSED structure):
```ruby
bulk_params = params.require(:bulk_ai_job_application_summary)
bulk_params.require(:rescore_requested)
bulk_params.permit(:job_id, :hiring_stage_id, :rescore_requested,
                   included_job_application_ids: [], excluded_job_application_ids: [], role_fit: [])
```
Absence raises `ActionController::ParameterMissing`; explicit `false` passes (Rails `Parameters#require` accepts `false`). DECIDED: required globally, both actions.
- `all_stages` — replace `rescore_requested: bulk_ai_job_application_summary_params[:rescore_requested]` with `params: bulk_ai_job_application_summary_params`. DECIDED (full-params convention).
- `create` — add `params: bulk_ai_job_application_summary_params`. OPEN item 6: forced by the design, never explicitly ruled on.

### 3. `app/interactors/queue_bulk_ai_summary_jobs.rb`
- Already-scored filter reads `context.params[:rescore_requested]` (replaces `context.rescore_requested`).
- Add to the `BulkGenerateAiSummariesJob.perform_later` hash: `'rescore_requested' => context.params[:rescore_requested],`

### 4. `app/jobs/bulk_generate_ai_summaries_job.rb`
In `each_iteration` (PROPOSED placement: immediately after `return unless job_application`):
```ruby
job_application.ai_summary_rescore_requested = payload['rescore_requested']
```
Jobs queued before deploy carry no key → `nil` → falsy (PROPOSED as acceptable).

### 5. `app/interactors/create_bulk_ai_summary_generation.rb` — the fix itself
```ruby
if active_ai_summary && !job_application.ai_summary_rescore_requested
  context.ai_summary = active_ai_summary
  return
end
```
Fall-through reaches the existing build of a new `AiJobApplicationSummary` with `status: :pending`; the `generate_ai_summary_with_credit_flow` guard passes because the latest summary is pending; generation runs. The textract-mismatch stale branch above the guard is unchanged.

### 6. Frontend — IMPLEMENTED this session (uncommitted)
- `useBulkGenerateAiSummaries.ts`: `rescoreRequested: boolean;` added to `BulkGenerateParams`. DECIDED placement.
- `BulkGenerateAiSummariesConfirmModal.tsx`: `rescoreRequested: false,` literal in the `bulkGenerate(` call — no state. DECIDED.
- `RunPlatoReviewAllModal.tsx` / `BulkGenerateAllStagesParams`: unchanged — already send the value unconditionally.

## OPEN questions blocking parts of this plan

See `decisions.md` OPEN list. In particular, before implementation: the three consequences (two `succeeded, stale: false` rows post-rescore; status row stays `current` during regeneration; one credit consumed per successful rescore) are NOT accepted — they are questions. The done-vs-deferred reporting defect is unresolved scope. Test scope unapproved.

## Verification (once implemented)

1. Staging whole-job bulk with re-score checked against already-scored candidates: worker log shows `[generate_ai_summary_with_credit_flow] pipeline done` per candidate (not only `entry`); new `AiJobApplicationSummary` rows exist; scores refresh.
2. Per-stage bulk (sends `rescoreRequested: false`): already-scored candidates still filtered; behavior unchanged.
3. Request missing `rescore_requested`: 400 `ParameterMissing`.
4. Specs for the touched files (scope OPEN).

## Related, separate from this plan

Three implemented, uncommitted fixes in the `qa-refinements` working tree — see HANDOFF.md session update. The other agent's `job-criteria-settings` branch modifies `queue_bulk_ai_summary_jobs.rb`, `bulk_generate_ai_summaries_job.rb`, `job.rb`, `textract_result.rb` and both bulk spec files; conflicts accepted, sequencing Jessica's.
