# X0 Adversarial Review (Pass 2) — Writer Census

Slice X0: authoritative write-site census for the four records' status/key columns.
Method: grepped app/, lib/, jobs, services, interactors, models, controllers, channels, rake tasks for every write form (.update, .update_columns, .update_column, .update_all, .save, direct `status =`, bang enum methods, build/create with status, raw SQL). Opened and read each hit.

## Authoritative write-site census (50 sites)

### TextractResult — textract_job_status / textract_job_result_text
1. `app/services/submit_resume_to_textract.rb:22` `@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')` (saved :24) — textract_job_status — build/save
2. `app/services/submit_resume_to_textract.rb:33` `@textract_result&.update_columns(textract_job_status: 'failed')` — textract_job_status — update_columns
3. `app/services/submit_resume_to_textract.rb:39` `@textract_result&.update_columns(textract_job_status: 'failed')` — textract_job_status — update_columns
4. `app/services/get_resume_text_from_textract.rb:31` `if @textract_result.update(update_textract_params)` (params :26-28: textract_job_status, textract_job_result, textract_job_result_text) — textract_job_status + textract_job_result_text — update
5. `app/services/get_resume_text_from_textract.rb:40` `@textract_result.update_columns(textract_job_status: 'failed')` — textract_job_status — update_columns
6. `app/services/get_resume_text_from_textract.rb:47` `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` — textract_job_status — update_columns

### AiJobApplicationSummary — status / stale
7. `app/services/submit_resume_to_textract.rb:19` `@job_application.ai_job_application_summaries.update_all(stale: true)` — stale — update_all
8. `app/interactors/create_ai_summary_generation.rb:37` `active_ai_summary.update_columns(stale: true)` — stale — update_columns
9. `app/interactors/create_ai_summary_generation.rb:47-51` `build(... status: :textract_processing ...)` (saved :53) — status — build/save
10. `app/interactors/create_ai_summary_generation.rb:60-64` `build(... status: :pending ...)` (saved :70) — status — build/save
11. `app/interactors/create_bulk_ai_summary_generation.rb:41` `active_ai_summary.update_columns(stale: true)` — stale — update_columns
12. `app/interactors/create_bulk_ai_summary_generation.rb:50-52` `build(... status: :pending ...)` — status — build/save
13. `app/services/ai_job_application_action/summary/generate.rb:32` `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?` — status — update
14. `app/services/ai_job_application_action/summary/generate.rb:35-38` `AiJobApplicationSummary.create(... status: :extracting)` — status — create
15. `app/services/ai_job_application_action/summary/generate.rb:64-65` `ai_summary.update({status: :summarizing, structured_data:})` (:68) — status — update
16. `app/services/ai_job_application_action/summary/generate.rb:175` `ai_summary&.update_columns(status: :retrying, error_message: e&.message)` — status — update_columns
17. `app/services/ai_job_application_action/summary/generate.rb:180` `ai_summary&.update_columns(status: :failed, ...)` — status — update_columns
18. `app/services/ai_job_application_action/summary/generate.rb:184` `ai_summary&.update_columns(status: :failed, ...)` — status — update_columns
19. `app/services/ai_job_application_action/orchestrate.rb:72` `@ai_job_application_summary.update(status: :awaiting_job_criteria)` — status — update
20. `app/services/ai_job_application_action/scoring/score_job_application.rb:23` `@ai_job_application_summary.update(status: :awaiting_job_criteria)` — status — update
21. `app/services/ai_job_application_action/scoring/score_job_application.rb:32` `@ai_job_application_summary.update(status: :scoring)` — status — update
22. `app/services/ai_job_application_action/scoring/score_job_application.rb:45` `@ai_job_application_summary.update(status: :awaiting_job_criteria)` — status — update
23. `app/services/ai_job_application_action/scoring/score_job_application.rb:119-122` `@ai_job_application_summary.update(update_params)` (status: :integrating, score_percentage, criteria_results) (:124) — status + score_percentage — update
24. `app/services/ai_job_application_action/scoring/score_job_application.rb:130` `@ai_job_application_summary&.update(status: :retrying, ...)` — status — update
25. `app/services/ai_job_application_action/scoring/score_job_application.rb:135` `@ai_job_application_summary&.update(status: :failed, ...)` — status — update
26. `app/services/ai_job_application_action/scoring/score_job_application.rb:139` `@ai_job_application_summary&.update(status: :failed, ...)` — status — update
27. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:49-51` `@ai_job_application_summary.update(update_params)` (integrated_role_analysis, status: :succeeded) (:53) — status — update
28. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:59` `@ai_job_application_summary&.update(status: :retrying, ...)` — status — update
29. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:64` `@ai_job_application_summary&.update(status: :failed, ...)` — status — update
30. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:68` `@ai_job_application_summary&.update(status: :failed, ...)` — status — update
31. `app/jobs/generate_ai_job_application_summary_job.rb:19` `ai_summary&.update_columns(status: :failed, error_message: error&.message)` (retry_on exhaustion block) — status — update_columns
32. `app/jobs/generate_ai_job_application_summary_job.rb:44` `ai_summary&.update_columns(status: :failed, error_message: e&.message)` (StandardError rescue) — status — update_columns

### AiJobApplicationSummaryStatus — status + denormalized columns
33. `app/interactors/find_or_create_ai_job_application_summary_status.rb:15` `@status_record.update_columns(status: 'regenerating')` — status — update_columns
34. `app/interactors/find_or_create_ai_job_application_summary_status.rb:29-32` direct assign `status = 'current'`, `score_percentage =`, `headline =`, `integrated_role_analysis =` (saved :37) — status + 3 denormalized — build/save
35. `app/interactors/find_or_create_ai_job_application_summary_status.rb:34` direct assign `status = 'none'` (saved :37) — status — build/save
36. `app/models/textract_result.rb:104-106` `status_record.update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` — status — update_columns
37. `app/models/ai_job_application_summary.rb:74-79` `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — status + 3 denormalized — update

### AiJobCriteria — status
38. `app/models/job.rb:696` `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)` — status — update_columns
39. `app/models/job.rb:699` `self.ai_job_criteria = AiJobCriteria.new(job: self, status: :pending)` — status — new/save
40. `app/services/ai_job_application_action/scoring/extract_criteria.rb:28` `update_columns(status: :in_progress)` — status — update_columns
41. `app/services/ai_job_application_action/scoring/extract_criteria.rb:32` `update_columns(status: :failed, ...)` — status — update_columns
42. `app/services/ai_job_application_action/scoring/extract_criteria.rb:62` `update_columns(status: :failed, ...)` — status — update_columns
43. `app/services/ai_job_application_action/scoring/extract_criteria.rb:122` `update_columns(status: :failed, ...)` — status — update_columns
44. `app/services/ai_job_application_action/scoring/extract_criteria.rb:132-140` `@ai_job_criteria.update(update_params)` (status: :succeeded, criteria, metadata) — status — update (deliberately .update to fire callback, per :138 comment)
45. `app/services/ai_job_application_action/scoring/extract_criteria.rb:146` `@ai_job_criteria&.update_columns(status: :retrying)` — status — update_columns
46. `app/services/ai_job_application_action/scoring/extract_criteria.rb:151` `@ai_job_criteria&.update_columns(status: :failed, ...)` — status — update_columns
47. `app/services/ai_job_application_action/scoring/extract_criteria.rb:155` `@ai_job_criteria&.update_columns(status: :failed, ...)` — status — update_columns
48. `app/services/ai_job_application_action/scoring/score_job_application.rb:44` `ai_job_criteria.update_columns(status: :failed, error_message: 'Criteria array is empty')` — status — update_columns
49. `app/jobs/extract_job_criteria_job.rb:9` `ai_job_criteria&.update_columns(status: :failed, ...)` — status — update_columns
50. `app/jobs/extract_job_criteria_job.rb:28` `ai_job_criteria&.update_columns(status: :failed, ...)` — status — update_columns

## Negative findings (no writes here)
- No bang enum methods (`textract_job_status_xxx!`, `status_xxx!`) used on any of the four records anywhere in app/ or lib/. The only enum-bang in the repo on a `status` is `invites_controller.rb:105` `@invite.status_pending!` (Invite model — out of scope).
- No raw SQL (`execute(`, `exec_update`, `exec_query`) writing these tables.
- Rake tasks (`housekeeping_tasks.rake:457` textract_backfill_status, `ai_bulk_extract.rake:54`, `one_off_tasks.rake:6`) only READ the four records or invoke `Summary::Generate` / `SubmitResumeToTextract` (whose writes are already censused). No direct write sites.
- Controllers: no direct status writes to the four records.
- `update_column` (singular) hits at `job_application.rb:649/651/654` write `external_resume_status` (JobApplication) — not one of the four records.
- `bulk_generate_ai_summaries_job.rb:180` `update_all(status: 'failed')` writes BulkAiSummaryJobApplication — not one of the four records.

## Verdicts vs candidate map

Map Part 10 census (`:589-592`) and tables 5.1-5.4 reconcile exactly with the 50 sites above — EXCEPT:

DISPUTE — Table 5.2, `retrying` row, writer list `summary/generate.rb:175, score_job_application.rb:130, integrate_analysis.rb:59, job :?`. The trailing `job :?` asserts `GenerateAiJobApplicationSummaryJob` is a `retrying` writer with an unknown line. It is NOT. The job's `retry_on` exhaustion block (`generate_ai_job_application_summary_job.rb:19`) and its StandardError rescue (`:44`) both write `status: :failed`, never `:retrying`. No site in the job writes `retrying`. Correction: drop `job :?` from the retrying writer list; the job writes only `failed` (:19, :44).

All other census/table claims AGREE.

## Omissions
None beyond the dispute above. The census range `find_or_create_…status.rb:15/25-37` correctly covers the denormalized-column writes at :29-32. The `ai_job_application_summary.rb:74-80` and `textract_result.rb:104-107` ranges correctly cover their denormalized writes.
