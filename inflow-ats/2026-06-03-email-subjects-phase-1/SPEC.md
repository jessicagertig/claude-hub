# Email Subjects (Phase 1) — Design [REVIEWED — stripped to keepers only]

**Branch:** `messaging-improvements`
**Date:** 2026-05-20
**Investigation reference:** `docs/superpowers/notes/2026-05-20-email-subjects-phase-1-investigation.md`
**Original spec (frozen):** `docs/superpowers/specs/2026-05-20-email-subjects-phase-1-design.md`
**Open decisions:** `docs/superpowers/specs/2026-05-20-email-subjects-phase-1-open-decisions.md`

This is the frozen spec plus a small set of reviewer additions that fill genuine gaps in implementing the goal — boundaries against body-family pattern matching, body↔subject parity items, load-bearing implementation details, and concrete enumeration of identifiers the original spec referred to as "relevant." Reviewer items that added NEW behavior or NEW requirements beyond the original goal were dropped.

Annotations of the form `<!-- added by adversarial reviewer ... -->` mark the retained additions.

Phase 1 splits into two sub-phases:
- **Phase 1a** — the bulk implementation: schema, validators, parse_text rename, mailer fallback, inbound subject capture, all the editable-surface frontend inputs and yup validation. Done by the phase-1 implementer in one pass.
- **Phase 1b** — two pieces that need specific, careful handling and should not be done in bulk: (1) the final treatment of how `notify_team` consumes the inbound subject, and (2) how the subject is displayed in the candidate messages-tab transcript. Both are part of phase 1 conceptually but handled as a deliberate follow-up immediately after phase 1a — not by the phase-1a implementer.

---

## Goal

Let users write a custom subject line for outbound emails to candidates, with the current system default subject pre-populated (the same hardcoded subject the backend already sends on every outbound email today) so they always know exactly what subject will send. Subject is optional at the data layer (mailer falls back to the existing hardcoded subject if blank), but the frontend enforces non-blank. Because the frontend always supplies a subject, in practice new outbound `channel_message` rows after phase 1 will rarely if ever have a blank subject — the nullable column and mailer fallback are there for legacy rows, not as an expected runtime path.

---

## Architecture

Add a new optional `subject` column on `channel_message_templates` and `channel_messages` — same shape as the existing `body` column.

<!-- added by adversarial reviewer: boundary -->
**Treat subject as a plain (non-rich-text) string.** Skip the Markdown step — do not run subject through `Redcarpet.render` at any layer. Sanitize subject at the controller using the same `Sanitizer#sanitize` call body uses today (XSS-vector tags like `<script>` get stripped; tags in the `RELAXED` whitelist pass through). Run subject through both of `render_template_message`'s Mustache passes — the plain-substitution pass produces the rendered subject for sending/display; the spanified-substitution pass produces the preview-UI variable-highlighting form parallel to body's `template_html`. Do not add `subject_legacy_markdown`, `subject_raw_html`, `subject_plain_text`, or `subject_sanitized_html` companion columns — body has those because body comes from a rich-text editor that emits multiple representations; subject is single-form. Do not add an `html_safe_subject` model method — body has `html_safe_body` for Rails-template HTML rendering, but subject goes into Mailgun's `Subject:` header as plain text and needs no ERB safety marker.

Rename the existing `CustomChannelMessageBodyValidator` to `CustomChannelMessageValidator` and apply it to `subject` the same way it is currently applied to `body`. The validator's only existing call site is the `validates :body, custom_channel_message_body: true` line on the `ChannelMessage` model — update that line to use the new validator key and add a sibling `validates :subject, custom_channel_message: true` line on the same model.

Rename the existing private `parse_body` methods in `ChannelMessages::CreateStageAutomationMessage` (interactor) and `ChannelMessages::BulkChannelMessageSendJob` (job) in place to `parse_text`. Keep their existing signatures and post-processing. Use each to substitute mail-merge variables in both body and subject within its calling context. No further refactor.

For outbound (user-composed) messages: update `ChannelMessageMailer#notify_candidate` to read `channel_message.subject` and fall back to the current hardcoded literal when the stored subject is blank. Pre-populate each subject input on the frontend with the rendered default so users always see what will send.

For outbound apply-response-template messages: `JobApplication#send_candidate_confirmation_email` and `CustomerApi::CompleteJobApplication#send_confirmation_email` both call `ChannelMessages::CreateOrganizationChannelMessage` when `job.use_apply_response_template` is true. Add a nullable `apply_response_template_subject` string column on `jobs`. Both callers include `subject:` in the params hash passed to `CreateOrganizationChannelMessage`, with the same gsub mail-merge substitution that `html_safe_apply_email` already applies to the body. From there the channel_message flows through the standard pipeline — `notify_candidate` reads `channel_message.subject` with fallback. `Job#add_default_apply_response_template` (`app/models/job.rb:346`) sets the default subject to `"{{JobTitle}} at {{OrganizationName}}"` — the token form of the current hardcoded mailer default — for newly created jobs.

For inbound (Postmark webhook) messages — both candidate-to-company replies and company-to-candidate replies via email — capture `@email.subject` in `Channel#send_message_to_company` and `send_message_to_candidate` and persist it on the inbound `ChannelMessage`. No code change required for `notify_team` in **phase 1a**; the inbound subject is reachable as `@channel_message.subject` once the column exists and the capture lands. `notify_team`'s actual consumption of the subject is **phase 1b** (see below).

Do not change the candidate's messages-tab transcript UI in phase 1a. Subject display in the transcript — for both historical messages (no stored subject) and new messages (stored subject) — is **phase 1b**. The current inclination is a low-visibility surface — the existing three-dot menu (which already shows raw email) or a small expand-to-view at the top of a message — but the exact treatment is uncertain enough that it needs the dedicated handling that phase 1b provides.

<!-- added by adversarial reviewer: boundary -->
**Skip the Redcarpet step when extending `render_template_message` for subject.** Body's current pipeline is Redcarpet (Markdown → HTML) → Mustache (substitution) → Mustache (spanification). Subject's pipeline is Mustache (substitution) → Mustache (spanification) — no Redcarpet. Both Mustache passes apply to subject the same way they apply to body; only the Markdown step is omitted.

---

## Data flow

**Outbound, user-composed** (single-send composer or bulk modal): the user sees the subject input pre-populated with the rendered default. They edit or accept it; on send, the value saves to the `channel_message.subject` column via the existing API path. `notify_candidate` reads it from the channel message when delivering via Mailgun.

**Outbound, template-driven** (single-send via template picker, bulk via template select, automation): the template provides the subject; when sending to a specific candidate, the relevant `parse_text` substitutes mail-merge variables with that candidate's values; the result saves to the channel message; `notify_candidate` reads from there.

**Outbound, apply-response-template** (candidate confirmation on application submit): `job.apply_response_template_subject` provides the subject; `html_safe_apply_email`-style gsub substitutes mail-merge variables; result is passed as `subject:` in params to `CreateOrganizationChannelMessage`; standard pipeline from there. When `apply_response_template_subject` is NULL (legacy jobs), the mailer fallback provides the current hardcoded default.

**Inbound** (Postmark webhook): a candidate or user replies via email; `Channel#send_message_to_company` / `send_message_to_candidate` captures `@email.subject` and stores it on the inbound channel message. `notify_team` accesses the stored subject via `@channel_message.subject` in phase 1a; how it actually appears in the team-notification email is phase 1b.

Per-surface default rendering differs by available context. "Single-send" here means the two surfaces in the candidate's messages tab: the template selection modal and the single-send composer.
- Single-send composer and the candidate-tab template selection modal: candidate context is known — render the default with variables substituted to that candidate's values.
- Bulk modal, template create/edit modal, automation modal's inline-create-template: show variables literally (`{{JobTitle}} at {{OrganizationName}}`) because no single candidate context applies.
- Automation modal's existing-template preview: show the saved template's subject as-is.

---

## Validation strategy

**Frontend:** mark `subject` as required in yup schemas where the form requires it. On submit with a cleared field, fire the standard form-error AND repopulate the field with the rendered default so the user sees the baseline. Going forward, every newly-created `channel_message` saves the actual subject that was sent.

Note: the "repopulate-the-cleared-field-with-the-rendered-default on validation error" behavior is a new pattern in this codebase — nothing currently repopulates a required field with a default on submit failure. The validation pattern itself (yup required + form-error display) and the general shape of setting state on error can be copied from existing forms; the difference for subject is that the state set on error is not empty, it's the rendered default.

**Backend:** make the subject column nullable for backwards compatibility — existing rows stay NULL with no backfill. Do not add model-level presence validation on subject. Apply the renamed `CustomChannelMessageValidator` to `subject` the same way it is currently applied to `body`. Add a mailer fallback to the current hardcoded literal when the stored subject is blank. In practice, historical channel-message rows will not trigger fresh sends post-phase-1, so the fallback is unlikely to fire — it exists as good practice given there is no backend presence validation.


---

## Scope notes

**Also in phase 1a (unrelated to subject):** add a nullable `mailgun_message_id` column to `channel_messages`. Column only — no code uses it in phase 1. Groundwork for phase 2 (Gmail threading via `Message-ID` / `In-Reply-To` / `References` headers). Add it in the same migration as the subject columns since the migration is already touching `channel_messages`.

**Out of phase 1 scope entirely (later phases):**
- Capturing Mailgun's response `Message-ID` on outbound and wiring `In-Reply-To` / `References` headers — phase 2.
- Mailgun error propagation — phase 3.
- User-attached files on outbound — phase 4.
- `from` address rework — phase 5.
- Consolidating the two `parse_text` methods (interactor + job) into a single shared helper. They have different signatures and post-processing; phase 1a only renames them in place.
- Backfilling subject on existing `channel_message` rows.

<!-- added by adversarial reviewer: body↔subject parity -->
**Extend the anonymization endpoint to redact subject alongside body.** `Api::V1::CandidatesController`'s candidate-anonymization endpoint currently iterates a candidate's `channel_messages` and runs `text_replacer` over `body`, `body_legacy_markdown`, `body_raw_html`, `body_plain_text`, and `body_sanitized_html` — twice per column (once for `real_first_name`, once for `real_last_name`). Add the same two `text_replacer` calls over `subject` so candidate names don't persist in stored subjects after an anonymization run. Name replacement only, not full redaction — same shape as the existing body redaction.

<!-- added by adversarial reviewer: org-level prerequisite -->
**Default template seed data.** `Organization.default_channel_message_templates` (in `app/models/organization.rb`) hardcodes the three default templates ("Thank you for applying", "Scheduling", "Rejection") that get installed for every newly-created organization. Add a `subject` value to each — `"{{JobTitle}} at {{OrganizationName}}"`, the token form of the current hardcoded mailer default. Otherwise every new org starts with NULL-subject default templates and the mailer fallback fires on every send from them. Similarly, `Job#add_default_apply_response_template` (`app/models/job.rb:346`) sets the default apply response template body for new jobs — add subject with the same default `"{{JobTitle}} at {{OrganizationName}}"`.

---

## Components affected (high-level inventory)

This is a checklist for the implementation plan, not a code spec.

### Phase 1a — Backend
- Create one migration adding `subject` and `mailgun_message_id` columns to the appropriate tables. Also add `apply_response_template_subject` (nullable string) to `jobs`.
- Rename `CustomChannelMessageBodyValidator` → `CustomChannelMessageValidator`. The validator's only existing call site is the `validates :body, custom_channel_message_body: true` line on `ChannelMessage`; update that line to the new validator key and add a sibling `validates :subject, custom_channel_message: true` line on the same model.
- Rename `parse_body` → `parse_text` in `ChannelMessages::CreateStageAutomationMessage` and `ChannelMessages::BulkChannelMessageSendJob`. Use each to substitute for both body and subject.
- <!-- added by adversarial reviewer: load-bearing --> Update `HiringStageMessageAutomationJob` to also pass the template's `subject` into `message_params`. It currently builds `message_params` from `automation.channel_message_template.body`; without adding subject, the template's custom subject is silently ignored and the mailer fallback fires instead.
- Update `JobApplication#send_candidate_confirmation_email` and `CustomerApi::CompleteJobApplication#send_confirmation_email` to include `subject:` in the params passed to `ChannelMessages::CreateOrganizationChannelMessage`. The subject value comes from `job.apply_response_template_subject`, run through the same gsub mail-merge substitution chain that `html_safe_apply_email` applies to the body. Extract the gsub chain into a shared method (e.g., `parse_apply_response_text`) usable for both body and subject, or inline the same chain on subject — implementer's call on shape, not a spec decision.
- Update `Job#add_default_apply_response_template` to set `apply_response_template_subject` to `"{{JobTitle}} at {{OrganizationName}}"` alongside the existing body default.
- Capture inbound `email.subject` in `Channel#send_message_to_company` and `send_message_to_candidate`.
- Update `ChannelMessageMailer#notify_candidate` to read `channel_message.subject` and fall back to the current hardcoded literal when the stored subject is blank. No code change in phase 1a for `notify_team`; the inbound subject is reachable as `@channel_message.subject` once the column exists and the capture lands. `notify_team`'s actual consumption choice is **phase 1b**.
- Permit `:subject` in the relevant API controllers.
  <!-- added by adversarial reviewer: concrete enumeration -->
  Concrete list:
  - `Api::V1::ChannelMessageTemplatesController`: permit `:subject` (alongside `:name`, `:body`, `:position`).
  - `Api::V1::ChannelMessagesController`: permit `:subject` (alongside `:body`).
  - `Api::V1::BulkChannelMessagesController`: permit `:subject` (alongside `:body`, etc.).
  - `Api::V1::HiringStageMessageAutomationsController`: do not permit `:subject` — automations inherit subject from their template.
  - `Api::V1::JobsController`: permit `:apply_response_template_subject` (alongside the existing `:apply_response_template` and `:use_apply_response_template`). Add `apply_response_template_subject` to the existing `Sanitizer#sanitize` call — same one-line shape.
  <!-- added by adversarial reviewer: XSS defense -->
  Add subject to the existing `Sanitizer#sanitize` call on the body line in both `Api::V1::ChannelMessagesController` and `Api::V1::BulkChannelMessagesController`. Same one-line shape body uses today. Strips XSS-vector tags (like `<script>`) before the value can reach the spanified-preview's `dangerouslySetInnerHTML` path or any future HTML rendering of the subject.
  <!-- added by adversarial reviewer: load-bearing -->
  In `Api::V1::BulkChannelMessagesController#create`, also include `subject: bulk_channel_message_params[:subject]` in the literal hash that gets passed forward to the bulk job. That hash is constructed by hand (not derived from the full permitted-params return), so permitting `:subject` alone won't propagate it — subject silently drops at the controller boundary without this addition.
- Expose `:subject` in the relevant serializers (including the public hire serializer).
  <!-- added by adversarial reviewer: concrete enumeration -->
  Concrete list:
  - `Api::V1::ChannelMessageSerializer`: expose `:subject`. (Embedded by `Api::V1::ChannelSerializer`'s `has_many :channel_messages` association — so once this serializer exposes `subject`, the channel-level cached response payload will carry `subject` on every embedded message. Phase 1a's frontend doesn't consume it yet; the transcript UI is phase 1b.)
  - `Api::V1::ChannelMessageTemplateSerializer`: expose `:subject`.
  - `ApiPublic::V1::Hire::ChannelMessageSerializer`: expose `:subject`.
  - The Job serializer used by the Job Setup page: expose `:apply_response_template_subject` so the frontend can pre-populate the subject input.
- Extend the mail-merge controller's existing render path so the template picker can preview the subject alongside the body.
  <!-- added by adversarial reviewer: concrete naming -->
  The mail-merge controller is `Api::V1::ChannelMessageTemplatesMailMergeController#show`, which calls `JobApplication#render_template_message`. The frontend consumes its response via `useMailMerge` in `app/javascript/shared/queryHooks/useChannelMessageTemplate.ts`. Extend `render_template_message`'s response payload to include a rendered-subject key plus a spanified-template variant of the subject parallel to the existing `template_html`.
  <!-- added by adversarial reviewer: body↔subject parity -->
  Widen `render_template_message`'s existing `has_invalid_tags`/`invalid_tags` computation — which today inspects the rendered body for surviving `{{...}}` patterns — to also inspect the rendered subject. Subject-side template typos then surface in the preview the same way body-side typos do.

### Phase 1a — Frontend
- Mark `subject` as required in yup schemas where the form requires it. Handle form errors by repopulating the cleared field with the rendered default — new pattern, see Validation strategy.
- Add a subject input above the body editor in:
  - the single-send composer in the candidate's messages tab,
  - the bulk message modal,
  - the template create/edit modal,
  - and the automation modal's inline-create-template flow.
  Pre-populate each surface with its appropriate rendered default per the per-surface rules in Data flow.
- In the candidate's messages tab, display the selected template's subject (rendered with the candidate's variable values) above the body preview in the template selection modal.
- Do not change the transcript UI in phase 1a.

### Phase 1b — held out of the phase-1a bulk pass

Both items below are part of phase 1 conceptually but need specific, hand-crafted handling that should not be bundled with the phase-1a work.

**1. `notify_team` subject treatment.** Phase 1a makes the inbound channel message's stored subject reachable from the mailer. In phase 1b, pick one of three treatments based on testing what reads correctly in the team's inbox:
1. Use the candidate's reply subject as the team-notification email's subject. Risk: may break threading of the team-notification chain in the team's inbox if it changes per reply.
2. Keep the existing hardcoded notification subject and surface the candidate's reply subject inside the message body of the team-notification email — the current display pattern for the message body itself extended to include the subject.
3. Omit the subject from the team-notification entirely. Probably not viable but listed for completeness.

**2. Subject display in the candidate messages-tab transcript.** Do not change the existing transcript UI in phase 1a. In phase 1b, add a way to see the subject of a transcript message — both new messages (which have a stored subject) and historical messages (which do not). Current inclination: a low-visibility surface such as the existing three-dot menu (which already shows the raw email) or a small expand-to-view at the top of the message row. Exact treatment is uncertain and is the reason this is its own phase rather than rolled into the bulk pass.
