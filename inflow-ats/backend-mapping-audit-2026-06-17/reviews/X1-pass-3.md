# X1 — AiJobApplicationSummaryStatus — Adversarial Review Pass 3

Re-verified the candidate map `backend-flow-map-2026-06-17.md` against current code from scratch.
Files traced:
- `app/models/ai_job_application_summary_status.rb`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/textract_result.rb:61-108`
- `app/models/ai_job_application_summary.rb:8,29-31,57-98`
- `app/models/job_application.rb:29-32,45,106-113,160-171`
- `app/interactors/queue_bulk_ai_summary_jobs.rb:32-40`
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb:23-24`
- `app/serializers/api/v1/job_application_serializer.rb:40-41`
- `app/controllers/api/v1/job_applications_controller.rb:27,38,56`
- `db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb`
- `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb`
- `db/schema.rb:168-178,1302-1303`
- FE: `JobApplicationNavItem.tsx:26-29`, `JobApplicationListContainer.tsx:235-236`, `PlatoTab.tsx:46,127,129`, `JobApplicationActivity.tsx:79-94`, `bulkAiSummaryCount.ts:37-41`, `jobApplication.ts:1-9`, `WebsocketJobChannelHandler.tsx:73-81`, `WebsocketGlobalChannelHandler.tsx:227,241,253,281`

## Verdicts

Nearly all map claims AGREE. ONE substantive DISPUTE: the migration filename for the `jobs.ai_job_application_summaries_count` column.

### DISPUTE — migration filename (appears 4x: lines 131, 608, 639, 656)
Map states the column is added by `db/migrate/20260622182504_add_ai_job_application_summaries_count_to_jobs.rb:5`.
Actual file: `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb`. Same timestamp prefix (`20260622182504`), so the provenance argument (column NOT in committed schema `2026_06_11_120001`, added by a later un-dumped migration) HOLDS. But the cited filename does not exist. The real migration `AddAiSummaryAndCriteriaColumnsToJobs` adds THREE columns: `ai_job_application_summaries_count` (`:5`), `ai_job_criteria_generations_count` (`:6`), `internal_job_criteria` (`:7`) — not a single-purpose count migration. Correction: cite `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb:5`.

### AGREE (verified)
- Enum `{none:0, initial_summary_pending:1, current:2, regenerating:3}` _prefix:true — `ai_job_application_summary_status.rb:9-14`. NO `regenerating` boolean column.
- Columns / unique index / FK indexes — migration `:5-16`, schema `:168-178`, `idx_ai_summary_statuses_on_job_application_id` unique, `idx_ai_summary_statuses_on_summary_id`.
- `validates :job_application_id, uniqueness: true` — `:16`.
- `counter_culture [:job_application, :job]` proc + `column_names status IN (2,3)` — `:7`.
- Band scopes poor/weak/mixed/good/excellent — `:20-24`.
- `JobApplication has_one :ai_job_application_summary_status` no `dependent:` — `:32`; wrapper `:160-162`; `enqueue_new_job_application :170`; `fit_bands :106-109`; `unscored :110-113`.
- `create_status_record` callback REMOVED — absent from `ai_job_application_summary.rb`; callbacks are `:29-31`.
- Writer `regenerating` — `find_or_create_…:14-15` `update_columns(status: 'regenerating')` guarded on `@status_record.ai_job_application_summary&.status_succeeded?` (pointer at `:12`); broadcasts `ai_summary_status_change` `:16-20`.
- Writer create-path `none` `:34,37`; `current` (stale-guarded `!stale?` `:27`) `:28-32,37`; save/fail `:37-38`; RecordNotUnique rescue `:43-44`.
- Writer `initial_summary_pending` — `textract_result.rb:104-107` `update_columns`, guard `:102` (only from none/initial_summary_pending), called `:70-72`.
- Writer success-path `current` — `ai_job_application_summary.rb:74-80` `.update(...)`, guard `:69` (`saved_change_to_status? && status_succeeded?`), early return no-row `:72`, `ai_summary_succeeded` broadcast `:93-97`. No stale guard (desync #7 correct).
- No-op pass-through when row exists but summary not succeeded — `:14` false → only `:42` assignment.
- Reader QueueBulkAiSummaryJobs `status: :current` `:36-40`.
- Serializer attributes (id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp) — `:4-6`; `published_at_timestamp = updated_at.to_i` `:8-10`.
- Embeds `shallow_job_application_serializer.rb:23-24`, `job_application_serializer.rb:40-41`; controller preloads `:27,38,56`.
- FE: NavItem Harvey-ball current/regenerating + scorePercentage!=null `:26-29`; Container passes props `:235-236`; PlatoTab fetch-key `:46` (no fallback), `:127` `|| ""`, `:129` `|| 0`; Activity `:79-94`/`publishedAtTimestamp :87`; bulkAiSummaryCount `:37-41`; TS interface 4-value union, no `publishedAtTimestamp` declared `:1-9`.
- WS JobChannel `ai_summary_status_change` invalidates summary+jobApplication (not list) `:73-76`; `ai_summary_succeeded` invalidates list `:77-81`. GlobalChannel completion/terminal events invalidate `jobApplicationsForStage` `:227,241,253,281`.
- No optimistic-UI desync: no queryHook writes the status via setQueryData/onMutate (verified absence).
- Complete writer census (whole app/lib): exactly 3 writer sites — `find_or_create_…:15` + `:25-37`, `textract_result.rb:104-107`, `ai_job_application_summary.rb:74-80`. No others. Map Part 10 census matches.

### Desync windows (5.3 + Part 9) — all AGREE
1 in-flight initial_summary_pending vs live summary; 2 failed/retrying leaves row stuck (no failed enum value); 3 regeneration keeps OLD denormalized data; 4 D auto-regen stuck regenerating, NO credit charged; 5 list ignores ai_summary_status_change but refreshed by terminal events; 6 no-row-at-all; 7 current pointing at stale summary (no stale guard on success-path); 8 counter_culture column provenance.

## Omissions
None material. The map's coverage of readers, writers, transitions, and desync windows for X1 is complete.

clean = false (one DISPUTE on the migration filename).
