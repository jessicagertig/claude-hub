# Source Accuracy — Round 1

## Findings

Verified every file path, identifier, and claim:

| Claim | Verified |
|---|---|
| `config/routes.rb:199` — `resources :bulk_ai_job_application_summaries, only: [:create]` | ✅ exact match |
| `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` — `create` action lines 6-28 | ✅ lines match |
| `bulk_ai_job_application_summary_params` lines 48-55 | ✅ exact |
| `app/interactors/queue_bulk_ai_summary_jobs.rb` — `:current` filter lines 36-40 | ✅ exact |
| `:processing` filter lines 43-45 | ✅ exact |
| `perform_later` payload lines 82-89 | ✅ exact |
| `app/jobs/bulk_generate_ai_summaries_job.rb` — `notify_complete` lines 123-145 | ✅ exact |
| `notify_failure` lines 148-172 | ✅ exact (spec says 158-171, actual starts at 148, private method at 173) |
| `hiringStageLink` construction at line 133 | ✅ exact |
| Mailer call at lines 137-144 | ✅ exact |
| `.deliver_later` at lines 144, 171 | ✅ exact |
| `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` — `complete` with 6 params | ✅ exact (line 4) |
| `Emails::SendTemplateEmail.new(message_params).send` | ✅ exact (line 28) |
| `app/serializers/api/v1/job_serializer.rb` — no `ai_job_application_summaries_count` | ✅ confirmed absent |
| `app/serializers/api/v1/job_serializer.rb` — no `should_auto_generate_ai_summaries` | ✅ confirmed absent |
| `Job#should_auto_generate_ai_summaries?` at line 948 | ✅ exact |
| `ai_job_application_summaries_count` column in `db/schema.rb:907` | ✅ exact |
| `AiJobApplicationSummaryPolicy#bulk_create?` at lines 12-14 | ✅ exact (line 12-13) |
| `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` — 37 lines | ✅ exact |
| `BulkGenerateAiSummariesConfirmModal.tsx` — `dismissModalWithAnimation` at line 53 | ✅ exact |
| `useOrganizationAiCreditBalance` at line 47 | ✅ exact |
| `validateBulkGenerateAiSummaries` at `validateWithYup.ts:548` | ✅ exact |
| `JobStagesContainer.tsx` — `Styled.Sidebar` at lines 121-140, 204-219 | ✅ exact |
| `/jobs/:id/setup/description` route | ✅ verified via `JobSetupContainer.tsx:443` |
| `/hire/settings/plato-ai` route | ✅ verified via `AccountContainer.tsx:75` |
| `/jobs/:id/setup/ai` route | ✅ verified via `JobSetupContainer.tsx:485` |

- F1 [LOW] Spec says `notify_failure` at "lines 158-171". The actual `notify_failure` method starts at line 148. Lines 158-165 are the broadcast inside `notify_failure`, and lines 167-171 are the mailer call. The spec's line range is slightly misleading but the intent is correct and the method name is accurate.

## Amendments Applied

- Spec "Job dispatch branching" section: changed "lines 158-171" to "lines 148-172" for `notify_failure`
