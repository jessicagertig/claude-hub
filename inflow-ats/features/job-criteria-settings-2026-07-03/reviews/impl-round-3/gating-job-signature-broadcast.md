# Angle 3 — Job gating change, ExtractJobCriteriaJob signature, broadcast lifecycle — Round 3

Read `job.rb:690-748` and the full `extract_job_criteria_job.rb` at HEAD.

- Gating change DECISIONS-verbatim plus the approved kwarg (flag 1): `_immediately(requesting_organization_user_id: nil)` guards description/in_progress/retrying; `_if_needed` keeps only the succeeded guard. No pending guard added (deliberate; test-documented).
- All FOUR enqueue sites verified at HEAD: `auto_extract_job_criteria` :711 (`set(wait: 30.seconds)` variant) and :713, `extract_job_criteria` :727 — all still single-positional, pending-guard + Flipper semantics untouched (not "harmonized"); only `_immediately` :738 passes the second arg.
- Flag 4 (positional, adjudicated — verified implemented as ruled): `perform(ai_job_criteria_id, requesting_organization_user_id = nil)`; old `[id]` Sidekiq payloads remain valid (default nil → helper's `OrganizationUser.find_by(id: nil)` → nil → bare return); exhaustion block reads `job.arguments.first` / `job.arguments.second` — the positional counterpart of the analog's kwargs reads.
- All THREE broadcast sites present and analog-shaped:
  1. End of `perform`, gated `if requesting_organization_user_id`; unreachable mid-retry because the `CustomErrorAiSummary` rescue re-raises before it.
  2. `retry_on` exhaustion block: broadcast only inside `if ai_job_criteria` after the failure write — nil row can never reach the helper's `reload`.
  3. `StandardError` rescue: after the failure write, gated `if ai_job_criteria && requesting_organization_user_id` (analog's dual gate).
- Helper guard ladder in analog order: OrganizationUser lookup → user → `ai_job_criteria.reload` → terminal-status guard → payload with conditional `errorMessage` → `GlobalChannel.broadcast_to(user, action: 'JOB_CRITERIA_EXTRACTION_COMPLETE', ...)`. camelCase payload keys hand-written in Ruby, matching the analog's mechanism. (`reload` noted-not-counted — conventions-pass-owned, per round directive.)
- JSON::ParserError path (failure write without re-raise, `extract_criteria.rb`) → perform continues → failed broadcast — the behavior flag 3's approval depends on; verified by the StandardError-free failed-broadcast spec (zero-criteria example writes failure inside the stubbed `extract` and the broadcast still fires from end-of-perform).
- Tests behavioral (rule 26): real `GlobalChannel.broadcast_to` expectations with payload contents, `perform_now`, DB-verified failure writes, `have_enqueued_job` for the retry path, no-broadcast assertions for nil requester (both success and failure).

## Findings

No issues found.
