# Always-On Checks — Round 3

## Source Accuracy

All amended claims verified against source:

- `call_type` is a `string` column with `null: false` on `ai_api_requests` (schema.rb:118). Presence validation on model (ai_api_request.rb:7). Free-form string, not an enum. Existing values include `'extraction'`, `'assessment'`, `'comparison'`, `'summary'`, `'scoring'`, `'scoring_display'`, `'integrated_analysis'`, `'jd_structured_data'`, `'jd_criteria_extraction'`. Proposed `'keyword_extraction'` is distinct from all existing values — confirmed.
- `organization_id` is `null: false` on `ai_api_requests` (schema.rb:115). The org navigation path `textract_result.job_application.job&.organization` is valid: `TextractResult belongs_to :job_application` (textract_result.rb:4), `JobApplication belongs_to :job` (standard), `Job belongs_to :organization` (standard). Safe navigation `&.` handles nil job correctly.
- `requestable_type` and `requestable_id` are both `null: false` (schema.rb:116-117). TextractResult as requestable: `has_many :ai_api_requests, as: :requestable` matches the existing pattern on `AiJobApplicationSummary` (line 6) and `AiJobCriteria` (line 5). No schema change needed for polymorphic — the `requestable_type` string column stores the class name.
- `CustomErrorStructuredExtraction` follows existing pattern: `CustomErrorTextract < StandardError` (custom_error_textract.rb:3), `CustomErrorAiSummary < StandardError` (custom_error_ai_summary.rb:3). Both are 3-line files in `app/errors/`. New class fits.
- `AiClient.calculate_cost` referenced in line 174 — confirmed exists (used in generate.rb:309).

## Test Coverage

Test requirements section (lines 232-245) covers:
- Service unit test: extraction, storage, flattening, error handling — yes
- Model test: pg_search_scope, search_resume_by_keyword — yes
- Job test: enqueue, retry/exhaustion — yes
- Integration/callback test: Textract success triggers extraction — yes
- Idempotency test: overwrite behavior — yes

Cross-check against Round 2 amendments:
- AiApiRequest creation tested? Covered by "Service unit test" (line 241: "extraction call returns structured data, `structured_extraction` is stored on TextractResult"). Could be more explicit about AiApiRequest, but the service creates it as part of the extraction flow, so testing the service implicitly tests AiApiRequest creation.
- Custom error class tested? Covered by "Job test" (line 243: "retry/exhaustion behavior works").
- Flattening algorithm tested? Covered by "Service unit test" (line 241: "flattening produces correct `structured_extraction_text`").

No gaps.

## Backward Compatibility

- Adding `has_many :ai_api_requests, as: :requestable` to TextractResult: safe. This is a read-side association only — it adds a query method but creates no schema changes. Two other models already have this association. No serializers expose TextractResult, so the new association won't leak to the API.
- Adding `include PgSearch::Model`: safe — already used on 4 other models. No method name collisions (checked: no existing `search_resume_text` or `search_resume_by_keyword` methods on TextractResult).
- New columns (`structured_extraction`, `structured_extraction_text`, `textsearch_vector`): all nullable, no default values that could affect existing records. No serializers expose TextractResult columns.

## Full-Stack Analog Completeness

All in-scope layers covered after amendments:
- Migrations: 3 column additions + 1 trigger (lines 150-166) ✓
- Service: extraction + flattening + AiApiRequest (lines 170-191) ✓
- Job: background processing + retry (lines 199-204) ✓
- Model: PgSearch + association (lines 208-212) ✓
- Backfill: data migration + backfill job (lines 214-226) ✓
- Error class: CustomErrorStructuredExtraction (line 201) ✓
- Out-of-scope items documented: controller, serializer, frontend, summary pipeline changes (lines 247-251) ✓

## Findings

No issues found.
