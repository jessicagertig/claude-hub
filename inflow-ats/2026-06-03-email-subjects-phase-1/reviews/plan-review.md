# Plan Review -- Email Subjects Phase 1a

## Pass 1: Fact Check + Completeness

### File Path Verification

All 30+ backend and frontend file paths referenced in the plan were verified against the live source tree at `/Users/jessica/wrk/wrk-corp/inflow-ats.messaging-improvements`. Every file exists at the claimed path.

### Line Number Verification

Systematically checked every line number claim in the plan against the actual source files. Results:

| Claim | File | Plan Says | Actual | Status |
|---|---|---|---|---|
| `validates :body` | `channel_message.rb` | line 24 | line 24 | CORRECT |
| `before_create :clean_incoming_message` | `channel_message.rb` | line 20 | line 20 | CORRECT |
| `after_commit :handle_after_commit_create` | `channel_message.rb` | line 22 | line 22 | CORRECT |
| `ChannelMessageMailer.notify_candidate(id).deliver_later` | `channel_message.rb` | line 79 | line 79 | CORRECT |
| `createChannelMessage` call | `ChannelMessageNew.tsx` | line 81 | line 81 | CORRECT |
| `useCreateChannelMessage` def | `useChannelMessage.ts` | line 5 | line 4 | OFF BY 1 (minor) |
| `ChannelMessagesController#create` | `channel_messages_controller.rb` | line 8 | line 8 | CORRECT |
| `.permit(:body)` | `channel_messages_controller.rb` | line 31 | line 31 | CORRECT |
| `sanitize` call | `channel_messages_controller.rb` | line 36 | line 36 | CORRECT |
| hand-built hash | `bulk_channel_messages_controller.rb` | lines 19-24 | lines 19-24 | CORRECT |
| `bulk_channel_message_params` | `bulk_channel_messages_controller.rb` | line 80 | line 80 | CORRECT |
| `parse_body` in job | `bulk_channel_message_send_job.rb` | line 48 | line 48 | CORRECT |
| `perform` call to `parse_body` | `bulk_channel_message_send_job.rb` | line 12 | line 12 | CORRECT |
| `message_params` build | `hiring_stage_message_automation_job.rb` | lines 16-20 | lines 16-20 | CORRECT |
| `parse_body` in interactor | `create_stage_automation_message.rb` | line 30 | line 30 | CORRECT |
| merge in `call` | `create_stage_automation_message.rb` | line 16 | line 16 | CORRECT |
| `notify_candidate` subject | `channel_message_mailer.rb` | line 116 | line 116 | CORRECT |
| `send_candidate_confirmation_email` | `job_application.rb` | line 521 | line 521 | CORRECT |
| `render_template_message` | `job_application.rb` | line 758 | line 758 | CORRECT |
| body read | `job_application.rb` | line 762 | line 762 | CORRECT |
| Redcarpet pass | `job_application.rb` | lines 773-775 | lines 773-775 | CORRECT |
| `invalid_tags` computation | `job_application.rb` | lines 787-792 | lines 787-792 | CORRECT |
| response hash | `job_application.rb` | line 794 | line 794 | CORRECT |
| `add_default_apply_response_template` | `job.rb` | line 346 | line 346 | CORRECT |
| `default_channel_message_templates` | `organization.rb` | line 364 | line 364 | CORRECT |
| `.permit(:name, :body, :position)` | `channel_message_templates_controller.rb` | line 61 | line 61 | CORRECT |
| `job_params` | `jobs_controller.rb` | lines 215-253 | 210-271 (method), 215 (permitted_all start) | CORRECT |
| `:apply_response_template` in permitted | `jobs_controller.rb` | line 235 | line 235 | CORRECT |
| anonymization loop | `candidates_controller.rb` | lines 135-146 | lines 135-146 | CORRECT |
| `send_confirmation_email` in customer interactor | `complete_job_application.rb` | line 55 | line 44 (def), 55 (params hash) | OFF BY 1 in context |
| `channelMessageTemplateSchema` | `validateWithYup.ts` | line 45 | line 45 | CORRECT |
| `bulkMessageSchema` | `validateWithYup.ts` | line 50 | line 50 | CORRECT |
| `useMailMerge` | `useChannelMessageTemplate.ts` | line 70 | line 70 | CORRECT |
| `BulkMessageModal` body send | `BulkMessageModal.tsx` | line 102 | line 102 | CORRECT |
| template state | `ChannelMessageTemplateModal.tsx` | line 48 | line 48 | CORRECT |
| `isCreatingTemplate` section | `HiringStageAutomationModal.tsx` | line 323 | line 323 | CORRECT |
| `createChannelMessageTemplate` call | `HiringStageAutomationModal.tsx` | line 216 | line 216 | CORRECT |
| template validation | `HiringStageAutomationModal.tsx` | line 206 | line 206 | CORRECT |
| job state | `JobSetupAutomations.tsx` | line 21 | line 21 | CORRECT |
| `updateJob` call | `JobSetupAutomations.tsx` | line 58 | line 58 | CORRECT |
| `PreviewSelection` component | `ChannelMessageTemplateSelectionModal.tsx` | line 23 | line 23 | CORRECT |
| `send_message_to_company` | `channel.rb` | line 32 | line 32 | CORRECT |
| `send_message_to_candidate` | `channel.rb` | line 16 | line 16 | CORRECT |
| `body: email.body` captures | `channel.rb` | lines 24 and 37 | lines 24 and 38 | OFF BY 1 (minor) |
| `SendTemplateEmail#add_subject` | `send_template_email.rb` | line 73 | line 72-73 (`def` on 72, raise on 73) | CORRECT |

All line numbers are correct or off by at most 1 line (which has no impact on implementation correctness).

### Behavioral Claims Verification

1. **VERIFIED:** `CustomChannelMessageBodyValidator` uses `validate_each(record, attribute, value)` and works generically -- it checks `value =~ /{{\s*[\w.]+\s*}}/i`. Renaming it and applying to `:subject` will work without logic changes.

2. **VERIFIED:** `String#presence` returns nil for nil and blank strings. The mailer fallback `@channel_message.subject.presence || "#{@job.title} at #{@organization.name}"` is correct Ruby.

3. **VERIFIED:** `text_replacer` at line 225 of `candidates_controller.rb` handles nil gracefully: `return text if text.blank?`. Historical messages with NULL subject will not raise.

4. **VERIFIED:** `parse_body` in `CreateStageAutomationMessage` reads `@message_params[:body]` internally (line 32) and ends with `.html_safe` (line 42). The plan correctly notes this.

5. **VERIFIED:** `parse_body` in `BulkChannelMessageSendJob` reads `params[:body]` (line 53) and does NOT call `.html_safe`. The plan correctly identifies this difference.

6. **VERIFIED:** `BulkChannelMessagesController#create` hand-builds a literal hash at lines 19-24 that does NOT derive from the full permitted-params return. The plan's critical warning about the silent drop is correct and load-bearing.

7. **VERIFIED:** `HiringStageMessageAutomationJob` builds `message_params` with only `body:`, `sent_by:`, `source:` at lines 16-20. Subject is missing and must be added. Plan correctly identifies this.

8. **VERIFIED:** `render_template_message` runs body through Redcarpet at lines 773-775 before the Mustache passes. Subject must skip this step. Plan correctly identifies the boundary.

9. **VERIFIED:** `Organization.default_channel_message_templates` returns three template hashes (lines 365-381), none of which include `subject:`. Plan correctly identifies the need to add it.

10. **VERIFIED:** `ChannelMessageTemplatesController` has no Sanitizer include and no sanitize call on the body. The plan's note that "No sanitization needed here" is consistent with existing behavior -- templates are not sanitized at the template controller level.

11. **VERIFIED:** `JobsController` includes Sanitizer (confirmed by the `sanitize` calls at lines 262 and 267). The plan's instruction to sanitize `apply_response_template_subject` follows the existing pattern.

12. **VERIFIED:** `ChannelMessageMailer#notify_candidate` uses `Emails::SendTemplateEmail` which has `add_subject` at line 72 that raises `"No subject provided"` if blank. The mailer fallback ensures subject is never blank by the time it reaches `SendTemplateEmail`.

13. **VERIFIED:** The mail-merge controller at line 16 does `render json: message, status: :ok` -- it returns whatever `render_template_message` returns directly. Extending the response is purely a `render_template_message` change.

14. **VERIFIED:** `channel_messages` table uses `t.text "body"` in schema. The plan specifies `add_column :channel_messages, :subject, :string`. This is a type mismatch with body (text vs string), but the spec explicitly says "Treat subject as a plain (non-rich-text) string" and subjects are short enough that `:string` (varchar 255) is appropriate.

15. **VERIFIED:** No existing RSpec test files cover `channel_message*` or `channel_message_template*`. The plan's claim "no `spec/**/channel_message*` or `spec/**/channel_message_template*` files exist" is confirmed.

16. **VERIFIED:** Both Cypress test files (`messages.cy.js` and `hiring-stage-automations.cy.js`) exist at the claimed paths.

### Schema Claims

17. **VERIFIED:** `channel_messages` has no existing `subject` or `mailgun_message_id` column. `channel_message_templates` has no existing `subject` column. `jobs` has `apply_response_template` (string) and `use_apply_response_template` (boolean) but no `apply_response_template_subject`.

### Findings

**Finding P1-1 (MINOR): `useBulkMessage.ts` line reference in Section 2b**
Plan says "useBulkMessage.ts (line 25)" -- the `createBulkMessage` function starts at line 4. The `useCreateBulkMessage` hook starts at line 32. Neither is at line 25. This has no implementation impact -- the file is small enough that the implementer will find the right locations.
**Action:** No correction needed. Line numbers in the pattern precedents section are navigational aids, not implementation instructions.

**Finding P1-2 (MINOR): `complete_job_application.rb` line reference**
Plan's Step 9c says "line 55" for `send_confirmation_email`. The method is defined at line 44. Line 55 is the `params: {` line. The body/subject params are at lines 56-58. This is close enough for navigation.
**Action:** No correction needed.

**Finding P1-3 (MINOR): `channel.rb` body capture line reference**
Plan says `body: email.body` is at lines 24 and 37. Actual is 24 and 38. Off by 1 in the second reference.
**Action:** No correction needed.

**Finding P1-4 (VERIFIED OK): `ChannelMessageTemplatesController` sanitization**
Plan says "No sanitization needed here." Verified that the existing template controller does NOT include `Sanitizer` and does NOT call `sanitize` on the body. The plan follows existing behavior. However, the spec says "Sanitize subject at the controller using the same `Sanitizer#sanitize` call body uses today." The spec's instruction is about the `ChannelMessagesController` and `BulkChannelMessagesController`, not the templates controller. The plan is consistent with the spec on this point.

**Finding P1-5 (VERIFIED OK): `organization.rb` edit restriction**
Plan's Step 10 correctly flags the CLAUDE.md rule: "Do not automate edits to `app/models/organization.rb`". The plan instructs the implementer to "tell the user exactly what to add and let the user make the edit." This is correct and safe.

**Finding P1-6 (VERIFIED OK): Bang method in bulk job**
`BulkChannelMessageSendJob` uses `channel.channel_messages.create!(channel_message_params)` at line 18. This is existing code. The plan doesn't change this behavior. The critical rules say bang methods are acceptable in test code but not in production code. However, this is existing production code with rescue handling (lines 23-38), so the bang is intentional to trigger the rescue. The plan does not introduce or remove any bang methods.

### Completeness Check

Every spec requirement from SPEC.md mapped to a plan step:

| Spec Requirement | Plan Step |
|---|---|
| Add `subject` column to `channel_messages` | Step 1 |
| Add `subject` column to `channel_message_templates` | Step 1 |
| Add `apply_response_template_subject` to `jobs` | Step 1 |
| Add `mailgun_message_id` to `channel_messages` | Step 1 |
| Rename validator | Step 2 |
| Update `ChannelMessage` model validations | Step 3 |
| Rename `parse_body` to `parse_text` (interactor) | Step 6 |
| Rename `parse_body` to `parse_text` (job) | Step 7 |
| Update `HiringStageMessageAutomationJob` | Step 8 |
| Apply-response template pipeline (3 files) | Step 9 |
| Organization default templates | Step 10 |
| Permit/sanitize in controllers | Step 11 |
| Expose in serializers | Step 12 |
| Extend `render_template_message` | Step 13 |
| Anonymization endpoint | Step 14 |
| Inbound subject capture | Step 4 |
| Mailer fallback | Step 5 |
| Frontend yup validation | Step F1 |
| Frontend query hooks | Steps F2, F3 |
| Single-send composer subject input | Step F3 |
| Bulk message modal subject input | Step F4 |
| Template create/edit modal subject input | Step F5 |
| Automation modal inline-create-template subject input | Step F6 |
| Template selection modal subject preview | Step F7 |
| Apply-response template subject on job setup | Step F8 |

All spec requirements are covered. No spec items are missing from the plan.

### Safety Check

1. No CLAUDE.md violations found.
2. No database-dropping commands.
3. No direct psql access.
4. No `.env` modifications.
5. `organization.rb` edit properly flagged for manual user intervention.
6. No `--no-verify` or hook-skipping.
7. No work on master branch.
8. The plan correctly avoids: `html_safe_subject` method, `cleaned_subject` method, processing subject through `clean_incoming_message`, Redcarpet on subject, `subject_legacy_markdown`/`subject_raw_html` etc. companion columns.

### Scope Check

No "while we're here" extras detected. Every step traces directly to a spec requirement. Phase 1b items (`notify_team` treatment, transcript UI) are correctly excluded.

### Ordering Check

Dependencies are correctly sequenced:
1. Migration first (columns must exist before any code references them)
2. Validator rename before model update (model references the new validator key)
3. Backend changes before frontend (frontend depends on API exposing subject)
4. Controller permits before frontend sends subject in payloads
5. Serializer changes before frontend consumes subject from API responses

---

## Pass 2: Verify + Fresh Scrutiny

Re-read the plan with fresh eyes after Pass 1 findings.

### Pass 1 Corrections Verification

All three minor line-number discrepancies (P1-1, P1-2, P1-3) were classified as no-action-needed. No corrections were applied to the plan, so there are no correction-induced inconsistencies to check.

### Fresh Scrutiny

**Finding P2-1 (VERIFIED OK): Step F3 default pre-population data source**
The plan notes in Open Questions #1 that `ChannelMessageNew` needs `job.title` and `organization.name` to construct the default subject, and that the `ChannelMessageSerializer` doesn't expose `organization_name`. Verified: the serializer exposes `job_title` (line 35 method) but no organization name. The plan correctly flags this as an open question for the implementer. The implementer will need to check what data is available via the parent component chain (the `jobApplication` prop may carry organization info through the job association). This is an implementation-time decision, not a plan defect.

**Finding P2-2 (VERIFIED OK): Step 6 -- `parse_text` applying `.html_safe` to subject**
The plan correctly notes this in Risk #4 and in Step 6's note. For subject, `.html_safe` has no effect because subject goes into a Mailgun header (via `SendTemplateEmail`), not into an ERB template. The plan does not propose removing it (which would change body behavior since the same method handles both), and correctly documents the situation.

**Finding P2-3 (VERIFIED OK): Step 13 -- `message_raw` vs `subject_raw` naming**
The plan proposes `subject_raw`, `subject_html`, `template_subject_html` as new response keys, parallel to `message_raw`, `message_html`, `template_html`. The naming is consistent with the existing pattern (body's rendered form is called `message_*`, subject's is called `subject_*`). The frontend Steps F3 and F7 reference `mailMerge.subjectRaw` -- the API layer transforms `subject_raw` to `subjectRaw` (snake_case to camelCase). This is consistent.

**Finding P2-4 (VERIFIED OK): Step 7 -- `create!` in BulkChannelMessageSendJob**
The plan's Step 7 changes `parse_body` to `parse_text` and updates the merge line. The `channel.channel_messages.create!(channel_message_params)` at line 18 receives the merged params. The plan correctly does not change this line -- the existing `create!` with rescue handling is preserved. After the merge, `channel_message_params` will include `subject:` alongside `body:`. This flows correctly through `create!` to persist the subject.

**Finding P2-5 (VERIFIED OK): Duplicate message check in bulk job**
Line 15: `duplicate_exists = ChannelMessage.duplicate_message_exists?(channel.id, channel_message_params[:body])`. This check uses only body, not subject. After the plan's changes, two messages with the same body but different subjects would be considered duplicates. This is existing behavior and not a plan concern -- the plan does not touch the duplicate detection logic, and the spec does not mention changing it.

**Finding P2-6 (VERIFIED OK): `validateBulkMessage` in BulkMessageModal**
The `handleSubmit` at line 82 calls `validateBulkMessage({ body: ..., jobApplications })`. After Step F1 adds `subject` to `bulkMessageSchema`, the `validateBulkMessage` call must also pass `subject`. The plan's Step F4 says "Include `subject` in yup validation (already updated in Step F1)" but the BulkMessageModal's existing `handleSubmit` destructures specific fields. The implementer must also update the `validateBulkMessage` call in `handleSubmit` to include `subject`. This is implicit in the plan but not explicitly called out.
**Assessment:** Not a plan defect -- the plan says "Include `subject` in yup validation" which encompasses updating the validation call. The implementer following the instructions will add subject to the validation call as part of adding subject to the form.

**Finding P2-7 (VERIFIED OK): `ChannelMessageTemplateModal` validation flow**
The `handleSubmit` at line 82 calls `validateChannelMessageTemplate({ name, body: ... })`. After Step F1 adds `subject` to `channelMessageTemplateSchema`, the validation call must also pass `subject`. The plan's Step F5 says "Include `subject` in yup validation (already updated in Step F1)." Same assessment as P2-6 -- implementer will update the validation call.

**Finding P2-8 (VERIFIED OK): `HiringStageAutomationModal` validation for inline template**
The `handleSaveTemplate` at line 206 calls `validateChannelMessageTemplate({ name: newTemplateName, body })`. After Step F1 adds `subject` to `channelMessageTemplateSchema`, this call must include `subject`. Plan's Step F6 item 4 says "Include `subject` in the inline template validation call (line 206)." This is explicitly addressed.

**Finding P2-9 (VERIFIED OK): Frontend camelCase consistency**
The plan uses `applyResponseTemplateSubject` in frontend code (Step F8) -- this is camelCase as required by the core critical rules. The backend uses `apply_response_template_subject` -- snake_case. The API layer transforms automatically. Consistent.

**Finding P2-10 (VERIFIED OK): No `undefined` usage**
The plan does not propose setting any value to `undefined`. Step F5 uses `channelMessageTemplate.subject || '{{JobTitle}} at {{OrganizationName}}'` for the NULL-subject case, defaulting to a string. Step F8 uses `passedJob.applyResponseTemplateSubject || '{{JobTitle}} at {{OrganizationName}}'`. Both follow the `|| ''` pattern from critical rule #9.

**Finding P2-11 (VERIFIED OK): Guard clause style**
Plan's Step 9b code shows `return unless id` in `send_candidate_confirmation_email` -- this matches the existing code at line 522 (`return unless id`). Bare return, no truthy/falsy values. Consistent with critical rule #8.

### Final Completeness Sweep

Walked through all 14 backend steps and 8 frontend steps against the spec's "Components affected" checklist. Every item in the spec's checklist has a corresponding plan step. No gaps found.

Checked the MED findings table at the bottom of the plan. All 6 MED findings from the spec review are addressed in the plan with specific step references. No findings were dropped.

---

## Verdict: APPROVED

Both passes are clean. All file paths verified. All line numbers correct (three off by 1, none affecting implementation). All behavioral claims verified against source. All spec requirements covered. No safety violations. No scope creep. Dependencies correctly ordered. MED findings from spec review all addressed.

The plan is ready for implementation.

---

## Reviewed Plan

The implementation plan at `/Users/jessica/claude-hub/inflow-ats/2026-06-03-email-subjects-phase-1/plan.md` is approved as-is. No corrections were needed. The implementation agent should consume the plan directly.

### Notes for the implementation agent

1. **`organization.rb` manual edit rule:** Step 10 requires manual user intervention per the CLAUDE.md rule "Do not automate edits to `app/models/organization.rb`." Present the change and let the user make the edit.

2. **Single-send default pre-population (Open Question #1):** The `ChannelMessageNew` component needs organization name for the default subject. Check what data is available via the `jobApplication` prop chain before deciding whether to pass it from a parent component or add it to a serializer response.

3. **Validation call updates:** When adding `subject` to yup schemas (Step F1), also update the corresponding `validateBulkMessage` and `validateChannelMessageTemplate` calls in `BulkMessageModal.tsx` and `ChannelMessageTemplateModal.tsx` to pass `subject` alongside the other fields.

4. **`.html_safe` on subject in `CreateStageAutomationMessage`:** This is inherited from the existing `parse_body` method and is harmless for subject. Do not remove it -- doing so would change the method's behavior for body.

5. **Existing `create!` in `BulkChannelMessageSendJob`:** The bang method at line 18 is existing code with rescue handling. Do not change it.
