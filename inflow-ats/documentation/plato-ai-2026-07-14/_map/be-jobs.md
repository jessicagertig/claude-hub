# Slice map: Sidekiq jobs (generate / bulk-generate summaries, retry/exhaustion, textract, AI-credit billing jobs)

Files: `app/jobs/{bulk_generate_ai_summaries_job,extract_job_criteria_job,generate_ai_job_application_summary_job,get_resume_text_from_textract_job,docx_to_pdf_job,stripe_webhook_handler_job,sync_ai_credit_purchases_with_stripe_job,notification/paid_ai_credit_pack_purchased_job}.rb` (+ their specs).

## generate_ai_job_application_summary_job.rb (NEW)
Thin dispatch. `perform(textract_result_id:, requesting_organization_user_id: nil)` → `TextractResult#generate_ai_summary_with_credit_flow` (all orchestration lives there).
- `retry_on CustomErrorAiSummary, wait: 2.min, attempts: 3`. On exhaustion: latest summary → `status: :failed` + error_message, then broadcasts completion.
- USER-VISIBLE: when `requesting_organization_user_id` present (MANUAL generate button), on finish broadcasts `AI_SUMMARY_COMPLETE` on user's GlobalChannel with `{status: 'succeeded'|'failed', candidateFullName, jobApplicationLink, errorMessage?}` → completion toast. When nil (AUTO-generation on new applicant) NO toast fires.
- Gate: broadcast only fires when summary status is succeeded OR failed. `candidateFullName` fallback `'Candidate'` (pre-existing style, name absent).
- Non-retryable StandardError: marks summary failed + broadcasts failure (only if requesting user present).

## bulk_generate_ai_summaries_job.rb (NEW — JobIteration::Iteration)
Iterates `payload['job_application_ids']`; per-applicant status rows in `BulkAiSummaryJobApplication` (bulk_job_id + job_application_id) with states processing/done/deferred/failed.
- Per iteration: skips if no JobApplication / no status row. Idempotency guard: if a non-(pending/failed) summary already exists created after the status row → sets row `:deferred`, returns (prevents double credit-charge on job-iteration cursor retry).
- `ValidateAiSummaryGeneration.call`; if not success returns (row stays processing). If `result.textract_pending` → row `:deferred`, no summary, no credit.
- Otherwise `CreateBulkAiSummaryGeneration.call` (creates the `AiJobApplicationSummary` row the pipeline needs — bulk analog of single-send `CreateAiSummaryGeneration`), then `result.textract_result.generate_ai_summary_with_credit_flow`, then row `:done`.
- `discard_on StandardError` and `retry_on CustomErrorAiSummary (2.min, 3)`: both set remaining `:processing` rows → `:failed` and call `notify_failure`.
- `on_complete`: counts done/deferred/failed. If succeeded==0 && failed>0 → `AI_SUMMARY_BULK_FAILED` broadcast + `*ResultMailer.failed`. Else → `AI_SUMMARY_BULK_COMPLETE` broadcast `{succeededCount, failedCount, skippedCount, hiringStageLink}` + `*ResultMailer.complete`. `skippedCount = payload skipped_count + deferred`.
- `kind` `all_stages` vs `single_hiring_stage` selects mailer (`BulkAllStagesAiSummaryResultMailer` vs `BulkJobApplicationAiSummaryResultMailer`) and link (`/jobs/:id/stages` vs `/jobs/:id/stages/:hs/applicants`). Mailers chained `.deliver_later` (correct).
- USER-VISIBLE: bulk "Generate Plato reviews" on a stage or all-stages → aggregate completion/failed toast + result email. Failed message: "We couldn't complete your Plato reviews for {jobTitle}".
- NOTE: file has heavy `ap` debug logging left in; `update_columns` used for status rows (skips callbacks) — intentional per comments. Missing trailing newline.

## extract_job_criteria_job.rb (NEW)
`perform(ai_job_criteria_id)` → `AiJobApplicationAction::Scoring::ExtractCriteria.new(...).extract`. `retry_on CustomErrorAiSummary (2.min, 3)`; on exhaustion or non-retryable StandardError sets `AiJobCriteria` → `status: :failed, error_message`. This is the job-criteria extraction pipeline entry (scoring). USER-VISIBLE: job's AI criteria extraction status shown failed if it exhausts.

## get_resume_text_from_textract_job.rb (MODIFIED)
Added exhaustion block to existing `retry_on CustomErrorTextract (5.min, 3)`: `cleanup_orphaned_summary(job_application_id)` — finds the JobApplication's summary in `status: :textract_processing, stale: false`, marks it `:failed` with "Resume processing failed after multiple attempts.", then calls `textract_result.send(:broadcast_ai_summary_failed, requesting_org_user, msg)` (private) to push the failure toast. USER-VISIBLE: when Textract permanently fails, a stuck "processing" summary now resolves to failed + toast instead of hanging.

## docx_to_pdf_job.rb (MODIFIED)
After `handle_possible_docx_resume`, if `resume_is_docx` AND `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, org)` → enqueue `SubmitResumeToTextractJob.perform_later(job_application.id)`. SHARED/non-AI surface: this job runs on the general resume-upload path for DOCX resumes; the new branch is Flipper-gated per org, so non-AI orgs (flag off) see no change. Regression risk if flag semantics change.

## sync_ai_credit_purchases_with_stripe_job.rb (NEW)
`perform(organization_id)` → `organization.sync_ai_credits_with_stripe`, then broadcasts `AI_CREDIT_PURCHASE_COMPLETE` to `organization.owner` GlobalChannel `{organizationId}`. USER-VISIBLE: billing page refreshes credit state after a purchase completes.

## notification/paid_ai_credit_pack_purchased_job.rb (NEW)
Slack ping to `SLACK_3RD_PARTY_PURCHASES_WEBHOOK` on paid AI credit pack purchase (org name/id, pack lookup key, credits granted). Internal-only; guarded rescues.

## stripe_webhook_handler_job.rb (MODIFIED — SHARED, HIGH REGRESSION SURFACE)
This is the main Stripe webhook handler shared with non-AI billing (main plan, WWR/WhatJobs listings). AI credit-pack branches were interleaved into existing event handlers:
- **checkout.session.completed**: new early branch when `metadata['ai_credit_pack_subscription']=='true'` → set `OrganizationAiCreditPurchase.stripe_subscription_id` via `update_columns`, then `return` (skips normal session handling). Non-AI sessions unaffected (falls through).
- **customer.subscription.updated**: now branches on `ai_credit_subscription_plan_lookup_key?`. AI credit-pack → update local purchase row (price key, credits/period, status, period start/end, cancel_at_period_end) + `sync_ai_credits_with_stripe`, does NOT touch org main-plan fields. Main-plan branch now gated on `object.id == organization.stripe_subscription_id`. REGRESSION RISK: main-plan subscription updates now only apply when the event's subscription id matches the org's — verify legit main-plan updates still process (org must have stripe_subscription_id set).
- **customer.subscription.deleted**: AI credit-pack lookup key → reconcile purchase row to `:canceled` + `sync_ai_credits_with_stripe`, and SKIPS `Notification::PaidSubscriptionDeletedJob` + `EngagementReport::GeneratorJob` + main sync. Main-plan deletion path otherwise unchanged. REGRESSION RISK: routing depends on `plan_lookup_key` from the deleted subscription's items.
- **invoice.paid**: restructured. Removed the upfront `raise CustomStripeSubscriptionMissingError` guard from top; now each listing branch `return`s early. New AI branches: `metadata['organization_ai_credit_purchase_id']` → one-off top-up `finalize_stripe_payment` + `grant_credits(invoice:)`; else retrieves subscription, and if AI credit subscription lookup key → `handle_subscription_credit_pack_invoice_paid` (updates amount/currency/invoice_item, then `subscription_update` billing_reason → `ApplyAiCreditUpgrade`, else `ApplyAiCreditSubscription`). Main-plan else-branch now also calls `organization.organization_ai_credit_balance&.reset_ai_credits`. New granular rescues (Stripe::StripeError, RecordInvalid/NotFound, StandardError). REGRESSION RISK: main-plan invoice.paid moved the missing-subscription guard into the else; WWR/WhatJobs listing invoice handling refactored to early `return`s — verify listing publish still fires.
- **charge.refunded**: NEW event handler. Resolves purchase via payment_intent → invoice(subscription, kind:subscription) or checkout session (kind:one_off) → `ApplyAiCreditRefund.call`. Only touches AI credit purchases (returns unless purchase found).

### Cross-file notes for scoring manifest
- Summary generation pipeline entry: `TextractResult#generate_ai_summary_with_credit_flow` (both single & bulk). Job criteria extraction entry: `AiJobApplicationAction::Scoring::ExtractCriteria#extract`. Actual model/prompt-role/call-order details live in the pipeline/action files, not these job wrappers.
- Retry config across AI jobs: summary jobs `CustomErrorAiSummary` 2.min ×3; textract `CustomErrorTextract` 5.min ×3. All have exhaustion blocks marking the relevant record failed + broadcasting.
