# Review Angles — Email Subjects Phase 1

Generated from: SPEC.md
Date: 2026-06-03

## Subsystems touched

**Backend — Models:**
- `app/models/channel_message.rb` — add subject validation, no `html_safe_subject`
- `app/models/channel_message_template.rb` — add subject column usage
- `app/models/channel.rb` — `send_message_to_company` (line 32), `send_message_to_candidate` (line 16) — capture `email.subject`
- `app/models/job.rb` — `add_default_apply_response_template` (line 346) — add `apply_response_template_subject` default
- `app/models/job_application.rb` — `send_candidate_confirmation_email` (line 521), `html_safe_apply_email` (line 537), `render_template_message` (line 758) — extend for subject
- `app/models/organization.rb` — `self.default_channel_message_templates` (line 364) — add subject to seed data

**Backend — Validators:**
- `app/validators/custom_channel_message_body_validator.rb` — rename to `custom_channel_message_validator.rb`, apply to both body and subject

**Backend — Controllers:**
- `app/controllers/api/v1/channel_messages_controller.rb` — permit `:subject`, sanitize subject
- `app/controllers/api/v1/bulk_channel_messages_controller.rb` — permit `:subject`, sanitize, add `subject:` to literal hash (lines 19-24)
- `app/controllers/api/v1/channel_message_templates_controller.rb` — permit `:subject`
- `app/controllers/api/v1/jobs_controller.rb` — permit `:apply_response_template_subject`, sanitize
- `app/controllers/api/v1/channel_message_templates_mail_merge_controller.rb` — extend response to include rendered subject
- `app/controllers/api/v1/candidates_controller.rb` — anonymization (lines 135-146) — add `text_replacer` for subject

**Backend — Interactors:**
- `app/interactors/channel_messages/create_stage_automation_message.rb` — rename `parse_body` → `parse_text` (line 30), use for both body and subject
- `app/interactors/customer_api/complete_job_application.rb` — `send_confirmation_email` (line 44) — add `subject:` to params hash

**Backend — Jobs:**
- `app/jobs/channel_messages/bulk_channel_message_send_job.rb` — rename `parse_body` → `parse_text` (line 48), use for both body and subject
- `app/jobs/hiring_stage_message_automation_job.rb` — add `subject:` to `message_params` (lines 16-20)

**Backend — Mailers:**
- `app/mailers/channel_message_mailer.rb` — `notify_candidate` (line 94): read `channel_message.subject`, fall back to hardcoded `"#{@job.title} at #{@organization.name}"` (line 116)

**Backend — Serializers:**
- `app/serializers/api/v1/channel_message_serializer.rb` — expose `:subject`
- `app/serializers/api/v1/channel_message_template_serializer.rb` — expose `:subject`
- `app/serializers/api_public/v1/hire/channel_message_serializer.rb` — expose `:subject`
- `app/serializers/api/v1/job_serializer.rb` — expose `:apply_response_template_subject`

**Backend — Migration:**
- Add `subject` (nullable string) to `channel_messages`
- Add `subject` (nullable string) to `channel_message_templates`
- Add `apply_response_template_subject` (nullable string) to `jobs`
- Add `mailgun_message_id` (nullable string) to `channel_messages`

**Frontend — Components:**
- `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageNew.tsx` — add subject input
- `app/javascript/ats/src/components/modals/BulkMessageModal.tsx` — add subject input
- `app/javascript/ats/src/components/modals/ChannelMessageTemplateModal.tsx` — add subject input
- `app/javascript/ats/src/components/modals/HiringStageAutomationModal.tsx` — add subject input in inline-create-template flow
- `app/javascript/ats/src/components/modals/ChannelMessageTemplateSelectionModal.tsx` — display rendered subject in preview

**Frontend — Hooks/Queries:**
- `app/javascript/shared/queryHooks/useChannelMessageTemplate.ts` — `useCreateChannelMessageTemplate`, `useUpdateChannelMessageTemplate` pass `subject`; `useMailMerge` consumes rendered subject
- `app/javascript/shared/queryHooks/useChannelMessage.ts` — `useCreateChannelMessage` passes `subject`

**Frontend — Validation:**
- `app/javascript/shared/lib/validateWithYup.ts` — add `subject` to `channelMessageTemplateSchema` (line 45), `bulkMessageSchema` (line 50), and single-send validation

## Full-stack analog

The closest full-stack analog is the **existing single-send channel message flow** — user composes a message body, it saves and delivers via email.

**Single-send pipeline (body-only today):**
- Frontend: `ChannelMessageNew.tsx` → `useCreateChannelMessage` (`app/javascript/shared/queryHooks/useChannelMessage.ts`)
- API: `POST /channels/:channel_id/channel_messages` → `Api::V1::ChannelMessagesController#create`
- Controller: permits `:body`, sanitizes via `Sanitizer#sanitize` (`app/utils/sanitizer.rb`), merges org-user metadata
- Interactor: `CreateChannelMessage` (`app/interactors/create_channel_message.rb`) → builds `channel_messages` on channel, saves
- Model: `ChannelMessage` → `before_create :clean_incoming_message` (line 20), `validates :body, custom_channel_message_body: true` (line 24), `after_commit :handle_after_commit_create` (line 22)
- Mailer trigger: `handle_after_commit_create` (line 67) → `sent_by_user?` branch (line 79) → `ChannelMessageMailer.notify_candidate(id).deliver_later`
- Mailer: `notify_candidate` (line 94) reads `@channel_message.html_safe_body`, uses hardcoded subject `"#{@job.title} at #{@organization.name}"` (line 116)
- Serializer: `Api::V1::ChannelMessageSerializer` returns response
- Auth: `JobApplicationPolicy#send_channel_message?` (called at controller line 12)
- Tests: `cypress/e2e/candidates/messages.cy.js`

**Secondary analog — bulk send:**
- Frontend: `BulkMessageModal.tsx` → API
- Controller: `BulkChannelMessagesController#create` — hand-builds literal hash (lines 19-24), calls `SendBulkMessageToCandidates`
- Interactor: `SendBulkMessageToCandidates` → enqueues `BulkChannelMessageSendJob`
- Job: `BulkChannelMessageSendJob#perform` → `parse_body` substitutes per candidate → `channel.channel_messages.create!`
- Model: same `after_commit` → `notify_candidate`

**Tertiary analog — automation:**
- Job: `HiringStageMessageAutomationJob#perform` (line 6) → builds `message_params` from template body only (lines 16-20) → `CreateStageAutomationMessage`
- Interactor: `CreateStageAutomationMessage#call` → `parse_body` substitutes → builds channel_message, saves
- Model: same `after_commit` → `notify_candidate`
- Tests: `cypress/e2e/job-setup/hiring-stage-automations.cy.js`

**Apply-response-template analog:**
- Model: `JobApplication#send_candidate_confirmation_email` (line 521) / `CustomerApi::CompleteJobApplication#send_confirmation_email` (line 44)
- Both call `CreateOrganizationChannelMessage` with `{ body: html_safe_apply_email, sent_by:, source: }`
- Model: same `after_commit` → `sent_by_organization?` branch (line 93) → `notify_candidate`

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Note the deviation so the reviewer doesn't flag it.

## Angles

### pipeline-parity
**What this covers:** Subject must flow through every path that body flows through — if any path handles body but silently drops subject, the mailer fallback fires and the user's custom subject is lost.
**Files across all layers:**
- `app/controllers/api/v1/channel_messages_controller.rb` — permit + sanitize subject alongside body
- `app/controllers/api/v1/bulk_channel_messages_controller.rb` — permit + sanitize + add `subject:` to the hand-built literal hash (lines 19-24) that gets passed to the bulk job
- `app/controllers/api/v1/channel_message_templates_controller.rb` — permit subject
- `app/controllers/api/v1/jobs_controller.rb` — permit + sanitize `apply_response_template_subject`
- `app/interactors/channel_messages/create_stage_automation_message.rb` — subject must be substituted alongside body in renamed `parse_text`
- `app/interactors/customer_api/complete_job_application.rb` — `send_confirmation_email` must include `subject:` in params
- `app/jobs/channel_messages/bulk_channel_message_send_job.rb` — subject must be substituted alongside body in renamed `parse_text`
- `app/jobs/hiring_stage_message_automation_job.rb` — `message_params` must include `subject:` from template
- `app/models/job_application.rb` — `send_candidate_confirmation_email` must include `subject:` in params
- `app/models/channel.rb` — both `send_message_to_company` and `send_message_to_candidate` must capture `email.subject`
- `app/mailers/channel_message_mailer.rb` — `notify_candidate` must read `channel_message.subject` with fallback
- `app/serializers/api/v1/channel_message_serializer.rb` — expose `:subject`
- `app/serializers/api/v1/channel_message_template_serializer.rb` — expose `:subject`
- `app/serializers/api_public/v1/hire/channel_message_serializer.rb` — expose `:subject`
- `app/serializers/api/v1/job_serializer.rb` — expose `:apply_response_template_subject`
**Analog files for comparison:** The body path through each of the four analog pipelines (single-send, bulk, automation, apply-response) — every point where body is read, passed, transformed, or stored.
**Convention context:** `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `cursor_rules/backend/interactors/`, `cursor_rules/backend/background_jobs.md`, `cursor_rules/backend/serializers.md`

### template-rendering
**What this covers:** Subject must go through the same mail-merge variable substitution as body, but must NOT go through the Redcarpet Markdown pipeline — getting this boundary wrong either breaks subjects with markup or strips variables.
**Files across all layers:**
- `app/models/job_application.rb` — `render_template_message` (line 758): subject must get both Mustache passes (plain + spanified) but skip the Redcarpet step at lines 773-775; `invalid_tags` check (lines 787-792) must also inspect subject; `html_safe_apply_email` (line 537) gsub chain must apply to subject with the same variables
- `app/interactors/channel_messages/create_stage_automation_message.rb` — `parse_text` must apply the same 7-variable gsub chain to subject
- `app/jobs/channel_messages/bulk_channel_message_send_job.rb` — `parse_text` must apply the same 7-variable gsub chain to subject
- `app/models/channel_message.rb` — `clean_incoming_message` (line 56) must NOT process subject through `remove_bad_line_breaks`; `cleaned_body` (line 174) must NOT have a `cleaned_subject` equivalent; `html_safe_body` (line 182) must NOT have an `html_safe_subject` equivalent
- `app/controllers/api/v1/channel_message_templates_mail_merge_controller.rb` — response must include rendered subject and spanified subject, without Markdown
**Analog files for comparison:** The body rendering pipeline in `render_template_message` (lines 762-794) — Redcarpet → Mustache → Mustache. Subject's pipeline is Mustache → Mustache only.
**Convention context:** `cursor_rules/backend/architecture.md`

### frontend-contract
**What this covers:** The frontend form inputs, validation schemas, mutation payloads, and API response consumption must all agree on the shape of subject — a mismatch means subject is collected but not sent, or sent but not displayed.
**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageNew.tsx` — subject input, pre-populated with rendered default (candidate context known)
- `app/javascript/ats/src/components/modals/BulkMessageModal.tsx` — subject input, pre-populated with literal tokens (no candidate context)
- `app/javascript/ats/src/components/modals/ChannelMessageTemplateModal.tsx` — subject input, pre-populated with literal tokens or saved value on edit
- `app/javascript/ats/src/components/modals/HiringStageAutomationModal.tsx` — subject input in inline-create-template flow
- `app/javascript/ats/src/components/modals/ChannelMessageTemplateSelectionModal.tsx` — display rendered subject from mail-merge response
- `app/javascript/shared/lib/validateWithYup.ts` — `subject: string().required()` in `channelMessageTemplateSchema` (line 45), `bulkMessageSchema` (line 50), and single-send
- `app/javascript/shared/queryHooks/useChannelMessage.ts` — `useCreateChannelMessage` must include subject in mutation payload
- `app/javascript/shared/queryHooks/useChannelMessageTemplate.ts` — create/update hooks must include subject; `useMailMerge` must consume rendered subject from response
- `app/serializers/api/v1/channel_message_serializer.rb` — response shape the frontend reads
- `app/serializers/api/v1/channel_message_template_serializer.rb` — response shape the frontend reads
- `app/controllers/api/v1/channel_message_templates_mail_merge_controller.rb` — response shape `useMailMerge` consumes
**Analog files for comparison:** How body currently flows through `ChannelMessageNew.tsx` → `useCreateChannelMessage` → controller → serializer response. Same shape for templates via `ChannelMessageTemplateModal.tsx` → `useCreateChannelMessageTemplate`.
**Convention context:** `cursor_rules/frontend/forms/`, `cursor_rules/frontend/modals/`, `cursor_rules/frontend/react_query/`, `cursor_rules/frontend/components/`, `cursor_rules/frontend/ui_styling.md`

### schema-and-migration
**What this covers:** Column additions, validator rename, and backward compatibility with existing data — nullable columns on three tables, a validator class rename with a single call site, and no backfill.
**Files across all layers:**
- The new migration file (not yet created)
- `app/models/channel_message.rb` — `validates :body, custom_channel_message_body: true` (line 24) must change to new validator key; add `validates :subject, custom_channel_message: true`
- `app/validators/custom_channel_message_body_validator.rb` — rename file and class to `CustomChannelMessageValidator`
- `app/models/channel_message_template.rb` — subject column usage
- `app/models/job.rb` — `apply_response_template_subject` column usage
**Analog files for comparison:** Existing column definitions on `channel_messages` (body, body_legacy_markdown, body_raw_html, body_plain_text, body_sanitized_html) — subject is intentionally simpler (single column, no companion columns).
**Convention context:** `cursor_rules/backend/migrations.md`, `cursor_rules/backend/architecture.md`

### security-and-privacy
**What this covers:** Subject must be sanitized in every controller that sanitizes body (XSS via the spanified preview's `dangerouslySetInnerHTML`), and must be included in the anonymization endpoint so candidate names don't persist in stored subjects.
**Files across all layers:**
- `app/controllers/api/v1/channel_messages_controller.rb` — sanitize subject (line 36 pattern)
- `app/controllers/api/v1/bulk_channel_messages_controller.rb` — sanitize subject (line 81 pattern)
- `app/controllers/api/v1/jobs_controller.rb` — sanitize `apply_response_template_subject` (lines 266-270 pattern)
- `app/utils/sanitizer.rb` — the `sanitize` method both controllers use
- `app/controllers/api/v1/candidates_controller.rb` — anonymization (lines 135-146): add `text_replacer` calls on `channel_message.subject` for both `real_first_name` and `real_last_name`; `text_replacer` must handle nil (historical messages have no subject)
**Analog files for comparison:** How body is sanitized in each controller; how body columns are anonymized in the candidates controller (lines 136-145).
**Convention context:** `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `cursor_rules/core_critical_rules.md`

### seeding-and-defaults
**What this covers:** Default templates and default apply-response subjects must be set so new organizations and new jobs don't start with null subjects that trigger the mailer fallback on every send. The mailer fallback string and the default template token string must produce the same result after substitution.
**Files across all layers:**
- `app/models/organization.rb` — `self.default_channel_message_templates` (line 364): add `subject: "{{JobTitle}} at {{OrganizationName}}"` to each template hash
- `app/models/job.rb` — `add_default_apply_response_template` (line 346): add `apply_response_template_subject: "{{JobTitle}} at {{OrganizationName}}"` to `update_columns`
- `app/mailers/channel_message_mailer.rb` — `notify_candidate` fallback (line 116): `"#{@job.title} at #{@organization.name}"` — must match what the token default produces after substitution
- Frontend default pre-population — each surface's default string must match the backend default
**Analog files for comparison:** How `add_default_apply_response_template` currently sets the body default (line 346); how `default_channel_message_templates` currently defines body-only templates (lines 364-382).
**Convention context:** `cursor_rules/backend/architecture.md`

## Always-on checks

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source.

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require. Known existing test files:
- `cypress/e2e/candidates/messages.cy.js`
- `cypress/e2e/job-setup/hiring-stage-automations.cy.js`
- `spec/support/api_factories.rb` (factory definitions reference ChannelMessage/ChannelMessageTemplate)
- No dedicated RSpec controller/interactor/mailer specs found for the affected code

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed. Key consumers to check:
- `CustomChannelMessageBodyValidator` rename — only call site is `channel_message.rb:24`
- `parse_body` rename — private methods, called only within their own class (`CreateStageAutomationMessage:16`, `BulkChannelMessageSendJob:12`)
- Serializer additions (`:subject`) — additive, no breaking change
- `render_template_message` response shape — additive keys, consumer is `useMailMerge`
- Migration — nullable columns, no backfill, no risk to existing rows

### Full-stack analog completeness
The review agent verifies the new feature has a corresponding piece for every layer of the single-send analog pipeline:
- Controller: permit + sanitize subject (same shape as body)
- Interactor: passes params through (no subject-specific change needed in `CreateChannelMessage`)
- Model: validates subject (same validator as body)
- Mailer: reads subject from record with fallback
- Serializer: exposes subject
- Auth: no change needed (policy gates the action, not individual fields)

A missing layer is a BLOCKER.
