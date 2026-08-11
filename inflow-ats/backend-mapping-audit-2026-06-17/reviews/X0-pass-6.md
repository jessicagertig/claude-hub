# X0 — Writer Census Adversarial Review (pass 6)

**Slice:** X0 — authoritative write-site census for the four records' status/key columns.
**Method:** Re-ran the full grep from scratch over `app/` and `lib/`, OPENED and READ every hit, confirmed column + write-form (`.update` vs `update_columns` vs `update_all` vs `.create`/`.build`+`.save`). Compared each confirmed site against map Part 10 (lines 793-809).

**Verdict:** The map's Part 10 census is ACCURATE at every cited site. Every site it lists exists in current code with the column and write-form it claims; my independent census surfaced no production site it missed. All disputes below are minor scope/labeling notes, not factual contradictions.

---

## Confirmed write-site census (independent)

### TextractResult — `textract_job_status` / `textract_job_result_text`
- `app/services/submit_resume_to_textract.rb:22` — `@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')` (`:24` `.save`) → `textract_job_status` (build+save)
- `submit_resume_to_textract.rb:33` — `@textract_result&.update_columns(textract_job_status: 'failed')` (InvalidS3Object rescue) → update_columns
- `submit_resume_to_textract.rb:39` — `@textract_result&.update_columns(textract_job_status: 'failed')` (StandardError rescue) → update_columns
- `app/services/get_resume_text_from_textract.rb:31` — `@textract_result.update(update_textract_params)` with params `:25-29` (`textract_job_status`, `textract_job_result`, `textract_job_result_text`) → `.update` (SOLE callback-firing write; writes both status + text; fires the bridge via `saved_change_to_textract_job_result_text?`)
- `get_resume_text_from_textract.rb:40` — `@textract_result.update_columns(textract_job_status: 'failed')` (job_status failed) → update_columns
- `get_resume_text_from_textract.rb:47` — `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` (InvalidJobIdException rescue) → update_columns

Map Part 10 line 793 lists exactly `submit:22/33/39`, `get:31/40/47`. AGREE.

### AiJobApplicationSummary — `status` / `stale` / key columns
- `create_ai_summary_generation.rb:37` `update_columns(stale: true)`; `:47-53` build `status: :textract_processing` + save; `:60-70` build `status: :pending` + save
- `create_bulk_ai_summary_generation.rb:41` `update_columns(stale: true)`; `:50-57` build `status: :pending` + save
- `summary/generate.rb:32` `.update(status: :extracting)`; `:35-39` `.create(status: :extracting)`; `:64-68` `.update(status: :summarizing)` (`:65`); `:175` `update_columns(status: :retrying)`; `:180` `update_columns(status: :failed)`; `:184` `update_columns(status: :failed)`
- `orchestrate.rb:72` `.update(status: :awaiting_job_criteria)`
- `score_job_application.rb:23/32/45` `.update(status: :awaiting_job_criteria/:scoring/:awaiting_job_criteria)`; `:119-124` `.update(status: :integrating)` (`:122`); `:130` `.update(status: :retrying)`; `:135/:139` `.update(status: :failed)`
- `integrate_analysis.rb:49-53` `.update(status: :succeeded)` (`:51`, SOLE `:succeeded` writer); `:59` `.update(status: :retrying)`; `:64/:68` `.update(status: :failed)`
- `generate_ai_job_application_summary_job.rb:19` `update_columns(status: :failed)` (retry-exhausted block); `:44` `update_columns(status: :failed)` (StandardError rescue) — both `:failed`, never `:retrying`
- `submit_resume_to_textract.rb:19` `ai_job_application_summaries.update_all(stale: true)` (stale)
- `submit_resume_to_textract.rb:26` `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` (KEY-column relink)

Map Part 10 line 794 lists every one of these at the exact lines. AGREE.

### AiJobApplicationSummaryStatus — `status` + denormalized columns
- `find_or_create_ai_job_application_summary_status.rb:15` `update_columns(status: 'regenerating')`; `:25` `build_ai_job_application_summary_status` + `:28-32` assign (`ai_job_application_summary`, `status='current'`, `score_percentage`, `headline`, `integrated_role_analysis`) OR `:34` `status='none'`, then `:37` `.save`
- `textract_result.rb:104-107` `update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` (set_initial_summary_pending)
- `ai_job_application_summary.rb:74-80` `.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` (update_summary_status_record; guarded `:69` `saved_change_to_status? && status_succeeded?`)

Map Part 10 line 795 lists `find_or_create:15/25-37`, `textract_result.rb:104-107`, `ai_job_application_summary.rb:74-80`. AGREE.

### AiJobCriteria — `status`
- `job.rb:696` `update_columns(status: :pending, error_message: nil)`; `:699-700` `.new(status: :pending)` + save
- `extract_criteria.rb:28` (`:in_progress`), `:32/:62/:122` (`:failed`), `:132-140` (`.update status: :succeeded` at `:133`, SOLE callback-firing), `:146` (`:retrying`), `:151/:155` (`:failed`)
- `score_job_application.rb:44` `update_columns(status: :failed, ...)`
- `extract_job_criteria_job.rb:9/28` `update_columns(status: :failed, ...)`

Map Part 10 line 796 lists exactly these. AGREE.

### BulkAiSummaryJobApplication (extra — not one of the four prompt records)
- `queue_bulk_ai_summary_jobs.rb:65-68` `.create(status: :processing)`
- `bulk_generate_ai_summaries_job.rb:54` `update_columns(status: :done)`; `:66` `update_columns(status: :deferred)`; `:86` `update_columns(status: :done)`; `:178-180` `update_all(status: 'failed')`

Map Part 10 line 797 lists `queue:65-69`, `bulk:54/66/86/178-180`. AGREE.

### Rake-layer (AiJobApplicationSummary.status, outside trigger coverage)
- `lib/tasks/ai_bulk_extract.rake:34-37` `AiJobApplicationSummary.create(status: :in_progress)` — `:in_progress` NOT a valid enum value (enum is pending…failed at `ai_job_application_summary.rb:10-21`); would raise `ArgumentError`
- `:59-62` `summary.update(status: :extracted)` — `:extracted` NOT a valid enum value
- `:89` `summary&.update(status: :failed)` — valid

Map Part 10 line 803 documents all three plus the STALE-enum note. AGREE.

### Enqueue-only / read-only confirmations
- `housekeeping_tasks.rake:409/445` enqueue `SubmitResumeToTextractJob` (not record writes). Lines 484-500 are read-only `.where(...).count` diagnostics — NOT writes. AGREE with map line 804.
- Only enum bang-setter on any status column anywhere: `invites_controller.rb:105` (out-of-scope Invite). No bang setter writes any of the four records. AGREE with map line 800.

---

## Disputes / notes

**No factual disputes.** Minor scope notes:

1. **Record DESTROY sites not in the column-write census (scope note, not a defect).** Two sites change record state by destruction but write no status/key column, so they are correctly excluded from a "column-write" census:
   - `textract_result.rb:134` `ai_summary_waiting_on_textract.destroy` (destroys an AiJobApplicationSummary on the bridge validation-fail branch).
   - `ai_job_application_summary.rb:47-54` `destroy_previous_textract_results` (`destroy_all` of prior non-succeeded TextractResults on succeed).
   These are owned by S-E / X3 elsewhere in the map; flagging only that the X0 census header ("WRITES any status/key column") does not, by its own definition, capture destroys. Not an error.

2. **`generate.rb:102/:129/:169` `.update(...)` are non-status writes** (`structured_data`, and `:169` headline/summary_text/structured_data) — correctly excluded from the status/key-column census. Confirmed they write no status/stale/denormalized-status column.

---

## Omissions

None within the census's stated scope. The two destroy sites in note 1 are the only record-state-change sites adjacent to the four records not enumerated in Part 10, and they fall outside "column write."

**clean = false** solely because the destroy-site scope note (note 1) is an item the census does not surface; every actual column-write verdict is AGREE.
