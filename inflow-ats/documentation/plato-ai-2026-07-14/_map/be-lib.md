# Slice map: `lib/` (tasks / backfills / helpers)

Scope: all `lib/**` changes in `production...develop`. Almost everything here is **dev/ops tooling** (rake tasks) — not called from the app UI. A few pieces are **operational (cron/Heroku Scheduler)** and one touches the **test-only routes** file. None render UI directly; QA relevance is (a) scheduled jobs that keep AI data healthy and (b) shared cron/counter surfaces that could regress non-AI behavior.

## Files & what changed

### Operational / cron (production-relevant, run on schedules — NOT user-triggered)

- **`lib/tasks/recurring_tasks.rake`** (modified):
  - `reset_counters` now ALSO calls `AiJobApplicationSummaryStatus.counter_culture_fix_counts` to fix `Job.ai_job_application_summaries_count`. SHARED counter-fix task — runs alongside existing `Job`/`ChannelMessage`/`OrganizationUser` counter fixes. Regression surface: if this counter is wrong, the per-Job AI-summary count badge/number in the UI would be off; the fix task itself is additive.
  - NEW task `retrigger_stuck_pending_criteria`: re-drives `AiJobCriteria` stuck in `status_pending` older than 10 min by `ExtractJobCriteriaJob.perform_later(existing_id)` (never creates a new record — a new one would hit the same pending poison-guard on `Job#extract_job_criteria` / `#auto_extract_job_criteria`). Scheduled via Heroku Scheduler. USER-VISIBLE effect: jobs whose criteria extraction was lost (worker restart / enqueue-before-commit race) recover automatically instead of blocking all future extraction for that job forever.

- **`lib/tasks/ai_credits.rake`** (NEW file, namespace `ai_credits:`). Mix of manual-ops and cron tasks:
  - `grant[org_id,amount,reason]` — calls `GrantAiCredits`; prints new addon balance. Manual ops (support grants).
  - `show[org_id]` — read-only dump of `OrganizationAiCreditBalance` (monthly/addon/total remaining, last reset, override) + last 10 `AiCreditBalanceTransaction`.
  - `reconcile` — rebuilds `monthly_credits_remaining`/`addon_credits_remaining` on every `OrganizationAiCreditBalance` from SUM of ledger transactions per bucket, via `update_columns` (counter_culture's Proc column_name can't auto-fix). Only writes when drift detected. Ops safety-net for credit-count drift.
  - `process_overdue_resets` — cron safety-net; calls `Organization.process_ai_credit_resets`, resets orgs with overdue billing periods.
  - `reset_daily` — cron; calls `ResetDailyAiCredits.call` per org for daily-allocation buckets.
  - `cleanup_orphaned_bulk_claims` — cron; marks `BulkAiSummaryJobApplication` rows stuck in `:processing` >24h as `:failed` (worker hard-death recovery). USER-VISIBLE: prevents bulk AI-summary claim rows from being permanently stuck, so re-runs aren't blocked.

- **`lib/tasks/housekeeping_tasks.rake`** (modified): `textract_backfill[org_limit]` gained a `dry_run` arg (`textract_backfill[5,dry]`). Dry run prints cost estimate then `next` WITHOUT enqueuing. Enqueue behavior unchanged in normal mode. Ops backfill for Textract resume processing on paid orgs.

### Test-only

- **`lib/test_routes.rb`** (modified): adds `POST organizations/create_ai_credit_subscription` → `organizations#create_ai_credit_subscription`. Only defined under `define_test_routes` (test env / Cypress seeding). NOT a production route. Enables Cypress/QA to seed an org with an AI-credit subscription.

### Dev-only benchmark / eval tooling (hardcoded local `/Users/jessica/...` paths — cannot run in prod; ignore for manual QA except as the scoring manifest source)

- `lib/tasks/AI_TASKS_README.md` (NEW) — docs.
- `lib/tasks/ai_scoring.rake`, `ai_scoring_pipeline.rake`, `ai_scoring_batch.rake`, `ai_scoring_candidate.rake`, `ai_scoring_regression.rake`, `ai_bulk_extract.rake`, `ai_comparison_benchmark.rake`, `ai_relevance_benchmark.rake` (all NEW). Offline prompt/version benchmarking; read local test-JD/HTML fixtures, write JSON results to local dirs. No DB writes to production data paths, no UI. Use only to confirm the model/prompt manifest below.

## Scoring manifest (extracted from the benchmark rake tasks — matches production prompt classes)

Prompt classes live under `AiJobApplicationAction::Scoring::Prompts::*` and `AiJobApplicationAction::Summary::Prompts::*`. Model/provider come from each class's `.model` / `.response_format` / `.messages` (rake tasks just orchestrate them).

**JD criteria extraction pipeline (Scoring):**
1. **Call 1 — `JobDescriptionStructuredData`** — provider `openai` (gpt-4.1-mini per comments). Input: `job_description_html`. Output: `title_technology` + `sections` (each typed; `type == 'criteria'` sections fed forward). Section decomposition.
2. `sleep 2` between calls.
3. **Call 2 — `JobDescriptionCriteriaExtraction`** — provider `gemini` (`gemini-2.5-flash` referenced; `.model` authoritative; content is fenced-JSON, stripped of ```json). Input: `criteria_sections`, `title_technology`. Output: `criteria[]` with `tier`/`duplicate`/`source_heading`. Post-processing in-task: reject `duplicate`; then **code-level heading tier overrides** — `source_heading` containing required/must/essential/minimum → `tier_1` (unless soft-skill), containing bonus/optional/extra credit → `tier_3`. (This override logic lives in the rake task; confirm whether production replicates it — the task is a benchmark harness, not the runtime path.)

**Candidate scoring:** `JobApplicationScoring` — provider chosen by `prompt_class.model.start_with?('gpt') ? 'openai' : 'gemini'`.

**Resume summary pipeline (Summary):** Call 1 `ResumeStructuredData` (openai); Call 2 `ResumeAssessment` (gemini `gemini-2.5-flash`); Call 3 comparison `ResumeComparison` benchmarked across `gemini-2.5-flash`, `claude-haiku-4-5-20251001`, `claude-sonnet-4-20250514`. Production model = each prompt class's `.model` (benchmark just A/B tests candidates).

Cost via `AiClient.calculate_cost(model:, input_tokens:, output_tokens:)`; client `AiClient.new(provider:)`.

## Regression callouts for QA
- `reset_counters` change is the only SHARED non-AI-scoped surface: adding a counter fix to a task that also fixes `Job`/`ChannelMessage`/`OrganizationUser` counts. Low risk (additive) but verify running it doesn't error and AI-summary counts on Job rows are correct.
- `retrigger_stuck_pending_criteria`, `ai_credits:process_overdue_resets`/`reset_daily`/`cleanup_orphaned_bulk_claims` must be registered in the actual scheduler for the self-healing behavior QA relies on — confirm they're scheduled, else stuck-pending jobs and overdue resets won't recover in prod.
