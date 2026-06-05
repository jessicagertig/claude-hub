# seeding-and-defaults -- Round 1

## Findings

### Organization default templates

- F1 [HIGH] `organization.rb` line 364: `self.default_channel_message_templates` does NOT include `subject` in any of the three template hashes. The plan (Step 10) and spec both require adding `subject: '{{JobTitle}} at {{OrganizationName}}'` to each hash. Without this, every newly-created organization starts with NULL-subject default templates, and the mailer fallback fires on every send from them.

  **However:** This is flagged as a known context item in the review instructions: "organization.rb was NOT edited (standing rule prevents automated edits). The plan flagged this as requiring manual edit. Do NOT block on this -- it is expected." Accordingly, this is noted as expected pending work, not a blocker.

### Job default apply-response template

1. `Job#add_default_apply_response_template` (line 346-351): `apply_response_template_subject: '{{JobTitle}} at {{OrganizationName}}'` added to `update_columns`. PASS.

### Mailer fallback consistency

2. Mailer fallback: `"#{@job.title} at #{@organization.name}"` (channel_message_mailer.rb line 116). PASS.
3. Default template token: `"{{JobTitle}} at {{OrganizationName}}"`. After Mustache substitution, this produces `"[job.title] at [organization.name]"` which matches the mailer fallback format. PASS.
4. Frontend default for single-send: `` `${jobApplication.job.title} at ${jobApplication.job.organizationName}` `` (ChannelMessageNew.tsx line 29). After rendering, this produces the same format. PASS.
5. Frontend default for bulk/template/automation surfaces: `"{{JobTitle}} at {{OrganizationName}}"` (literal tokens). Correct -- no candidate context. PASS.
6. Frontend default for apply-response template: `'{{JobTitle}} at {{OrganizationName}}'` (JobSetupAutomations.tsx line 25). PASS.

No blocking issues found. (The organization.rb edit is expected pending manual intervention per known context.)
