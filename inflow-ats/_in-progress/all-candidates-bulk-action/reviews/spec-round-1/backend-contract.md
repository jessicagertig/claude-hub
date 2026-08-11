# Backend Contract — Round 1

## Findings

- F1 [HIGH] `bulk_ai_job_application_summary_params` — the spec says "Add `rescore_requested` to the existing `bulk_ai_job_application_summary_params` method." However, the existing method uses `params.require(:bulk_ai_job_application_summary).permit(...)` (controller:48-55). The all-stages mutation POSTs with `{ bulkAiJobApplicationSummary: { jobId, rescoreRequested } }` which the API layer transforms to `{ bulk_ai_job_application_summary: { job_id, rescore_requested } }`. This works — the same top-level require key. BUT the spec's "New mutation" section says the POST body is `{ bulkAiJobApplicationSummary: { jobId, rescoreRequested } }` — this is correct and matches the analog. Verified: consistent. No issue.

  Actually, on closer inspection: the `all_stages` action needs to call `bulk_ai_job_application_summary_params[:job_id]` for the job lookup, and the expanded permit list would include `rescore_requested`. This is fine. **No issue — withdrawing.**

- F2 [MED] Spec section "Controller action" says "Resolve job application IDs from all candidates in the job" but does not specify the association path. The `create` action uses `@job.hiring_stages.find(p[:hiring_stage_id])` then `stage.job_applications`. For all-stages, it should be `@job.job_applications.pluck(:id)`. Verified: `Job` has `has_many :job_applications` (via grep). The spec should name the association path for implementation clarity.

## Amendments Applied

- Spec "Controller action" bullet 3: changed "Resolve job application IDs from all candidates in the job" to "Resolve job application IDs via `@job.job_applications.pluck(:id)` — all candidates in the job, regardless of hiring stage"

(No other issues found.)
