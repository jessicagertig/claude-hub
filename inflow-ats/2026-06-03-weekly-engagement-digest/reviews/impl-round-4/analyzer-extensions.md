# Analyzer Extensions -- Round 4

## Findings

### Backward compatibility (re-verified)

`ReportGenerator` at `report_generator.rb:17`: `OrganizationAnalyzer.new(organization: @organization)` -- new params `organization_user_id:` and `since:` default to `nil`. When nil:
- `scoped_job_ids` takes the `else` branch -> `@organization.jobs.select(:id)` (original behavior).
- `@cutoff = nil || months.months.ago` -> `months.months.ago` (original behavior).
- All downstream methods (`inbound_metrics`, `job_metrics`, `candidate_update_metrics`, `job_application_update_metrics`) check `if @organization_user_id` and take the `else` branch using the original `@organization.*` queries.

`build_result` at line 460 adds `channel_messages: candidate_mgmt[:channel_messages]` -- this is a new key in the output hash. `ReportGenerator#build_payload` at lines 29-69 reads from `engagement_data` but does not access `candidate_management[:channel_messages]`. The new key is ignored by the existing consumer. SAFE.

### Subquery composition

`@job_ids`, `@candidate_ids`, and `@job_application_ids` are all `ActiveRecord::Relation` objects with `.select(:id)`, generating SQL subqueries. These are used in downstream `where` clauses via `WHERE column IN (SELECT id FROM ...)`. This is a valid and efficient pattern -- no array materialization needed. Verified for:
- `inbound_metrics` line 79: `JobApplication.where(id: @job_application_ids)` -> subquery. CORRECT.
- `channel_message_metrics` line 260: `where(job_applications: { id: @job_application_ids })` -> subquery through join. CORRECT.
- `comment_metrics` line 227: `where(job_applications: { job_id: @job_ids })` -> subquery. CORRECT.
- `stage_move_metrics` line 182: `where(job_application_id: @job_application_ids)` -> subquery. CORRECT.

### ChannelMessage query correctness

`channel_message_metrics` at lines 257-272:
- Join: `ChannelMessage.joins(channel: :job_application)` generates `INNER JOIN channels ON ... INNER JOIN job_applications ON ...`. CORRECT per model associations (`ChannelMessage belongs_to :channel`, `Channel belongs_to :job_application`).
- Filter: `where(job_applications: { id: @job_application_ids })` -- scoped to org_user's applications. CORRECT.
- Cutoff: `where('channel_messages.created_at > ?', @cutoff)` -- table-qualified to avoid ambiguity in join. CORRECT.
- Sent_by enum values: `sent_by_user` (1), `sent_by_organization` (3), `sent_by_candidate` (2) at `channel_message.rb:27-32`. CORRECT.
- `messages_sent_total` = `sent_by_user + sent_by_organization` (Ruby addition of two integers). Matches spec: "sum of messages_sent_by_user + messages_sent_by_organization." CORRECT. Note this excludes `sent_by_system` (0), which is correct per spec.

### Edge case: org_user with no hiring_team_memberships

If a non-admin org_user has no `HiringTeamMembership` records, `org_user.jobs` returns an empty relation. `scoped_job_ids` returns `org_user.jobs.select(:id)` (empty subquery). All downstream queries return zero counts. `extract_metrics` produces all-zero metrics. `WeeklyDigestClassifier` classifies as `:all_counts_zero`. Mailer sends the zero-bucket template. This is the intended behavior per spec (bucket 1: "every one of the 7 metrics is zero").

No issues found.
