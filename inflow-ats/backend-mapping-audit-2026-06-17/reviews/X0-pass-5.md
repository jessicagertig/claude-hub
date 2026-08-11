# X0 — Writer Census Adversarial Review (Pass 5)

**Slice:** X0 — Writer census (authoritative coverage baseline)
**Method:** Re-grepped the entire codebase from scratch for every write to the status/key columns of the four records, then OPENED and READ each hit to confirm it is a real write. Compared the confirmed list against the candidate map's Part 5 state-transition tables (5.1–5.4), Part 10 coverage cross-check, and the changelog/Part 9 narrative.

## Verdict summary

The candidate map's X0 census is **accurate and essentially complete** for status/stale writes. Every write site I independently confirmed is present and correctly attributed in the map (writer file:line, `.update` vs `update_columns` vs build/create, column). One genuine omission: the census enumeration (Part 10 line 766) for AiJobApplicationSummary omits the `submit_resume_to_textract.rb:26` `update_columns(textract_result_id:)` key-column write (it IS documented narratively elsewhere in the map, just not in the census line). One minor scope note on `textract_result_id` being a key column under the slice's "status/key column" mandate.

## Confirmed write-site census (from scratch)

### TextractResult — textract_job_status / textract_job_result_text
1. `app/services/submit_resume_to_textract.rb:22` — `@job_application.textract_results.build(textract_job_id:, textract_job_status: 'in_progress')` saved at `:24` — **build/create**, column textract_job_status
2. `app/services/submit_resume_to_textract.rb:33` — `@textract_result&.update_columns(textract_job_status: 'failed')` — **update_columns**
3. `app/services/submit_resume_to_textract.rb:39` — `@textract_result&.update_columns(textract_job_status: 'failed')` — **update_columns**
4. `app/services/get_resume_text_from_textract.rb:31` — `@textract_result.update({textract_job_status: <downcased>, textract_job_result:, textract_job_result_text:})` — **`.update`** (SOLE callback-firing TextractResult write; only site writing both status + result_text)
5. `app/services/get_resume_text_from_textract.rb:40` — `@textract_result.update_columns(textract_job_status: 'failed')` — **update_columns**
6. `app/services/get_resume_text_from_textract.rb:47` — `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` — **update_columns**

### AiJobApplicationSummary — status / stale
7. `app/interactors/create_ai_summary_generation.rb:37` — `active_ai_summary.update_columns(stale: true)` — **update_columns**, stale
8. `app/interactors/create_ai_summary_generation.rb:47-51` — `build(status: :textract_processing, requested_by_organization_user_id:)` saved `:53` — **build/create**, status
9. `app/interactors/create_ai_summary_generation.rb:60-64` — `build(status: :pending)` saved `:70` — **build/create**, status
10. `app/interactors/create_bulk_ai_summary_generation.rb:41` — `active_ai_summary.update_columns(stale: true)` — **update_columns**, stale
11. `app/interactors/create_bulk_ai_summary_generation.rb:50-54` — `build(status: :pending)` saved `:57` — **build/create**, status
12. `app/services/ai_job_application_action/summary/generate.rb:32` — `existing_ai_summary.update(status: :extracting)` — **`.update`**
13. `app/services/ai_job_application_action/summary/generate.rb:35-39` — `AiJobApplicationSummary.create(status: :extracting)` — **create**
14. `app/services/ai_job_application_action/summary/generate.rb:64-68` — `ai_summary.update({status: :summarizing, structured_data:})` (write `:68`) — **`.update`**
15. `app/services/ai_job_application_action/summary/generate.rb:175` — `ai_summary&.update_columns(status: :retrying)` — **update_columns**
16. `app/services/ai_job_application_action/summary/generate.rb:180` — `ai_summary&.update_columns(status: :failed)` — **update_columns**
17. `app/services/ai_job_application_action/summary/generate.rb:184` — `ai_summary&.update_columns(status: :failed)` — **update_columns**
18. `app/services/ai_job_application_action/orchestrate.rb:72` — `@ai_job_application_summary.update(status: :awaiting_job_criteria)` — **`.update`**
19. `app/services/ai_job_application_action/scoring/score_job_application.rb:23` — `update(status: :awaiting_job_criteria)` — **`.update`**
20. `app/services/ai_job_application_action/scoring/score_job_application.rb:32` — `update(status: :scoring)` — **`.update`**
21. `app/services/ai_job_application_action/scoring/score_job_application.rb:45` — `update(status: :awaiting_job_criteria)` — **`.update`**
22. `app/services/ai_job_application_action/scoring/score_job_application.rb:119-124` — `update({score_percentage:, criteria_results:, status: :integrating})` (write `:124`) — **`.update`**
23. `app/services/ai_job_application_action/scoring/score_job_application.rb:130` — `update(status: :retrying)` — **`.update`**
24. `app/services/ai_job_application_action/scoring/score_job_application.rb:135` — `update(status: :failed)` — **`.update`**
25. `app/services/ai_job_application_action/scoring/score_job_application.rb:139` — `update(status: :failed)` — **`.update`**
26. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:49-53` — `update({integrated_role_analysis:, status: :succeeded})` (write `:53`, fires update_summary_status_record) — **`.update`**
27. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:59` — `update(status: :retrying)` — **`.update`**
28. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:64` — `update(status: :failed)` — **`.update`**
29. `app/services/ai_job_application_action/scoring/integrate_analysis.rb:68` — `update(status: :failed)` — **`.update`**
30. `app/jobs/generate_ai_job_application_summary_job.rb:19` — `ai_summary&.update_columns(status: :failed)` (retry-exhaustion) — **update_columns** (failed-only writer)
31. `app/jobs/generate_ai_job_application_summary_job.rb:44` — `ai_summary&.update_columns(status: :failed)` (StandardError) — **update_columns**
32. `app/services/submit_resume_to_textract.rb:19` — `ai_job_application_summaries.update_all(stale: true)` — **update_all**, stale
33. `app/services/submit_resume_to_textract.rb:26` — `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` — **update_columns**, KEY column `textract_result_id` (not status/stale)

### AiJobApplicationSummaryStatus — status + denormalized columns
34. `app/interactors/find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — **update_columns** (status-only; denormalized cols NOT cleared; bypasses counter_culture)
35. `app/interactors/find_or_create_ai_job_application_summary_status.rb:28-32` + save `:37` — create-path `status = 'current'` + denormalized (score_percentage/headline/integrated_role_analysis/ai_job_application_summary_id) — **build/save** (fires counter_culture)
36. `app/interactors/find_or_create_ai_job_application_summary_status.rb:34` + save `:37` — create-path `status = 'none'` — **build/save**
37. `app/models/textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` — **update_columns** (bypasses counter_culture)
38. `app/models/ai_job_application_summary.rb:74-80` — `ai_job_application_summary_status.update(ai_job_application_summary_id:, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — **`.update`** (fires counter_culture; via after_commit `update_summary_status_record`, gated `:69` `saved_change_to_status? && status_succeeded?`)

### AiJobCriteria — status
39. `app/models/job.rb:696` — `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)` — **update_columns**
40. `app/models/job.rb:699` — `AiJobCriteria.new(job:, status: :pending)` saved `:700` — **build/create**
41. `app/services/ai_job_application_action/scoring/extract_criteria.rb:28` — `update_columns(status: :in_progress)` — **update_columns**
42. `app/services/ai_job_application_action/scoring/extract_criteria.rb:32` — `update_columns(status: :failed)` — **update_columns**
43. `app/services/ai_job_application_action/scoring/extract_criteria.rb:62` — `update_columns(status: :failed)` — **update_columns**
44. `app/services/ai_job_application_action/scoring/extract_criteria.rb:122` — `update_columns(status: :failed)` — **update_columns**
45. `app/services/ai_job_application_action/scoring/extract_criteria.rb:132-140` — `@ai_job_criteria.update({status: :succeeded, criteria:, metadata:})` — **`.update`** (deliberately, to fire resume_waiting_summaries; in-code comment `:138-139`)
46. `app/services/ai_job_application_action/scoring/extract_criteria.rb:146` — `update_columns(status: :retrying)` — **update_columns**
47. `app/services/ai_job_application_action/scoring/extract_criteria.rb:151` — `update_columns(status: :failed)` — **update_columns**
48. `app/services/ai_job_application_action/scoring/extract_criteria.rb:155` — `update_columns(status: :failed)` — **update_columns**
49. `app/services/ai_job_application_action/scoring/score_job_application.rb:44` — `ai_job_criteria.update_columns(status: :failed, error_message: 'Criteria array is empty')` — **update_columns**
50. `app/jobs/extract_job_criteria_job.rb:9` — `ai_job_criteria&.update_columns(status: :failed)` (exhaustion) — **update_columns**
51. `app/jobs/extract_job_criteria_job.rb:28` — `ai_job_criteria&.update_columns(status: :failed)` (StandardError) — **update_columns**

### Rake-layer (out of trigger/structural coverage; STALE enum values)
52. `lib/tasks/ai_bulk_extract.rake:34-38` — `AiJobApplicationSummary.create(status: :in_progress)` — **create**; `:in_progress` is NOT a valid enum value → would raise ArgumentError
53. `lib/tasks/ai_bulk_extract.rake:59-62` — `summary.update(status: :extracted)` — **`.update`**; `:extracted` is NOT valid → ArgumentError
54. `lib/tasks/ai_bulk_extract.rake:89` — `summary&.update(status: :failed)` — **`.update`**

### Bang enum methods on the four records
NONE. The only `status_xxx!`/`textract_job_status_xxx!` bang write in the codebase is `app/controllers/api/v1/invites_controller.rb:105` on the out-of-scope `Invite` model.

## Disputes / omissions vs candidate map

- **OMISSION (census enumeration):** Part 10 line 766 (AiJobApplicationSummary census) omits `submit_resume_to_textract.rb:26` `update_columns(textract_result_id:)`. The write is documented narratively (lines 63, 138, 152, 236-237, 254) but is absent from the X0 census enumeration line that the slice asks to be authoritative. Under the slice's "every status/key column" mandate, `textract_result_id` is a key column and the census line should include it.

All other census claims verified AGREE.
