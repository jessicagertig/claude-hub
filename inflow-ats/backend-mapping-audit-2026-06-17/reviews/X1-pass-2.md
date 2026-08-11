# Slice X1 — AiJobApplicationSummaryStatus — Adversarial Pass 2

Re-traced from scratch against current code. Candidate map: `backend-flow-map-2026-06-17.md`.

## Files opened and traced
- `app/models/ai_job_application_summary_status.rb` (model, enum, counter_culture, scopes)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (create/regenerating writer)
- `app/models/textract_result.rb:61-108` (`generate_ai_summary_with_credit_flow`, `set_initial_summary_pending`)
- `app/models/ai_job_application_summary.rb` (update_summary_status_record, callbacks)
- `app/models/job_application.rb:31-32,45,100-115,160-171` (associations, scopes, wrapper, callback)
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb:22-24`
- `app/serializers/api/v1/job_application_serializer.rb:38-41`
- `app/interactors/queue_bulk_ai_summary_jobs.rb:30-54`
- `app/controllers/api/v1/job_applications_controller.rb:27,38,56` (includes preload)
- `db/schema.rb` (status table + jobs table), `db/migrate/20260611120001_...`, `db/migrate/20260622182504_add_ai_job_application_summaries_count_to_jobs.rb`
- FE: `JobApplicationNavItem.tsx:26-29`, `JobApplicationListContainer.tsx:235-236`, `WebsocketJobChannelHandler.tsx:73-80`, `bulkAiSummaryCount.ts:40`, `JobApplicationActivity.tsx:79-103`, `PlatoTab.tsx:41-46`, `shared/types/jobApplication.ts:1-22`

## Verdict summary
The map is accurate on nearly every X1 claim. One material issue: the counter_culture rollup column `jobs.ai_job_application_summaries_count` is NOT in the committed `db/schema.rb` (schema version 2026_06_11_120001); it is added only by a later migration `20260622182504` that has not been dumped into schema. The map presents the rollup as working fact (Part 9 data model + desync window #8) without flagging this.

## DISPUTE / omission detail

### counter_culture column provenance
- Map (Part 9:542, 5.3 commentary, desync #8:581): `counter_culture [:job_application, :job] → jobs.ai_job_application_summaries_count, counted only when status IN (2,3)`.
- Code: `ai_job_application_summary_status.rb:7` declares the counter against `ai_job_application_summaries_count`. BUT `db/schema.rb` (version 2026_06_11_120001) jobs table has NO such column. The column is added by `db/migrate/20260622182504_add_ai_job_application_summaries_count_to_jobs.rb:5` — a migration dated AFTER the schema dump and not reflected in schema.rb.
- Correction: the counter_culture target column is supplied by an un-dumped (post-schema) migration. Until that migration is applied AND schema re-dumped, any status write moving a row into/out of current/regenerating would raise (unknown column) in an env at the committed schema version. The map should note the column's provenance and that schema.rb does not yet contain it.

All other X1 claims AGREE (see verdicts list).
