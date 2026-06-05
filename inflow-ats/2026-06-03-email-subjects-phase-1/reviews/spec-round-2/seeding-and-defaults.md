# Seeding and Defaults -- Round 2

## Findings

Round 2 deepened verification on default string consistency and edge cases.

### Token-to-literal consistency
Default template subject: `"{{JobTitle}} at {{OrganizationName}}"` (tokens)
Mailer fallback: `"#{@job.title} at #{@organization.name}"` (interpolation)

After substitution, `"{{JobTitle}} at {{OrganizationName}}"` becomes `"[job.title] at [org.name]"`. The mailer fallback produces `"[job.title] at [org.name]"`. These are character-for-character identical after substitution. Confirmed.

### apply_response_template_subject default
`Job#add_default_apply_response_template` uses `update_columns` which bypasses callbacks and validations. The spec says add `apply_response_template_subject:` to the same `update_columns` call. `update_columns` accepts a hash, so adding another key is straightforward. Confirmed.

### Edge case: what happens when apply_response_template_subject is set but apply_response_template (body) is NULL?
`add_default_apply_response_template` sets both body and subject. If a job is created without the default being applied, both are NULL. If the default is applied, both are set. There's no realistic scenario where subject is set but body is NULL, or vice versa, after the default application. If an admin manually clears the body but not the subject (unlikely), the apply-response flow reads `job.apply_response_template` for body -- if NULL, `html_safe_apply_email` would be called on `nil`, which would crash on `.scrub`. But this is an existing edge case unrelated to subject. No spec concern.

### Edge case: what happens when use_apply_response_template is true but apply_response_template_subject is NULL?
This is the legacy-job case. `send_candidate_confirmation_email` would pass `subject: nil` (or however the implementer handles `job.apply_response_template_subject` being nil). The channel_message gets `subject: nil`. The mailer fallback fires. The email arrives with the correct subject. Covered.

### Existing organizations upgrade path
After deployment, existing orgs have templates with NULL subject. When users open these templates in the edit modal, the frontend shows the default tokens (or empty, depending on implementation). The spec's "pre-populate with rendered default" applies to create, not edit. For edit, the spec says "saved value on edit" -- NULL shows as empty. Round 1 noted this as MED (SD-F1). The implementer should handle NULL as "show default." This remains a MED implementation concern, not a spec gap.

No new issues found.

## Amendments Applied

None.
