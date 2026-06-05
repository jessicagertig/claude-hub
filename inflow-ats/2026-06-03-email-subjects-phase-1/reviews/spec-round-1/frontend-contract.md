# Frontend Contract -- Round 1

## Findings

Verified frontend files, yup schemas, query hooks, and serializer response shapes.

### Yup validation schemas

- `channelMessageTemplateSchema` (line 45): currently `{ name: string().required(), body: string().required() }`. Spec says add `subject: string().required()`. No issue -- straightforward addition.
- `bulkMessageSchema` (line 50): currently `{ body: string().required(), jobApplications: array().min(1) }`. Spec says add `subject: string().required()`. No issue.
- Single-send validation: There is no dedicated `channelMessageSchema` in `validateWithYup.ts`. The single-send composer (`ChannelMessageNew.tsx`) does not appear to use a yup schema from this file -- it likely validates inline or uses a different mechanism. The spec says "mark subject as required in yup schemas where the form requires it." The spec correctly refers to `channelMessageTemplateSchema` and `bulkMessageSchema` and "single-send validation" without specifying a schema name, leaving it to the implementer to add one if needed.

- F1 [MED] spec / single-send validation / The spec references "single-send validation" in the yup schemas section, but no single-send yup schema currently exists in `validateWithYup.ts`. The single-send composer may validate body presence through a different mechanism (e.g., disabled submit button, inline check). The implementer needs to investigate `ChannelMessageNew.tsx` to determine how body is currently validated and mirror that pattern for subject. This is an implementation concern, not a spec gap -- the spec correctly does not prescribe a specific schema name.

### Query hooks

- `useCreateChannelMessage` (`useChannelMessage.ts`): calls `apiPost({ path: ..., variables })`. The `variables` object is whatever the component passes. If the component includes `subject` in the mutation call's variables, it will be sent. No hook change needed -- the hook is generic. Spec correctly notes the component must include subject. No issue.

- `useCreateChannelMessageTemplate` / `useUpdateChannelMessageTemplate` (`useChannelMessageTemplate.ts`): same pattern -- `apiPost({ path: ..., variables })`. The component must include `subject` in the variables. No hook change needed. Spec correctly notes this. No issue.

- `useMailMerge` (`useChannelMessageTemplate.ts`): calls `apiGet` to the mail-merge controller. The response currently includes `{ message_raw, message_html, template_html, has_invalid_tags, invalid_tags }`. The spec says the response will be extended to include rendered subject and spanified subject. The frontend will need to destructure these new keys. Spec correctly identifies this. No issue.

### Serializer response shapes

- `ChannelMessageSerializer`: currently exposes `body`, `cleaned_body`, `html_safe_body`, `body_sanitized_html`. Spec says add `:subject`. No issue.
- `ChannelMessageTemplateSerializer`: currently exposes `id`, `name`, `body`, `position`, `created_by_user_full_name`. Spec says add `:subject`. No issue.
- `ApiPublic::V1::Hire::ChannelMessageSerializer`: currently exposes `id`, `job_application_id`, `created_at`, `sent_by`, `source`, `created_by_organization_user_id`, `body`, `body_plain_text`. Spec says add `:subject`. No issue.
- `JobSerializer`: currently exposes `use_apply_response_template`, `apply_response_template`. Spec says add `:apply_response_template_subject`. No issue.

### Frontend component files
All five frontend files referenced in the spec exist:
- `ChannelMessageNew.tsx` -- confirmed exists
- `BulkMessageModal.tsx` -- confirmed exists
- `ChannelMessageTemplateModal.tsx` -- confirmed exists
- `HiringStageAutomationModal.tsx` -- confirmed exists
- `ChannelMessageTemplateSelectionModal.tsx` -- confirmed exists

### Per-surface default rendering
The spec defines per-surface defaults:
- Single-send composer (candidate tab): rendered with candidate's values -- candidate context known.
- Bulk modal: literal tokens `{{JobTitle}} at {{OrganizationName}}` -- no single candidate context.
- Template create/edit modal: literal tokens -- no candidate context.
- Automation modal inline-create-template: literal tokens -- no candidate context.
- Automation modal existing-template preview: saved template's subject as-is.
- Template selection modal (candidate tab): rendered with candidate's values via mail-merge.

This is internally consistent. No issue.

## Amendments Applied

None -- no BLOCKER or HIGH findings.
