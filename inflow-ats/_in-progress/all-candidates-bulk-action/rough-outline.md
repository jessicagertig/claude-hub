# Rough Outline (non-authoritative reference)

1. Backend endpoint — new route + controller action for all-stages bulk generation
2. Interactor change — QueueBulkAiSummaryJobs accepts a rescore param
3. Job serializer — expose ai_job_application_summaries_count
4. Downstream effects — anything in the existing pipeline that assumes a single hiring stage
5. Frontend trigger — job-level UI entry point for the action
6. Frontend confirm modal — confirmation flow with credit/count info
7. Frontend empty state modals — when there is no job description or no candidates yet
8. Frontend mutation — React Query hook for the new endpoint
