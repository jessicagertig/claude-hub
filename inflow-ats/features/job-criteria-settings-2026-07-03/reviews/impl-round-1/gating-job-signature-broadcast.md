# Angle 3 — Job gating change, ExtractJobCriteriaJob signature, WebSocket broadcast lifecycle — Round 1

## Gating change (SPEC 4.1)

`job.rb:730-748` (committed) matches DECISIONS verbatim plus the approved flag-1 kwarg:
- `extract_job_criteria_immediately(requesting_organization_user_id: nil)` gains `in_progress`/`retrying` guards; passes the kwarg positionally to `perform_later`.
- `extract_job_criteria_if_needed` keeps ONLY the `succeeded` guard; existing comment above it preserved.
- `auto_extract_job_criteria` and `extract_job_criteria` UNTOUCHED (their `status_pending?` guard + Flipper gate preserved — not harmonized, correct).
- No pending guard added (documented consequence honored).
- `zero_criteria_extraction_failure?` placed directly after `latest_succeeded_ai_job_criteria` (job.rb:696-698) per plan E.1.4.

## Flag 4 (adjudicated — verified honored, not re-litigated)

- Signature is optional positional: `def perform(ai_job_criteria_id, requesting_organization_user_id = nil)` (extract_job_criteria_job.rb:15).
- Exhaustion block reads args POSITIONALLY: `job.arguments.first` (id, :9) and `job.arguments.second` (requesting id, :12) — consistent with the signature form, the positional counterpart of the analog's `job.arguments.first[:key]` reads.
- All enqueue sites consistent: job.rb:707/:709/:723 unchanged single positional arg (binds nil); `_immediately` (job.rb:737) passes two positional args. Old `[id]` Sidekiq payloads remain valid. Backward-compat asserted by the untouched pre-existing spec examples (`perform_now(id)`) — all pass in the committed run.

## Broadcast lifecycle — three sites, diffed against `generate_ai_job_application_summary_job.rb`

1. End of `perform` (:24): `broadcast_completion(ai_job_criteria, requesting_organization_user_id) if requesting_organization_user_id` — unreachable mid-retry (`CustomErrorAiSummary` re-raised at :25-28 before it). Matches analog :34.
2. `retry_on` exhaustion (:5-13): the pre-existing safe-nav write was converted to `if ai_job_criteria` block wrapping write + `broadcast_completion(ai_job_criteria, job.arguments.second)` — mirrors the analog's `if textract_result` guard (:17-21); a nil row can never reach the helper. ActiveJob instance-execs the block so the private helper is callable — identical mechanism to the analog (:20).
3. StandardError rescue (:29-34): failure write kept, then `broadcast_completion(...) if ai_job_criteria && requesting_organization_user_id` — matches the analog's dual gate (:45). `Rails.logger.error` + `ap` logging present.

Helper (:38-62) structurally mirrors the analog's `broadcast_completion` (:50-80): OrganizationUser lookup → `user` guard → fresh record state → terminal-status guard → payload with conditional `errorMessage` → `GlobalChannel.broadcast_to(user, action:, payload:)`. Payload keys camelCase written directly in Ruby (`jobId`, `jobTitle`, `zeroCriteriaFailure`) — matches the analog's socket-path convention (`candidateFullName`); no api.ts transform on this path.

- `ai_job_criteria.reload` (:45) is SPEC §7-verbatim and gate-bound to the Phase 6.5 conventions pass (plan R-1) — noted in code-quality.md, NOT counted this round per the round directive. The reload is functionally load-bearing (ExtractCriteria writes status via `update_columns` on its own instance).
- JSON::ParserError path (extract_criteria.rb:148-151, failure write without re-raise, perform continues): reaches the perform-end broadcast with reloaded `failed` status → failed broadcast fires. Flag-3 approval premise holds.
- Auto path (nil requesting id): perform-end and rescue sites are gated on presence; exhaustion site calls the helper with nil, which exits at the `OrganizationUser.find_by(id: nil)` guard — identical to the analog's exhaustion behavior (analog also passes the value unconditionally). No auto-path broadcast is possible.

## Tests (behavioral, rule 26)

`extract_job_criteria_job_spec.rb` additions: success broadcast (asserts `GlobalChannel.broadcast_to` with action + `status: 'succeeded'` + `jobId` + `zeroCriteriaFailure: false`); zero-criteria failure (`zeroCriteriaFailure: true` + `errorMessage`); StandardError → failure write asserted on the reloaded row + failed broadcast; `CustomErrorAiSummary` → `have_enqueued_job(described_class)` + `not_to receive(:broadcast_to)`; no-requesting-user (single positional arg) → no broadcast on success or failure. `ExtractCriteria` stub uses the exact production kwargs (`.with(ai_job_criteria_id: ...)` — no type-mismatch masking, pipeline rule 7). All pass on committed code. Existing examples untouched (append-only diff).

`job_criteria_lifecycle_spec.rb` gating additions all present per SPEC 12 — see test-coverage.md.

## Findings

No issues found. (The exhaustion-block broadcast site has no direct test — this matches the SPEC §12/plan E.2.6 test plan exactly; recorded as a LOW residual gap in test-coverage.md, not here.)
