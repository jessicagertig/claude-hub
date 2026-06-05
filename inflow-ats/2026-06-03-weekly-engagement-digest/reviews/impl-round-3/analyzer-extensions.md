# Analyzer Extensions -- Round 3

## Findings

### Constructor backward compatibility

`ReportGenerator` at `report_generator.rb:17` calls `OrganizationAnalyzer.new(organization: @organization)`. The new constructor signature `def initialize(organization:, months: 6, organization_user_id: nil, since: nil)` defaults both new params to `nil`. When `organization_user_id` is `nil`, `scoped_job_ids` takes the `else` branch at line 64-65, returning `@organization.jobs.select(:id)` -- identical to the original `load_base_ids`. When `since` is `nil`, `@cutoff = since || months.months.ago` resolves to `months.months.ago` -- identical to original. VERIFIED backward compatible.

### load_base_ids branching

`scoped_job_ids` at line 54-67:
- `nil` org_user_id -> org-wide jobs. CORRECT.
- Nonexistent org_user_id -> `@organization.organization_users.find_by(id:)` returns `nil` -> `@organization.jobs.none.select(:id)`. CORRECT (graceful degradation to zero results).
- Admin org_user (`is_admin` at `organization_user.rb:55-57` = `org_admin? || is_owner`) -> org-wide jobs. CORRECT.
- Non-admin org_user -> `org_user.jobs` via `has_many :jobs, through: :hiring_team_memberships` at `organization_user.rb:15`. CORRECT.

`@candidate_ids` and `@job_application_ids` at lines 50-51 are derived from `@job_ids`, correctly propagating the scoping. VERIFIED.

### ChannelMessage query

`channel_message_metrics` at lines 257-272:
- Joins `channel: :job_application` -- `ChannelMessage belongs_to :channel` at `channel_message.rb:9`, `Channel belongs_to :job_application` at `channel.rb:6`. Join path is valid.
- Filters by `job_applications: { id: @job_application_ids }` -- correctly scoped to the org_user's job applications.
- Filters by `channel_messages.created_at > @cutoff` -- correctly uses the generalized cutoff.
- `sent_by: :sent_by_user` / `:sent_by_organization` / `:sent_by_candidate` -- match `ChannelMessage` enum values at `channel_message.rb:27-32`. CORRECT.
- `messages_sent_total` = `sent_by_user + sent_by_organization`. CORRECT per spec ("everything not sent_by_candidate" that is also not `sent_by_system`; spec explicitly says "sum of messages_sent_by_user + messages_sent_by_organization").

### build_result integration

`candidate_management_metrics` at line 176 includes `channel_messages: channel_message_metrics`. `build_result` at line 460 propagates `channel_messages: candidate_mgmt[:channel_messages]`. The job's `extract_metrics` at line 48 reads `candidate_mgmt[:channel_messages]`. Full chain verified.

### template_metrics scoping

`template_metrics` at line 139-152 still uses `@organization.channel_message_templates` (not scoped by org_user). This was noted in Round 1 as MED. The digest does not consume template metrics -- the job's `extract_metrics` only reads `inbound`, `setup_activity.jobs.published`, `candidate_management.stage_moves/comments/reviews/channel_messages`. No production impact. Not a new finding.

No issues found.
