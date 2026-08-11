# Layer 1 — Diff-to-Spec: AiApiRequest Tracking

**Focus area:** AiApiRequest creation in `ExtractStructuredResumeData`, polymorphic association on `TextractResult`, analog fidelity to `AiJobApplicationAction::Summary::Generate#create_ai_api_request`.

## Checklist

| # | Spec requirement | Code | Status |
|---|-----------------|------|--------|
| 1 | `requestable: textract_result` (TextractResult, not AiJobApplicationSummary) | `requestable: @textract_result` (line 96) | MATCH |
| 2 | `call_type: 'keyword_extraction'` (distinct from summary pipeline's `'extraction'`) | `call_type: 'keyword_extraction'` (line 97) | MATCH |
| 3 | `provider: 'openai'` | `provider: 'openai'` (line 98) | MATCH |
| 4 | `model` from API-returned result | `model = result[:model]` (line 90) | MATCH |
| 5 | `input_tokens` / `output_tokens` from result, default 0 | `result[:input_tokens] \|\| 0`, `result[:output_tokens] \|\| 0` (lines 91-92) | MATCH |
| 6 | `cost` via `AiClient.calculate_cost` with `.to_f.round(6)` | Exact match (line 102) | MATCH |
| 7 | `prompt_text: messages.to_json` | `prompt_text: messages.to_json` (line 103) | MATCH |
| 8 | `response_body: result[:content]` | `response_body: result[:content]` (line 104) | MATCH |
| 9 | `organization` from `textract_result.job_application&.job&.organization`, guard: return early if nil | Resolved at line 13, guard at line 14 | MATCH |
| 10 | `has_many :ai_api_requests, as: :requestable` on TextractResult | `textract_result.rb:8` | MATCH |

## Analog comparison

**Analog:** `app/services/ai_job_application_action/summary/generate.rb:296-313`

The analog parameterizes `ai_summary`, `call_type`, `provider` because it makes 4 API calls with different call types. The new service hardcodes `call_type: 'keyword_extraction'`, `provider: 'openai'`, and uses `@textract_result` directly — appropriate since there's only one call.

The `AiApiRequest.create(...)` call body matches the analog field-for-field: `organization`, `requestable`, `call_type`, `provider`, `model`, `input_tokens`, `output_tokens`, `cost`, `prompt_text`, `response_body`. Same calculation pattern for cost.

**Polymorphic pattern verified:** `AiApiRequest` model (`app/models/ai_api_request.rb:5`) has `belongs_to :requestable, polymorphic: true`. Three other models already use `has_many :ai_api_requests, as: :requestable`: `AiJobApplicationSummary`, `AiJobCriteria`, and now `TextractResult`.

## Note for Layer 2

The analog creates the AiApiRequest immediately after the API call (generate.rb:56) BEFORE parsing JSON (line 58). The new service creates it only after both JSON parsing AND `textract_result.update(...)` succeed (line 37). If `JSON.parse` raises, the API cost goes untracked. This is not a spec deviation (the spec doesn't prescribe ordering), but a code correctness concern for Layer 2.

---

**VERDICT: CLEAN — 0 findings**
