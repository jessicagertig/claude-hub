# Slice: LLM/model pipeline — providers, ai_client, textract, relevance benchmark

## Files
- `app/services/ai_client.rb` (new)
- `app/services/ai_providers/{openai,gemini,anthropic,deepseek,mistral}.rb` (new)
- `app/services/ai_relevance_benchmark.rb` (new — dev/benchmark tool, NOT user-facing)
- `app/services/submit_resume_to_textract.rb` (modified)
- `app/services/get_resume_text_from_textract.rb` (modified)

## AiClient — the provider dispatcher
- `AiClient.new(provider:)` fetches a provider class from `PROVIDERS` (`openai`/`deepseek`/`mistral`/`gemini`/`anthropic`) and `constantize`s it. Unknown provider → `KeyError` from `PROVIDERS.fetch`.
- `#chat(messages:, model:, response_format: nil)` delegates to the provider's `chat`.
- `.calculate_cost(model:, input_tokens:, output_tokens:)` uses the `PRICING` table (cost per 1M tokens, input/output). Returns `nil` for any model not in the table (used only for benchmark cost display).
- **PRICING table models** (name → input/output $/1M): `gpt-4o-2024-08-06` 2.50/10, `gpt-4o-mini-2024-07-18` 0.15/0.60, `gpt-4.1-mini-2025-04-14` 0.40/1.60, `gemini-3.1-flash-lite` 0.25/1.50, `gemini-3.5-flash` 1.50/9, `deepseek-chat` 0.27/1.10, `mistral-large-latest` 2/6, `gemini-2.5-flash` 0.15/0.60, `claude-haiku-4-5-20251001` 0.80/4, `claude-sonnet-4-20250514` 3/15.

## Provider adapters — uniform contract
All five expose `chat(messages:, model:, response_format: nil)` returning a hash:
`{ content:, input_tokens:, output_tokens:, model: }`. On non-200 they raise `CustomErrorAiSummary` with the API's `error.message` (or a generic string). `Faraday::Error` and `JSON::ParserError` are also caught and re-raised as `CustomErrorAiSummary` (connection/parse error). All log via `Rails.logger.error` + `ap`.

Provider-by-provider details (exact, for the manifest):
- **Openai** — `POST https://api.openai.com/v1/chat/completions`. Body always includes `temperature: 0`; `response_format` added when passed. Auth `Bearer Variables::OPENAI_API_KEY`. Faraday timeouts: `timeout=120`, `open_timeout=30`. Tokens from `usage.prompt_tokens`/`usage.completion_tokens`; content from `choices[0].message.content`.
- **Gemini** — `POST https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` (OpenAI-compat endpoint). Body = model+messages (+`response_format` if passed), NO temperature. Auth `Bearer Variables::GEMINI_API_KEY`. Same token/content paths as OpenAI. No custom timeouts.
- **Deepseek** — `POST https://api.deepseek.com/v1/chat/completions`. Same shape as Gemini. Auth `Bearer Variables::DEEPSEEK_API_KEY`.
- **Mistral** — `POST https://api.mistral.ai/v1/chat/completions`. Same shape. Auth `Bearer Variables::MISTRAL_API_KEY`.
- **Anthropic** — `POST https://api.anthropic.com/v1/messages` (Messages API, different shape). Splits out the `system` role message into a top-level `system` field; remaining messages go in `messages`. `max_tokens: 4096` hardcoded. When `response_format` is set, appends "IMPORTANT: Return ONLY valid JSON. No markdown fences…" to the system text (Anthropic has no native JSON mode here). Content from `content[0].text`; tokens from `usage.input_tokens`/`usage.output_tokens`. Headers `x-api-key`, `anthropic-version: 2023-06-01`. NO custom timeouts.

Note: only OpenAI sets `temperature: 0`; the others rely on provider defaults. Only OpenAI sets Faraday timeouts.

## AiRelevanceBenchmark — dev/eval harness, NOT wired to any UI/controller
- Instantiated with `test_cases:` + optional `output_path:`; run via console/rake, writes JSON to `output_path`. Reuses the real `AiJobApplicationAction::Summary::Generate` pipeline for helper math (`calculate_months_by_domain`, `calculate_total_months`, `format_months`) and the real prompt classes (`Summary::Prompts::ResumeAssessment/ResumeComparison/ResumeSummary`).
- **Confirms the production summary-scoring pipeline call order** (Calls 2→3→4; Call 1 = extraction is outside this slice):
  - **Call 2 Assessment (role-blind)** — input: work_experiences, education, skills → output `primary_domain, secondary_domain, primary_indices, secondary_indices, key_skills, career_narrative, standout_accomplishments`; then `calculate_months_by_domain`. Benchmark models: `gpt-4o-mini` (openai), `gemini-2.5-flash`.
  - **Call 3 Comparison (role-aware)** — input: months_by_domain, key_skills, career_narrative, job_title → output `applicable_experience, gaps, overlap_summary`. Benchmark models: `gpt-4o-mini`, `claude-haiku-4-5-20251001`, `claude-sonnet-4-20250514`.
  - **Call 4 Summary (role-blind)** — input: total_experience (formatted), career_narrative, months_by_domain, key_skills, standout_accomplishments, applicable_experience, gaps, overlap_summary, education, certifications → output `headline, summary`. Benchmark models: haiku, sonnet.
- Each call uses first successful prior-call output as input; if all fail, later calls are skipped. `clean_json` strips ```json fences. 0.5s sleep between models. Cost via `AiClient.calculate_cost`.
- **QA relevance:** the benchmark's per-call prompt inputs/outputs and the 2→3→4 ordering ARE the source of truth for the scoring manifest; the models/providers actually used in production live in `AiJobApplicationAction::Summary::*` (out of this slice), not in these benchmark constants.

## Textract changes — USER-VISIBLE (resume-text extraction feeding AI summaries)

### submit_resume_to_textract.rb
- OLD: found any single `TextractResult` for the job application and DESTROYED it before building a new one.
- NEW: no longer destroys prior TextractResults. Instead, unless an `ai_job_application_summary` is already actively `textract_processing` (and not stale), it marks all of that application's `ai_job_application_summaries` as `stale: true` (`update_all`). Builds a new `TextractResult`; on save, finds a waiting summary (`status: :textract_processing, stale: false, textract_result_id: nil`) and links it via `update_columns(textract_result_id:)`, then enqueues `GetResumeTextFromTextractJob` with a 2-minute delay.
- **Effect:** multiple TextractResults per application now accumulate (history retained instead of destroyed). Summaries created while extraction is pending get linked to the fresh TextractResult so the AI summary flow resumes once text is ready.

### get_resume_text_from_textract.rb
- Now selects the LATEST TextractResult (`order(created_at: :desc).first`) instead of `.first` — required because prior results are no longer destroyed.
- NEW guard: if the latest TextractResult has a nil `textract_job_id`, it re-enqueues `SubmitResumeToTextractJob` and returns (self-heals a half-created record).
- On Textract SUCCEEDED: switched from `update_columns` to `update` (runs validations/callbacks) and logs failure with `errors.full_messages` if the update fails. FAILED path still uses `update_columns(textract_job_status: 'failed')`.
- Adds an `ap` log of the AWS Textract job status.

## SHARED / non-AI regression surfaces
- **`TextractResult` lifecycle change** — prior results are no longer destroyed and `submit` now `update_all(stale: true)` on `ai_job_application_summaries`. Any code assuming one TextractResult per JobApplication, or reading `textract_results.first`, could now read a stale/older row. The two textract services here were updated to `.order(created_at: :desc).first`, but other readers of `textract_results.first` elsewhere in the app are a regression risk.
- **`GetResumeTextFromTextract` update path** switched `update_columns`→`update`: now fires TextractResult validations/callbacks that previously were bypassed — could newly fail/side-effect on save.
- `Variables::*_API_KEY` env constants must be present for each provider (empty key → 401 surfaced as `CustomErrorAiSummary`).

## Edge cases / gates
- Provider `chat` non-200 or malformed JSON → `CustomErrorAiSummary` (propagates to the AI summary job's error handling).
- Anthropic JSON-mode is prompt-enforced only (no API-level guarantee) → higher chance of parse errors than OpenAI/Gemini/etc.
- `calculate_cost` returns nil for models absent from PRICING (benchmark display only; no user impact).
- Textract nil `textract_job_id` → auto re-submit; latest-result ordering assumes `created_at` monotonicity.
