# Plato AI — SUMMARY / SCORING pipeline manifest

**Scope:** exactly how a candidate is turned into an AI review (headline + summary) and scored against a job's criteria — call sequence, models, providers, the scoring math, what `score_percentage` / `headline` / `integrated_role_analysis` / `criteria_results` are, and how a credit is consumed.

**Source of truth (traced, verified against code on branch `develop`):**
`app/jobs/generate_ai_job_application_summary_job.rb` → `app/models/textract_result.rb` (`generate_ai_summary_with_credit_flow` + `generate_ai_summary`) → `app/services/ai_job_application_action/orchestrate.rb` → `app/services/ai_job_application_action/summary/generate.rb` → `app/services/ai_job_application_action/scoring/score_job_application.rb` → `.../scoring/calculate.rb` → `.../scoring/integrate_analysis.rb`; criteria via `.../scoring/extract_criteria.rb`; PII stripping via `.../summary/anonymize_for_ai.rb`; transport via `app/services/ai_client.rb` + `app/services/ai_providers/{openai,gemini}.rb`; credit debit via `app/interactors/create_ai_credit_balance_transaction.rb`; prompt classes under `app/services/ai_job_application_action/{summary,scoring}/prompts/`; display sync via `app/models/ai_job_application_summary.rb#handle_after_update_commit`.

---

## 1. Three interlocking pipelines

| Pipeline | Keyed to | Provider(s) | Produces |
|---|---|---|---|
| **CRITERIA EXTRACTION** | the **JOB** (`AiJobCriteria`) | OpenAI | the scoring rubric: a list of atomic `criteria` (text + tier + `contains_title_technology`), extracted once per job from the job description |
| **SUMMARY** | the **CANDIDATE** (`AiJobApplicationSummary`) | OpenAI | `structured_data`, `headline`, `summary_text`, `role_analysis` |
| **SCORING** | the **CANDIDATE against the JOB's criteria** | Gemini (score + display) + OpenAI (final narrative) | `score_percentage`, `criteria_results`, `integrated_role_analysis` |

A candidate is scored **against that job's extracted criteria**, not against a global rubric. Criteria are extracted per job and reused for every candidate on that job. If a job's criteria are not ready, candidate summaries park at status `awaiting_job_criteria` and auto-resume when criteria finish (see §3, §4).

---

## 2. Entry point + credit flow

**Job wrapper:** `GenerateAiJobApplicationSummaryJob.perform(textract_result_id:, requesting_organization_user_id: nil)`, `queue_as :default`, `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3`.
- On **retry exhaustion**: the exhaustion block sets the newest summary `status: :failed` (with `error_message`) and calls `broadcast_completion`. `broadcast_completion` emits a `GlobalChannel` `AI_SUMMARY_COMPLETE` toast **only when `requesting_organization_user_id` is present** (manual-generation path); the auto path (nil user) fires no toast.
- The job body is a thin dispatch: `return unless textract_result`, then `textract_result.generate_ai_summary_with_credit_flow`, then `broadcast_completion` on the manual path.

Both single-send and bulk generation converge on **`TextractResult#generate_ai_summary_with_credit_flow`** (textract_result.rb:61). Sequence:

1. `latest_ai_summary = job_application.latest_ai_job_application_summary`; **`return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`** — idempotent skip (no duplicate charge unless the resume text is stale).
2. `find_or_create_ai_job_application_summary_status`, then `set_initial_summary_pending` — the companion `AiJobApplicationSummaryStatus` row is moved to `initial_summary_pending` (only from `none`/`initial_summary_pending`), driving the "generating" badge. A prior *succeeded* review stays visible during regen (the status row is not blanked).
3. `generate_ai_summary` (textract_result.rb:110) → `AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call` — runs the whole multi-call pipeline (§3–§6).
4. Reload newest summary (`ai_job_application_summaries.order(created_at: :desc).first`); **`return unless status_succeeded?`** — a credit is consumed **only on full success**.
5. `CreateAiCreditBalanceTransaction.call(summary:)` — debit **1 credit**; `return unless consume_result.success?`.
6. `NotifyZeroAiCredits.call(organization:)` then `NotifyLowAiCredits.call(organization:)`.

**Credit debit** (`CreateAiCreditBalanceTransaction`, `CREDIT_COST = 1`): reads `organization.organization_ai_credit_balance` (fails `:missing_balance` if absent); picks a `bucket` via `determine_bucket` (expiring-first order: **daily → monthly → addon_subscription → addon**, each needing `>= 1` remaining); if every bucket is empty → `context.fail!(error: :insufficient_credits)`. On a bucket hit it saves one immutable `AiCreditBalanceTransaction` row `entry_type: :ai_summary_usage_debit, bucket:, amount: -1, description: "AI summary generation for application #{job_application_id}"`. The entire multi-call pipeline costs **exactly one credit** regardless of how many LLM calls ran. A `failed`/`retrying` summary reaches neither step 5 nor a debit — no partial charging.

---

## 3. Orchestrator state machine (`Orchestrate#call`)

Loads the `TextractResult`, its `job_application`, and the **newest** `AiJobApplicationSummary` (`order(created_at: :desc).first`; `return unless` present). Dispatches on that summary's `status` — the pipeline is resumable, so a retried/re-enqueued job picks up where it left off:

| Entry status | Action |
|---|---|
| `pending` / `textract_processing` / `extracting` / `retrying` | `run_summary` → `check_criteria_and_score` |
| `summarizing` | if `summary_complete?` (`headline` + `summary_text` present) → `check_criteria_and_score`; else `run_summary` → `check_criteria_and_score` |
| `awaiting_job_criteria` | `check_criteria_and_score` |
| `scoring` | `criteria_results` present → `run_integration`; else `run_scoring` → `run_integration` |
| `integrating` | `run_integration` |
| `succeeded` / `failed` | **no-op** `return` (idempotent stop — never re-charges) |

- `run_summary`: calls `Summary::Generate.new(textract_result_id:).generate`, then `@ai_job_application_summary.reload` (documented deviation from cursor_rules `_base.md` Rule 8 — Generate mutates via its own reference, leaving the orchestrator's copy stale).
- `check_criteria_and_score`: `return if status_failed?`; `return unless summary_complete?`; sets `status: :awaiting_job_criteria`; reads `job.latest_ai_job_criteria`:
  - criteria `status_succeeded?` → `run_scoring` then `run_integration` inline.
  - else → `job.extract_job_criteria` **unless** criteria already `pending`/`in_progress` (debounce), then `return` and **wait**.
- `run_scoring` / `run_integration` each `reload` and `return if status_failed?` before the next paid call; `run_integration` additionally `return unless criteria_results.present?`.

**Resume mechanism:** when criteria later succeed, `AiJobCriteria#resume_waiting_summaries` (`after_commit on: :update`, gated on `saved_change_to_status? && status_succeeded?`) re-enqueues `GenerateAiJobApplicationSummaryJob` for every summary in `awaiting_job_criteria`, which re-enters the machine.

**Status progression (happy path):**
`pending → extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded`
(`retrying` on a retryable error; `failed` terminal.)

---

## 4. CRITERIA EXTRACTION pipeline (per JOB) — builds the rubric

`Job#extract_job_criteria` → `ExtractJobCriteriaJob.perform(ai_job_criteria_id)` → `Scoring::ExtractCriteria#extract`. Also auto-triggered on job **publish** or a meaningful **description change** (Flipper `AI_APPLICANT_SUMMARY`-gated, debounced, `wait: 30.seconds` when a prior criteria exists). Guards: needs `AiJobCriteria`, its `job`, `job.organization`; sets `status: in_progress` (`update_columns`); **fails** if `job.description` blank. Provider **openai** for both calls.

**Call 1 — `jd_structured_data`** · `Prompts::JobDescriptionStructuredData` · **`gpt-4.1-mini-2025-04-14`**
Decomposes the job-description HTML into `sections` (heading / type / inferred_section_type / content) plus `title_technology`. Keeps only sections with `type == 'criteria'`; fails if none.

**Call 2 — `jd_criteria_extraction`** · `Prompts::JobDescriptionCriteriaExtraction` · **`gpt-4o-2024-08-06`**
Extracts atomic criteria from those sections + `title_technology`; each = `{ text, tier (tier_1/2/3), tier_reasoning, binary, contains_title_technology, source_heading, source_text, duplicate }`.

**Post-processing (deterministic code, after Call 2):**
- Strip any leading `[tier_N]` label the model injected into `text` (`\A\s*\[tier_\d+\]\s*:?\s*`).
- **Heading override:** `source_heading` matching `/require|must|essential|minimum/` → force `tier_1` (unless the criterion text is a `SOFT_SKILLS` item); matching `/bonus|optional|extra credit/` → force `tier_3`.
- **Dedup:** record `raw_criteria_count`, drop `duplicate: true`, delete the flag from survivors. Fails if none remain.
- Persist via **`update`** (NOT `update_columns`) so the `after_commit` resume callback fires: `status: succeeded, criteria:, metadata: {title_technology, raw_criteria_count, criteria_count}`.

Error handling: `CustomErrorAiSummary` → `retrying` (`update_columns`) + re-raise (job retries); `JSON::ParserError`/`StandardError` → `failed` + `error_message`.

(Full extraction detail lives in `_manifest/extraction.md`.)

---

## 5. SUMMARY pipeline (per CANDIDATE) — `Summary::Generate` — 4 OpenAI calls

Provider `openai` throughout. Guards: `TextractResult` exists, `textract_job_result_text` present, `job.organization` present. Reuses the newest summary if it is `pending`/`textract_processing`/`extracting`/`retrying` (moving it to `extracting`); otherwise `AiJobApplicationSummary.create(... status: :extracting)`. Every call logs an `AiApiRequest`.

| # | call_type | Prompt class | Model | Runs when | Input | Output written |
|---|---|---|---|---|---|---|
| 1 | `extraction` | `ResumeStructuredData` | `gpt-4o-mini` | always | raw resume text + job title (**full PII** — the only call that sees PII) | `structured_data` (work_experience, education, skills, certifications, stated_experience, etc.); code adds `total_months_experience`; `status → summarizing` |
| 2 | `assessment` | `ResumeAssessment` | `gpt-4o-mini` | only if `work_experience` present | **anonymized** work_experience / education / skills (role-blind) | primary/secondary domain, `experience_classifications`, `career_narrative`, `key_skills`, `standout_accomplishments`; code adds `assessment` + computed `months_by_domain` |
| 3 | `comparison` | `ResumeComparison` | `gpt-4o-mini` | only if `job_title` **and** `months_by_domain` present | months_by_domain, key_skills, career_narrative, job_title, stated_experience (role-aware) | `comparison` = `applicable_experience`, `gaps`, `overlap_summary` |
| 4 | `summary` | `ResumeSummary` | `gpt-4o-mini` | always | **role-blind** — distilled Call-2/Call-3 outputs + anonymized education/certs (no job title) | final `headline`, `summary_text` (from `summary`), and merges `role_analysis`/`applicable_experience`/`gaps`/`overlap_summary` into `structured_data` |

**Deterministic tenure math (no AI):** `parse_date` handles year-only, `M.YYYY`, seasonal ("Fall 2025"), and `present`/`current`/`ongoing` → today; unparseable dates are logged and skipped (never fabricated). `merge_intervals` de-overlaps concurrent roles before summing days (`/30.44`, rounded). `months_by_domain`: primary domain = primary+secondary-classified experiences merged; secondary domain = the secondary subset only.

Call 4 writes `headline`/`summary_text`/`structured_data` but does **not** set a terminal status — it leaves the summary at `summarizing`; the transition to scoring is the orchestrator's job. Errors: `CustomErrorAiSummary` → `update_columns(status: :retrying)` + re-raise; `JSON::ParserError`/`StandardError` → `failed`.

---

## 6. SCORING pipeline (per CANDIDATE) — `Scoring::ScoreJobApplication` — Gemini + OpenAI

Entry `new(ai_job_application_summary:, textract_result:).score`; `return unless` both present. Provider `gemini` for the scoring + display calls.

**Criteria gating (governs the "Awaiting job criteria" UI state), in order:**
- criteria blank OR `status_failed?` → summary `status: awaiting_job_criteria`, call `job.extract_job_criteria`, return.
- criteria `pending`/`in_progress`/`retrying` → `awaiting_job_criteria`, return (wait).
- else → summary `status: scoring`.
- (after building the profile) criteria present but `criteria` array blank → mark criteria `failed` (`update_columns`), summary `awaiting_job_criteria`, re-trigger `job.extract_job_criteria`, return.

Requires `structured_data` on the summary (raises `CustomErrorAiSummary` "Structured data missing" if absent — the SUMMARY pipeline must have run first). Re-anonymizes `structured_data` via `AnonymizeForAi` and builds a text `candidate_profile` (professional summary, stated experience, work experience, education, skills, certifications) — **still no PII**.

**Scoring call — `scoring`** · `Prompts::JobApplicationScoring` · Gemini **`gemini-3.1-flash-lite`**
`messages(criteria:, candidate_profile:)` → `scores[]`, each `{ criterion_text, tier, score ∈ full_match/partial_match/not_found, reasoning }`. `run_scoring` strips any leaked `[tier_N]` prefix from `criterion_text`, merges `contains_title_technology` back from the source criterion by matching `text`, and computes a per-run `score_percentage` via `Scoring::Calculate.compute` (§7). Returns `{criteria_results:, score_percentage:}` or `nil` on any error.

**MEDIAN-OF-5 near boundaries:** the first run runs always (`raise "Scoring call failed"` if it returns nil; `raise "Scoring returned no score_percentage"` if its score is nil). `boundaries = FIT_LABELS.map(&:first).reject(&:zero?)` = **[90, 60, 35, 15]**. If the first score is within **5 points** of any of these (`(first_score - b).abs <= 5`), run **4 more** scoring calls, `sort_by { score_percentage }`, and select the **median** run (`sorted[len/2]`). A failed extra run just drops from the set. Well inside a band → **1** scoring call only. (Borderline candidates therefore cost 5× the scoring call.)

**Display call — `scoring_display`** · `Prompts::ScoringDisplay` · Gemini **`gemini-3.1-flash-lite`**
Rewrites each scored criterion of the *selected* run into one recruiter-style `display_sentence` citing concrete evidence. Merged into the selected run's results by `criterion_text` (missing match → `display_sentence: ''`).

Writes `score_percentage`, `criteria_results`, `status: integrating` via `update` (raises `CustomErrorAiSummary` on failure). Errors mirror Generate (`retrying`+raise / `failed`).

**Final narrative — `integrated_analysis`** · `Scoring::IntegrateAnalysis` · `Prompts::IntegratedAnalysis` · OpenAI **`gpt-4.1-mini-2025-04-14`**
Reads `role_analysis`, `applicable_experience`, `gaps`, `overlap_summary`, `assessment.career_narrative`, `assessment.key_skills`, `assessment.standout_accomplishments`, `criteria_results`, and `score_percentage`; produces `integrated_role_analysis` (the paragraph shown on the candidate card) and sets `status: succeeded`. Tone is gated by the fit label (§7); the opening-sentence template is `.sample`d per call (`BEGINNING_TEMPLATES` / `MIXED_TEMPLATES`) → **phrasing varies run-to-run** (expected non-determinism).

---

## 7. Scoring math (`Scoring::Calculate.compute`) + fit labels

Pure, deterministic. Per criterion:
- **Tier weight:** `TIER_WEIGHTS = { tier_1: 6, tier_2: 4, tier_3: 2 }` (unknown tier → tier_2 weight = 4).
- **Match value:** `SCORE_VALUES = { full_match: 1.0, partial_match: 0.7, not_found: 0.0 }` (unknown score → 0.0).
- **Title-technology multiplier:** a criterion with `contains_title_technology: true` has its weight ×**3** (`TITLE_TECHNOLOGY_MULTIPLIER`).
- `effective_weight = weight × multiplier`; `total_weighted_score += effective_weight × value`; `max_possible += effective_weight`.
- **`score_percentage = round(total_weighted_score / max_possible × 100, 2)`**; returns `nil` if input blank or `max_possible` is 0.

**Fit labels** (`IntegratedAnalysis::FIT_LABELS`, evaluated as `find { |threshold, _| score >= threshold }` over descending thresholds — so **lower-inclusive**; these thresholds double as the median-of-5 boundaries and the `JobApplication` fit-band filter scopes):

| score_percentage | label |
|---|---|
| ≥ 90 | excellent fit |
| ≥ 60, < 90 | good fit |
| ≥ 35, < 60 | mixed fit |
| ≥ 15, < 35 | weak fit |
| < 15 (incl. 0) | poor fit |

---

## 8. What the candidate ultimately gets (persisted on `AiJobApplicationSummary`)

- **`score_percentage`** (decimal) — the weighted % from §7.
- **`headline`** + **`summary_text`** — Call 4 of the SUMMARY pipeline.
- **`criteria_results`** (jsonb) — per-criterion `{criterion_text, tier, contains_title_technology, score, reasoning, display_sentence}`.
- **`integrated_role_analysis`** (text) — the fit-gated recruiter narrative.
- **`structured_data`** (jsonb) — extracted profile + `role_analysis`, `gaps`, `applicable_experience`, `overlap_summary`, `assessment`, `comparison`, `months_by_domain`, `total_months_experience`.

**Display sync on any status change** (`AiJobApplicationSummary#handle_after_update_commit`, `after_commit on: :update`, gated on `saved_changes.key?('status')`):
- `update_summary_status_record`: on **`succeeded`** copies `score_percentage`/`headline`/`integrated_role_analysis` onto the companion `AiJobApplicationSummaryStatus` and sets it `current` (with `ai_job_application_summary_id: id`). On **`failed`**: `initial_summary_pending → none`; `regenerating → current` (a prior succeeded review stays accessible); other status-row states untouched. (There is deliberately no `failed` state on the status row.)
- `broadcast_status_change`: `JobChannel.broadcast_to(job, event: 'ai_summary_status_change', payload: {jobApplicationId, aiJobApplicationSummaryId, hiringStageId})` for live list/table update (gated by `BROADCAST_STATUSES`).
- `destroy_previous_textract_results` also runs here.

(Separately, the manual-generation path's `GenerateAiJobApplicationSummaryJob` broadcasts a `GlobalChannel` `AI_SUMMARY_COMPLETE` toast to the requesting user on `succeeded`/`failed` — §2.)

---

## 9. Providers, cost ledger, bias controls

**Dispatch:** `AiClient.new(provider:).chat(messages:, model:, response_format:)` resolves a provider from `PROVIDERS` (`constantize`; unknown → `KeyError`) and returns `{content, input_tokens, output_tokens, model}`. Non-200 / `Faraday::Error` / `JSON::ParserError` → raised as `CustomErrorAiSummary`.
- **OpenAI** — `POST /v1/chat/completions`, body always `temperature: 0` (deterministic), Faraday `timeout: 120` / `open_timeout: 30`. Used for: all 4 summary calls, both criteria-extraction calls, integrated_analysis.
- **Gemini** — OpenAI-compat `POST /v1beta/openai/chat/completions`, **no** temperature set (provider default), no custom timeouts. Used for: scoring + scoring_display calls.
- Both read tokens from `usage.prompt_tokens`/`usage.completion_tokens`, content from `choices[0].message.content`, and **`model` from the API response (`parsed['model']`)** — i.e. the resolved dated snapshot, not the request alias.

**Cost ledger:** every LLM call writes an `AiApiRequest` (`organization`, `requestable` = summary or criteria, `call_type`, `provider`, `model`, `input_tokens`, `output_tokens`, `cost = AiClient.calculate_cost(...).to_f.round(6)`, `prompt_text`, `response_body`). `PRICING` (per 1M input/output tokens): `gpt-4o-2024-08-06` 2.50/10, `gpt-4o-mini-2024-07-18` 0.15/0.60, `gpt-4.1-mini-2025-04-14` 0.40/1.60, `gemini-3.1-flash-lite` 0.25/1.50. **Note:** the summary calls pass the alias `gpt-4o-mini`, which is absent from `PRICING`; cost resolves correctly only because OpenAI's response echoes the dated snapshot `gpt-4o-mini-2024-07-18`, which is the model stored on `AiApiRequest`. A model not in the table yields `nil` cost (→ 0.0). This ledger is usage/cost tracking only — **separate from** credit consumption (§2), which is a flat 1 credit per succeeded pipeline.

**Bias controls (QA-checkable):** `AnonymizeForAi` deletes `%w[name email phone location links]` from a deep-dup of `structured_data` before summary Calls 2–4 and before all scoring calls — only summary Call 1 (extraction) sees PII. Criteria extraction never sees candidate data at all (job description only). Scoring/summary/display/integration prompts forbid pronouns and the word "resume", bar `partial_match` when a criterion names a specific tool with no alternative, and treat multilingualism as not communication-skill evidence. Candidate name/email/phone must never surface in `summary_text`, `criteria_results`, or `integrated_role_analysis`.

---

## 10. Per-candidate AI call count (cost model)

- Criteria extraction: **2 OpenAI calls per JOB** (amortized across all candidates on that job; not re-run per candidate once succeeded).
- Summary: **2–4 OpenAI calls** (Calls 2 and 3 are conditional on `work_experience` / `job_title`).
- Scoring: **1 or 5 Gemini scoring calls** (5 only near a fit boundary) **+ 1 Gemini display call**.
- Integration: **1 OpenAI call**.
- **Credits: exactly 1 per succeeded candidate**, no matter how many LLM calls ran (and 0 for `failed`/`retrying`).
