# Analyzer Extensions -- Round 2

## Findings

Re-examined all analyzer changes with fresh eyes. Focused on edge cases and correctness.

### Constructor

- `since: nil` default means `@cutoff = nil || months.months.ago` which resolves to `months.months.ago`. CORRECT.
- `since: 1.week.ago` from the digest job means `@cutoff = 1.week.ago`. CORRECT.
- No type coercion issues: `since` receives a `Time` object from `1.week.ago`, and `months.months.ago` also returns a `Time` object. CORRECT.

### scoped_job_ids edge cases

- `@organization.organization_users.find_by(id: @organization_user_id)` -- scopes the lookup to the organization's own org_users, preventing cross-org data leakage. If someone passes an org_user_id from a different organization, `find_by` returns nil, and the guard returns `@organization.jobs.none.select(:id)`. CORRECT.
- `org_user.is_admin` at `organization_user.rb:55-57` returns `org_admin? || is_owner` where `is_owner` at line 51-53 returns `org_owner? || god_admin?`. This correctly identifies all admin-level roles. CORRECT.
- `org_user.jobs` goes through `has_many :jobs, through: :hiring_team_memberships` (line 15). For non-admin users with no hiring team memberships, this returns an empty relation. The digest would show all-zero metrics. CORRECT behavior.

### inbound_metrics scoping

- When `@organization_user_id` present: `JobApplication.where(id: @job_application_ids)` -- `@job_application_ids` is already scoped from `load_base_ids`. CORRECT.
- The `most_recent` fallback at line 86-87 uses `base_apps` (the scoped set), not `@organization.job_applications`. This is correct -- the fallback should show the most recent app within the user's scope. CORRECT.

### job_metrics scoping

- When `@organization_user_id` present: `Job.where(id: @job_ids)` -- uses the scoped job IDs. CORRECT.

### candidate_update_metrics and job_application_update_metrics scoping

- Both correctly branch on `@organization_user_id`. CORRECT.

### channel_message_metrics

- Uses `@job_application_ids` (already scoped) and `@cutoff`. CORRECT.
- Four separate COUNT queries hit the database. Could be optimized into a single GROUP BY query, but this is a performance concern, not a correctness concern. ACCEPTABLE.

### build_result passthrough

- Line 460: `channel_messages: candidate_mgmt[:channel_messages]`. Passes through the raw hash from `channel_message_metrics`. CORRECT.

### Backward compatibility (re-verified)

- `ReportGenerator` at `report_generator.rb:17`: `OrganizationAnalyzer.new(organization: @organization)`. Hits defaults for both new params. `scoped_job_ids` takes the `else` branch. All scoping methods take their `else` branches. No change. VERIFIED.

No new findings. No BLOCKER or HIGH.
