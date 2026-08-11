# Plato — AI Candidate Review: End-to-End Backend

Source: inflow-ats `develop` (verified on branch `qa-refinements`, byte-identical to `origin/develop`). All identifiers, models, and thresholds below were read directly from code.

---

## 0. What it is (stakeholder / customer framing)

When a candidate applies (or a recruiter asks), **Plato** reads the résumé, writes a plain-language summary, and scores the candidate against that specific job's requirements — producing a fit percentage, a fit label (excellent → poor), and a per-requirement breakdown with evidence. Every candidate is scored **blind**: name, email, phone, location, and profile links are stripped before any evaluative AI call, so scores reflect qualifications only.

There are **two AI subsystems** that meet in the middle:

- **Job Criteria Extraction** — runs once per *job*. Turns the job description into a structured, tiered list of scoring criteria.
- **Candidate Summary + Scoring** — runs once per *application*. Turns the résumé into a summary, then scores it against the job's criteria.

Both are metered: every model call is logged to `AiApiRequest` with tokens + cost, and each successful candidate review consumes **1 AI credit**.

---

## 1. The two subsystems

### A. Job Criteria Extraction — `AiJobApplicationAction::Scoring::ExtractCriteria` (per `Job` → `AiJobCriteria`)

Input: the job's `description` (HTML). Two OpenAI calls + deterministic Ruby post-processing:

**Call 1 — `JobDescriptionStructuredData`** (`gpt-4.1-mini-2025-04-14`, `call_type: jd_structured_data`)
Splits the JD into sections by heading, tags each section `criteria` vs `non_criteria` (company/benefits/culture/process/legal are non-criteria), and extracts `title_technology` (a specific language/framework/platform named in the job title, e.g. "React", "Salesforce" — generic terms like "backend"/"senior" excluded). Only `criteria`-typed sections continue.

**Call 2 — `JobDescriptionCriteriaExtraction`** (`gpt-4o-2024-08-06`, `call_type: jd_criteria_extraction`)
Decomposes sections into **atomic criteria**. Per criterion it returns: `text`, `tier` (tier_1/2/3), `tier_reasoning`, `binary` (met-or-not vs. spectrum), `contains_title_technology`, `duplicate`, `source_heading`, `source_text`. Compound requirements get split; "or" lists stay whole; duplicates get marked (less-specific version flagged, more-specific survives inheriting the higher tier).

**Tiering logic** (in prompt): heading-locked (Required/Must/Essential/Minimum → tier_1; Preferred/Nice-to-have → tier_2; Bonus/Optional → tier_3), with inline signal words for neutral headings. Hard rule: **soft skills cap at tier_2** regardless of heading.

**Ruby post-processing** (`extract_criteria.rb`): strips any stray `[tier_x]` labels from `text`; a **code-level heading override** re-forces tier_1 for require/must/essential/minimum headings (skipping soft skills) and tier_3 for bonus/optional; drops duplicates. Result saved to `AiJobCriteria` (`status: succeeded`, `criteria` jsonb, `metadata`). Saved with `update` (not `update_columns`) specifically so its `after_commit` fires and **resumes any candidate summaries parked waiting on criteria**.

### B. Candidate Summary + Scoring (per `JobApplication` → `AiJobApplicationSummary`)

Driven by a resumable state machine, `AiJobApplicationAction::Orchestrate`, keyed on the summary's `status`. It runs: **summary → (wait for criteria) → scoring → integration**. Detailed below.

---

## 2. Every step, front to back

### Step 1 — Triggers (four entry points)

| Path | Trigger | Chain |
|---|---|---|
| **Auto (new application)** | `JobApplication` `after_commit on: :create` → `enqueue_new_job_application` | Submits résumé to Textract; if the job has auto-generate on, pre-builds a `textract_processing` summary row |
| **Auto (résumé replaced)** | `JobApplicationsController#update` when a new `resume` is attached | Marks old summaries stale, re-submits to Textract |
| **Manual (one candidate)** | `POST /api/v1/job_applications/:id/ai_job_application_summaries` | `ValidateAiSummaryGeneration` → `CreateAiSummaryGeneration` → `GenerateAiJobApplicationSummaryJob` (passes `requesting_organization_user_id` → drives the completion toast) |
| **Bulk** | `POST /api/v1/bulk_ai_job_application_summaries` (+ `/all_stages`) | `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob` (JobIteration) → per-candidate `CreateBulkAiSummaryGeneration` + inline `generate_ai_summary_with_credit_flow`; claims tracked in `BulkAiSummaryJobApplication` |

`.docx` résumés route through `DocxToPdfJob` first (Textract never sees raw `.docx`). All Textract paths are gated on Flipper `:TEXTRACT_RESUME_PROCESSING`.

**Criteria extraction is triggered separately**: `Job` `after_commit on: :update` fires `auto_extract_job_criteria` when the job is **published** or its **description meaningfully changes** (HTML-normalized compare). Because a job can never be *created* in a published state, the publish transition (always a later `update`) is what fires the first extraction; it is also called defensively at pipeline start (`extract_job_criteria_if_needed`) and from the scorer if criteria are missing.

### Step 2 — Résumé ingestion (AWS Textract)

`SubmitResumeToTextractJob` → `SubmitResumeToTextract#submit_resume`: sends the résumé to AWS Textract, creates a `TextractResult` (`in_progress`), links the waiting summary, and schedules `GetResumeTextFromTextractJob` **2 minutes later**. That job (`GetResumeTextFromTextract#parse_resume_text`) polls Textract; on success it writes `textract_job_result_text`. On not-ready/failed it raises `CustomErrorTextract` → retry (**5 min × 3**); on exhaustion the summary is marked `failed`.

Writing `textract_job_result_text` fires `TextractResult` `after_commit → queue_ai_summary_job`, which validates and enqueues `GenerateAiJobApplicationSummaryJob`.

### Step 3 — The credit-flow hub

`GenerateAiJobApplicationSummaryJob#perform` is a thin dispatcher over `TextractResult#generate_ai_summary_with_credit_flow`, which:
1. Bails if a fresh succeeded summary already exists.
2. Kicks off criteria extraction if needed (runs **in parallel** with the summary).
3. Ensures the read-model status row exists, sets it `initial_summary_pending`.
4. Runs the pipeline (`Orchestrate`).
5. **On success only**, consumes 1 credit via `CreateAiCreditBalanceTransaction`.

### Step 4 — Summary pipeline (`Summary::Generate`, 4 OpenAI calls, all `gpt-4o-mini`)

| # | Prompt | Sees PII? | Produces |
|---|---|---|---|
| 1 | `ResumeStructuredData` (`call_type: extraction`) | **Yes** (mechanical extraction only) | name/email/phone/location/links, professional_summary, `stated_experience`, work_experience, education, skills, certifications |
| 2 | `ResumeAssessment` (`assessment`) | No (anonymized) | primary/secondary/tertiary **domain** hierarchy, per-experience classification, key_skills, `career_narrative`, standout_accomplishments — deliberately **role-blind** (no job title given) |
| 3 | `ResumeComparison` (`comparison`) | No | `applicable_experience`, `gaps`, `overlap_summary` — **role-aware** (gets the job title) |
| 4 | `ResumeSummary` (`summary`) | No | `headline` (<80 char), `summary` (2–3 sentences), `role_analysis` — receives only distilled Call 2 + Call 3 output, **never raw résumé or job title** |

Between calls, Ruby computes tenure deterministically: `total_months_experience` and `months_by_domain` via **date parsing + interval merging** (handles "Present", "Fall 2025", "4.2023", year-only, etc.). No year counts are ever invented by the model — only the candidate's own `stated_experience` claim may be quoted.

Persists `headline`, `summary_text`, and `structured_data`; status advances `extracting → summarizing`, then to `awaiting_job_criteria`.

### Step 5 — Scoring (`Scoring::ScoreJobApplication`)

Guards on `job.latest_ai_job_criteria`: if blank/failed → set `awaiting_job_criteria` and trigger extraction; if still in progress → wait. Once criteria are `succeeded`:

1. Anonymize `structured_data` → build a plain-text `candidate_profile`.
2. **`JobApplicationScoring`** (`gemini-3.1-flash-lite`, `call_type: scoring`): per criterion → `full_match` / `partial_match` / `not_found` + evidence-cited `reasoning` (must cite specific companies/titles/metrics; no pronouns; never the word "resume").
3. **Score math** — `Scoring::Calculate.compute` (pure Ruby):
   - Tier weights: **tier_1 = 6, tier_2 = 4, tier_3 = 2**
   - Match values: **full = 1.0, partial = 0.7, not_found = 0.0**
   - Title-technology criteria get a **×3 weight multiplier**
   - `score% = Σ(weight × mult × value) / Σ(weight × mult) × 100`
4. **Boundary stability**: if the first score lands within **5 points** of a fit boundary (90/60/35/15), it runs **5 total** scoring passes and takes the **median** — protects the fit label from single-call jitter.
5. **`ScoringDisplay`** (`gemini-3.1-flash-lite`, `scoring_display`): rewrites each criterion result into a recruiter-voice `display_sentence` with concrete evidence. Merged into `criteria_results`. Status → `scoring → integrating`.

### Step 6 — Integration (`Scoring::IntegrateAnalysis`)

**`IntegratedAnalysis`** (`gpt-4.1-mini-2025-04-14`, `call_type: integrated_analysis`): reconciles the Step 4 `role_analysis` with the Step 5 scoring so they don't contradict, and produces `integrated_role_analysis` (<600 chars). A **fit-label-driven framing sentence** opens it (template chosen by band; weak/poor lead with gaps). Strict output rules: no score numbers, no tier/criteria jargon, no pronouns, no "resume". Status → `succeeded`.

### Step 7 — Finalize

On `succeeded`:
- `update_summary_status_record` writes the **read model** (`AiJobApplicationSummaryStatus` → `current`, copying `score_percentage`, `headline`, `integrated_role_analysis`).
- Older non-succeeded `TextractResult`s are destroyed.
- 1 credit consumed (bucket order **daily → monthly → addon_subscription → addon**, via an immutable `AiCreditBalanceTransaction amount: -1`; `counter_culture` decrements the balance in the same save).
- Websocket broadcasts fire (`AI_SUMMARY_COMPLETE` toast on the manual path; live list refresh via `JobChannel`).

---

## 3. Reference tables (for spec expansion)

### Model / provider roster (exactly what's in code)

| Stage | Class | Provider | Model |
|---|---|---|---|
| JD → sections | `JobDescriptionStructuredData` | OpenAI | `gpt-4.1-mini-2025-04-14` |
| Sections → criteria | `JobDescriptionCriteriaExtraction` | OpenAI | `gpt-4o-2024-08-06` |
| Résumé → structured | `ResumeStructuredData` | OpenAI | `gpt-4o-mini` |
| Domain assessment | `ResumeAssessment` | OpenAI | `gpt-4o-mini` |
| Role comparison | `ResumeComparison` | OpenAI | `gpt-4o-mini` |
| Headline/summary | `ResumeSummary` | OpenAI | `gpt-4o-mini` |
| Criterion scoring | `JobApplicationScoring` | Gemini | `gemini-3.1-flash-lite` |
| Display sentences | `ScoringDisplay` | Gemini | `gemini-3.1-flash-lite` |
| Integration | `IntegratedAnalysis` | OpenAI | `gpt-4.1-mini-2025-04-14` |

OpenAI calls run `temperature: 0` (120s timeout); Gemini uses provider default. All 9 calls are structured-output (strict JSON schema).

### Fit bands (`FIT_LABELS` backend == `AiJobApplicationSummaryStatus` scopes)

| Score | Label |
|---|---|
| ≥ 90 | excellent |
| 60–89 | good |
| 35–59 | mixed |
| 15–34 | weak |
| 0–14 | poor |

### Status machines

- `AiJobApplicationSummary`: `pending → textract_processing → extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded` (+ `retrying`, `failed`)
- `AiJobCriteria`: `pending → in_progress → succeeded` (+ `failed`, `retrying`)
- `AiJobApplicationSummaryStatus` (read model, one per application): `none / initial_summary_pending / current / regenerating`

### Credit gating

`ValidateAiSummaryGeneration`: Flipper `:AI_APPLICANT_SUMMARY` on **AND** résumé present **AND** total credit balance > 0 **AND** job has a description. Cost = **1 credit per succeeded review**; plan tier affects credit *allocation*, not access.

### Reliability

Summary/criteria jobs `retry_on CustomErrorAiSummary` (2 min × 3); Textract `retry_on CustomErrorTextract` (5 min × 3). `Orchestrate` is idempotent — each stage sets `retrying` on transient failure and re-raises, and the state machine resumes from the persisted `status` on retry.

### Persistence

- `ai_job_application_summaries` (structured_data, headline, summary_text, score_percentage, criteria_results, integrated_role_analysis, stale, requested_by_organization_user_id, status, error_message)
- `ai_job_criteria` (criteria, metadata, status)
- `ai_job_application_summary_statuses` (read model, unique per application)
- All model calls logged to `ai_api_requests` (call_type, provider, model, tokens, cost, prompt, response)

---

## 4. Notes for spec expansion

1. **Billing guarantee (not a risk).** A customer is charged **1 credit if and only if a scoring process runs all the way through to `succeeded`** (the final `IntegrateAnalysis` stage). `generate_ai_summary_with_credit_flow` does `return unless ai_job_application_summary&.status_succeeded?` before calling `CreateAiCreditBalanceTransaction`, so any failure or retry short of completion takes no credit. The bulk path enforces the same guard (it calls the same method inline). The debit itself is a **single atomic write**: `AiCreditBalanceTransaction.save` inserts the immutable ledger row and `counter_culture` decrements `#{bucket}_credits_remaining` in the same save's transaction. There is deliberately no DB transaction spanning the pipeline and the debit — the pipeline is 9 external OpenAI/Gemini calls across separate Sidekiq runs and retry boundaries, so no Postgres transaction could (or should) wrap it.

2. **Dead prompt files.** `Summary::Prompts::ResumeRelevance` and `RoleCategorization` exist in the tree but are referenced nowhere — treat as removed / ignore in any spec.

---

## File chain traced

`job_application.rb` → `submit_resume_to_textract_job.rb` → `submit_resume_to_textract.rb` → `get_resume_text_from_textract_job.rb` → `get_resume_text_from_textract.rb` → `textract_result.rb#generate_ai_summary_with_credit_flow` → `ai_job_application_action/orchestrate.rb` → `summary/generate.rb` (+ 4 `summary/prompts/*`) → `scoring/score_job_application.rb` (+ `scoring/prompts/job_application_scoring.rb`, `scoring_display.rb`, `scoring/calculate.rb`) → `scoring/integrate_analysis.rb` (+ `scoring/prompts/integrated_analysis.rb`).

Criteria side: `job.rb#extract_job_criteria*` → `extract_job_criteria_job.rb` → `scoring/extract_criteria.rb` (+ `scoring/prompts/job_description_structured_data.rb`, `job_description_criteria_extraction.rb`).

Credit / gating: `validate_ai_summary_generation.rb`, `create_ai_credit_balance_transaction.rb`, `organization_ai_credit_balance.rb`, `find_or_create_ai_job_application_summary_status.rb`.

Models: `ai_job_application_summary.rb`, `ai_job_criteria.rb`, `ai_job_application_summary_status.rb`, `ai_api_request.rb`. Schema: `db/schema.rb`.
