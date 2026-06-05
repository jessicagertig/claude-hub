# Email Subjects Phase 1a -- Implementation Plan

## 1. Summary

This feature adds a custom subject line to outbound emails from Inflow ATS to job candidates. Today every outbound email uses a hardcoded subject (`"#{job.title} at #{organization.name}"`). After this change, users can write custom subjects for single-send messages, bulk messages, automated stage messages, and apply-response confirmation emails. Inbound emails (candidate replies via Postmark webhook) will also have their subject captured and stored. The feature adds nullable `subject` columns to `channel_messages` and `channel_message_templates`, a nullable `apply_response_template_subject` column to `jobs`, and a groundwork-only `mailgun_message_id` column to `channel_messages`. The frontend adds a plain-text subject input to five surfaces (single-send composer, bulk message modal, template create/edit modal, automation modal's inline-create-template flow, and template selection modal preview), with yup validation requiring non-empty subjects. The mailer falls back to the existing hardcoded subject when the stored subject is blank (for legacy rows), but in practice the frontend always supplies a subject.

**Phase 1b (NOT in this plan):** `notify_team` subject treatment, and candidate messages-tab transcript subject display.

---

## 2. Pattern Precedents

### 2a. Single-send channel message pipeline (body-only today) -- PRIMARY ANALOG

The full-stack path for how `body` flows through single-send today. Subject will follow the same path at every layer.

- **Frontend:** `ChannelMessageNew.tsx` (line 81) passes `{ channelId, body }` to `useCreateChannelMessage` in `app/javascript/shared/queryHooks/useChannelMessage.ts` (line 5)
- **API:** `POST /channels/:channel_id/channel_messages` handled by `Api::V1::ChannelMessagesController#create` (line 8). Controller permits `:body` (line 31), sanitizes it (line 36), merges org-user metadata (line 10)
- **Interactor:** `CreateChannelMessage` (line 19) builds `channel_messages` on channel with params, saves
- **Model:** `ChannelMessage` validates `:body` with `custom_channel_message_body: true` (line 24), runs `before_create :clean_incoming_message` (line 20), runs `after_commit :handle_after_commit_create` (line 22)
- **Mailer:** `handle_after_commit_create` (line 79) calls `ChannelMessageMailer.notify_candidate(id).deliver_later`. `notify_candidate` (line 116) uses hardcoded `"#{@job.title} at #{@organization.name}"` as subject
- **Serializer:** `Api::V1::ChannelMessageSerializer` (line 7) exposes `:body`
- **Cypress:** `cypress/e2e/candidates/messages.cy.js`

### 2b. Bulk send pipeline

- **Frontend:** `BulkMessageModal.tsx` (line 102) passes `body` to `useCreateBulkMessage` in `useBulkMessage.ts` (line 25)
- **Controller:** `BulkChannelMessagesController#create` (lines 19-24) hand-builds a literal hash with `body: bulk_channel_message_params[:body]`. This is the critical drop point -- permitting `:subject` in `bulk_channel_message_params` is insufficient; `subject:` must also be added to this hand-built hash
- **Interactor:** `SendBulkMessageToCandidates` (line 18) passes params to `BulkChannelMessageSendJob.perform_later`
- **Job:** `BulkChannelMessageSendJob#perform` (line 12) calls `parse_body(user, job_application, params)` for mail-merge substitution, then `channel.channel_messages.create!`

### 2c. Automation pipeline

- **Job:** `HiringStageMessageAutomationJob#perform` (lines 16-20) builds `message_params` from `automation.channel_message_template.body` only -- subject must be added here
- **Interactor:** `CreateStageAutomationMessage#call` (line 16) merges params with `body: parse_body()` -- subject must also be substituted via renamed `parse_text`

### 2d. Apply-response template pipeline

- **Model:** `JobApplication#send_candidate_confirmation_email` (line 525) passes `{ body: html_safe_apply_email }` to `CreateOrganizationChannelMessage`
- **Interactor:** `CustomerApi::CompleteJobApplication#send_confirmation_email` (line 55) passes `{ body: job_application.html_safe_apply_email }` to `CreateOrganizationChannelMessage`
- **Both need** `subject:` added to params, with the same gsub chain applied to `job.apply_response_template_subject`

### 2e. Inbound message capture

- **Model:** `Channel#send_message_to_company` (line 32) and `send_message_to_candidate` (line 16) build channel_messages from `email.body`, `email.raw_html`, `email.body` (plain_text) -- subject must capture `email.subject`

### 2f. Template rendering / mail merge

- **Model:** `JobApplication#render_template_message` (lines 758-799) runs the body through Redcarpet (markdown->HTML) then two Mustache passes (plain substitution + spanified highlighting). Subject skips Redcarpet, gets both Mustache passes
- **Controller:** `ChannelMessageTemplatesMailMergeController#show` (line 10) calls `render_template_message` and returns its response. Frontend `useMailMerge` (line 70) consumes it

---

## 3. Files to Create or Modify

### New files
| File | Purpose |
|---|---|
| `db/migrate/YYYYMMDDHHMMSS_add_subject_and_mailgun_message_id_to_channel_messages.rb` | Migration adding 4 columns across 3 tables |
| `app/validators/custom_channel_message_validator.rb` | Renamed validator (was `custom_channel_message_body_validator.rb`) |

### Modified files -- Backend (18 files)
| File | Change |
|---|---|
| `app/validators/custom_channel_message_body_validator.rb` | DELETE (renamed to `custom_channel_message_validator.rb`) |
| `app/models/channel_message.rb` | Update validator key from `custom_channel_message_body` to `custom_channel_message`; add `validates :subject, custom_channel_message: true` |
| `app/models/channel_message_template.rb` | No code change needed (column just exists) |
| `app/models/channel.rb` | Add `subject: email.subject` to both `send_message_to_company` and `send_message_to_candidate` hash |
| `app/models/job.rb` | Add `apply_response_template_subject: "{{JobTitle}} at {{OrganizationName}}"` to `add_default_apply_response_template` |
| `app/models/job_application.rb` | Extend `render_template_message` for subject (both Mustache passes, no Redcarpet); extend `invalid_tags` to inspect subject; add `html_safe_apply_subject` method or inline gsub chain; add `subject:` to `send_candidate_confirmation_email` params |
| `app/models/organization.rb` | Add `subject: '{{JobTitle}} at {{OrganizationName}}'` to each hash in `self.default_channel_message_templates` |
| `app/controllers/api/v1/channel_messages_controller.rb` | Permit `:subject`; sanitize subject alongside body |
| `app/controllers/api/v1/bulk_channel_messages_controller.rb` | Permit `:subject`; sanitize subject; add `subject: bulk_channel_message_params[:subject]` to hand-built hash (line 19-24) |
| `app/controllers/api/v1/channel_message_templates_controller.rb` | Permit `:subject` alongside `:name`, `:body`, `:position` |
| `app/controllers/api/v1/jobs_controller.rb` | Permit `:apply_response_template_subject`; sanitize it alongside `apply_response_template` |
| `app/controllers/api/v1/channel_message_templates_mail_merge_controller.rb` | Response already returns whatever `render_template_message` returns -- the change is in `render_template_message` itself |
| `app/controllers/api/v1/candidates_controller.rb` | Add `text_replacer` calls on `channel_message.subject` for `real_first_name` and `real_last_name` in anonymization loop (lines 135-146) |
| `app/interactors/channel_messages/create_stage_automation_message.rb` | Rename `parse_body` to `parse_text`; use it for both body and subject |
| `app/interactors/customer_api/complete_job_application.rb` | Add `subject:` to params hash passed to `CreateOrganizationChannelMessage` |
| `app/jobs/channel_messages/bulk_channel_message_send_job.rb` | Rename `parse_body` to `parse_text`; use it for both body and subject |
| `app/jobs/hiring_stage_message_automation_job.rb` | Add `subject: automation.channel_message_template.subject` to `message_params` |
| `app/mailers/channel_message_mailer.rb` | In `notify_candidate`: read `@channel_message.subject` and fall back to `"#{@job.title} at #{@organization.name}"` when blank |
| `app/serializers/api/v1/channel_message_serializer.rb` | Add `:subject` to attributes |
| `app/serializers/api/v1/channel_message_template_serializer.rb` | Add `:subject` to attributes |
| `app/serializers/api_public/v1/hire/channel_message_serializer.rb` | Add `:subject` to attributes |
| `app/serializers/api/v1/job_serializer.rb` | Add `:apply_response_template_subject` to attributes |

### Modified files -- Frontend (7 files)
| File | Change |
|---|---|
| `app/javascript/shared/lib/validateWithYup.ts` | Add `subject: string().required()` to `channelMessageTemplateSchema` and `bulkMessageSchema`; add new `validateSingleMessage` function with subject required |
| `app/javascript/shared/queryHooks/useChannelMessage.ts` | Include `subject` in mutation payload passed by `createChannelMessage` |
| `app/javascript/shared/queryHooks/useChannelMessageTemplate.ts` | Include `subject` in `createChannelMessageTemplate` and `updateChannelMessageTemplate` payloads (already included via spread -- no change needed if the component passes it). No change needed in `useMailMerge` (it returns whatever the API returns) |
| `app/javascript/shared/queryHooks/useBulkMessage.ts` | Include `subject` in `createBulkMessage` payload and destructured args |
| `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageNew.tsx` | Add subject text input above body editor; pre-populate with rendered default (candidate context known: `"[job.title] at [organization.name]"`); include `subject` in `createChannelMessage` call; add yup validation |
| `app/javascript/ats/src/components/modals/BulkMessageModal.tsx` | Add subject text input above body editor; pre-populate with literal tokens `"{{JobTitle}} at {{OrganizationName}}"`; include `subject` in `createBulkMessage` call; add yup validation |
| `app/javascript/ats/src/components/modals/ChannelMessageTemplateModal.tsx` | Add subject text input between name and body editor; pre-populate with literal tokens on create, saved value on edit; include `subject` in create/update calls; add yup validation |
| `app/javascript/ats/src/components/modals/HiringStageAutomationModal.tsx` | In inline-create-template flow: add subject text input between template name and body editor; pre-populate with literal tokens; include `subject` in `createChannelMessageTemplate` call; add yup validation for inline template |
| `app/javascript/ats/src/components/modals/ChannelMessageTemplateSelectionModal.tsx` | Display rendered subject from `mailMerge` response above the body preview |
| `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAutomations.tsx` | Add subject text input for apply-response template alongside the body editor; include `applyResponseTemplateSubject` in `updateJob` call |

---

## 4. Backend Changes

### Step 1: Migration

**Read before working:** `cursor_rules/backend/migrations.md`

Create a single migration adding all four columns:

```
rails generate migration AddSubjectAndMailgunMessageIdToChannelMessages
```

Contents:
- `add_column :channel_messages, :subject, :string, null: true` -- nullable, no default
- `add_column :channel_messages, :mailgun_message_id, :string, null: true` -- groundwork for phase 2
- `add_column :channel_message_templates, :subject, :string, null: true`
- `add_column :jobs, :apply_response_template_subject, :string, null: true`

No indexes needed. No backfill. No data migration.

The `down` method should remove all four columns.

### Step 2: Rename validator

**Read before working:** `cursor_rules/backend/_base.md`, `cursor_rules/backend/architecture.md`

1. Rename file `app/validators/custom_channel_message_body_validator.rb` to `app/validators/custom_channel_message_validator.rb`
2. Rename class `CustomChannelMessageBodyValidator` to `CustomChannelMessageValidator`
3. The validator logic stays identical -- it checks for `{{...}}` patterns in the attribute value. It already works generically via `validate_each(record, attribute, value)` and applies to whatever attribute it's attached to

### Step 3: Update ChannelMessage model

**Read before working:** `cursor_rules/backend/_base.md`, `cursor_rules/backend/architecture.md`

1. Change line 24 from `validates :body, custom_channel_message_body: true` to `validates :body, custom_channel_message: true`
2. Add `validates :subject, custom_channel_message: true` on the next line
3. Do NOT add presence validation on subject -- it's intentionally nullable for legacy rows
4. Do NOT add `html_safe_subject` method
5. Do NOT add `cleaned_subject` method
6. Do NOT process subject through `clean_incoming_message` / `remove_bad_line_breaks` -- those are for inbound email body HTML cleanup. Subject is plain text

### Step 4: Update Channel model (inbound subject capture)

**Read before working:** `cursor_rules/backend/_base.md`

In `Channel#send_message_to_company` (line 32), add `subject: email.subject` to the hash passed to `channel_messages.build`.

In `Channel#send_message_to_candidate` (line 16), add `subject: email.subject` to the hash passed to `channel_messages.build`.

Pattern: identical to how `body: email.body` is already captured on lines 24 and 37.

### Step 5: Update mailer -- notify_candidate subject with fallback

**Read before working:** `cursor_rules/backend/_base.md`

In `ChannelMessageMailer#notify_candidate` (line 116), change the hardcoded subject:

```ruby
# Before:
subject: "#{@job.title} at #{@organization.name}",

# After:
subject: @channel_message.subject.presence || "#{@job.title} at #{@organization.name}",
```

`String#presence` returns nil for blank strings and nil values, triggering the fallback.

Do NOT change `notify_team` in this phase -- that is phase 1b.

### Step 6: Rename parse_body to parse_text in CreateStageAutomationMessage

**Read before working:** `cursor_rules/backend/interactors/interactor_patterns_and_structure.md`

In `app/interactors/channel_messages/create_stage_automation_message.rb`:

1. Rename method `parse_body` (line 30) to `parse_text`
2. Change its signature to accept a text argument: `def parse_text(text)` instead of reading from `@message_params[:body]`
3. Replace `body = @message_params[:body]` with `text.scrub...` using the passed argument
4. In `call` (line 16), use `parse_text` for both body and subject:
   ```ruby
   channel_message_params = @message_params.merge(
     body: parse_text(@message_params[:body]),
     subject: parse_text(@message_params[:subject])
   )
   ```

Note: `parse_text` applies `.html_safe` at the end. For subject this is harmless (subject goes into a Mailgun header, not an ERB template), but is worth noting for the implementer.

### Step 7: Rename parse_body to parse_text in BulkChannelMessageSendJob

**Read before working:** `cursor_rules/backend/background_jobs.md`

In `app/jobs/channel_messages/bulk_channel_message_send_job.rb`:

1. Rename method `parse_body` (line 48) to `parse_text`
2. Change signature to `def parse_text(user, job_application, text)` -- take the text to substitute as the third argument instead of reading `params[:body]`
3. Replace `params[:body]` inside the method with `text`
4. In `perform` (line 12), use it for both body and subject:
   ```ruby
   channel_message_params = params.merge(
     body: parse_text(user, job_application, params[:body]),
     subject: parse_text(user, job_application, params[:subject])
   )
   ```

Note: unlike `CreateStageAutomationMessage#parse_text`, this version does NOT call `.html_safe`. Keep that difference -- it reflects the existing difference between the two methods.

### Step 8: Update HiringStageMessageAutomationJob

**Read before working:** `cursor_rules/backend/background_jobs.md`

In `app/jobs/hiring_stage_message_automation_job.rb` (lines 16-20), add `subject:` to `message_params`:

```ruby
message_params = {
  body: automation.channel_message_template.body,
  subject: automation.channel_message_template.subject,
  sent_by: 'sent_by_organization',
  source: 'source_in_app'
}
```

Without this, the template's custom subject is silently dropped and the mailer fallback fires.

### Step 9: Update apply-response template pipeline

**Read before working:** `cursor_rules/backend/_base.md`, `cursor_rules/backend/architecture.md`

**9a. `Job#add_default_apply_response_template`** (line 346):

Add `apply_response_template_subject` to the `update_columns` call:

```ruby
def add_default_apply_response_template
  update_columns(
    apply_response_template: "<p>Hello {{CandidateFirstName}},</p>...",
    apply_response_template_subject: '{{JobTitle}} at {{OrganizationName}}'
  )
end
```

**9b. `JobApplication#send_candidate_confirmation_email`** (line 521):

Add `subject:` to the params hash. The subject value comes from `job.apply_response_template_subject`, run through the same gsub substitution chain as `html_safe_apply_email`. Either inline the gsub chain or extract a shared helper:

```ruby
def send_candidate_confirmation_email
  return unless id

  if job.use_apply_response_template
    ChannelMessages::CreateOrganizationChannelMessage.call(
      organization: job.organization,
      channel_id: channels.first.id,
      params: {
        body: html_safe_apply_email,
        subject: parse_apply_response_text(job.apply_response_template_subject),
        sent_by: 'sent_by_organization',
        source: 'source_in_app'
      }
    )
  else
    JobApplicationMailer.candidate_confirmation(id).deliver_later
  end
end
```

The `parse_apply_response_text` helper (or inline gsub chain) applies the same substitutions as `html_safe_apply_email` but without `.html_safe` at the end (subject doesn't need it):

```ruby
def parse_apply_response_text(text)
  return '' if text.blank?

  text.scrub
      .gsub('{{JobTitle}}', job.title)
      .gsub('{{CandidateFullName}}', candidate.full_name)
      .gsub('{{CandidateFirstName}}', candidate.first_name)
      .gsub('{{CandidateLastName}}', candidate.last_name)
      .gsub('{{OrganizationName}}', job.organization.name)
      .gsub(/ /, ' ')
end
```

Note: `html_safe_apply_email` can then be refactored to call `parse_apply_response_text(job.apply_response_template)&.html_safe` -- implementer's call on whether to do this inline refactor or keep them separate.

**9c. `CustomerApi::CompleteJobApplication#send_confirmation_email`** (line 55):

Same change -- add `subject:` to the params hash:

```ruby
params: {
  body: job_application.html_safe_apply_email,
  subject: job_application.parse_apply_response_text(job_application.job.apply_response_template_subject),
  sent_by: 'sent_by_organization',
  source: 'source_in_app'
}
```

Note: `parse_apply_response_text` must be a public method on `JobApplication` for this call to work, or the subject gsub can be done inline here.

### Step 10: Update Organization default templates

**Read before working:** `cursor_rules/backend/_base.md`

**Note:** `app/models/organization.rb` has a special rule: "Do not automate edits to `app/models/organization.rb`". The implementer should tell the user exactly what to add and let the user make the edit.

In `Organization.default_channel_message_templates` (line 364), add `subject: '{{JobTitle}} at {{OrganizationName}}'` to each of the three template hashes.

### Step 11: Permit and sanitize subject in controllers

**Read before working:** `cursor_rules/backend/controllers/controller_patterns_and_crud.md`

**11a. `Api::V1::ChannelMessagesController`:**
- In `channel_message_params` (line 31), change `.permit(:body)` to `.permit(:body, :subject)`
- Add sanitization for subject alongside body (line 36):
  ```ruby
  next_params[:subject] = sanitize(next_params[:subject]) if next_params.key?(:subject)
  ```

**11b. `Api::V1::BulkChannelMessagesController`:**
- In `bulk_channel_message_params` (line 80), add `:subject` to `.permit(...)`:
  ```ruby
  next_params = params.require(:bulk_channel_message).permit(:body, :subject, :hiring_stage_id, ...)
  ```
- Add sanitization (after line 81):
  ```ruby
  next_params[:subject] = sanitize(next_params[:subject]) if next_params.key?(:subject)
  ```
- **Critical:** In `create` (lines 19-24), add `subject:` to the hand-built hash:
  ```ruby
  channel_message_params = {
    body: bulk_channel_message_params[:body],
    subject: bulk_channel_message_params[:subject],
    created_by_organization_user_id: current_organization_user.id,
    sent_by: 'sent_by_user',
    source: 'source_in_app'
  }
  ```
  Without this, permitting `:subject` alone won't propagate it -- it silently drops.

**11c. `Api::V1::ChannelMessageTemplatesController`:**
- In `channel_message_template_params` (line 61), change `.permit(:name, :body, :position)` to `.permit(:name, :body, :subject, :position)`
- No sanitization needed here (templates are org-internal, not rendered through `dangerouslySetInnerHTML` in the same XSS-risk way -- they go through `render_template_message`'s Mustache passes which are already sanitized at the consumer level)

**11d. `Api::V1::JobsController`:**
- In `job_params` (lines 215-253), add `:apply_response_template_subject` to the `permitted_all` array, near `:apply_response_template` (line 235)
- Add sanitization (after line 267):
  ```ruby
  if sanitized_params.key?(:apply_response_template_subject)
    sanitized_params[:apply_response_template_subject] = sanitize(sanitized_params[:apply_response_template_subject])
  end
  ```

**11e. `Api::V1::HiringStageMessageAutomationsController`:**
- Do NOT permit `:subject` -- automations inherit subject from their template

### Step 12: Expose subject in serializers

**Read before working:** `cursor_rules/backend/serializers.md`

All four are simple attribute additions -- no method definition needed (subject is a database column).

**12a. `Api::V1::ChannelMessageSerializer`** (line 4): Add `:subject` to the attributes list.

**12b. `Api::V1::ChannelMessageTemplateSerializer`** (line 4): Add `:subject` to the attributes list.

**12c. `ApiPublic::V1::Hire::ChannelMessageSerializer`** (line 4): Add `:subject` to the attributes list.

**12d. `Api::V1::JobSerializer`** (line 4): Add `:apply_response_template_subject` to the attributes list, near `:apply_response_template` (line 52).

### Step 13: Extend render_template_message for subject

**Read before working:** `cursor_rules/backend/architecture.md`

In `JobApplication#render_template_message` (line 758):

1. After reading the template body (line 762), also read `subject = channel_message_template.subject || ''`
2. Apply the same `gsub('{{{', '{{').gsub('}}}', '}}')` + placeholder triple-brace wrapping to `subject` (the loop at lines 763-765)
3. Apply the same zero-width space and NBSP cleanup to subject (lines 767-768)
4. **Skip Redcarpet for subject** -- do NOT pass subject through the `markdown.render()` call at lines 773-775. This is the critical boundary.
5. Apply the two Mustache passes to subject:
   ```ruby
   subject_raw = Mustache.render(subject_prepared, placeholder_options(sender))
   subject_html = Mustache.render(subject_prepared, placeholder_options_with_spans(sender))
   template_subject_html = Mustache.render(subject_prepared, placeholder_options_with_spans_unfilled)
   ```
   Note: `subject_prepared` is the subject after placeholder wrapping and cleanup, NOT after Redcarpet.
6. Extend the `invalid_tags` check (lines 787-792) to also inspect subject:
   ```ruby
   subject_template = Mustache::Template.new(channel_message_template.subject || '')
   subject_used_tags = subject_template.tags
   subject_invalid_tags = subject_used_tags - known_tags
   all_invalid_tags = invalid_tags + subject_invalid_tags
   has_invalid_tags = !all_invalid_tags.empty?
   ```
7. Add subject fields to the response hash (line 794):
   ```ruby
   response = {
     message_raw: message_raw,
     message_html: message_html,
     template_html: template_html,
     subject_raw: subject_raw,
     subject_html: subject_html,
     template_subject_html: template_subject_html,
     has_invalid_tags: has_invalid_tags,
     invalid_tags: all_invalid_tags
   }
   ```

### Step 14: Anonymization endpoint -- add subject redaction

**Read before working:** `cursor_rules/backend/controllers/controller_patterns_and_crud.md`

In `Api::V1::CandidatesController` anonymization loop (lines 135-146), add two `text_replacer` calls for `channel_message.subject`:

```ruby
channel_message.subject = text_replacer(channel_message.subject, real_first_name, name_replacement)
channel_message.subject = text_replacer(channel_message.subject, real_last_name, name_replacement)
```

`text_replacer` already handles nil gracefully (returns text if `text.blank?`), so historical messages with NULL subject won't raise.

---

## 5. Frontend Changes

### Step F1: Update yup validation schemas

**Read before working:** `cursor_rules/frontend/forms/form_validation_and_errors.md`

In `app/javascript/shared/lib/validateWithYup.ts`:

1. Add `subject: string().required()` to `channelMessageTemplateSchema` (line 45):
   ```ts
   const channelMessageTemplateSchema = object({
     name: string().required(),
     subject: string().required(),
     body: string().required(),
   });
   ```

2. Add `subject: string().required()` to `bulkMessageSchema` (line 50):
   ```ts
   const bulkMessageSchema = object({
     subject: string().required(),
     body: string().required(),
     jobApplications: array().min(1),
   });
   ```

3. Add a new `validateSingleMessage` function for the single-send composer (MED finding FC-F1: no single-send yup schema exists today):
   ```ts
   const singleMessageSchema = object({
     subject: string().required(),
     body: string().required(),
   });

   export async function validateSingleMessage(fields: { subject: string; body: string }) {
     return await validateSchema(fields, singleMessageSchema);
   }
   ```

### Step F2: Update useBulkMessage hook

**Read before working:** `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`

In `app/javascript/shared/queryHooks/useBulkMessage.ts`, add `subject` to the destructured args and the variables payload:

```ts
const createBulkMessage = async ({
  jobId,
  hiringStageId,
  body,
  subject,
  excludedJobApplicationIds = null,
  includedJobApplicationIds = null,
}) => {
  // ...
  return await apiPost({
    path: `/jobs/${jobId}/bulk_channel_messages`,
    variables: {
      hiringStageId,
      body,
      subject,
      includedJobApplicationIds,
      excludedJobApplicationIds,
    },
  });
};
```

### Step F3: Add subject input to ChannelMessageNew (single-send composer)

**Read before working:** `cursor_rules/frontend/forms/form_state_and_change_handlers.md`, `cursor_rules/frontend/forms/form_validation_and_errors.md`, `cursor_rules/frontend/components/component_architecture.md`

This is the candidate's messages tab single-send composer.

1. Add state for subject, pre-populated with the rendered default. The component receives `jobApplication` which has `jobApplication.job.title` and `jobApplication.job.organizationName` (via the serializer). Construct the default: `"${job.title} at ${organizationName}"`. The component will need access to these values -- check what `jobApplication` exposes or pass them as props.

2. Add a `FormInput` for subject above the ProseMirror editor:
   ```tsx
   <FormInput
     onChange={handleChangeSubject}
     name="subject"
     placeholder=""
     label="Subject"
     value={subject}
     errors={errors}
   />
   ```

3. Include `subject` in the `createChannelMessage` call (line 82):
   ```ts
   createChannelMessage({
     channelId: allChannel?.id,
     body: serializedState,
     subject: subject,
   }, { ... });
   ```

4. Add yup validation before sending (new pattern -- currently single-send has no yup validation, just an empty-body check at line 71). Use the new `validateSingleMessage` function.

5. **Repopulate on validation error:** If subject is empty on submit, repopulate with the rendered default AND show the validation error. This is a new pattern per the spec.

6. When inserting a template via `handleInsertTemplate`, also set the subject from `mailMerge.subjectRaw` (the rendered subject from the mail-merge response).

**Default pre-population:** Candidate context is known -- render with actual values: `"Software Engineer at Acme Corp"`.

### Step F4: Add subject input to BulkMessageModal

**Read before working:** `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`, `cursor_rules/frontend/forms/form_validation_and_errors.md`

1. Add state: `const [subject, setSubject] = useState("{{JobTitle}} at {{OrganizationName}}");`
2. Add a `FormInput` for subject above the ProseMirror editor, after the template select
3. Include `subject` in the `createBulkMessage` call (line 102)
4. Include `subject` in yup validation (already updated in Step F1)
5. When a template is selected via `handleChangeSelectChannelMessageTemplate`, also set subject from `template.subject || "{{JobTitle}} at {{OrganizationName}}"`
6. Repopulate default on validation error

**Default pre-population:** No candidate context -- show literal tokens: `"{{JobTitle}} at {{OrganizationName}}"`.

### Step F5: Add subject input to ChannelMessageTemplateModal

**Read before working:** `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`, `cursor_rules/frontend/forms/form_validation_and_errors.md`

1. Add `subject` to the `channelMessageTemplate` state (line 48). On create, default to `"{{JobTitle}} at {{OrganizationName}}"`. On edit, use the saved template's subject value.
   - **MED finding SD-F1:** On edit, if the template has a NULL subject (legacy template), show the default `"{{JobTitle}} at {{OrganizationName}}"` instead of empty.
2. Add a `FormInput` for subject between the template name input and the ProseMirror body editor
3. `subject` is already included in the spread (`...channelMessageTemplate`) in the create/update calls (lines 99, 123) -- it will be sent automatically once it's part of the state object
4. Include `subject` in yup validation (already updated in Step F1)

### Step F6: Add subject input to HiringStageAutomationModal (inline-create-template)

**Read before working:** `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`

1. Add state: `const [newTemplateSubject, setNewTemplateSubject] = useState("{{JobTitle}} at {{OrganizationName}}");`
2. In the `isCreatingTemplate` section (line 323), add a `FormInput` for subject between template name and body editor
3. Include `subject` in the `createChannelMessageTemplate` call (line 216):
   ```ts
   createChannelMessageTemplate(
     { name: newTemplateName, subject: newTemplateSubject, body },
     { ... }
   );
   ```
4. Include `subject` in the inline template validation call (line 206)
5. Reset `newTemplateSubject` alongside `newTemplateName` in `handleDiscardTemplate` and success handler

### Step F7: Display subject in ChannelMessageTemplateSelectionModal preview

**Read before working:** `cursor_rules/frontend/components/component_architecture.md`

1. In `PreviewSelection` component (line 23), also render the subject from `mailMerge.subjectRaw` or `mailMerge.subjectHtml` above the body preview:
   ```tsx
   {mailMerge?.subjectRaw && (
     <Styled.SubjectPreview>
       Subject: {mailMerge.subjectRaw}
     </Styled.SubjectPreview>
   )}
   ```
2. Add a styled component `Styled.SubjectPreview` for the subject display -- should be visually distinct from the body (e.g., bold, smaller, above the body with a separator)

### Step F8: Add subject input to JobSetupAutomations (apply-response template)

**Read before working:** `cursor_rules/frontend/forms/form_state_and_change_handlers.md`

1. Add `applyResponseTemplateSubject` to the `job` state (line 21):
   ```ts
   const [job, setJob] = useState({
     useApplyResponseTemplate: passedJob.useApplyResponseTemplate,
     applyResponseTemplate: passedJob.applyResponseTemplate,
     applyResponseTemplateSubject: passedJob.applyResponseTemplateSubject || '{{JobTitle}} at {{OrganizationName}}',
   });
   ```
2. Add a `FormInput` for subject above the ProseMirror body editor, inside the `Styled.Template` conditional block
3. Include `applyResponseTemplateSubject` in the `updateJob` call (line 58)

---

## 6. Validation and Constraints

| Layer | What | Where | Why |
|---|---|---|---|
| **Frontend yup** | `subject: string().required()` | `validateWithYup.ts` -- in `channelMessageTemplateSchema`, `bulkMessageSchema`, and new `singleMessageSchema` | Ensures every new outbound message has a subject |
| **Frontend repopulate** | On validation failure, repopulate cleared subject with rendered default | Each form component's submit handler | New pattern (spec-mandated): user always sees the baseline subject |
| **Backend nullable** | `subject` column is nullable | Migration | Backwards compatibility -- existing rows stay NULL |
| **Backend no presence** | No `validates :presence` on `subject` | `ChannelMessage` model | Legacy rows must remain valid |
| **Backend custom validator** | `validates :subject, custom_channel_message: true` | `ChannelMessage` model | Catches `{{...}}` patterns in subject that would produce ugly template syntax in delivered email |
| **Backend sanitizer** | `sanitize(subject)` in controllers | `ChannelMessagesController`, `BulkChannelMessagesController`, `JobsController` | XSS defense -- strips `<script>` etc. before subject can reach `dangerouslySetInnerHTML` via spanified preview |
| **Mailer fallback** | `@channel_message.subject.presence \|\| hardcoded` | `ChannelMessageMailer#notify_candidate` | Safety net for legacy NULL-subject rows |
| **SendTemplateEmail** | `add_subject` raises `"No subject provided"` if blank | `app/services/emails/send_template_email.rb` line 73 | Existing validation -- the mailer fallback ensures this never fires |

---

## 7. Test Plan

### 7a. RSpec (new)

No existing RSpec test files cover the affected code (confirmed: no `spec/**/channel_message*` or `spec/**/channel_message_template*` files exist). The codebase has RSpec specs in `spec/interactors/`, `spec/services/`, and `spec/requests/api_public/`.

**Recommended new specs:**

1. **Validator spec** (`spec/validators/custom_channel_message_validator_spec.rb`):
   - Validates that body with `{{...}}` patterns fails
   - Validates that subject with `{{...}}` patterns fails
   - Validates that body/subject without patterns passes
   - Validates that nil subject passes (no presence validation)

2. **Mailer spec** (`spec/mailers/channel_message_mailer_spec.rb`):
   - `notify_candidate` uses `channel_message.subject` when present
   - `notify_candidate` falls back to `"#{job.title} at #{organization.name}"` when subject is nil
   - `notify_candidate` falls back when subject is empty string

3. **Model spec** (`spec/models/job_application_spec.rb`):
   - `render_template_message` returns `subject_raw`, `subject_html`, `template_subject_html` keys
   - `render_template_message` substitutes variables in subject
   - `render_template_message` does NOT run Redcarpet on subject (no `<p>` tags in output)
   - `render_template_message` detects invalid tags in subject

### 7b. Existing Cypress tests to verify

These Cypress tests cover the affected workflows and must still pass:

1. **`cypress/e2e/candidates/messages.cy.js`** -- Tests manual messaging, template creation from message, template selection, template editing. Will need updates to fill in the new subject field.
2. **`cypress/e2e/job-setup/hiring-stage-automations.cy.js`** -- Tests automation creation with template selection and inline template creation. Will need updates for the subject field in inline template creation.

### 7c. New Cypress tests

1. **Subject in single-send:** Compose a message with a custom subject, send it, verify the subject is preserved (check via API response or by inspecting the channel message)
2. **Subject in bulk send:** Open bulk message modal, verify subject is pre-populated with `{{JobTitle}} at {{OrganizationName}}`, modify subject, send
3. **Subject in template create/edit:** Create a template with a custom subject, verify it's saved. Edit the template, change subject, verify update
4. **Subject in template selection preview:** Select a template, verify the rendered subject appears in the preview
5. **Subject validation:** Clear the subject field, attempt to submit, verify validation error and repopulation with default
6. **Apply-response template subject:** Navigate to Job Setup > Automations, enable apply response template, verify subject input appears, set subject, save

---

## 8. Documentation Impact

No documentation files need creation or update. This is an internal product feature with no public API documentation impact (the public API serializer exposes `:subject` as an additive change).

---

## 9. Risks and Open Questions

### Risks

1. **BulkChannelMessagesController hand-built hash drop:** This is the highest-risk single point of failure. If `subject:` is not added to the hand-built hash at lines 19-24, bulk sends silently lose the subject even though it's permitted in params. The spec calls this out explicitly.

2. **HiringStageMessageAutomationJob missing subject:** Same silent-drop risk. If `subject:` is not added to `message_params` at lines 16-20, automated messages silently lose the template's subject.

3. **Redcarpet boundary in render_template_message:** Subject must NOT go through the Redcarpet Markdown pass (lines 773-775). Getting this wrong wraps the subject in `<p>` tags, which would appear as literal HTML in the Mailgun `Subject:` header.

4. **`.html_safe` on subject:** `CreateStageAutomationMessage#parse_text` ends with `.html_safe`. This is inherited from the existing `parse_body` method. For subject, `.html_safe` has no effect (subject goes into a Mailgun header, not an ERB template) -- but it's worth noting so the implementer doesn't remove it thinking it's wrong, which would change the body behavior.

5. **Organization.rb edit restriction:** The source repo's CLAUDE.md says "Do not automate edits to `app/models/organization.rb`." The implementer must present the change and let the user make it.

### Open questions

1. **Single-send default pre-population source:** The `ChannelMessageNew` component receives `jobApplication` but needs `job.title` and `organization.name` to construct the default subject. The `ChannelMessageSerializer` does not currently expose `organization_name` -- only `job_title` (line 35). The implementer may need to pass the organization name down from a parent component or add it to the serializer response. Check what data is already available at that component level before deciding.

2. **Template subject on edit with NULL (MED finding SD-F1):** When editing a legacy template that has a NULL subject, the frontend should show the default `"{{JobTitle}} at {{OrganizationName}}"` rather than an empty field. This is an implementation detail the implementer should handle in `ChannelMessageTemplateModal` state initialization.

---

## 10. Estimated Scope

| Category | Count |
|---|---|
| New files | 2 (migration + renamed validator) |
| Deleted files | 1 (old validator filename) |
| Modified backend files | ~20 |
| Modified frontend files | ~9 |
| New RSpec test files | 3 |
| Modified Cypress test files | 2 |
| New Cypress test files | 0 (add tests to existing files) |
| Estimated lines changed (backend) | ~120 |
| Estimated lines changed (frontend) | ~200 |
| Estimated lines of new tests | ~150 |

---

## MED Findings from Spec Review -- How Addressed

| Finding | How addressed in this plan |
|---|---|
| **PP-F1:** `parse_text` rename needs generalized argument | Steps 6-7 specify changing the method signature to accept text as an argument |
| **TR-F1:** `clean_incoming_message` boundary | Step 3 explicitly states: do NOT process subject through `clean_incoming_message` / `remove_bad_line_breaks` |
| **TR-F2:** `html_safe_apply_email` ends with `.html_safe` not needed for subject | Step 9b notes that `parse_apply_response_text` does NOT call `.html_safe`; Risk 4 documents the `.html_safe` situation in `CreateStageAutomationMessage` |
| **FC-F1:** No single-send yup schema exists today | Step F1 creates a new `validateSingleMessage` function |
| **SD-F1:** Legacy NULL-subject templates on edit should show default | Step F5 item 1 addresses this explicitly |
| **AO-F2:** No test plan in spec | Section 7 provides a complete test plan |
