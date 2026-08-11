# FindOrCreateAiJobApplicationSummaryStatus — Rough Outline

Non-authoritative reference material.

**1.** `FindOrCreateAiJobApplicationSummaryStatus` interactor — receives `job_application`. Finds the `AiJobApplicationSummaryStatus` record for this job_application. If the record exists, determines whether the current generation is a regeneration and sets status accordingly. If the record does not exist, creates one, accounting for historical job_applications that may already have a succeeded summary.

**2.** `JobApplication#find_or_create_ai_job_application_summary_status` — helper method that calls the interactor.

**3.** Trigger paths — every place the helper is called:
- **A.** Job application created — `enqueue_new_job_application` calls the helper as last line.
- **B.** Manual generation — `CreateAiSummaryGeneration` calls the helper when a new `AiJobApplicationSummary` is created.
- **C.** Auto generation — `queue_ai_summary_job` else branch calls the helper before enqueuing `GenerateAiJobApplicationSummaryJob`.
- **D.** Bulk generation — `BulkGenerateAiSummariesJob#each_iteration` calls the helper. Exact placement needs investigation.

**4.** Removal:
- Delete `create_status_record` callback from `AiJobApplicationSummary`
- Delete `find_or_create_by` calls from `CreateAiSummaryGeneration` (lines 54 and 74)
