# X0 Adversarial Review — Pass 7 (Writer Census)

**Slice:** X0 — Writer census (authoritative coverage baseline)
**Method:** Re-read all code from scratch. Grepped entire `app/` + `lib/` for every write to the four records' status/key columns, then OPENED and READ each file to confirm. Compared against candidate map Part 10 (lines 818-836) and Part 9.

## Independent census (confirmed by reading each file)

### TextractResult — textract_job_status / textract_job_result_text
- `app/services/submit_resume_to_textract.rb:22` `.build(textract_job_id:, textract_job_status: 'in_progress')` — build (textract_job_status)
- `app/services/submit_resume_to_textract.rb:33` `@textract_result&.update_columns(textract_job_status: 'failed')` — update_columns (rescue InvalidS3ObjectException)
- `app/services/submit_resume_to_textract.rb:39` `@textract_result&.update_columns(textract_job_status: 'failed')` — update_columns (rescue StandardError)
- `app/services/get_resume_text_from_textract.rb:31` `@textract_result.update(update_textract_params)` — **.update** (textract_job_status: 'succeeded' + textract_job_result_text + textract_job_result; SOLE callback-firing write, fires bridge via saved_change_to_textract_job_result_text?)
- `app/services/get_resume_text_from_textract.rb:40` `@textract_result.update_columns(textract_job_status: 'failed')` — update_columns
- `app/services/get_resume_text_from_textract.rb:47` `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` — update_columns (rescue InvalidJobIdException)

### AiJobApplicationSummary — status / stale / key columns
- `app/interactors/create_ai_summary_generation.rb:37` `update_columns(stale: true)` — stale
- `app/interactors/create_ai_summary_generation.rb:47-51` `.build(status: :textract_processing)` + `:53` `.save`
- `app/interactors/create_ai_summary_generation.rb:60-64` `.build(status: :pending)` + `:70` `.save`
- `app/interactors/create_bulk_ai_summary_generation.rb:41` `update_columns(stale: true)` — stale
- `app/interactors/create_bulk_ai_summary_generation.rb:50-54` `.build(status: :pending)` + `:57` `.save`
- `app/services/ai_job_application_action/summary/generate.rb:32` `existing_ai_summary.update(status: :extracting)`
- `generate.rb:35-39` `AiJobApplicationSummary.create(status: :extracting)`
- `generate.rb:64-68` `ai_summary.update(status: :summarizing, ...)` (status :65)
- `generate.rb:175` `update_columns(status: :retrying, ...)`
- `generate.rb:180` `update_columns(status: :failed, ...)`
- `generate.rb:184` `update_columns(status: :failed, ...)`
- `app/services/ai_job_application_action/orchestrate.rb:72` `@ai_job_application_summary.update(status: :awaiting_job_criteria)`
- `app/services/ai_job_application_action/scoring/score_job_application.rb:23` `update(status: :awaiting_job_criteria)`
- `score_job_application.rb:32` `update(status: :scoring)`
- `score_job_application.rb:45` `update(status: :awaiting_job_criteria)`
- `score_job_application.rb:119-124` `update(status: :integrating, ...)` (status :122)
- `score_job_application.rb:130` `update(status: :retrying, ...)`
- `score_job_application.rb:135` `update(status: :failed, ...)`
- `score_job_application.rb:139` `update(status: :failed, ...)`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb:49-53` `update(status: :succeeded, ...)` (status :51)
- `integrate_analysis.rb:59` `update(status: :retrying, ...)`
- `integrate_analysis.rb:64` `update(status: :failed, ...)`
- `integrate_analysis.rb:68` `update(status: :failed, ...)`
- `app/jobs/generate_ai_job_application_summary_job.rb:19` `update_columns(status: :failed, ...)` (exhaustion block)
- `generate_ai_job_application_summary_job.rb:44` `update_columns(status: :failed, ...)` (rescue)
- `app/services/submit_resume_to_textract.rb:19` `update_all(stale: true)` — stale
- `app/services/submit_resume_to_textract.rb:26` `waiting_summary&.update_columns(textract_result_id:)` — KEY column relink

### AiJobApplicationSummaryStatus — status + denormalized columns
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:15` `update_columns(status: 'regenerating')`
- `find_or_create_ai_job_application_summary_status.rb:25-37` `.build` + assign (current branch :28-32 writes status + denormalized cols; none branch :34) + `:37 .save`
- `app/models/textract_result.rb:104-107` `set_initial_summary_pending` `update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')`
- `app/models/ai_job_application_summary.rb:74-80` `update_summary_status_record` `.update(ai_job_application_summary_id:, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`

### AiJobCriteria — status
- `app/models/job.rb:696` `update_columns(status: :pending, error_message: nil)`
- `app/models/job.rb:699` `AiJobCriteria.new(job:, status: :pending)` + `:700 .save`
- `app/services/ai_job_application_action/scoring/score_job_application.rb:44` `ai_job_criteria.update_columns(status: :failed, ...)`
- `app/services/ai_job_application_action/scoring/extract_criteria.rb:28` `update_columns(status: :in_progress)`
- `extract_criteria.rb:32` `update_columns(status: :failed, ...)`
- `extract_criteria.rb:62` `update_columns(status: :failed, ...)`
- `extract_criteria.rb:122` `update_columns(status: :failed, ...)`
- `extract_criteria.rb:132-140` `.update(status: :succeeded, ...)` (status :133, update :140; SOLE .update — fires resume_waiting_summaries callback)
- `extract_criteria.rb:146` `update_columns(status: :retrying)`
- `extract_criteria.rb:151` `update_columns(status: :failed, ...)`
- `extract_criteria.rb:155` `update_columns(status: :failed, ...)`
- `app/jobs/extract_job_criteria_job.rb:9` `update_columns(status: :failed, ...)` (exhaustion)
- `extract_job_criteria_job.rb:28` `update_columns(status: :failed, ...)` (rescue)

### Out-of-(four-record)-scope but in map (cross-references) — confirmed
- BulkAiSummaryJobApplication: `queue_bulk_ai_summary_jobs.rb:65-69` create(:processing); `bulk_generate_ai_summaries_job.rb:54` (:done), `:66` (:deferred), `:86` (:done), `:178-180` update_all(:failed). FIFTH record, not one of the four in scope; map handles as cross-ref.
- Rake: `lib/tasks/ai_bulk_extract.rake:34-38` create(status: :in_progress — INVALID enum), `:59-62` update(status: :extracted — INVALID enum), `:89` update(status: :failed). Confirmed both stale enum values.
- Bang enum writes: only `app/controllers/api/v1/invites_controller.rb:105` (Invite, out of scope). No bang writes to the four records. Confirmed.
- Housekeeping rake `:409`/`:445`: `SubmitResumeToTextractJob.perform_later` enqueues, NOT direct writes. Confirmed.

## Verdict
Every X0 write-site claim in the candidate map (Part 10 lines 818-836, Part 9 transition table) is CONFIRMED against literal code. No write site is missing from the census. No claimed site is wrong. clean = true for X0.
