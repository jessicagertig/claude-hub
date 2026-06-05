# seeding-and-defaults -- Round 2

## Findings

Re-verified defaults and mailer fallback consistency with fresh scrutiny.

### Additional checks this round:

1. Verified mailer fallback string produces the same result as the token default after substitution:
   - Mailer fallback: `"#{@job.title} at #{@organization.name}"` (Ruby interpolation)
   - Token default: `"{{JobTitle}} at {{OrganizationName}}"` (Mustache/gsub substitution)
   - After substitution, both produce `"[title] at [name]"`. PASS.

2. Verified frontend default for single-send is rendered (not tokens): `` `${jobApplication.job.title} at ${jobApplication.job.organizationName}` `` (JavaScript template literal). This produces `"Software Engineer at Acme Corp"` -- matches the mailer fallback format. PASS.

3. Verified frontend defaults for non-candidate-context surfaces are literal tokens: `"{{JobTitle}} at {{OrganizationName}}"`. These surfaces (bulk modal, template modal, automation modal, apply-response template) correctly show tokens because no single candidate context applies. PASS.

4. Verified `add_default_apply_response_template` uses `update_columns` (not `update`) -- this bypasses callbacks, consistent with the existing pattern for the body default. PASS.

5. Confirmed again that `organization.rb` `default_channel_message_templates` does NOT include subject. This is the expected manual edit per known context. Not a finding.

No issues found.
