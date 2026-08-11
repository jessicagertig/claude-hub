# X0 — Writer Census Adversarial Review (pass 4)

**Slice:** X0 — authoritative write-site census for the four records' status/key columns.
**Method:** Re-grepped the entire `app/` and `lib/` from scratch; opened and read every hit. Compared against the candidate map's Part 10 (Coverage Cross-Check) and the inline write citations.

## Scope columns (per task)
- TextractResult.textract_job_status / textract_job_result_text
- AiJobApplicationSummary.status / stale
- AiJobApplicationSummaryStatus.status + denormalized (ai_job_application_summary_id, score_percentage, headline, integrated_role_analysis)
- AiJobCriteria.status

## Authoritative confirmed write-site census (all opened + read)

### TextractResult.textract_job_status / textract_job_result_text
1. `app/services/submit_resume_to_textract.rb:22` — `.build(textract_job_id:..., textract_job_status: 'in_progress')` + `.save` `:24` — textract_job_status — build/save
2. `app/services/submit_resume_to_textract.rb:33` — `@textract_result&.update_columns(textract_job_status: 'failed')` — textract_job_status — update_columns
3. `app/services/submit_resume_to_textract.rb:39` — `@textract_result&.update_columns(textract_job_status: 'failed')` — textract_job_status — update_columns
4. `app/services/get_resume_text_from_textract.rb:31` — `@textract_result.update(update_textract_params)` where params (`:25-29`) = `textract_job_status: …'succeeded', textract_job_result:, textract_job_result_text:` — textract_job_status + textract_job_result_text — **.update** (fires `queue_ai_summary_job` after_commit + `saved_change_to_textract_job_result_text?`)
5. `app/services/get_resume_text_from_textract.rb:40` — `@textract_result.update_columns(textract_job_status: 'failed')` — textract_job_status — update_columns
6. `app/services/get_resume_text_from_textract.rb:47` — `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` — textract_job_status — update_columns

### AiJobApplicationSummary.status / stale
7. `app/interactors/create_ai_summary_generation.rb:37` — `active_ai_summary.update_columns(stale: true)` — stale — update_columns
8. `app/interactors/create_ai_summary_generation.rb:47-53` — `.build(status: :textract_processing)` + `.save` `:53` — status — build/save
9. `app/interactors/create_ai_summary_generation.rb:60-70` — `.build(status: :pending)` + `.save` `:70` — status — build/save
10. `app/interactors/create_bulk_ai_summary_generation.rb:41` — `active_ai_summary.update_columns(stale: true)` — stale — update_columns
11. `app/interactors/create_bulk_ai_summary_generation.rb:50-57` — `.build(status: :pending)` + `.save` `:57` — status — build/save
12. `app/services/submit_resume_to_textract.rb:19` — `ai_job_application_summaries.update_all(stale: true)` — stale — update_all
13. `app/services/ai_job_application_action/summary/generate.rb:32` — `existing_ai_summary.update(status: :extracting)` — status — .update (reuse branch)
14. `app/services/ai_job_application_action/summary/generate.rb:35-39` — `AiJobApplicationSummary.create(status: :extracting)` — status — create
15. `app/services/ai_job_application_action/summary/generate.rb:64-68` — `ai_summary.update(status: :summarizing,…)` — status — .update
16. `app/services/ai_job_application_action/summary/generate.rb:175` — `ai_summary&.update_columns(status: :retrying,…)` — status — update_columns
17. `app/services/ai_job_application_action/summary/generate.rb:180` — `ai_summary&.update_columns(status: :failed,…)` — status — update_columns
18. `app/services/ai_job_application_action/summary/generate.rb:184` — `ai_summary&.update_columns(status: :failed,…)` — status — update_columns
19. `app/services/ai_job_application_action/orchestrate.rb:72` — `@ai_job_application_summary.update(status: :awaiting_job_criteria)` — status — .update
20. `app/services/ai_job_application_action/scoring/score_job_application.rb:23` — `.update(status: :awaiting_job_criteria)` — status — .update
21. `:32` — `.update(status: :scoring)` — status — .update
22. `:45` — `.update(status: :awaiting_job_criteria)` — status — .update
23. `:119-124` — `.update(score_percentage:, criteria_results:, status: :integrating)` — status — .update
24. `:130` — `&.update(status: :retrying,…)` — status — .update
25. `:135` — `&.update(status: :failed,…)` — status — .update
26. `:139` — `&.update(status: :failed,…)` — status — .update
27. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:49-53` — `.update(integrated_role_analysis:, status: :succeeded)` — status — **.update** (fires `update_summary_status_record` + `destroy_previous_textract_results`)
28. `:59` — `&.update(status: :retrying,…)` — status — .update
29. `:64` — `&.update(status: :failed,…)` — status — .update
30. `:68` — `&.update(status: :failed,…)` — status — .update
31. `app/jobs/generate_ai_job_application_summary_job.rb:19` — `ai_summary&.update_columns(status: :failed,…)` — status — update_columns (retry-exhaustion)
32. `app/jobs/generate_ai_job_application_summary_job.rb:44` — `ai_summary&.update_columns(status: :failed,…)` — status — update_columns (StandardError rescue)

### AiJobApplicationSummaryStatus.status + denormalized
33. `app/models/ai_job_application_summary.rb:74-80` — `update(ai_job_application_summary_id:, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — status + all denormalized — **.update**
34. `app/models/textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` — status + fk — update_columns
35. `app/interactors/find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — status — update_columns
36. `app/interactors/find_or_create_ai_job_application_summary_status.rb:28-35` + `:37` save — create-path: `:29` status='current', `:30-32` score_percentage/headline/integrated_role_analysis, `:28` ai_job_application_summary= pointer, OR `:34` status='none'; persisted by `:37` `.save` — status + denormalized — assign+save

### AiJobCriteria.status
37. `app/models/job.rb:696` — `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)` — status — update_columns
38. `app/models/job.rb:699` — `AiJobCriteria.new(status: :pending)` + `:700` `.save` — status — new/save
39. `app/jobs/extract_job_criteria_job.rb:9` — `&.update_columns(status: :failed,…)` — status — update_columns
40. `app/jobs/extract_job_criteria_job.rb:28` — `&.update_columns(status: :failed,…)` — status — update_columns
41. `app/services/ai_job_application_action/scoring/score_job_application.rb:44` — `ai_job_criteria.update_columns(status: :failed,…)` — status — update_columns
42. `app/services/ai_job_application_action/scoring/extract_criteria.rb:28` — `update_columns(status: :in_progress)` — status — update_columns
43. `:32` — `update_columns(status: :failed,…)` — status — update_columns
44. `:62` — `update_columns(status: :failed,…)` — status — update_columns
45. `:122` — `update_columns(status: :failed,…)` — status — update_columns
46. `:132-140` — `@ai_job_criteria.update(status: :succeeded, criteria:, metadata:)` — status — **.update** (deliberate, fires resume_waiting_summaries)
47. `:146` — `&.update_columns(status: :retrying)` — status — update_columns
48. `:151` — `&.update_columns(status: :failed,…)` — status — update_columns
49. `:155` — `&.update_columns(status: :failed,…)` — status — update_columns

### BulkAiSummaryJobApplication.status (companion claim record)
50. `app/interactors/queue_bulk_ai_summary_jobs.rb:65-69` — `.create(status: :processing)` — status — create
51. `app/jobs/bulk_generate_ai_summaries_job.rb:54` — `update_columns(status: :done)` — status — update_columns
52. `:66` — `update_columns(status: :deferred)` — status — update_columns
53. `:86` — `update_columns(status: :done)` — status — update_columns
54. `:178-180` — `update_all(status: 'failed', updated_at:)` — status — update_all

### Rake-layer (outside trigger/structural coverage)
55. `lib/tasks/ai_bulk_extract.rake:34-38` — `AiJobApplicationSummary.create(status: :in_progress)` — status — create — **STALE: `:in_progress` not in current 10-value enum → ArgumentError**
56. `lib/tasks/ai_bulk_extract.rake:59-62` — `summary.update(status: :extracted,…)` — status — .update — **STALE: `:extracted` not in current enum**
57. `lib/tasks/ai_bulk_extract.rake:89` — `summary&.update(status: :failed,…)` — status — .update

## Cross-checks
- Bang enum methods (`status_xxx!`/`textract_job_status_xxx!`) on the four records: NONE. Only hit is `invites_controller.rb:105` on the out-of-scope `Invite` model. (Map line 721 correct.)
- `update_all` on the four records: only `submit_resume_to_textract.rb:19` (stale) + `bulk_generate_ai_summaries_job.rb:178-180` (bulk-claim record).
- Channels dir: no writes.
- Only AiJobCriteria creator: `job.rb:699`. Only status-row creator: `find_or_create…status.rb:25`+`:37`. (No stray `find_or_create_by`/`AiJobApplicationSummaryStatus.create`.)

## Verdict
Every Part-10 census line in the candidate map is confirmed against literal code. No DISPUTES. Minor omission noted below; otherwise clean.
