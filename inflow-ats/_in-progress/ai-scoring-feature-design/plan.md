# AI Scoring Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary

Integrate candidate-criteria scoring into the existing AI summary pipeline. When a job is published, extract grading criteria from its description via a 2-call AI pipeline. When each candidate's resume is processed, score it against those criteria, then generate an integrated role analysis combining summary insights with scoring evidence. The scoring pipeline runs as part of the unified `AiJobApplicationSummary` lifecycle — extended from a 4-call summary pipeline to a 4+4 evaluation pipeline (4 summary calls + 2 scoring calls + 1 display call + 1 integration call). Frontend changes are out of scope. Four existing scoring prompt files are **FROZEN — do not modify**.

## Open PRs — Conflict Check

Checked via `gh pr list --state open --limit 20`. No open PR touches AI summary models, services, serializers, or the Job model's callback chain. The `messaging-improvements` branch (#3035) touches messaging controllers/serializers only — no overlap.

---

## Pattern Precedents

### P1. `AiJobApplicationAction::Summary::Generate` — Direct Analog for `ExtractCriteria`

**File:** `app/services/ai_job_application_action/summary/generate.rb` (315 lines)

The structural template for building `ExtractCriteria`. Key patterns to replicate:
- **Constructor:** `def initialize(textract_result_id:)` — takes an ID, loads with `find_by` (line 7)
- **Main method:** `def generate` — single public method with descriptive name (per `cursor_rules/backend/services.md` Rule 2)
- **Status transitions:** uses `update_columns` for intermediate transitions and `update` with return-value check for data writes (lines 32, 68, 102, 128, 168) — `update_columns` bypasses callbacks/validations, `update` triggers them
- **AiApiRequest creation:** private `create_ai_api_request` method called after each AI call (lines 296-312)
- **Error handling:** three-tier rescue: `CustomErrorAiSummary` (re-raise for retry), `JSON::ParserError` (fail, no re-raise), `StandardError` (fail, no re-raise) (lines 171-184)
- **Guard clauses:** bare `return` without truthy/falsy values (lines 16-17, 24)
- **Logging:** `ap` debug logs throughout (lines 12-14, 23)

### P2. `TextractResult#queue_ai_summary_job` — Callback-Triggers-Job Pattern

**File:** `app/models/textract_result.rb` (lines 95-125)

The pattern for `AiJobCriteria`'s `after_commit` callback that resumes waiting summaries:
- `after_commit` on update, with guard conditions (`textract_job_result_text.present?`, `saved_change_to_textract_job_result_text?`)
- Finds waiting records, enqueues jobs for each

### P3. `Job#handle_status_changed_to_published` — Publish Callback Pattern

**File:** `app/models/job.rb` (lines 542-557)

The pattern for adding `extract_job_criteria` to the publish lifecycle:
- Called from `handle_status_change` (line 522) inside `handle_before_update` (line 478)
- Uses `touch`, `update_column`, `perform_later` — one-liner calls per side effect
- All jobs enqueued in `handle_before_update` run inside the transaction — Sidekiq pushes to Redis before commit. The existing pattern accepts this and guards in the job with `find_by`

### P4. `GetResumeTextFromTextractJob` — Job with Retry + Exhaustion Pattern

**File:** `app/jobs/get_resume_text_from_textract_job.rb` (32 lines)

The pattern for `ExtractJobCriteriaJob`:
- `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` with exhaustion block
- `find_by` guard in the job
- Delegates to a service

### P5. `BulkGenerateAiSummariesJob` — Status Enum References in Jobs

**File:** `app/jobs/bulk_generate_ai_summaries_job.rb` (line 50, 89)

Shows how status enum symbols are used in `where` clauses: `status: %i[succeeded failed]`, `status: :succeeded`. These must all be updated when the enum values change.

### P6. `Api::V1::AiJobApplicationSummarySerializer` / `ShallowSerializer` — Serializer Pattern

**Files:** `app/serializers/api/v1/ai_job_application_summary_serializer.rb`, `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb`

Per `cursor_rules/backend/serializers.md` Rule 1: just list attributes, no method definitions for regular columns. The shallow serializer omits heavy columns (`structured_data`).

### P7. `Api::V1::JobApplicationSerializer` — has_one Association Serializer

**File:** `app/serializers/api/v1/job_application_serializer.rb` (lines 40-44)

Pattern for adding `has_one :ai_job_application_summary_status`:
- `has_one :ai_job_application_summary, serializer: Api::V1::AiJobApplicationSummaryShallowSerializer`
- Custom method: `def ai_job_application_summary; object.latest_ai_job_application_summary; end`

---

## Files to Create or Modify

### New Files (12)

| # | File | Purpose |
|---|------|---------|
| 1 | `db/migrate/TIMESTAMP_create_ai_job_criteria.rb` | Migration for `ai_job_criteria` table |
| 2 | `db/migrate/TIMESTAMP_create_ai_job_application_summary_statuses.rb` | Migration for `ai_job_application_summary_statuses` table |
| 3 | `app/models/ai_job_criteria.rb` | Model with status enum, `after_commit` callback |
| 4 | `app/models/ai_job_application_summary_status.rb` | Lightweight read model |
| 5 | `app/services/ai_job_application_action/scoring/extract_criteria.rb` | Per-job criteria extraction (2 AI calls) |
| 6 | `app/services/ai_job_application_action/scoring/score_job_application.rb` | Per-application scoring (2 AI calls) |
| 7 | `app/services/ai_job_application_action/scoring/calculate.rb` | Weighted score computation |
| 8 | `app/services/ai_job_application_action/scoring/integrate_analysis.rb` | Integrated role analysis (1 AI call) |
| 9 | `app/services/ai_job_application_action/orchestrate.rb` | Pipeline orchestrator |
| 10 | `app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb` | New prompt (only prompt requiring development) |
| 11 | `app/jobs/extract_job_criteria_job.rb` | Background job for criteria extraction |
| 12 | `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` | Serializer for status read model |

### Modified Files (16)

| # | File | What Changes |
|---|------|-------------|
| 1 | `db/migrate/20260311120000_create_ai_job_application_summaries.rb` | Add `score_percentage`, `criteria_results`, `integrated_role_analysis` columns (rollback and edit in place) |
| 2 | `app/models/ai_job_application_summary.rb` | Redesigned status enum (10 values), new associations, `after_commit` updates |
| 3 | `app/models/job.rb` | `has_one :ai_job_criteria`, `extract_job_criteria`, `handle_description_change`, `description_meaningfully_changed?` |
| 4 | `app/models/job_application.rb` | `has_one :ai_job_application_summary_status` |
| 5 | `app/models/textract_result.rb` | Replace `generate_ai_summary` call with orchestrator |
| 6 | `app/services/ai_job_application_action/summary/generate.rb` | Status enum updates (`in_progress` → `extracting`, remove `succeeded` assignment) |
| 7 | `app/serializers/api/v1/ai_job_application_summary_serializer.rb` | Add `score_percentage`, `criteria_results`, `integrated_role_analysis` |
| 8 | `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb` | Add `score_percentage` |
| 9 | `app/serializers/api/v1/shallow_job_application_serializer.rb` | Add `has_one :ai_job_application_summary_status` |
| 10 | `app/controllers/api/v1/job_applications_controller.rb` | Add eager loading for `ai_job_application_summary_status` |
| 11 | `app/jobs/generate_ai_job_application_summary_job.rb` | Update status enum references in broadcast + exhaustion |
| 12 | `app/jobs/bulk_generate_ai_summaries_job.rb` | Update status enum references |
| 13 | `app/interactors/create_ai_summary_generation.rb` | Update status enum references |
| 14 | `app/interactors/validate_ai_summary_generation.rb` | No code change needed (references `textract_job_status_failed?` on TextractResult, not AiJobApplicationSummary status) — but verify during implementation |
| 15 | `app/models/textract_result.rb` (callback) | Update `queue_ai_summary_job` status references |
| 16 | `app/jobs/get_resume_text_from_textract_job.rb` | Verify `textract_processing` status reference still works (enum value unchanged) |

### Spec Files (New + Modified)

| # | File | Status |
|---|------|--------|
| 1 | `spec/models/ai_job_criteria_spec.rb` | New |
| 2 | `spec/models/ai_job_application_summary_status_spec.rb` | New |
| 3 | `spec/models/ai_job_application_summary_spec.rb` | Modified — status enum update, new callback tests |
| 4 | `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb` | New |
| 5 | `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` | New |
| 6 | `spec/services/ai_job_application_action/scoring/calculate_spec.rb` | New |
| 7 | `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb` | New |
| 8 | `spec/services/ai_job_application_action/orchestrate_spec.rb` | New |
| 9 | `spec/jobs/extract_job_criteria_job_spec.rb` | New |
| 10 | `spec/models/job_spec.rb` or `spec/models/job_criteria_lifecycle_spec.rb` | New/Modified — `extract_job_criteria`, `handle_description_change`, `description_meaningfully_changed?` |
| 11 | `spec/jobs/generate_ai_job_application_summary_job_spec.rb` | Modified — enum reference updates |
| 12 | `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` | Modified — enum reference updates |
| 13 | `spec/serializers/ai_job_application_summary_serializer_spec.rb` | New — new attributes |
| 14 | `spec/support/ai_credits_test_helpers.rb` | Modified — update `status: :succeeded` references |

---

## Implementation Tasks

### Phase A: Database Schema

**Cursor rules to read:** `cursor_rules/backend/migrations.md`, `cursor_rules/core_critical_rules.md`

#### A.1 Rollback and edit the existing `ai_job_application_summaries` migration

- [ ] A.1.1 Run `bundle exec rails db:migrate:status` to identify all migrations after `20260311120000_create_ai_job_application_summaries`
- [ ] A.1.2 Count the migrations after it. Roll back exactly that many steps: `bundle exec rails db:rollback STEP=N`
  - If any migration in the chain is irreversible, make it reversible first (add a `down` method)
- [ ] A.1.3 Edit `db/migrate/20260311120000_create_ai_job_application_summaries.rb` in place. Add three columns inside the `create_table` block:
  ```ruby
  t.decimal :score_percentage
  t.jsonb :criteria_results
  t.text :integrated_role_analysis
  ```
  These are all nullable with no default — matching the spec.
- [ ] A.1.4 Re-run `bundle exec rails db:migrate` to bring all migrations forward
- [ ] A.1.5 Verify the schema loaded correctly with `bundle exec rails db:migrate:status` (all migrations `up`)

#### A.2 Create `ai_job_criteria` migration

- [ ] A.2.1 Generate migration `create_ai_job_criteria` with timestamp after all existing migrations
- [ ] A.2.2 Migration content:
  ```ruby
  class CreateAiJobCriteria < ActiveRecord::Migration[6.1]
    def change
      create_table :ai_job_criteria do |t|
        t.references :job, null: false, foreign_key: true
        t.integer :status, null: false, default: 0
        t.jsonb :criteria
        t.jsonb :metadata
        t.text :error_message
        t.timestamps
      end

      add_index :ai_job_criteria, :job_id, unique: true
    end
  end
  ```
  Note: `t.references :job` adds a non-unique index by default. The `add_index` with `unique: true` replaces the default or adds a unique constraint. Since `t.references` adds `index: true` by default, use `t.references :job, null: false, foreign_key: true, index: false` and then `add_index :ai_job_criteria, :job_id, unique: true` to avoid a duplicate index.
- [ ] A.2.3 Run `bundle exec rails db:migrate`

#### A.3 Create `ai_job_application_summary_statuses` migration

- [ ] A.3.1 Generate migration `create_ai_job_application_summary_statuses`
- [ ] A.3.2 Migration content:
  ```ruby
  class CreateAiJobApplicationSummaryStatuses < ActiveRecord::Migration[6.1]
    def change
      create_table :ai_job_application_summary_statuses do |t|
        t.references :job_application, null: false, foreign_key: true, index: false
        t.references :ai_job_application_summary, foreign_key: true
        t.boolean :regenerating, null: false, default: false
        t.timestamps
      end

      add_index :ai_job_application_summary_statuses, :job_application_id, unique: true,
                name: 'idx_ai_summary_statuses_on_job_application_id'
    end
  end
  ```
- [ ] A.3.3 Run `bundle exec rails db:migrate`

---

### Phase B: Models

**Cursor rules to read:** `cursor_rules/backend/_base.md`, `cursor_rules/core_critical_rules.md`

#### B.1 `AiJobCriteria` model

**File:** `app/models/ai_job_criteria.rb` (new)

**Pattern precedent:** `AiJobApplicationSummary` (lines 3-46) — same enum/callback structure.

- [ ] B.1.1 Create the model file with:
  - `belongs_to :job`
  - `has_many :ai_api_requests, as: :requestable` (polymorphic — zero changes to `ai_api_requests` table per investigation P1)
  - Status enum with `_prefix: true`: `pending: 0`, `in_progress: 1`, `succeeded: 2`, `failed: 3`
  - `validates :status, presence: true`

- [ ] B.1.2 Add `after_commit` callback: `after_commit :resume_waiting_summaries, on: [:update]`
  - Guard: `return unless saved_change_to_status? && status_succeeded?`
  - Find all `AiJobApplicationSummary` records for this job with status `awaiting_job_criteria`:
    ```ruby
    job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each do |ai_job_application_summary|
      GenerateAiJobApplicationSummaryJob.perform_later(
        textract_result_id: ai_job_application_summary.textract_result_id
      )
    end
    ```
  - The `find_each` handles the case where multiple applications are waiting on the same criteria (per spec Section 1 and review angle `concurrency-and-race-conditions`)
  - Uses `update` (not `update_columns`) for `succeeded` transitions in `ExtractCriteria` to ensure this callback fires (per spec Section 4)
  - **CRITICAL:** The callback must use `saved_change_to_status?` (not `status_changed?`) because `after_commit` fires after the transaction — `changed?` and `status_changed?` are reset after save. `saved_change_to_status?` retains the change info. Pattern from `AiJobApplicationSummary#destroy_previous_textract_results` (line 40).

- [ ] B.1.3 Access path for waiting summaries: `job.ai_job_application_summaries` requires the `has_many :ai_job_application_summaries, through: :job_applications` on Job (already exists at `app/models/job.rb:51`). Verify this works for the query.

#### B.2 `AiJobApplicationSummaryStatus` model

**File:** `app/models/ai_job_application_summary_status.rb` (new)

- [ ] B.2.1 Create the model file with:
  - `belongs_to :job_application`
  - `belongs_to :ai_job_application_summary, optional: true`
  - `validates :job_application_id, uniqueness: true`

#### B.3 Update `AiJobApplicationSummary` model

**File:** `app/models/ai_job_application_summary.rb`

- [ ] B.3.1 Replace the status enum with the redesigned 10-value enum:
  ```ruby
  enum status: {
    pending: 0,
    textract_processing: 1,
    extracting: 2,
    summarizing: 3,
    awaiting_job_criteria: 4,
    scoring: 5,
    integrating: 6,
    succeeded: 7,
    retrying: 8,
    failed: 9
  }, _prefix: true
  ```
  **CRITICAL:** This changes the integer values. `succeeded` moves from `2` to `7`, `failed` from `3` to `9`, `textract_processing` from `6` to `1`, `retrying` from `7` to `8`. Since the feature is not in production/staging, no data migration is needed — existing dev data will be invalid but that's acceptable per spec Section 3.

  **Removed values:** `in_progress` (was `1`, replaced by `extracting`), `extracted` (was `4`, absorbed into `summarizing` flow). **New values:** `extracting`, `summarizing`, `awaiting_job_criteria`, `scoring`, `integrating`.

- [ ] B.3.2 Add `has_one :ai_job_application_summary_status`

- [ ] B.3.3 The existing `destroy_previous_textract_results` callback (lines 38-45) uses `status_succeeded?` — this continues to work because `succeeded` is still in the enum, just at value `7`. The semantic meaning also holds: `succeeded` means "full pipeline complete" which is when old textract results should be cleaned up. No change needed.

#### B.4 Update `Job` model associations

**File:** `app/models/job.rb`

- [ ] B.4.1 Add `has_one :ai_job_criteria` to the associations section (near line 51, after `has_many :ai_job_application_summaries`)

#### B.5 Update `JobApplication` model

**File:** `app/models/job_application.rb`

- [ ] B.5.1 Add `has_one :ai_job_application_summary_status` to the associations section (near line 30, after the `latest_ai_job_application_summary` association)

---

### Phase C: Status Enum Ripple — EXHAUSTIVE AUDIT

**Cursor rules to read:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/_base.md`

**CRITICAL per spec Section 3 ("Every Reference to `status_succeeded?`") and pipeline failure pattern #6 (rename cascades).** Every file that references any `AiJobApplicationSummary` status enum value must be found and updated. This is the most error-prone phase — a missed reference means credits consumed at the wrong time, broadcasts firing too early, or logic blocked until scoring completes.

**Before starting:** Run `grep -rn` across the entire codebase for all status enum references:
```bash
grep -rn "status_succeeded\|status_failed\|status_in_progress\|status_pending\|status_extracted\|status_textract_processing\|status_retrying\|status: :succeeded\|status: :failed\|status: :in_progress\|status: :pending\|status: :extracted\|status: :textract_processing\|status: :retrying" --include="*.rb" app/ spec/
```

- [ ] C.1 **`app/services/ai_job_application_action/summary/generate.rb`** — the most critical update

  - [ ] C.1.1 Line 31: `status_in_progress?` → `status_extracting?`
  - [ ] C.1.2 Line 31: `status_textract_processing?` — **unchanged** (value stays at position 1 in the new enum, but was at position 6 in old. The symbol name is the same so `status_textract_processing?` still works.)
  - [ ] C.1.3 Line 31: `status_retrying?` — **unchanged** (symbol name same)
  - [ ] C.1.4 Line 32: `update_columns(status: :in_progress) unless existing_ai_summary.status_in_progress?` → `update_columns(status: :extracting) unless existing_ai_summary.status_extracting?`
  - [ ] C.1.5 Line 38: `status: :in_progress` → `status: :extracting`
  - [ ] C.1.6 Line 65: `status: :extracted` → `status: :summarizing`
    - **Rationale:** after Call 1 (extraction), the old code set `extracted`. In the new pipeline, after Call 1 completes and before Calls 2-4 run, the status should be `summarizing` (the pipeline is in the summarizing phase). This is the boundary between "extraction" and "summarizing". The spec says `Summary::Generate` sets `summarizing` before running Calls 2-4.
    - **Alternative approach:** Set `extracting` during Call 1, then set `summarizing` after Call 1 completes (just before Call 2). This is cleaner because `extracting` means "Call 1 running" and `summarizing` means "Calls 2-4 running". Implement: after the extraction `update` at line 68, the status is already `summarizing` (from the update_params change). No separate transition needed.
  - [ ] C.1.7 Lines 162-163: `status: :succeeded` → **REMOVE the `status:` key from this hash entirely**. The final status assignment in `Summary::Generate` must NOT set `succeeded` or any terminal status. After Call 4, `Summary::Generate` stores the data but leaves the status at `summarizing`. The orchestrator reads the populated fields and advances the status.
    - **Implementation:** The `succeeded_update_params` hash at line 162 becomes:
      ```ruby
      final_update_params = {
        headline: summary_data['headline'],
        summary_text: summary_data['summary'],
        structured_data: final_structured
      }
      ```
    - Rename the variable from `succeeded_update_params` to `final_update_params` to avoid confusion.
  - [ ] C.1.8 Line 174: `status: :retrying` — **unchanged** (symbol name same)
  - [ ] C.1.9 Lines 179, 183: `status: :failed` — **unchanged** (symbol name same). However, the integer value changed from `3` to `9`. Since we're using symbols (`:failed`), Rails handles the mapping. Verify the `update_columns` uses the symbol, not a raw integer.

- [ ] C.2 **`app/models/textract_result.rb`**

  - [ ] C.2.1 Line 79: `status_succeeded?` — **unchanged**. This gates credit consumption. In the new pipeline, `succeeded` means "full evaluation complete" — exactly what we want for credit consumption. No change needed. Verify this is correct per spec Section 8.
  - [ ] C.2.2 Line 103: `status: :textract_processing` — **unchanged** (symbol name same).

- [ ] C.3 **`app/jobs/generate_ai_job_application_summary_job.rb`**

  - [ ] C.3.1 Line 19 (retry exhaustion): `status: :failed` — **unchanged** (symbol name same).
  - [ ] C.3.2 Line 44 (StandardError rescue): `status: :failed` — **unchanged**.
  - [ ] C.3.3 Line 61 (broadcast): `status_succeeded?` — **unchanged**. The broadcast should fire after the full pipeline completes. `status_succeeded?` now means full evaluation, which is correct.

- [ ] C.4 **`app/jobs/bulk_generate_ai_summaries_job.rb`**

  - [ ] C.4.1 Line 50: `status: %i[succeeded failed]` — **unchanged** (symbol names same). Guards against re-processing already-completed summaries.
  - [ ] C.4.2 Line 89: `status: :succeeded` — **unchanged**. Counts successful summaries for the completion broadcast.

- [ ] C.5 **`app/interactors/create_ai_summary_generation.rb`**

  - [ ] C.5.1 Line 31: `where.not(status: :failed)` — **unchanged** (symbol name same).
  - [ ] C.5.2 Line 49: `status: :textract_processing` — **unchanged**.
  - [ ] C.5.3 Line 60: `status: :pending` — **unchanged**.

- [ ] C.6 **`app/jobs/get_resume_text_from_textract_job.rb`**

  - [ ] C.6.1 Line 14-15: `status: :textract_processing` — **unchanged**.

- [ ] C.7 **`app/services/submit_resume_to_textract.rb`**

  - [ ] C.7.1 Line 18: `status: :textract_processing` — **unchanged**.
  - [ ] C.7.2 Line 25: `status: :textract_processing` — **unchanged**.

- [ ] C.8 **Spec files** — Update all status enum references:

  - [ ] C.8.1 `spec/models/ai_job_application_summary_spec.rb`:
    - Line 8-16: Update the enum assertion from 6 values to 10 values with new integer mappings
    - Line 36: `status: :succeeded` — valid, but integer value changed. Since specs use symbols, this should work. However, verify the test still passes after the enum change.

  - [ ] C.8.2 `spec/jobs/generate_ai_job_application_summary_job_spec.rb`:
    - Line 64: `status: :succeeded` — unchanged (symbol)
    - Line 74: `status: :succeeded` in a `where` — unchanged
    - Line 137: `status: :succeeded` — unchanged
    - Line 172: `status: :succeeded` — unchanged

  - [ ] C.8.3 `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`:
    - Lines 61, 138, 163: `status: :succeeded` — unchanged

  - [ ] C.8.4 `spec/support/ai_credits_test_helpers.rb`:
    - Line 138: `status: :succeeded` — unchanged

  - [ ] C.8.5 Run the full `grep` again after all changes to confirm zero stale references to removed enum values (`in_progress`, `extracted`). The old values `in_progress` and `extracted` no longer exist in the enum — any reference to them will cause a runtime error.

---

### Phase D: Services — Scoring Pipeline

**Cursor rules to read:** `cursor_rules/backend/services.md`, `cursor_rules/backend/_base.md`, `cursor_rules/core_critical_rules.md`

#### D.1 `AiJobApplicationAction::Scoring::ExtractCriteria`

**File:** `app/services/ai_job_application_action/scoring/extract_criteria.rb` (new)

**Structural template:** `AiJobApplicationAction::Summary::Generate` (P1)

- [ ] D.1.1 Constructor: `def initialize(ai_job_criteria_id:)`
  - Load `AiJobCriteria.find_by(id: ai_job_criteria_id)` (per `cursor_rules/backend/services.md` Rule 3 + Rule 6)
  - Store as `@ai_job_criteria`

- [ ] D.1.2 Main method: `def extract` (single descriptive public method per `cursor_rules/backend/services.md` Rule 2)
  - Guard: `return unless @ai_job_criteria`
  - Load `@job = @ai_job_criteria.job`
  - Guard: `return unless @job`
  - Load `@organization = @job.organization`
  - Guard: `return unless @organization`
  - Transition status: `@ai_job_criteria.update_columns(status: :in_progress)` unless already `status_in_progress?`

- [ ] D.1.3 Call 1 — Job Description Structured Data (gpt-4.1-mini):
  - Get `job_description_html = @job.description`
  - Guard: `return` if description blank (set failed status with error message)
  - Build messages: `AiJobApplicationAction::Scoring::Prompts::JobDescriptionStructuredData.messages(job_description_html: job_description_html)`
  - Create `AiClient.new(provider: 'openai')` — Call 1 uses gpt-4.1-mini via OpenAI provider
  - Call: `ai_client.chat(messages:, model:, response_format:)`
  - Create `AiApiRequest` via private `create_ai_api_request` method (same pattern as P1 lines 296-312)
  - Parse JSON response
  - Extract `title_technology` and `criteria_sections` (sections where `type == 'criteria'`)

- [ ] D.1.4 Call 2 — Criteria Extraction (gpt-4o):
  - Build messages: `AiJobApplicationAction::Scoring::Prompts::JobDescriptionCriteriaExtraction.messages(criteria_sections: criteria_sections, title_technology: title_technology)`
  - Create new `AiClient.new(provider: 'openai')` — Call 2 uses gpt-4o via OpenAI provider
  - Call: `ai_client.chat(messages:, model:, response_format:)`
  - Create `AiApiRequest`
  - Parse JSON response

- [ ] D.1.5 Code-level heading tier override (runs after Call 2 returns):
  ```ruby
  criteria = parsed_response['criteria']
  criteria.each do |criterion|
    heading = criterion['source_heading']&.downcase
    next unless heading

    if heading.match?(/required|must|essential|minimum/)
      # Skip soft skills — they cap at tier_2 per prompt instructions
      next if soft_skill?(criterion['text'])
      criterion['tier'] = 'tier_1'
    elsif heading.match?(/bonus|optional|extra credit/)
      criterion['tier'] = 'tier_3'
    end
  end
  ```
  Implement `soft_skill?` as a private method checking against the soft skills list from the prompt (communication, organizational skills, time management, etc.).

- [ ] D.1.6 Deduplication: Filter out criteria where `duplicate == true`. For surviving criteria where the duplicate had a higher tier, promote the survivor. Remove the `duplicate` field from stored criteria (per spec: "duplicate field not stored").
  ```ruby
  # Group by uniqueness, filter duplicates, handle tier inheritance
  non_duplicates = criteria.reject { |c| c['duplicate'] }
  non_duplicates.each { |c| c.delete('duplicate') }
  ```
  **Note:** The tier inheritance for duplicates is already handled by Call 2's prompt instructions ("the surviving criterion inherits the higher tier"). The code-level override runs after Call 2 but before dedup, so the overridden tiers are what get compared. However, the code-level heading override may change a duplicate's tier — but since we're filtering duplicates out, we only need to ensure the surviving (non-duplicate) criterion has the correct tier. The prompt handles this: "If the less specific duplicate was tier_1 and the more specific is tier_2, promote the surviving criterion to tier_1." Post-heading-override, we trust the model's dedup tier assignments.

- [ ] D.1.7 Build metadata and save:
  ```ruby
  metadata = {
    'title_technology' => title_technology,
    'raw_criteria_count' => criteria.size,
    'criteria_count' => non_duplicates.size
  }

  update_params = {
    status: :succeeded,
    criteria: non_duplicates,
    metadata: metadata
  }
  ```
  Use `@ai_job_criteria.update(update_params)` (NOT `update_columns`) to ensure the `after_commit` callback fires and resumes waiting summaries (per spec Section 4). Check the return value per `core_critical_rules.md` Rule 11:
  ```ruby
  unless @ai_job_criteria.update(update_params)
    raise CustomErrorAiSummary, "Failed to update AiJobCriteria: #{@ai_job_criteria.errors.full_messages.join(', ')}"
  end
  ```

- [ ] D.1.8 Error handling — three-tier rescue matching `Summary::Generate`:
  ```ruby
  rescue CustomErrorAiSummary => e
    Rails.logger.error "ExtractCriteria failed for AiJobCriteria #{@ai_job_criteria&.id}: #{e&.message}"
    ap e&.message
    @ai_job_criteria&.update_columns(status: :failed, error_message: e&.message)
    raise
  rescue JSON::ParserError => e
    Rails.logger.error "ExtractCriteria JSON parse failed for AiJobCriteria #{@ai_job_criteria&.id}: #{e&.message}"
    ap e&.message
    @ai_job_criteria&.update_columns(status: :failed, error_message: "Failed to parse AI response: #{e&.message}")
  rescue StandardError => e
    Rails.logger.error "ExtractCriteria unexpected error for AiJobCriteria #{@ai_job_criteria&.id}: #{e&.message}"
    ap e&.message
    @ai_job_criteria&.update_columns(status: :failed, error_message: e&.message)
  end
  ```
  Note: `update_columns` for `failed` is intentional — we do NOT want to fire the `after_commit` callback for failed status (it only resumes summaries on `succeeded`). This matches the spec: "The `succeeded` status transition must use `update` (not `update_columns`) to ensure the `after_commit` callback fires. `failed` transitions may use `update_columns`."

- [ ] D.1.9 Private `create_ai_api_request` method — copy pattern from `Summary::Generate` (lines 296-312), but use `@ai_job_criteria` as the `requestable`:
  ```ruby
  def create_ai_api_request(call_type:, provider:, result:, messages:)
    model = result[:model]
    input_tokens = result[:input_tokens] || 0
    output_tokens = result[:output_tokens] || 0

    AiApiRequest.create(
      organization: @organization,
      requestable: @ai_job_criteria,
      call_type: call_type,
      provider: provider,
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost: AiClient.calculate_cost(model: model, input_tokens: input_tokens, output_tokens: output_tokens).to_f.round(6),
      prompt_text: messages.to_json,
      response_body: result[:content]
    )
  end
  ```

#### D.2 `AiJobApplicationAction::Scoring::ScoreJobApplication`

**File:** `app/services/ai_job_application_action/scoring/score_job_application.rb` (new)

- [ ] D.2.1 Constructor: `def initialize(ai_job_application_summary:, textract_result:)`
  - Takes already-loaded objects (called from orchestrator in the request cycle, per `cursor_rules/backend/services.md` Rule 3)
  - Store `@ai_job_application_summary`, `@textract_result`
  - Derive: `@job_application = @ai_job_application_summary.job_application`, `@job = @job_application.job`, `@organization = @job.organization`

- [ ] D.2.2 Main method: `def score`
  - Guard: `return unless @ai_job_application_summary && @textract_result`
  - Load criteria: `ai_job_criteria = @job.ai_job_criteria`
  - **Criteria check:** If `ai_job_criteria.blank?` or not `ai_job_criteria.status_succeeded?`:
    - Set summary status to `awaiting_job_criteria`: `@ai_job_application_summary.update_columns(status: :awaiting_job_criteria)`
    - If criteria extraction not already in progress, trigger it:
      ```ruby
      if ai_job_criteria.blank? || ai_job_criteria.status_failed?
        @job.extract_job_criteria
      end
      ```
    - Return (orchestrator will be re-invoked by `AiJobCriteria` `after_commit` callback)
  - Transition: `@ai_job_application_summary.update_columns(status: :scoring)`
  - Get resume text: `resume_text = @textract_result.textract_job_result_text`
  - Get criteria array: `criteria = ai_job_criteria.criteria`

- [ ] D.2.3 Scoring call (Gemini flash-lite):
  - Build messages: `AiJobApplicationAction::Scoring::Prompts::JobApplicationScoring.messages(criteria: criteria, resume_text: resume_text)`
  - Create `AiClient.new(provider: 'gemini')`
  - Call: `ai_client.chat(messages:, model:, response_format:)`
  - Create `AiApiRequest` linked to `@ai_job_application_summary`
  - Parse JSON — get `scoring_results = parsed['scores']`

- [ ] D.2.4 Display sentence call (Gemini flash-lite):
  - Build messages: `AiJobApplicationAction::Scoring::Prompts::ScoringDisplay.messages(scoring_results: scoring_results)`
  - Same gemini client
  - Call: `ai_client.chat(messages:, model:, response_format:)`
  - Create `AiApiRequest`
  - Parse JSON — get `display_results = parsed['criteria']`

- [ ] D.2.5 Merge results: combine scoring_results (score, reasoning) with display_results (summary) and criteria metadata (tier, contains_title_technology) into `criteria_results` array matching the spec schema:
  ```ruby
  criteria_results = scoring_results.map do |score_entry|
    display_entry = display_results.find { |d| d['criterion_text'] == score_entry['criterion_text'] }
    criterion_source = criteria.find { |c| c['text'] == score_entry['criterion_text'] }

    {
      'criterion_text' => score_entry['criterion_text'],
      'tier' => score_entry['tier'],
      'contains_title_technology' => criterion_source&.dig('contains_title_technology') || false,
      'score' => score_entry['score'],
      'reasoning' => score_entry['reasoning'],
      'summary' => display_entry&.dig('summary') || ''
    }
  end
  ```

- [ ] D.2.6 Calculate score: `score_percentage = AiJobApplicationAction::Scoring::Calculate.compute(criteria_results)`

- [ ] D.2.7 Save results and advance status:
  ```ruby
  update_params = {
    score_percentage: score_percentage,
    criteria_results: criteria_results,
    status: :integrating
  }
  unless @ai_job_application_summary.update(update_params)
    raise CustomErrorAiSummary, "Failed to update scoring results: #{@ai_job_application_summary.errors.full_messages.join(', ')}"
  end
  ```

- [ ] D.2.8 Error handling — three-tier rescue on `@ai_job_application_summary`:
  - `CustomErrorAiSummary`: set `status: :retrying` (NOT `:failed` — must match `Summary::Generate` line 174 pattern so the job's retry finds a resumable status, not a terminal one) + re-raise
  - `JSON::ParserError`: set `status: :failed` + no re-raise
  - `StandardError`: set `status: :failed` + no re-raise
  Use `update_columns` for all status sets (same as `Summary::Generate`)

#### D.3 `AiJobApplicationAction::Scoring::Calculate`

**File:** `app/services/ai_job_application_action/scoring/calculate.rb` (new)

- [ ] D.3.1 Module-level class method (no constructor needed — pure computation):
  ```ruby
  module AiJobApplicationAction
    module Scoring
      class Calculate
        TIER_WEIGHTS = { 'tier_1' => 6, 'tier_2' => 4, 'tier_3' => 2 }.freeze
        SCORE_VALUES = { 'full_match' => 1.0, 'partial_match' => 0.7, 'not_found' => 0.0 }.freeze
        TITLE_TECHNOLOGY_MULTIPLIER = 3

        def self.compute(criteria_results)
          return unless criteria_results.present?

          total_weighted_score = 0.0
          max_possible = 0.0

          criteria_results.each do |result|
            weight = TIER_WEIGHTS[result['tier']] || TIER_WEIGHTS['tier_2']
            value = SCORE_VALUES[result['score']] || 0.0
            multiplier = result['contains_title_technology'] ? TITLE_TECHNOLOGY_MULTIPLIER : 1

            effective_weight = weight * multiplier
            total_weighted_score += effective_weight * value
            max_possible += effective_weight * 1.0
          end

          return if max_possible.zero?

          (total_weighted_score / max_possible * 100).round(2)
        end
      end
    end
  end
  ```

#### D.4 `AiJobApplicationAction::Scoring::IntegrateAnalysis`

**File:** `app/services/ai_job_application_action/scoring/integrate_analysis.rb` (new)

- [ ] D.4.1 Constructor: `def initialize(ai_job_application_summary:)`
  - Store `@ai_job_application_summary`
  - Derive `@organization` from the summary's job_application chain

- [ ] D.4.2 Main method: `def integrate`
  - Guard: `return unless @ai_job_application_summary`
  - Gather inputs from `structured_data`:
    - `role_analysis`, `applicable_experience`, `gaps`, `overlap_summary`, `career_narrative`, `key_skills`, `standout_accomplishments`
  - Gather scoring inputs: `criteria_results`, `score_percentage`

- [ ] D.4.3 AI call with new prompt:
  - Build messages: `AiJobApplicationAction::Scoring::Prompts::IntegratedAnalysis.messages(...)` (pass all inputs)
  - Create `AiClient.new(provider: ...)` — provider/model TBD (prompt not yet written)
  - Call: `ai_client.chat(messages:, model:, response_format:)`
  - Create `AiApiRequest`
  - Parse response — extract `integrated_role_analysis` text

- [ ] D.4.4 Save and advance to terminal state:
  ```ruby
  update_params = {
    integrated_role_analysis: integrated_role_analysis,
    status: :succeeded
  }
  unless @ai_job_application_summary.update(update_params)
    raise CustomErrorAiSummary, "Failed to update integrated analysis: #{@ai_job_application_summary.errors.full_messages.join(', ')}"
  end
  ```
  **IMPORTANT:** `succeeded` is the terminal state. This triggers:
  - `destroy_previous_textract_results` callback (existing)
  - Credit consumption in `generate_ai_summary_with_credit_flow` (existing)
  - Broadcast in `GenerateAiJobApplicationSummaryJob` (existing)

- [ ] D.4.5 Error handling — three-tier rescue on `@ai_job_application_summary` (same as D.2.8: `CustomErrorAiSummary` -> `retrying` + re-raise; `JSON::ParserError` -> `failed`; `StandardError` -> `failed`)

#### D.5 `AiJobApplicationAction::Scoring::Prompts::IntegratedAnalysis`

**File:** `app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb` (new)

- [ ] D.5.1 Create the prompt file following the exact same structure as the other prompt files (P6):
  - `SYSTEM_PROMPT` constant with `<<~PROMPT.freeze`
  - `JSON_SCHEMA` constant with response format
  - `MODEL` constant
  - Class methods: `self.messages(...)`, `self.response_format`, `self.model`
- [ ] D.5.2 **The prompt text itself requires development and testing.** The implementing agent should create a minimal working prompt that accepts the structured inputs (role_analysis, applicable_experience, gaps, overlap_summary, career_narrative, key_skills, standout_accomplishments, criteria_results, score_percentage) and produces a text `integrated_role_analysis`. Jessica will iterate on the prompt text after implementation.
- [ ] D.5.3 Response format: text output (single string), not structured JSON. The response schema should extract a single `integrated_role_analysis` string field.

---

### Phase E: Pipeline Orchestrator

**Cursor rules to read:** `cursor_rules/backend/services.md`, `cursor_rules/backend/architecture.md`

#### E.1 `AiJobApplicationAction::Orchestrate`

**File:** `app/services/ai_job_application_action/orchestrate.rb` (new)

- [ ] E.1.1 Constructor: `def initialize(textract_result_id:)`
  - Match `Summary::Generate` constructor signature exactly (same parameter)
  - Load `@textract_result = TextractResult.find_by(id: textract_result_id)`

- [ ] E.1.2 Main method: `def call` (per `cursor_rules/backend/services.md` Rule 2 — use descriptive name, but `call` is acceptable for an orchestrator that "calls" sub-services)
  - Guard: `return unless @textract_result`
  - Load `@job_application = @textract_result.job_application`
  - Load latest summary: `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first`
  - Guard: `return unless @ai_job_application_summary`

- [ ] E.1.3 Status-based resume logic — check current status and resume from the appropriate point:
  ```ruby
  case
  when @ai_job_application_summary.status_pending? ||
       @ai_job_application_summary.status_textract_processing? ||
       @ai_job_application_summary.status_extracting? ||
       @ai_job_application_summary.status_retrying?
    run_summary
    check_criteria_and_score
  when @ai_job_application_summary.status_summarizing?
    # Check if summary data is populated (summary complete)
    if summary_complete?
      check_criteria_and_score
    else
      run_summary
      check_criteria_and_score
    end
  when @ai_job_application_summary.status_awaiting_job_criteria?
    check_criteria_and_score
  when @ai_job_application_summary.status_scoring?
    if @ai_job_application_summary.criteria_results.present?
      run_integration
    else
      run_scoring
      run_integration
    end
  when @ai_job_application_summary.status_integrating?
    run_integration
  when @ai_job_application_summary.status_succeeded?,
       @ai_job_application_summary.status_failed?
    return # Terminal states — do nothing
  end
  ```

- [ ] E.1.4 Private method `summary_complete?`:
  ```ruby
  def summary_complete?
    @ai_job_application_summary.headline.present? &&
      @ai_job_application_summary.summary_text.present?
  end
  ```

- [ ] E.1.5 Private method `run_summary`:
  ```ruby
  def run_summary
    AiJobApplicationAction::Summary::Generate.new(textract_result_id: @textract_result.id).generate
    @ai_job_application_summary.reload
  end
  ```
  **Note on `reload`:** This is one of the rare cases where `reload` is necessary (per `cursor_rules/backend/_base.md` Rule 8 exception). `Summary::Generate` loads and updates the summary via its own reference. The orchestrator's `@ai_job_application_summary` is stale after `Generate` runs. The orchestrator needs fresh data to check the status and decide next steps. Document this deviation.

- [ ] E.1.6 Private method `check_criteria_and_score`:
  ```ruby
  def check_criteria_and_score
    # Verify summary actually completed
    return if @ai_job_application_summary.status_failed?
    return unless summary_complete?

    # Advance status past summarizing
    @ai_job_application_summary.update_columns(status: :awaiting_job_criteria)

    ai_job_criteria = @ai_job_application_summary.job_application.job.ai_job_criteria

    if ai_job_criteria&.status_succeeded?
      run_scoring
      run_integration
    else
      # Status stays at awaiting_job_criteria
      # Trigger extraction if not already in progress
      @ai_job_application_summary.job_application.job.extract_job_criteria unless ai_job_criteria&.status_pending? || ai_job_criteria&.status_in_progress?
      return
    end
  end
  ```

- [ ] E.1.7 Private method `run_scoring`:
  ```ruby
  def run_scoring
    @ai_job_application_summary.reload
    return if @ai_job_application_summary.status_failed?

    AiJobApplicationAction::Scoring::ScoreJobApplication.new(
      ai_job_application_summary: @ai_job_application_summary,
      textract_result: @textract_result
    ).score
    @ai_job_application_summary.reload
  end
  ```

- [ ] E.1.8 Private method `run_integration`:
  ```ruby
  def run_integration
    @ai_job_application_summary.reload
    return if @ai_job_application_summary.status_failed?
    return unless @ai_job_application_summary.criteria_results.present?

    AiJobApplicationAction::Scoring::IntegrateAnalysis.new(
      ai_job_application_summary: @ai_job_application_summary
    ).integrate
  end
  ```

---

### Phase F: Orchestrator Integration

**Cursor rules to read:** `cursor_rules/backend/architecture.md`, `cursor_rules/backend/_base.md`

#### F.1 Replace `generate_ai_summary` in `TextractResult`

**File:** `app/models/textract_result.rb`

- [ ] F.1.1 Update `generate_ai_summary` method (line 52-54) to call the orchestrator:
  ```ruby
  def generate_ai_summary
    AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call
  end
  ```
  The method name stays `generate_ai_summary` because it's called from `generate_ai_summary_with_credit_flow` (line 71). Renaming would require updating the caller. The spec says: "The standalone `TextractResult#generate_ai_summary` method should be removed or made private after the orchestrator replaces its usage." Making it private is safer:

- [ ] F.1.2 Move `generate_ai_summary` below the `private` keyword (after line 93). It's only called from `generate_ai_summary_with_credit_flow` (same class) — no external callers need it.

---

### Phase G: Job Lifecycle Triggering

**Cursor rules to read:** `cursor_rules/backend/_base.md`, `cursor_rules/backend/background_jobs.md`, `cursor_rules/core_critical_rules.md`

#### G.1 `ExtractJobCriteriaJob`

**File:** `app/jobs/extract_job_criteria_job.rb` (new)

**Pattern precedent:** `GetResumeTextFromTextractJob` (P4)

- [ ] G.1.1 Create the job file:
  ```ruby
  # frozen_string_literal: true

  class ExtractJobCriteriaJob < ApplicationJob
    queue_as :default
    retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3 do |job, error|
      ap '[ExtractJobCriteriaJob] retries exhausted'
      ap error
      ai_job_criteria = AiJobCriteria.find_by(id: job.arguments.first)
      ai_job_criteria&.update_columns(status: :failed, error_message: error&.message)
    end

    def perform(ai_job_criteria_id)
      ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria_id)
      return unless ai_job_criteria

      AiJobApplicationAction::Scoring::ExtractCriteria.new(
        ai_job_criteria_id: ai_job_criteria.id
      ).extract
    rescue CustomErrorAiSummary => e
      ap '[ExtractJobCriteriaJob] CustomErrorAiSummary — retrying'
      ap e
      raise
    rescue StandardError => e
      Rails.logger.error "ExtractJobCriteriaJob failed for #{ai_job_criteria_id}: #{e.message}"
      ap '[ExtractJobCriteriaJob] StandardError'
      ap e
      ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria_id)
      ai_job_criteria&.update_columns(status: :failed, error_message: e&.message)
    end
  end
  ```

  **Exhaustion block pattern:** matches `GenerateAiJobApplicationSummaryJob` (P5) — on exhaustion, find the record and set `failed`. This follows pipeline failure pattern #14 (analog structural matching: `GenerateAiJobApplicationSummaryJob` has an exhaustion block, so `ExtractJobCriteriaJob` must too).

#### G.2 `Job#extract_job_criteria`

**File:** `app/models/job.rb`

- [ ] G.2.1 Add the method in the private section (or near the other AI-related methods):
  ```ruby
  def extract_job_criteria
    return unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)

    existing_ai_job_criteria = ai_job_criteria

    # Debounce: if pending, a job is already queued with 2-minute delay
    return if existing_ai_job_criteria&.status_pending?

    if existing_ai_job_criteria
      # Reset to pending — a new extraction will run
      existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)
    else
      self.ai_job_criteria = AiJobCriteria.new(job: self, status: :pending)
      return unless ai_job_criteria.save
    end

    ExtractJobCriteriaJob.set(wait: 2.minutes).perform_later(ai_job_criteria.id)
  end
  ```

  **Guard clause style:** bare `return` without truthy/falsy values per `core_critical_rules.md` Rule 8.

  **`update_columns` for reset:** The spec says `in_progress` does NOT return early because we can't know if the in-progress extraction uses current or stale description. Resetting to `pending` via `update_columns` (bypasses `after_commit`) is safe — we don't want to fire the `resume_waiting_summaries` callback when resetting to `pending`.

  **Save check:** `return unless ai_job_criteria.save` per `core_critical_rules.md` Rule 11.

  **Transaction timing note:** Per spec Section 7, `extract_job_criteria` runs inside `handle_before_update` which runs inside a `before_update` callback. The `AiJobCriteria` save and `perform_later` happen inside the Job's save transaction. If the Job save fails, the `AiJobCriteria` save rolls back but the Sidekiq job is already enqueued. The job's `find_by` guard handles this — job fires, finds no record, returns. This follows existing patterns (e.g., `UpdateDistributionsJob.perform_later(id)` at line 479).

#### G.3 `Job#handle_description_change`

**File:** `app/models/job.rb`

- [ ] G.3.1 Add `handle_description_change` call to `handle_before_update` (line 475-483). Add it after the existing `handle_status_change` call:
  ```ruby
  def handle_before_update
    if changed?
      handle_status_change
      handle_description_change
      UpdateDistributionsJob.perform_later(id) unless skip_update_callback
      update_columns(display_location: location_pretty) if location_pretty_has_changed?
    end
  end
  ```

- [ ] G.3.2 Add the method:
  ```ruby
  def handle_description_change
    return unless description_changed?
    return unless published?
    return unless description_meaningfully_changed?

    extract_job_criteria
  end
  ```

#### G.4 `Job#description_meaningfully_changed?`

- [ ] G.4.1 Add the method:
  ```ruby
  def description_meaningfully_changed?
    old_text = ActionView::Base.full_sanitizer.sanitize(description_was).to_s.downcase.gsub(/[^a-z]/, '')
    new_text = ActionView::Base.full_sanitizer.sanitize(description).to_s.downcase.gsub(/[^a-z]/, '')
    old_text != new_text
  end
  ```

  **Uses `ActionView::Base.full_sanitizer.sanitize`** — the same approach as the existing `description_without_html` method (line 677-678).

  **Removes digits intentionally** — per spec: "number-only changes like salary or years-of-experience do not change the extracted criteria structure."

#### G.5 `Job#handle_status_changed_to_published` — Add criteria extraction

**File:** `app/models/job.rb` (lines 542-557)

- [ ] G.5.1 Add `extract_job_criteria` as the last line of `handle_status_changed_to_published`:
  ```ruby
  def handle_status_changed_to_published
    ap '***PUBLISHED***'
    touch(:published_at)
    update_column(:originally_published_at, published_at) if originally_published_at.nil?

    Notification::JobStatusChangeJob.perform_later(id, status)
    JobPingGoogleIndexJob.perform_later(id)
    UpdateStripeSubscriptionJob.perform_later(organization.id)
    CareersPageSubscriptionsNotifierJob.perform_later(id)

    new_published_job_webhook = organization.registered_webhooks.find_by(kind: :new_published_job)
    RegisteredWebhooks::NewJobPublishedJob.perform_later(id, new_published_job_webhook.id) if new_published_job_webhook.present?

    extract_job_criteria
  end
  ```

---

### Phase H: Serializers

**Cursor rules to read:** `cursor_rules/backend/serializers.md`

#### H.1 Update `AiJobApplicationSummarySerializer` (full)

**File:** `app/serializers/api/v1/ai_job_application_summary_serializer.rb`

- [ ] H.1.1 Add new attributes:
  ```ruby
  attributes :id, :status, :headline, :summary_text, :structured_data,
             :job_application_id, :stale, :created_at,
             :score_percentage, :criteria_results, :integrated_role_analysis
  ```
  Per `cursor_rules/backend/serializers.md` Rule 1: no method definitions needed for regular columns.

#### H.2 Update `AiJobApplicationSummaryShallowSerializer`

**File:** `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb`

- [ ] H.2.1 Add `score_percentage`:
  ```ruby
  attributes :id, :status, :headline, :summary_text, :stale, :created_at, :score_percentage
  ```

#### H.3 Create `AiJobApplicationSummaryStatusSerializer`

**File:** `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` (new)

- [ ] H.3.1 Create the serializer:
  ```ruby
  # frozen_string_literal: true

  class Api::V1::AiJobApplicationSummaryStatusSerializer < ActiveModel::Serializer
    attributes :id, :ai_job_application_summary_id, :regenerating
  end
  ```

#### H.4 Update `ShallowJobApplicationSerializer`

**File:** `app/serializers/api/v1/shallow_job_application_serializer.rb`

- [ ] H.4.1 Add the association:
  ```ruby
  has_one :ai_job_application_summary_status,
          serializer: Api::V1::AiJobApplicationSummaryStatusSerializer
  ```

- [ ] H.4.2 Add eager loading to `app/controllers/api/v1/job_applications_controller.rb`:
  - Line 25: Add `.includes(:ai_job_application_summary_status)` to the existing `.includes(resume_attachment: :blob)` chain
  - Line 35: Add `.includes(:ai_job_application_summary_status)` to the existing `.includes(resume_attachment: :blob)` chain

---

### Phase I: `AiJobApplicationSummaryStatus` Lifecycle Management

**This phase wires the status read model into the pipeline.**

- [ ] I.1 Determine where to create the `AiJobApplicationSummaryStatus` record. Per spec: "Created when AI evaluation first kicks off for a job application." This means it should be created in `CreateAiSummaryGeneration` when a new `AiJobApplicationSummary` is created. Add after the summary save succeeds:
  ```ruby
  AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application) do |status_record|
    status_record.regenerating = false
  end
  ```

- [ ] I.2 Update `ai_job_application_summary_id` when a summary reaches `succeeded`. This can be done in the orchestrator's final step or via an `after_commit` on `AiJobApplicationSummary`. Using `after_commit` is more reliable (catches all paths):

  Add to `AiJobApplicationSummary`:
  ```ruby
  after_commit :update_summary_status_record, on: :update

  def update_summary_status_record
    return unless saved_change_to_status? && status_succeeded?

    ai_job_application_summary_status = job_application.ai_job_application_summary_status
    return unless ai_job_application_summary_status

    ai_job_application_summary_status.update_columns(
      ai_job_application_summary_id: id,
      regenerating: false
    )
  end
  ```

- [ ] I.3 Set `regenerating: true` when regeneration starts. In `CreateAiSummaryGeneration`, when creating a new summary while an active one exists (the active summary check at line 30-44):
  - Currently, if an active non-stale summary exists, the interactor returns it silently.
  - For regeneration support: when a summary is marked stale and a new one is created, set `regenerating: true` on the status record.
  - This is a future concern — for now, the status record just tracks existence and latest success.

---

### Phase J: Test Plan

**Cursor rules to read:** `cursor_rules/backend/_base.md` (spec exception for bang methods)

#### J.1 Update existing specs for enum changes

- [ ] J.1.1 `spec/models/ai_job_application_summary_spec.rb`:
  - Update the enum assertion to the new 10-value enum
  - Update `status: :succeeded` in destroy_previous_textract_results test — verify it passes with the new integer value (7 instead of 2). Since we use symbols, it should work, but verify.
  - Add test: status transitions from `integrating` to `succeeded` trigger `destroy_previous_textract_results`

- [ ] J.1.2 `spec/jobs/generate_ai_job_application_summary_job_spec.rb`:
  - All `status: :succeeded` references use symbols — verify they work with new enum
  - If any test creates a summary with `status: :in_progress` or `status: :extracted`, update to `status: :extracting` or `status: :summarizing`

- [ ] J.1.3 `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`:
  - Same treatment as J.1.2

- [ ] J.1.4 `spec/support/ai_credits_test_helpers.rb`:
  - Update `status: :succeeded` if needed (line 138)

- [ ] J.1.5 Run grep for `in_progress` and `extracted` status references across ALL spec files:
  ```bash
  grep -rn "status: :in_progress\|status_in_progress\|status: :extracted\|status_extracted" --include="*.rb" spec/
  ```
  Update every hit.

#### J.2 New model specs

- [ ] J.2.1 `spec/models/ai_job_criteria_spec.rb`:
  - Status enum values (4 values)
  - `after_commit` callback: when status transitions to `succeeded`, enqueue `GenerateAiJobApplicationSummaryJob` for each waiting summary
  - `after_commit` callback: does NOT fire for `failed` transitions
  - `after_commit` callback: handles zero waiting summaries gracefully
  - `after_commit` callback: handles multiple waiting summaries (enqueues one job per summary)
  - Association: `belongs_to :job`, `has_many :ai_api_requests`

- [ ] J.2.2 `spec/models/ai_job_application_summary_status_spec.rb`:
  - Uniqueness on `job_application_id`
  - `regenerating` defaults to false
  - `ai_job_application_summary_id` nullable

#### J.3 New service specs

- [ ] J.3.1 `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb`:
  - **Call 1 + Call 2:** stub `AiClient#chat` to return predetermined JSON, verify `AiApiRequest` records created with correct `requestable` (the `AiJobCriteria` record)
  - **Heading tier override:** provide criteria with known headings, verify tier forced to `tier_1` for "Required" headings, `tier_3` for "Bonus" headings, soft skills capped at `tier_2`
  - **Dedup:** provide criteria with `duplicate: true`, verify filtered out, `duplicate` key removed from stored criteria
  - **Status transitions:** verify `pending` → `in_progress` → `succeeded`
  - **Error handling:** `CustomErrorAiSummary` → `failed` + re-raise; `JSON::ParserError` → `failed` no re-raise; `StandardError` → `failed` no re-raise
  - **Guard: blank description** → sets failed status

- [ ] J.3.2 `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb`:
  - **Criteria present path:** stub AI calls, verify `criteria_results` and `score_percentage` written, status → `integrating`
  - **Criteria absent path:** no `AiJobCriteria` exists → sets `awaiting_job_criteria`, triggers `extract_job_criteria` on job, returns
  - **Criteria failed path:** `AiJobCriteria` exists with `failed` status → sets `awaiting_job_criteria`, re-triggers extraction
  - **Scoring + display merge:** verify the `criteria_results` array has all expected fields

- [ ] J.3.3 `spec/services/ai_job_application_action/scoring/calculate_spec.rb`:
  - All tier/multiplier combinations:
    - tier_1 full_match = 6 * 1.0 = 6
    - tier_2 partial_match = 4 * 0.7 = 2.8
    - tier_3 not_found = 2 * 0 = 0
    - title_technology 3x multiplier
  - Edge cases: empty array → returns nil, all not_found → 0, single criterion
  - Formula verification with known inputs

- [ ] J.3.4 `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb`:
  - Stub AI call, verify `integrated_role_analysis` written, status → `succeeded`
  - Error handling: verify `failed` status set on error

- [ ] J.3.5 `spec/services/ai_job_application_action/orchestrate_spec.rb`:
  - **Full pipeline (happy path):** stub `Summary::Generate`, `ScoreJobApplication`, `IntegrateAnalysis`. Verify called in order, status reaches `succeeded`.
  - **Resume from each checkpoint:**
    - `extracting` → runs summary, scoring, integration
    - `summarizing` with data populated → skips summary, runs scoring, integration
    - `awaiting_job_criteria` with criteria now present → runs scoring, integration
    - `scoring` with `criteria_results` populated → runs integration only
    - `integrating` → runs integration only
    - `succeeded` → does nothing
    - `failed` → does nothing
  - **Criteria gap:** after summary, no criteria → sets `awaiting_job_criteria`, returns

#### J.4 New job specs

- [ ] J.4.1 `spec/jobs/extract_job_criteria_job_spec.rb`:
  - Not-found guard: returns silently for nonexistent ID
  - Delegates to `ExtractCriteria` service
  - Retry exhaustion: sets `failed` status on the `AiJobCriteria` record

#### J.5 Job model specs

- [ ] J.5.1 `spec/models/job_spec.rb` (or new file `spec/models/job_criteria_lifecycle_spec.rb`):
  - **`extract_job_criteria`:**
    - Flipper gate: returns if `:AI_APPLICANT_SUMMARY` not enabled
    - Pending debounce: returns if existing criteria with `pending` status
    - Creates new `AiJobCriteria` if none exists
    - Resets `in_progress` to `pending` and enqueues
    - Resets `succeeded`/`failed` to `pending` and enqueues
    - 2-minute delay on the job
    - Save failure: returns without enqueuing
  - **`handle_description_change`:**
    - Fires only when `description_changed?` AND `published?` AND `description_meaningfully_changed?`
    - Does not fire for draft jobs
    - Does not fire when description unchanged
  - **`description_meaningfully_changed?`:**
    - HTML-only changes → not meaningful (returns false)
    - Whitespace-only changes → not meaningful
    - Number-only changes → not meaningful (digits stripped)
    - Text changes → meaningful (returns true)
    - Case changes → not meaningful (lowercased)

#### J.6 Serializer specs

- [ ] J.6.1 `spec/serializers/ai_job_application_summary_serializer_spec.rb`:
  - Verify `score_percentage`, `criteria_results`, `integrated_role_analysis` present in full serializer output
  - Verify `score_percentage` present in shallow serializer output

---

## Validation and Constraints

- **`AiJobCriteria`:** `status` presence validated by enum. `job_id` uniqueness enforced by database unique index. No application-level validation on `criteria` or `metadata` jsonb (trust the AI pipeline output).
- **`AiJobApplicationSummaryStatus`:** `job_application_id` uniqueness enforced by database unique index and model validation. `regenerating` has database default `false`.
- **`AiJobApplicationSummary` new columns:** All nullable, no defaults — populated only when scoring completes. No validation on `score_percentage` range (trust the `Calculate` module). No validation on `criteria_results` shape (trust the pipeline).
- **No bang methods** per `core_critical_rules.md` Rule 10 (exception: specs can use them).
- **Always check save/update return values** per `core_critical_rules.md` Rule 11.

---

## Risks and Open Questions

### R1. `integrated_analysis.rb` Prompt — Not Yet Written
The prompt for the integration analysis step requires development and testing. The plan creates a minimal scaffold; Jessica will iterate on the actual prompt text. This is the only prompt that needs authoring — the other four are frozen.

### R2. `reload` Usage in Orchestrator
The orchestrator must `reload` the summary after `Summary::Generate` completes, because `Generate` loads and mutates the summary via its own reference. This is a documented deviation from `cursor_rules/backend/_base.md` Rule 8 (no reload). It's necessary because `Generate` was not designed to be called from an orchestrator — it manages its own summary lifecycle.

### R3. Error Propagation Through Orchestrator
When `Summary::Generate` raises `CustomErrorAiSummary`, it sets the summary status to `retrying` and re-raises. The orchestrator does not catch this — it propagates to `GenerateAiJobApplicationSummaryJob`, which has its own `retry_on CustomErrorAiSummary`. This is correct: the job retries, the orchestrator runs again, and the resume logic picks up from the `retrying` status. The orchestrator's case statement (E.1.3) includes `status_retrying?` in the first `when` branch alongside `status_pending?`, `status_textract_processing?`, and `status_extracting?` — re-running the summary from the beginning.

### R4. Transaction Safety for `extract_job_criteria` in `before_update`
`extract_job_criteria` creates/updates an `AiJobCriteria` record and enqueues a Sidekiq job inside a `before_update` callback. If the outer Job save fails, the AiJobCriteria change rolls back but the job is already in Redis. The job's `find_by` guard handles this safely. This follows existing patterns (`UpdateDistributionsJob` in the same callback). Documented in spec Section 7.

### R5. Bulk Scoring — Multiple Applications Hitting `awaiting_job_criteria`
When `BulkGenerateAiSummariesJob` processes multiple applications for the same job, all may reach `awaiting_job_criteria` before criteria extraction completes. The `AiJobCriteria.after_commit` callback handles this by finding ALL waiting summaries and enqueuing a job for each. `extract_job_criteria` has the `pending` debounce to prevent multiple extraction jobs.

### R6. `retrying` Status Handling
The `retrying` status (value `8`) is set by `Summary::Generate` when `CustomErrorAiSummary` is caught. The orchestrator's case statement (E.1.3) handles `retrying` alongside `pending`, `textract_processing`, and `extracting` — re-running the summary from the beginning.

---

## Estimated Scope

| Category | Count |
|----------|-------|
| New files | 12 (models, services, job, serializer, migrations, prompt) |
| Modified files | ~15 (models, services, serializers, jobs, interactors) |
| New spec files | ~10 |
| Modified spec files | ~4 |
| Estimated new lines | ~1,200-1,500 |
| Estimated modified lines | ~100-150 |

---

## Implementation Order

The recommended order minimizes dependencies and allows incremental testing:

1. **Phase A** (Database) — schema must exist before models
2. **Phase B** (Models) — models must exist before services reference them
3. **Phase C** (Status Enum Ripple) — must complete before running any existing tests
4. **Phase D** (Services) — D.3 (Calculate) first (no dependencies), then D.1 (ExtractCriteria), D.2 (ScoreJobApplication), D.4 (IntegrateAnalysis)
5. **Phase E** (Orchestrator) — depends on all services
6. **Phase F** (Integration) — wire orchestrator into TextractResult
7. **Phase G** (Job Lifecycle) — depends on models, services, and job
8. **Phase H** (Serializers) — can be done in parallel with E-G
9. **Phase I** (Status Lifecycle) — depends on models and interactors
10. **Phase J** (Tests) — can be written incrementally with each phase, but the full suite should run after all phases complete
