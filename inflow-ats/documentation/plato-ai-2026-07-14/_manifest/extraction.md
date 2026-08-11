# Manifest — Job-Criteria Extraction Pipeline

**Scope:** How the JOB-CRITERIA EXTRACTION pipeline works — the per-JOB pipeline that turns a
job description into a tiered, deduplicated list of scoring criteria (`AiJobCriteria`). This is
distinct from (and a prerequisite of) the per-CANDIDATE summary + scoring pipeline.

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` (branch `develop`, feature = `develop` ∆ `production`).

**Files traced (definitive chain):**
`app/models/job.rb` → `app/jobs/extract_job_criteria_job.rb` → `app/services/ai_job_application_action/scoring/extract_criteria.rb` → `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb` + `.../job_description_criteria_extraction.rb` → `app/services/ai_client.rb` → `app/services/ai_providers/openai.rb` → `app/models/ai_job_criteria.rb` (`resume_waiting_summaries` after_commit) ← triggered by `app/services/ai_job_application_action/orchestrate.rb` + `.../scoring/score_job_application.rb`.

---

## 1. Inputs

The pipeline's **only direct model input is the job description HTML** — `Job#description`.
It reads NO candidate data, NO resume, NO textract text, NO PII. Criteria are a property of the
job, computed once per extraction run and reused across all candidates on that job.

**Clarification on "resume via textract":** the resume (via `TextractResult` →
`GetResumeTextFromTextract` → the Summary pipeline) is NOT an input to criteria extraction. The
resume only INDIRECTLY *triggers* criteria extraction: when a candidate's summary reaches the
scoring gate and the job has no succeeded criteria yet, the scoring path calls
`Job#extract_job_criteria` (see Triggers §2, path C). The two extraction model calls never see the
resume — they receive only the job description HTML and its derived sections.

Persisted record: `AiJobCriteria` (table `ai_job_criteria`) — columns: `job_id`, `status`
(integer enum), `criteria` (jsonb), `metadata` (jsonb), `error_message` (text). Belongs to `Job`;
`has_many :ai_api_requests, as: :requestable`.

`status` enum (`_prefix: true`): `pending: 0, in_progress: 1, succeeded: 2, failed: 3, retrying: 4`.

---

## 2. Triggers — how an extraction run starts

All three trigger paths do the same thing: build `job.ai_job_criteria.new(status: :pending)`, save
it, and enqueue `ExtractJobCriteriaJob.perform_later(new_ai_job_criteria.id)`. A new pending
`AiJobCriteria` row is created per run; prior rows are retained (`latest_ai_job_criteria` =
`ai_job_criteria.order(created_at: :desc).first`).

**A. Job publish / meaningful description change** (`Job#handle_criteria_extraction_after_commit`)
- Registered via `after_commit :handle_after_update_commit, on: [:update]` (job.rb:58), which calls
  `handle_criteria_extraction_after_commit` (job.rb:511).
- Fires `auto_extract_job_criteria` when `saved_change_to_status? && published?` (job just
  published) OR `published? && description_meaningfully_changed?` (description text changed after
  HTML-sanitized comparison, `sanitize_for_compare`).
- `auto_extract_job_criteria` is gated by `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`;
  returns if the latest criteria is already `status_pending?`. If a prior criteria exists it enqueues
  with `wait: 30.seconds`, otherwise immediately.

**B. `Job#extract_job_criteria`** — same as A but always immediate enqueue; also Flipper-gated and
skips when latest is `status_pending?`. This is the method called from the candidate flow (path C).

**C. Candidate scoring gate (indirect, resume-driven)** — when a candidate summary is ready to
score but the job lacks succeeded criteria, these call `Job#extract_job_criteria`:
- `Orchestrate#check_criteria_and_score` (orchestrate.rb:80): after a summary is complete it sets
  the summary to `awaiting_job_criteria`; if `latest_ai_job_criteria` is not `status_succeeded?`, it
  calls `job.extract_job_criteria` **unless** criteria is already `pending`/`in_progress`, then
  returns (the summary waits).
- `ScoreJobApplication` (score_job_application.rb:23 and :45): on blank/failed/empty criteria it
  parks the summary at `awaiting_job_criteria` and re-triggers `@job.extract_job_criteria`.

**D. `Job#extract_job_criteria_immediately`** — creates + enqueues if `description.present?` (NOT
Flipper-gated); no in-app caller in `app/` besides its definition (utility/console path).

---

## 3. Job runner — `ExtractJobCriteriaJob`

- `queue_as :default`.
- `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3`. On exhaustion, the block sets the
  `AiJobCriteria` to `status: :failed` with the error message.
- `perform(ai_job_criteria_id)`: loads the record (returns if gone), calls
  `AiJobApplicationAction::Scoring::ExtractCriteria.new(ai_job_criteria_id:).extract`.
- Rescues: `CustomErrorAiSummary` → re-raise (feeds `retry_on`); `StandardError` → set record
  `status: :failed`, `error_message`.

---

## 4. Core service — `AiJobApplicationAction::Scoring::ExtractCriteria#extract`

Keyed by `ai_job_criteria_id`. Provider is **openai** for both calls (`AiClient.new(provider: 'openai')`).

**Guards / setup (in order):**
1. Load `AiJobCriteria` by id; `return unless` present.
2. `@job = @ai_job_criteria.job`; `return unless` present.
3. `@organization = @job.organization`; `return unless` present.
4. Set `status: :in_progress` via `update_columns` (skips callbacks), unless already in_progress.
5. `job_description_html = @job.description`. If blank → `update_columns(status: :failed, error_message: 'Job description is blank')`, return.

### Call 1 — `jd_structured_data` (decompose JD into sections)
- Prompt: `Prompts::JobDescriptionStructuredData`. Model: **`gpt-4.1-mini-2025-04-14`**. Provider: openai.
- Roles: `system` (recruiter-assistant instructions: split JD into heading-delimited sections,
  classify each `criteria` vs `non_criteria`, infer `inferred_section_type` ∈
  {company_about, benefits, compensation, culture, process_meta, legal, criteria}, decode HTML
  entities, preserve every sentence, extract `title_technology` from the title) + `user`
  (`"Here is the job description HTML:\n\n#{job_description_html}"`).
- Output (strict `json_schema`, `strict: true`):
  `{ title_technology: string|null, sections: [ { heading: string|null, inferred_section_type: string|null, type: "criteria"|"non_criteria", content: string } ] }`.
- Logs an `AiApiRequest` (`call_type: 'jd_structured_data'`, `requestable: @ai_job_criteria`).
- Post: parse content → `title_technology`, and keep only `sections` where `type == 'criteria'`.
  If none → `update_columns(status: :failed, error_message: 'No criteria sections found in job description')`, return.

### Call 2 — `jd_criteria_extraction` (extract atomic scoring criteria)
- Prompt: `Prompts::JobDescriptionCriteriaExtraction`. Model: **`gpt-4o-2024-08-06`**. Provider: openai.
- Roles: `system` (extract one atomic requirement per criterion; decompose compound sentences
  (but not "or" alternatives); assign `tier` ∈ tier_1/tier_2/tier_3 via heading-lock + signal-word
  rules; soft skills cap at tier_2; mark `binary`; flag `contains_title_technology` by fuzzy match
  to the title tech; mark `duplicate` for less-specific repeats) + `user`
  (`"Title technology: <tt>"` then each criteria section as `--- Section N: <heading> ---\n<content>`).
- Output (strict `json_schema`): `{ criteria: [ { text, tier ∈ tier_1|tier_2|tier_3, tier_reasoning, binary, contains_title_technology, duplicate, source_heading: string|null, source_text } ] }`.
- Logs an `AiApiRequest` (`call_type: 'jd_criteria_extraction'`, `requestable: @ai_job_criteria`).

**Deterministic code post-processing (after Call 2, no AI):**
1. **Strip leaked tier labels** from each `text`: remove a leading `[tier_N]` prefix (regex `\A\s*\[tier_\d+\]\s*:?\s*`).
2. **Heading tier override** per criterion (uses downcased `source_heading`):
   - matches `/require|must|essential|minimum/` → `tier = 'tier_1'` — UNLESS the text is a soft
     skill (`soft_skill?` against the hardcoded `SOFT_SKILLS` list), in which case unchanged.
   - matches `/bonus|optional|extra credit/` → `tier = 'tier_3'`.
3. **Dedup:** record `raw_criteria_count = criteria.size`; keep only criteria where `duplicate` is
   falsey; delete the `duplicate` key from survivors. If none survive →
   `update_columns(status: :failed, error_message: 'No criteria extracted from job description')`, return.

**Success write:**
- `metadata = { 'title_technology' => title_technology, 'raw_criteria_count' => <int>, 'criteria_count' => <survivors> }`.
- `@ai_job_criteria.update(status: :succeeded, criteria: non_duplicates, metadata: metadata)`
  — uses **`update` (NOT `update_columns`) deliberately** so the `after_commit` callback fires and
  resumes waiting candidate summaries (§6). If `update` returns false → `raise CustomErrorAiSummary`.

**Error handling (rescue order):**
- `CustomErrorAiSummary` → `update_columns(status: :retrying)`, then re-raise (lets the job's
  `retry_on` retry, up to 3 attempts / 2-min waits).
- `JSON::ParserError` → `update_columns(status: :failed, error_message: "Failed to parse AI response: …")`.
- `StandardError` → `update_columns(status: :failed, error_message: …)`.

---

## 5. Provider transport — `AiClient` → `AiProviders::Openai`

- `AiClient.new(provider: 'openai')` resolves `AiProviders::Openai` from `PROVIDERS`;
  `#chat(messages:, model:, response_format:)` delegates to the provider.
- `AiProviders::Openai#chat`: `POST https://api.openai.com/v1/chat/completions`, body always
  `temperature: 0`, `response_format` attached (the strict `json_schema`). Auth
  `Bearer Variables::OPENAI_API_KEY`. Faraday `timeout: 120`, `open_timeout: 30`. Non-200 →
  `raise CustomErrorAiSummary`. Returns `{ content:, input_tokens: usage.prompt_tokens, output_tokens: usage.completion_tokens, model: <resolved model> }`.
- Cost ledger: `ExtractCriteria#create_ai_api_request` writes an `AiApiRequest` per call with
  `organization`, `requestable = @ai_job_criteria`, `call_type`, `provider`, `model`,
  `input_tokens`, `output_tokens`, `cost` (`AiClient.calculate_cost` from the `PRICING` table,
  rounded to 6 dp), `prompt_text` (messages JSON), `response_body` (raw content). Both extraction
  models are in `PRICING` (`gpt-4.1-mini-2025-04-14` = $0.40/$1.60 per 1M in/out;
  `gpt-4o-2024-08-06` = $2.50/$10.00), so cost is non-null.

---

## 6. Outputs & downstream handoff

**Primary output — one `AiJobCriteria` row** (`status: succeeded`) with:
- `criteria` (jsonb array). Each surviving criterion object:
  `{ text, tier ∈ tier_1|tier_2|tier_3, tier_reasoning, binary, contains_title_technology, source_heading, source_text }`
  (the `duplicate` key is deleted from survivors).
- `metadata` (jsonb): `{ title_technology, raw_criteria_count, criteria_count }`.

**Ledger output — two `AiApiRequest` rows** (`jd_structured_data`, `jd_criteria_extraction`),
`requestable = AiJobCriteria`, feeding usage/cost displays.

**Resume-waiting-summaries handoff** (`AiJobCriteria#resume_waiting_summaries`,
`after_commit on: [:update]`): fires only when `saved_change_to_status? && status_succeeded?`. For
every `job.ai_job_application_summaries` with `status: :awaiting_job_criteria`, it enqueues
`GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:, requesting_organization_user_id:)`
— re-driving the orchestrator so parked candidate summaries proceed to scoring now that criteria
exist. This is why the success write uses `update` (fires the callback) and interim writes use
`update_columns` (skip it).

**Consumers of the criteria** (downstream, out of this pipeline): `ScoreJobApplication` feeds
`criteria` into the gemini scoring model; `Scoring::Calculate` applies tier weights
(tier_1=6, tier_2=4, tier_3=2) and a ×3 multiplier for `contains_title_technology: true` to compute
`score_percentage`.

---

## 7. Bias / determinism notes (stakeholder framing)

- Criteria extraction is computed from the **job description alone** — no candidate identity, no
  resume, no PII enters either model call. The requirements bar is defined once, per job, before any
  candidate is compared, so every candidate on a job is scored against the identical criteria set.
- Both calls run at OpenAI `temperature: 0` with strict JSON schemas, making extraction output
  highly stable run-to-run. Tier assignment is further constrained by deterministic code overrides
  (heading lock to tier_1/tier_3, soft-skill cap to tier_2) applied after the model output.
