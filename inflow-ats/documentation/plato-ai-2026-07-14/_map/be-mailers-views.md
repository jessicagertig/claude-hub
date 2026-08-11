# Slice: BE mailers + views — low/zero-credit + bulk-AI-summary result notifications

Scope: `app/mailers/ai_credit_notification_mailer.rb`, `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb`, `app/mailers/bulk_job_application_ai_summary_result_mailer.rb`, `app/views/layouts/{account_application,application}.html.erb`, plus their specs. All three mailers are NEW.

Trace: mailer callers → `app/interactors/notify_low_ai_credits.rb`, `app/interactors/notify_zero_ai_credits.rb`, `app/jobs/bulk_generate_ai_summaries_job.rb`.

## What changed

### AiCreditNotificationMailer (NEW) — billing/credit balance notifications
Two methods, each delivered via `.deliver_later` from its interactor. Each iterates `admin_recipients(organization)` and sends a per-recipient templated email through `Emails::SendTemplateEmail.new(message_params).send` (Postmark-style template send, NOT ERB mail).

- `low_credits(organization)` — subject **"Your Plato AI credits are running low"**, template `user-ai-credit-balance-low`. Variables: `user_first_name`, `organization_name`, `credits_remaining` (`balance&.total_credits_remaining.to_i`), `billing_url` → `{AtsRootUrl}/hire/settings/plato-ai/billing`. From `DEFAULT_EMAIL_FROM_ADDRESS`.
- `zero_credits(organization)` — subject **"Your Plato AI credits have run out"**, template `user-ai-credit-balance-zero`. Same variables minus `credits_remaining`. From `DEFAULT_EMAIL_FROM_ADDRESS`.
- `admin_recipients` = `organization.organization_users.select(&:is_admin).map(&:user).uniq`. Per spec: includes org_owner, org_admin, god_admin; EXCLUDES org_user (member) and org_interviewer. Comment rationale: only admins/owner can purchase credits.

### BulkAllStagesAiSummaryResultMailer + BulkJobApplicationAiSummaryResultMailer (NEW) — bulk AI review results
Delivered via `.deliver_later` from `BulkGenerateAiSummariesJob` (`notify_complete` / `notify_failure`). Sent to the SINGLE acting user (`@user`), not admins. From `EMAIL_NOTIFICATIONS_ADDRESS`.

- `complete(...)` — subject **"Your Plato reviews for {job.title} are ready"**. Templates `user-bulk-all-stages-ai-summary-complete` / `user-bulk-ai-summary-complete`. Variables include `total_count` (= succeeded+failed+skipped), `succeeded_count`, `failed_count`, `skipped_count`, and a link. All-stages link → `/jobs/{id}/stages`; single-stage link → `/jobs/{id}/stages/{hiring_stage_id}/applicants` plus `hiring_stage_name` (`hiring_stage&.name || ''`).
- `failed(...)` — subject **"We couldn't complete your Plato reviews for {job.title}"**. Templates `...-failed`. Variables include `total_queued_count` and same link. Single-stage variant also carries `hiring_stage_name`.
- Bulk job `kind` payload selects all-stages vs single-hiring-stage mailer. Job also fires a `GlobalChannel.broadcast_to` websocket action (`AI_SUMMARY_BULK_COMPLETE` / `AI_SUMMARY_BULK_FAILED`) alongside the email.

### Layout views (SHARED, non-AI surface)
Both `account_application.html.erb` and `application.html.erb` add one line to the inline `<script>` window-globals block:
`window.AI_CREDIT_ALLOCATIONS = '<%= ENV["AI_CREDIT_ALLOCATIONS"]&.html_safe %>';`
Exposes the raw `AI_CREDIT_ALLOCATIONS` env value (a JSON/pricing config string) to frontend JS for credit-pack pricing display.

## User-visible behavior / actions enabled
- Org admins/owner receive a "credits running low" email (with remaining count + billing link) and a separate "credits have run out" email; each links to the Plato AI billing settings page to buy more. Members/interviewers never get these.
- The user who triggers a bulk AI review (all-stages or a single hiring stage) gets a completion email with succeeded/failed/skipped counts, or a failure email, plus a live toast via websocket.

## Conditions / states gating the emails
- **low_credits fires only when:** balance present; `settings['low_ai_credit_notifications_enabled']` true; `settings['low_ai_credit_notification_threshold']` positive; NOT already sent since last increase (`sent_low_notification_since_increase?`); remaining > 0 AND remaining ≤ threshold. Mutually exclusive with zero via the `remaining.zero?` guard.
- **zero_credits fires only when:** balance present; `settings['zero_ai_credit_notifications_enabled']` true; NOT already sent since last increase (`sent_zero_notification_since_increase?`); `total_credits_remaining` not positive. Runs BEFORE low so zero takes precedence.
- Dedup: each interactor sets `*_notification_sent_at` + `sent_*_notification_since_increase` via `update_columns`; re-notification only after a balance increase resets the flag. QA: verify a second consumption below threshold does NOT re-email until credits are topped up.
- Bulk mailers: `notify_complete`/`notify_failure` return early unless payload + user resolvable; `hiring_stage` uses `find_by` so a deleted stage yields `hiring_stage_name = ''` and a link to a possibly-missing stage id.

## SHARED / regression-risk surfaces
- **`layouts/account_application.html.erb` and `layouts/application.html.erb`** — global layouts rendered on EVERY page (account app + main hire app). New `window.AI_CREDIT_ALLOCATIONS` line. If `ENV["AI_CREDIT_ALLOCATIONS"]` contains an unescaped single quote it would break the inline `'...'` JS string and could break the whole globals script block on every page. QA: load any page in both apps, confirm no JS console error and other window globals (Sentry DSN, recaptcha, job-board embed URL) still populate.
- **`BulkGenerateAiSummariesJob` + `GlobalChannel` websocket broadcast** — shared job/websocket path; emails are additive to existing broadcast behavior.

## Notes for reviewers
- Specs exist (`ai_credit_notification_mailer_spec.rb`, `bulk_all_stages_ai_summary_result_mailer_spec.rb`); they stub `Emails::SendTemplateEmail` and assert recipient selection + variables. No spec for `bulk_job_application_ai_summary_result_mailer.rb` in this slice's file list.
- These mailers do NOT build ActionMailer mail bodies; delivery happens inside the method body via `SendTemplateEmail`, wrapped by `.deliver_later` at the callsite (so the actual send runs in the ActiveJob worker).
- No prompt/model/provider content in this slice (mailers/views only) — nothing for the scoring manifest.
