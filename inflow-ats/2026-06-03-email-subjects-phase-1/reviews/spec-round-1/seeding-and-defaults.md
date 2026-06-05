# Seeding and Defaults -- Round 1

## Findings

### Organization default templates
Source: `Organization.default_channel_message_templates` (lines 364-382) defines three templates:
1. "Thank you for applying" -- body only
2. "Scheduling" -- body only
3. "Rejection" -- body only

Spec says: add `subject: "{{JobTitle}} at {{OrganizationName}}"` to each. This means every new organization gets templates with a subject that, after mail-merge substitution, produces the same string as the mailer fallback.

Mailer fallback: `"#{@job.title} at #{@organization.name}"` (line 116 of `channel_message_mailer.rb`).
Default template subject: `"{{JobTitle}} at {{OrganizationName}}"` -- after substitution, produces `"[job title] at [org name]"`.

These match. Correct.

### Default apply-response template
Source: `Job#add_default_apply_response_template` (line 346-348):
```ruby
def add_default_apply_response_template
  update_columns(apply_response_template: "<p>Hello {{CandidateFirstName}},...</p>")
end
```

Spec says: add `apply_response_template_subject: "{{JobTitle}} at {{OrganizationName}}"` to the `update_columns` call. This means every new job gets an apply-response subject default that matches the mailer fallback after substitution. Correct.

### Frontend default pre-population
Spec defines per-surface defaults:
- Single-send composer: rendered with candidate's values. The default before any user edit should be the mailer default string with variables substituted to the current candidate. This means the frontend needs to render `"{{JobTitle}} at {{OrganizationName}}"` with the known job title and org name.
- Bulk modal: literal tokens `"{{JobTitle}} at {{OrganizationName}}"` because no single candidate context.
- Template create/edit modal: literal tokens or saved value on edit.
- Automation modal inline-create-template: literal tokens.

These are consistent with the backend defaults.

### Consistency check
- New org's first template-based send: template has `subject: "{{JobTitle}} at {{OrganizationName}}"` -> after mail-merge -> `"[title] at [org]"`. This matches what the mailer fallback would produce.
- New job's apply-response send: `apply_response_template_subject: "{{JobTitle}} at {{OrganizationName}}"` -> after gsub -> `"[title] at [org]"`. Matches fallback.
- Legacy org (existing templates have NULL subject): template-based send uses NULL subject -> mailer fallback fires -> `"[title] at [org]"`. Same result. Correct.
- Legacy job (no `apply_response_template_subject`): `job.apply_response_template_subject` is NULL -> params include `subject: nil` -> mailer fallback fires -> `"[title] at [org]"`. Same result. Correct.

### Existing organizations
The spec says "no backfill." Existing orgs' templates will have NULL subject. This is fine because:
1. If an existing org sends from a template, the template's NULL subject flows to the channel_message.
2. The mailer fallback fires, producing the current hardcoded subject.
3. Behavior is unchanged from today. Correct.

However, once the frontend is deployed, users will see the subject input on template edit modals. When they open an existing template for editing, the subject field will be empty (NULL). The spec says the frontend pre-populates with the rendered default on create, but on edit, it should show the saved value. For NULL saved values on legacy templates, the frontend should show the default tokens so users can see what will send.

- F1 [MED] spec / legacy template edit / When editing an existing template that has NULL subject, the spec's per-surface rules say "saved value on edit" for the template create/edit modal. For legacy templates, the saved value is NULL. The frontend should detect NULL and show the default tokens (`"{{JobTitle}} at {{OrganizationName}}"`) rather than an empty field, so the user knows what subject will be used. The spec doesn't explicitly address this case. This is a UX concern that the implementer should handle, but the spec's existing direction ("pre-populate each surface with its appropriate rendered default") is sufficient guidance if "default" is understood to apply when the saved value is NULL.

No issues found.

## Amendments Applied

None -- no BLOCKER or HIGH findings.
