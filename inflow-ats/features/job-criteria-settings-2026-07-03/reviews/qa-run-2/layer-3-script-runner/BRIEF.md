# Layer 3 Script-Runner — Shared Agent Brief (qa-run-2)

You verify the **job-criteria-settings** feature's BUSINESS LOGIC AT RUNTIME by seeding data and running temporary Ruby scripts against a live `RAILS_ENV=test` server. Layer 2 (static code review) already passed; you catch what only shows up when the code actually runs against a real DB.

## Environment (already set up — do NOT start/stop the server)

- Live test server: `http://app.lvh.me:5007` (worktree `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`, branch `job-criteria-settings-qa`, RAILS_ENV=test, DB `inflow_test`). Sidekiq is running.
- **Script runner:** `test_frr` = alias `RAILS_ENV=test foreman run rails runner`. It only works from the worktree dir. Run scripts like this (write scripts to `/tmp` ONLY):
  ```
  cd /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings && source ~/.nvm/nvm.sh 2>/dev/null; RAILS_ENV=test foreman run rails runner /tmp/your-script.rb
  ```
  (Each invocation boots Rails (~20s) and prints deprecation/nokogumbo noise on stderr — ignore that; look at your own puts output.)
- **Data seeding:** use the harness (auto-cleans first, which WIPES the DB incl. the Flipper flags — the plans re-enable them):
  ```
  qa-harness seed --plan reviews/seed-plans/<plan>.json --config ~/claude-hub/inflow-ats/qa-config.yml
  ```
  (run from the working dir `/Users/jessica/claude-hub/inflow-ats/features/job-criteria-settings-2026-07-03/`). To reset between scenarios: `qa-harness cleanup --config ~/claude-hub/inflow-ats/qa-config.yml` (then re-seed).
- Seed plans in `reviews/seed-plans/`: `ai-org-published-job.json` (workhorse: paid org, AI flag on, 1 published "Senior Engineer" job, 0 criteria rows = never-extracted), `ai-org-unpublished-job.json` (draft job), `ai-org-member-on-hiring-team.json` (adds non-admin Taylor Brooks on the hiring team), `ai-disabled-org.json` (AI_APPLICANT_SUMMARY NOT enabled), `ai-org-with-candidates.json` (adds 3 candidates).
- Default user: `rezu.may@wrkhq.com` (admin of Acme Inc.).

## HARD RULES

- Scripts go in `/tmp` ONLY. Never write into the source repo or worktree.
- **Never** modify `.env`, never set `DATABASE_URL`, never run `psql`, never run `db:drop/reset/setup/schema:load`. DB access ONLY via `test_frr` (rails runner), the running app (curl to :5007), or the seed endpoints. You are on the test DB — keep it that way.
- Do NOT start or stop the server or sidekiq.
- **Do NOT trigger real paid OpenAI extraction.** The success path of `POST /jobs/:id/ai_job_criteria` and `ExtractJobCriteriaJob#perform` (via the real `ExtractCriteria` service) call OpenAI and cost money + are non-deterministic. To exercise those, either (a) build the `AiJobCriteria` row directly in the target state via `test_frr`, or (b) STUB the extraction inside your rails-runner script (e.g., redefine `AiJobApplicationAction::Scoring::ExtractCriteria` behavior, or use `ExtractJobCriteriaJob.perform_now` only with the extraction stubbed to a canned result or to raise). It is fine to test POST's GUARD/ERROR paths (blank description → 422, flipper off → 422, in-flight latest → 200 no-op) because those return BEFORE enqueuing. Do not rely on Sidekiq actually completing a real extraction.
- Building `AiJobCriteria` rows directly in a verification script (e.g. `AiJobCriteria.create!(job:, status:, criteria:, error_message:)`) is allowed for QA setup (rails-runner path). This is test setup, not app code — the "no find_or_create_by / manual read-build-save" conventions are for production code, not your scripts.

## Key domain facts (from SPEC.md — read it for full intent: working dir SPEC.md)

- `AiJobCriteria` (table `ai_job_criteria`, belongs_to :job) has enum status `%w[pending in_progress succeeded failed retrying]` (`_prefix: true`, so predicates are `status_succeeded?` etc.), a JSONB `criteria` array, and `error_message`. `ZERO_CRITERIA_ERROR_MESSAGES` (defined in `ai_job_criteria.rb`) = three exact strings incl. `'Criteria array is empty'`. `AiJobCriteria#zero_criteria_failure?` = `status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)`.
- `Job#latest_ai_job_criteria` = `ai_job_criteria.order(created_at: :desc).first`; `Job#latest_succeeded_ai_job_criteria` = latest with status succeeded; `Job#zero_criteria_extraction_failure?` = `latest_ai_job_criteria&.zero_criteria_failure?`.
- `Job#extract_job_criteria_immediately(requesting_organization_user_id: nil)` creates a NEW pending `AiJobCriteria` row and enqueues `ExtractJobCriteriaJob.perform_later(row.id, requesting_organization_user_id)` — but is a NO-OP (creates no row) when the latest row is `in_progress` or `retrying`.
- `ExtractJobCriteriaJob.perform(ai_job_criteria_id, requesting_organization_user_id = nil)` — optional positional 2nd arg. `retry_on CustomErrorAiSummary, attempts: 3`; on exhaustion it sets the row `failed` and broadcasts. `broadcast_completion` does a FRESH `AiJobCriteria.find_by(id:)` read, gates on succeeded||failed, broadcasts a `JOB_CRITERIA_EXTRACTION_COMPLETE` GlobalChannel payload (`status,jobId,jobTitle,zeroCriteriaFailure,errorMessage?`) — on BOTH success and failure — but ONLY when `requesting_organization_user_id` is present (auto path = nil → no broadcast).
- Review guards: `ValidateAiSummaryGeneration` (manual) and `ValidateAutoAiSummaryGeneration` (auto) `context.fail!` a candidate review when `job.zero_criteria_extraction_failure?`, with a user-facing message. `QueueBulkAiSummaryJobs` fail-fasts on the same condition (reads optional `context.job&.`). `BulkGenerateAiSummariesJob#each_iteration` sets the claim row `:failed` (not stuck `:processing`) when validation fails.
- `TextractResult` funnel: returns early (skips `extract_job_criteria_if_needed`) when `job_application.job.zero_criteria_extraction_failure?`.
- Controller `Api::V1::AiJobCriteriaController`: `GET /jobs/:job_id/ai_job_criteria` (authorize `show?` = hiring-team/admin; UNGATED by Flipper — returns null payload for AI-disabled orgs) and `POST` (authorize `update_ai_settings?` = org-wide `can_use_ai_credits?`; Flipper `AI_APPLICANT_SUMMARY` gate; blank description → 422; in-flight latest → 200 no-op). Serializer `JobAiJobCriteriaSerializer` exposes `criteria, extracted_at, status, zero_criteria_failure`.

## ADJUDICATED (matching behavior is NOT a finding)
The GET(hiring-team)/POST(org-wide can_use_ai_credits?) authorization asymmetry is spec-directed (SPEC §9) and analog-consistent — a non-hiring-team org member with `hiring_team_ai_credits_control_enabled` CAN POST-regenerate a job they cannot GET. Confirm it behaves that way; do NOT flag it as HIGH (it is a collected MED).

## Pre-existing known failures — exclude from findings
9 `on_complete` examples in `bulk_generate_ai_summaries_job_spec.rb` are broken at the develop base. Not a feature defect.

## Severity
BLOCKER (feature broken at runtime) / HIGH (wrong behavior, lost data, wrong result, missing guard firing in a real workflow, security/authorization gap, data-integrity defect) / MED (do-not-fix: pre-existing, spec-compliant-though-imperfect, analog-consistent, edge-case-with-tradeoffs, out-of-scope, needs product decision, perf-only) / LOW (nitpick). Spec-implementation mismatch is NEVER MED — that is HIGH. Only HIGH+ affects convergence.

## Your workflow
1. `qa-harness seed --plan <plan> --config ...` (picks/creates your data).
2. Write `test_frr` scripts to `/tmp` that build objects, call the feature's methods/services, and ASSERT return values / DB state / payloads / guard behavior. Print clear PASS/FAIL lines.
3. Run them from the worktree (command above). Use `curl` to :5007 for HTTP-level checks.
4. Between scenarios, `qa-harness cleanup` then re-seed.
5. Review any prior-round findings (given in your dispatch) and validate/invalidate each.

## Output
Write EXACTLY one file: `reviews/qa-run-2/layer-3-script-runner/round-{N}/agent-{M}.json` under the working dir, using this shape:
```json
{
  "layer": "script-runner",
  "round": 1,
  "agent_index": 1,
  "focus": "...",
  "scenarios_run": ["seed plan(s) used + what was exercised"],
  "findings": [
    {"id":"l3-a{M}-001","severity":"HIGH","title":"...","evidence":"script output / DB state proving it","file":"app/...","recommendation":"..."}
  ],
  "verifications_passed": ["short bullet list of what you confirmed WORKS at runtime — this is the main value; be specific"]
}
```
Empty `findings` = your assigned logic works. Your final chat message: one-paragraph summary + severity counts + the 2-4 most important things you verified.
