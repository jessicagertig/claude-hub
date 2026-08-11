# Data Integrity & Security (always-on) — Round 3

- **Authorization**: both actions scope the lookup through `current_organization.jobs` before authorizing; authorize-after-find with explicit policy queries; the create action takes the AI-settings gate (`update_ai_settings?`). Cross-org access impossible via the scoped `where`; spec-proven 403 for non-privileged create.
- **Input surface**: no body params accepted anywhere in the new controller (path `job_id` only); nothing user-controlled reaches SQL beyond the scoped `where(id: params[:job_id])`.
- **Broadcast privacy**: `GlobalChannel.broadcast_to(user, ...)` targets ONLY the requesting user's stream; payload contains the job title and the extraction error message for a job that user already has AI-settings access to. No cross-user leakage; auto-path (nil requester) never broadcasts.
- **Data consistency**: no migrations; `update_columns` sites (`bulk_generate_ai_summaries_job.rb:63`, extract job failure writes) verified not inside transactions (rule 25); double-POST residual risk documented per DECISIONS and mitigated by the disabled button + model in-flight guards; the claim-row `:failed` write closes the permanently-un-queueable poisoning path rather than opening one.
- **Flipper**: paid-API trigger (POST) gated; ungated GET returns only derived read-only state (all-null for orgs with no rows), matching the `GET /ai_credits` precedent, with the whole tab UI behind the `AI_APPLICANT_SUMMARY` FeatureFlipper.

## Findings

No issues found.
