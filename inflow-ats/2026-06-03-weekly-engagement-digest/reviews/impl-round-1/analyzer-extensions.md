# Analyzer Extensions -- Round 1

## Findings

### Plan-flagged issues verification

Both issues flagged in the plan review have been correctly addressed:

1. **Analyzer scoping gap:** `inbound_metrics` (line 78-82), `job_metrics` (line 112-116), `candidate_update_metrics` (line 195-199), and `job_application_update_metrics` (line 210-214) all correctly branch on `@organization_user_id` to scope queries. FIXED.

2. **`build_result` gap:** Line 460 adds `channel_messages: candidate_mgmt[:channel_messages]` to the `build_result` output. FIXED.

### New findings

- F1 [MED] `template_metrics` at line 139-152 still uses `@organization.channel_message_templates` without scoping for `@organization_user_id`. However, the digest does NOT consume template metrics (the job's `extract_metrics` reads only `stage_moves`, `comments`, `reviews`, `channel_messages`, `inbound`, and `jobs` from the result). The unscoped template data affects only the `scoring` and `summary` sections of the analyzer output, which the digest does not use. No production impact for digest recipients, but the scoring/summary sections will be inaccurate for non-admin org_user-scoped calls. Not a blocker because no consumer reads those values in the digest flow.

### Backward compatibility

- `ReportGenerator` at `report_generator.rb:17` calls `OrganizationAnalyzer.new(organization: @organization)`. Both new params default to `nil`. The `@cutoff` resolves to `months.months.ago` (existing behavior). `scoped_job_ids` takes the `else` branch (all org jobs). `inbound_metrics`, `job_metrics`, `candidate_update_metrics`, and `job_application_update_metrics` all take their `else` branches. No behavioral change for existing caller. VERIFIED.

- The new `channel_messages` key in `candidate_management_metrics` is additive. `ReportGenerator#build_payload` at `report_generator.rb:52-56` accesses `stage_moves`, `comments`, `reviews`, `candidate_updates`, `job_application_updates` -- it does not access `channel_messages`. VERIFIED.

### ChannelMessage query

- Join path: `ChannelMessage` -> `channel` (via `belongs_to :channel` at `channel_message.rb:9`) -> `job_application` (via `belongs_to :job_application` at `channel.rb:6`). CORRECT.
- `sent_by` enum values: `sent_by_system: 0`, `sent_by_user: 1`, `sent_by_candidate: 2`, `sent_by_organization: 3` (channel_message.rb:27-32). The query uses symbolic enum values correctly. VERIFIED.
- `messages_sent_total` sums `sent_by_user` + `sent_by_organization`, excluding `sent_by_system` and `sent_by_candidate`. Matches spec. VERIFIED.

No BLOCKER or HIGH findings.
