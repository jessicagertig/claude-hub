# X0 — Writer Census (Authoritative Coverage Baseline)

**Angle:** X0
**Slice:** Every site that WRITES a status/key column of the four records.
**Method:** Grepped entire `app/`, then OPENED and READ each file to confirm the write, the column, and update-vs-update_columns.

## Files traced

- `app/services/submit_resume_to_textract.rb`
- `app/services/get_resume_text_from_textract.rb`
- `app/models/textract_result.rb`
- `app/models/ai_job_application_summary.rb`
- `app/models/ai_job_application_summary_status.rb`
- `app/models/ai_job_criteria.rb`
- `app/models/job.rb` (extract_job_criteria, lines 685-704)
- `app/models/job_application.rb` (find_or_create_ai_job_application_summary_status, lines 160-170)
- `app/interactors/create_ai_summary_generation.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb` (NEW file)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (NEW file)
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/jobs/extract_job_criteria_job.rb`
- `app/services/ai_job_application_action/orchestrate.rb`
- `app/services/ai_job_application_action/summary/generate.rb`
- `app/services/ai_job_application_action/scoring/score_job_application.rb`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb`
- `app/services/ai_job_application_action/scoring/extract_criteria.rb`

---

## RECORD 1 — TextractResult (textract_job_status / textract_job_result_text)

1. `app/services/submit_resume_to_textract.rb:22` — `@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')` — col `textract_job_status` — **build** (persisted by `.save` at line 24).
2. `app/services/submit_resume_to_textract.rb:33` — `@textract_result&.update_columns(textract_job_status: 'failed')` (rescue InvalidS3ObjectException) — col `textract_job_status` — **update_columns**.
3. `app/services/submit_resume_to_textract.rb:39` — `@textract_result&.update_columns(textract_job_status: 'failed')` (rescue StandardError) — col `textract_job_status` — **update_columns**.
4. `app/services/get_resume_text_from_textract.rb:25-31` — `@textract_result.update({ textract_job_status: <downcased aws status>, textract_job_result:, textract_job_result_text: resume_text_from_blocks(...) })` — cols `textract_job_status` + `textract_job_result_text` — **update** (fires `after_commit :queue_ai_summary_job`).
5. `app/services/get_resume_text_from_textract.rb:40` — `@textract_result.update_columns(textract_job_status: 'failed')` (AWS reports FAILED) — col `textract_job_status` — **update_columns**.
6. `app/services/get_resume_text_from_textract.rb:47` — `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` (rescue InvalidJobIdException) — col `textract_job_status` — **update_columns**.

Note: `not_started`/`succeeded` are written ONLY by the literal downcased AWS string at get:26 (succeeded path) — there is no explicit `textract_job_status_succeeded!` call. `not_started` (enum 0) is never written by application code.

## RECORD 2 — AiJobApplicationSummary (status / stale)

### status writes
7. `app/interactors/create_ai_summary_generation.rb:49` — `.build(... status: :textract_processing ...)` — col `status` — **build** (saved at :53).
8. `app/interactors/create_ai_summary_generation.rb:62` — `.build(... status: :pending ...)` — col `status` — **build** (saved at :70).
9. `app/interactors/create_bulk_ai_summary_generation.rb:52` — `.build(... status: :pending ...)` — col `status` — **build** (saved at :57). (NEW file; bulk-path summary creation.)
10. `app/services/ai_job_application_action/summary/generate.rb:32` — `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?` — col `status` — **update**.
11. `app/services/ai_job_application_action/summary/generate.rb:35-39` — `AiJobApplicationSummary.create(job_application:, textract_result:, status: :extracting)` — col `status` — **create**.
12. `app/services/ai_job_application_action/summary/generate.rb:64-68` — `ai_summary.update({ status: :summarizing, structured_data: })` — col `status` — **update**.
13. `app/services/ai_job_application_action/summary/generate.rb:175` — `ai_summary&.update_columns(status: :retrying, error_message:)` (rescue CustomErrorAiSummary) — col `status` — **update_columns**.
14. `app/services/ai_job_application_action/summary/generate.rb:180` — `ai_summary&.update_columns(status: :failed, error_message:)` (rescue JSON::ParserError) — col `status` — **update_columns**.
15. `app/services/ai_job_application_action/summary/generate.rb:184` — `ai_summary&.update_columns(status: :failed, error_message:)` (rescue StandardError) — col `status` — **update_columns**.
16. `app/services/ai_job_application_action/orchestrate.rb:72` — `@ai_job_application_summary.update(status: :awaiting_job_criteria)` (check_criteria_and_score) — col `status` — **update**.
17. `app/services/ai_job_application_action/scoring/score_job_application.rb:23` — `@ai_job_application_summary.update(status: :awaiting_job_criteria)` (criteria not succeeded) — col `status` — **update**.
18. `app/services/ai_job_application_action/scoring/score_job_application.rb:32` — `@ai_job_application_summary.update(status: :scoring)` — col `status` — **update**.
19. `app/services/ai_job_application_action/scoring/score_job_application.rb:45` — `@ai_job_application_summary.update(status: :awaiting_job_criteria)` (criteria array empty) — col `status` — **update**.
20. `app/services/ai_job_application_action/scoring/score_job_application.rb:119-124` — `@ai_job_application_summary.update({ score_percentage:, criteria_results:, status: :integrating })` — col `status` (+ score_percentage, criteria_results) — **update**.
21. `app/services/ai_job_application_action/scoring/score_job_application.rb:130` — `@ai_job_application_summary&.update(status: :retrying, error_message:)` (rescue CustomErrorAiSummary) — col `status` — **update**.
22. `app/services/ai_job_application_action/scoring/score_job_application.rb:135` — `@ai_job_application_summary&.update(status: :failed, error_message:)` (rescue JSON::ParserError) — col `status` — **update**.
23. `app/services/ai_job_application_action/scoring/score_job_application.rb:139` — `@ai_job_application_summary&.update(status: :failed, error_message:)` (rescue StandardError) — col `status` — **update**.
24. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:49-53` — `@ai_job_application_summary.update({ integrated_role_analysis:, status: :succeeded })` — col `status` (+ integrated_role_analysis) — **update** (the ONLY write that reaches `succeeded`; fires `after_commit :update_summary_status_record` + `destroy_previous_textract_results`).
25. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:59` — `@ai_job_application_summary&.update(status: :retrying, error_message:)` (rescue CustomErrorAiSummary) — col `status` — **update**.
26. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:64` — `@ai_job_application_summary&.update(status: :failed, error_message:)` (rescue JSON::ParserError) — col `status` — **update**.
27. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:68` — `@ai_job_application_summary&.update(status: :failed, error_message:)` (rescue StandardError) — col `status` — **update**.
28. `app/jobs/generate_ai_job_application_summary_job.rb:19` — `ai_summary&.update_columns(status: :failed, error_message:)` (retry_on exhaustion block) — col `status` — **update_columns**.
29. `app/jobs/generate_ai_job_application_summary_job.rb:44` — `ai_summary&.update_columns(status: :failed, error_message:)` (rescue StandardError) — col `status` — **update_columns**.

### stale writes
30. `app/services/submit_resume_to_textract.rb:19` — `@job_application.ai_job_application_summaries.update_all(stale: true)` (only when NO textract_processing+stale:false summary exists) — col `stale` — **update_all**.
31. `app/interactors/create_ai_summary_generation.rb:37` — `active_ai_summary.update_columns(stale: true)` (textract_result_id mismatch) — col `stale` — **update_columns**.
32. `app/interactors/create_bulk_ai_summary_generation.rb:41` — `active_ai_summary.update_columns(stale: true)` (textract_result_id mismatch) — col `stale` — **update_columns**. (NEW.)

## RECORD 3 — AiJobApplicationSummaryStatus (status + denormalized columns)

NOTE: enum is now `{none:0, initial_summary_pending:1, current:2, regenerating:3}` (_prefix:true). The map's 10-value mirror enum and the `create_status_record`/`update_summary_status_record(update_columns)` mechanism are STALE.

33. `app/models/textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` (set_initial_summary_pending; only when status_none? || status_initial_summary_pending?) — cols `status` + `ai_job_application_summary_id` — **update_columns**. (NEW.)
34. `app/models/ai_job_application_summary.rb:74-80` — `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` (update_summary_status_record after_commit on summary→succeeded) — cols `status`, `ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis` — **update** (CHANGED from map: map said update_columns + `regenerating:false` + status integer 7; current code uses `update`, status `'current'`, no `regenerating` key).
35. `app/interactors/find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` (existing record whose summary status_succeeded?) — col `status` — **update_columns**. (NEW — this is where `regenerating` IS set; the map's Gap 7 "never set to true" is STALE.)
36. `app/interactors/find_or_create_ai_job_application_summary_status.rb:25-35` — `@status_record = build_ai_job_application_summary_status` then assigns `status = 'current'` (+ ai_job_application_summary, score_percentage, headline, integrated_role_analysis) when latest summary succeeded & not stale, else `status = 'none'`; `@status_record.save` at :37 — cols `status` (+ denormalized) — **build + assignment + save**. (NEW.)

Callers of FindOrCreateAiJobApplicationSummaryStatus: `JobApplication#find_or_create_ai_job_application_summary_status` (job_application.rb:160), itself called from `TextractResult#generate_ai_summary_with_credit_flow:70` and from `JobApplication` enqueue path (job_application.rb:170).

## RECORD 4 — AiJobCriteria (status)

37. `app/models/job.rb:696` — `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)` (extract_job_criteria, existing record) — col `status` — **update_columns**.
38. `app/models/job.rb:699` — `self.ai_job_criteria = AiJobCriteria.new(job: self, status: :pending)` (extract_job_criteria, new record) — col `status` — **new** (saved at :700).
39. `app/services/ai_job_application_action/scoring/extract_criteria.rb:28` — `@ai_job_criteria.update_columns(status: :in_progress) unless @ai_job_criteria.status_in_progress?` — col `status` — **update_columns**.
40. `app/services/ai_job_application_action/scoring/extract_criteria.rb:32` — `@ai_job_criteria.update_columns(status: :failed, error_message: 'Job description is blank')` — col `status` — **update_columns**.
41. `app/services/ai_job_application_action/scoring/extract_criteria.rb:62` — `@ai_job_criteria.update_columns(status: :failed, error_message: 'No criteria sections found in job description')` — col `status` — **update_columns**.
42. `app/services/ai_job_application_action/scoring/extract_criteria.rb:122` — `@ai_job_criteria.update_columns(status: :failed, error_message: 'No criteria extracted from job description')` — col `status` — **update_columns**.
43. `app/services/ai_job_application_action/scoring/extract_criteria.rb:132-136` — `@ai_job_criteria.update({ status: :succeeded, criteria:, metadata: })` — col `status` (+ criteria, metadata) — **update** (the ONLY write reaching `succeeded`; fires `after_commit :resume_waiting_summaries`).
44. `app/services/ai_job_application_action/scoring/extract_criteria.rb:146` — `@ai_job_criteria&.update_columns(status: :retrying)` (rescue CustomErrorAiSummary) — col `status` — **update_columns**.
45. `app/services/ai_job_application_action/scoring/extract_criteria.rb:151` — `@ai_job_criteria&.update_columns(status: :failed, error_message: "Failed to parse AI response: ...")` (rescue JSON::ParserError) — col `status` — **update_columns**.
46. `app/services/ai_job_application_action/scoring/extract_criteria.rb:155` — `@ai_job_criteria&.update_columns(status: :failed, error_message:)` (rescue StandardError) — col `status` — **update_columns**.
47. `app/services/ai_job_application_action/scoring/score_job_application.rb:44` — `ai_job_criteria.update_columns(status: :failed, error_message: 'Criteria array is empty')` — col `status` — **update_columns**.
48. `app/jobs/extract_job_criteria_job.rb:9` — `ai_job_criteria&.update_columns(status: :failed, error_message:)` (retry_on exhaustion block) — col `status` — **update_columns**.
49. `app/jobs/extract_job_criteria_job.rb:28` — `ai_job_criteria&.update_columns(status: :failed, error_message:)` (rescue StandardError) — col `status` — **update_columns**.

---

## Out-of-scope writes confirmed (NOT one of the four records)

- `app/jobs/bulk_generate_ai_summaries_job.rb:54,66,86,180` — write `BulkAiSummaryJobApplication.status` (`done`/`deferred`/`failed`), not AiJobApplicationSummary. The bulk job does NOT directly write AiJobApplicationSummary.status; generation flows through `generate_ai_summary_with_credit_flow`.
- `app/interactors/queue_bulk_ai_summary_jobs.rb:37` — READ query on AiJobApplicationSummaryStatus (status: :current), not a write. Lines 44/65-68 write BulkAiSummaryJobApplication.
- Export jobs (export_*_job.rb), invites_controller, billing — unrelated records.

## Key map-divergence flags surfaced by the census

- **AiJobApplicationSummaryStatus enum changed** to 4 values (none/initial_summary_pending/current/regenerating). Map shows old 10-value mirror enum (map lines 509-515).
- **`update_summary_status_record` CHANGED** (map line 502/605): now `update` (not update_columns), status `'current'` (not integer 7 'succeeded'), NO `regenerating` key. Also now broadcasts JobChannel `ai_summary_succeeded` (ai_job_application_summary.rb:93-97) — absent from map.
- **`regenerating` IS now set** (find_or_create_ai_job_application_summary_status.rb:15). Map Gap 7 ("never set to true", lines 638-650) is STALE.
- **`create_status_record` callback REMOVED** from AiJobApplicationSummary (map line 500 describes it; it no longer exists). Replaced by `FindOrCreateAiJobApplicationSummaryStatus` interactor + `set_initial_summary_pending`.
- **`CreateBulkAiSummaryGeneration` is a NEW file** (map Trigger B says bulk calls generate_ai_summary_with_credit_flow directly with no create interactor; bulk now creates the summary row via this interactor — bulk_generate_ai_summaries_job.rb:74).
