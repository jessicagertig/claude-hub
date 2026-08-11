# Rescore Filter — Round 1

## Findings

No issues found.

Verified:
- `unless context.rescore_requested` wraps the `:current` filter at interactor lines 36-42
- `:processing` filter at lines 46-49 remains unconditional
- Controller passes `rescore_requested: bulk_ai_job_application_summary_params[:rescore_requested]` (:42)
- Frontend `RunPlatoReviewAllModal` derives `rescoreRequested` from local `rescore` state (:59)
- Mutation hook passes `rescoreRequested` in the request body (:48)
- Existing `create` flow does not pass `rescore_requested`, so the filter applies as before (falsy default)
