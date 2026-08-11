# X0 — Writer Census — Adversarial Review Pass 3

**Slice:** X0 (authoritative write-site census for the four records' status/key columns)
**Method:** Re-audited from scratch. Grepped entire codebase (app/, lib/, jobs, services, interactors, models, controllers, channels, rake tasks). Opened and READ every hit. Compared against the candidate map's X0 census (Part 10, lines 660-677) and the DIVERGENCE CHANGELOG write-related claims.

## Files traced
- app/services/submit_resume_to_textract.rb
- app/services/get_resume_text_from_textract.rb
- app/interactors/create_ai_summary_generation.rb
- app/interactors/create_bulk_ai_summary_generation.rb
- app/services/ai_job_application_action/summary/generate.rb
- app/services/ai_job_application_action/orchestrate.rb
- app/services/ai_job_application_action/scoring/score_job_application.rb
- app/services/ai_job_application_action/scoring/integrate_analysis.rb
- app/services/ai_job_application_action/scoring/extract_criteria.rb
- app/jobs/generate_ai_job_application_summary_job.rb
- app/jobs/extract_job_criteria_job.rb
- app/jobs/bulk_generate_ai_summaries_job.rb (BulkAiSummaryJobApplication — 5th record, out of my 4-record scope)
- app/interactors/queue_bulk_ai_summary_jobs.rb (same)
- app/models/job.rb (extract_job_criteria)
- app/models/ai_job_application_summary.rb (update_summary_status_record, callbacks, enum, BROADCAST_STATUSES)
- app/models/ai_job_application_summary_status.rb (enum, counter_culture, no write callbacks)
- app/models/textract_result.rb (set_initial_summary_pending)
- app/interactors/find_or_create_ai_job_application_summary_status.rb
- lib/tasks/ai_bulk_extract.rake  ← **NOT in the map's census**
- lib/tasks/housekeeping_tasks.rake (reads only)
- lib/tasks/recurring_tasks.rake (routes through already-censused services)
- lib/tasks/ai_relevance_benchmark.rake, ai_comparison_benchmark.rake (reads only)
- db/schema.rb, db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb

## AGREE — map census claims verified against literal code

### TextractResult (Part 10: `submit_resume_to_textract.rb:22/33/39`, `get_resume_text_from_textract.rb:31/40/47`)
- submit_resume_to_textract.rb:22 — `.build(... textract_job_status: 'in_progress')` ✓
- submit_resume_to_textract.rb:33 — `@textract_result&.update_columns(textract_job_status: 'failed')` ✓
- submit_resume_to_textract.rb:39 — `@textract_result&.update_columns(textract_job_status: 'failed')` ✓
- get_resume_text_from_textract.rb:31 — `@textract_result.update(update_textract_params)` (status: succeeded + textract_job_result + textract_job_result_text) ✓ `.update`
- get_resume_text_from_textract.rb:40 — `update_columns(textract_job_status: 'failed')` ✓
- get_resume_text_from_textract.rb:47 — `update_columns(textract_job_status: 'failed', textract_job_id: nil)` ✓

### AiJobApplicationSummary (status + stale)
- create_ai_summary_generation.rb:37 `update_columns(stale: true)`; :47-53 build `:textract_processing`+save(:53); :60-70 build `:pending`+save(:70) ✓
- create_bulk_ai_summary_generation.rb:41 `update_columns(stale: true)`; :50-57 build `:pending`+save(:57) ✓
- summary/generate.rb:32 `.update(status: :extracting)`; :35-39 `.create(status: :extracting)`; :64-68 `.update(status: :summarizing)` (write :68); :175 `update_columns(status: :retrying)`; :180 `update_columns(status: :failed)`; :184 `update_columns(status: :failed)` ✓ (generate.rb:102/129/169 write only structured_data/headline/summary_text — correctly excluded)
- orchestrate.rb:72 `.update(status: :awaiting_job_criteria)` ✓
- score_job_application.rb:23 `.update(status: :awaiting_job_criteria)`; :32 `.update(status: :scoring)`; :45 `.update(status: :awaiting_job_criteria)`; :119-124 `.update(status: :integrating)` (write :124); :130 `.update(status: :retrying)`; :135 `.update(status: :failed)`; :139 `.update(status: :failed)` ✓
- integrate_analysis.rb:49-53 `.update(status: :succeeded)` (write :53); :59 `.update(status: :retrying)`; :64 `.update(status: :failed)`; :68 `.update(status: :failed)` ✓
- generate_ai_job_application_summary_job.rb:19 `update_columns(status: :failed)`; :44 `update_columns(status: :failed)` — both `:failed`, never `:retrying` ✓
- submit_resume_to_textract.rb:19 `update_all(stale: true)` ✓

### AiJobApplicationSummaryStatus
- find_or_create_ai_job_application_summary_status.rb:15 `update_columns(status: 'regenerating')`; :25-37 build + assign status `'current'`(:29) or `'none'`(:34) + denormalized cols(:30-32) + save(:37) ✓
- textract_result.rb:104-107 `update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` ✓
- ai_job_application_summary.rb:74-80 `.update(status: 'current', ai_job_application_summary_id:, score_percentage:, headline:, integrated_role_analysis:)` ✓
- No write callbacks on the status model; only 3 writers exist. ✓

### AiJobCriteria (status)
- job.rb:696 `update_columns(status: :pending)`; :699 `AiJobCriteria.new(status: :pending)`+save(:700) ✓
- extract_criteria.rb:28 `update_columns(status: :in_progress)`; :32/:62/:122 `update_columns(status: :failed)`; :132-140 `.update(status: :succeeded)` (write :140, the only callback-firing AiJobCriteria write — fires resume_waiting_summaries); :146 `update_columns(status: :retrying)`; :151/:155 `update_columns(status: :failed)` ✓
- score_job_application.rb:44 `update_columns(status: :failed)` ✓
- extract_job_criteria_job.rb:9 `update_columns(status: :failed)`; :28 `update_columns(status: :failed)` ✓

### Bang-enum-method claim (Part 10 ORPHANS note)
- Verified: the ONLY prefixed-bang status write anywhere is `invites_controller.rb:105` (`@invite.status_pending!`) on the out-of-scope `Invite` model. No `status_xxx!` / `textract_job_status_xxx!` write touches any of the 4 records. ✓

### BulkAiSummaryJobApplication (5th record; out of my 4-record scope but listed in census)
- queue_bulk_ai_summary_jobs.rb:65-69 `BulkAiSummaryJobApplication.create(status: :processing)`; bulk_generate_ai_summaries_job.rb:54/66/86/178-180 — these write BulkAiSummaryJobApplication, none of my 4 records. No contamination. ✓

## DISPUTE — map claim contradicted by code

### D1 — counter_culture migration FILENAME is wrong (map lines 131, 608)
Map states the column is added by `db/migrate/20260622182504_add_ai_job_application_summaries_count_to_jobs.rb:5`.
Actual file: `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` (class `AddAiSummaryAndCriteriaColumnsToJobs`). No file named `add_ai_job_application_summaries_count_to_jobs.rb` exists.
- The SUBSTANTIVE claim is CORRECT: `:5` `add_column :jobs, :ai_job_application_summaries_count, :integer, default: 0, null: false`; the column is NOT in db/schema.rb (version 2026_06_11_120001 — verified `grep` returns nothing). The same migration also adds `ai_job_criteria_generations_count` (:6) and `internal_job_criteria` (:7).
- But the cited filename is fabricated/stale. A reader following the map's path would not find the file. **DISPUTE on the file citation.**

## OMISSIONS — write sites the map's X0 census misses

### O1 — `lib/tasks/ai_bulk_extract.rake` AiJobApplicationSummary.status writes (3 sites)
The X0 census Part 10 and the DIVERGENCE CHANGELOG do not mention this rake task at all. It contains direct AiJobApplicationSummary.status writes:
- `lib/tasks/ai_bulk_extract.rake:34-38` — `AiJobApplicationSummary.create(job_application:, textract_result:, status: :in_progress)`. `:in_progress` is NOT a valid value of the AiJobApplicationSummary enum (`pending/textract_processing/extracting/summarizing/awaiting_job_criteria/scoring/integrating/succeeded/retrying/failed`, ai_job_application_summary.rb:10-21) — stale enum reference that would raise `ArgumentError` at runtime, but it is a syntactic write site.
- `lib/tasks/ai_bulk_extract.rake:59-62` — `summary.update(status: :extracted, ...)`. `:extracted` is also NOT a valid enum value (stale).
- `lib/tasks/ai_bulk_extract.rake:89` — `summary&.update(status: :failed, error_message: e.message)`. Valid value.

The task brief explicitly requires grepping rake tasks for status writes. These three are confirmed write sites to AiJobApplicationSummary.status and are absent from the census. They appear to be dead/stale (the enum values `in_progress`/`extracted` no longer exist), but the census claims completeness and these are real write-site hits. The map's "ORPHANS: NONE" coverage assertion is therefore incomplete for the rake layer.

## Verdict
clean = false (1 DISPUTE on migration filename; 1 OMISSION cluster of 3 rake-task write sites).

All other census line citations for the four in-scope records (TextractResult, AiJobApplicationSummary, AiJobApplicationSummaryStatus, AiJobCriteria) are confirmed accurate against literal code.
