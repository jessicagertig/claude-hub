# Pass 1 — CLAUDE.md and cursor_rules compliance

## core_critical_rules.md

| Rule | Status | Evidence |
|------|--------|----------|
| 1. No begin blocks | COMPLIANT | Plan uses method-level rescue in service (step 4.1) and job (step 5.1) |
| 2. Theme colors | N/A | Backend only |
| 3. Use awesome print | COMPLIANT | Plan uses `ap` throughout (steps 4.1, 5.1, 7.1) |
| 4. PUT for updates | N/A | No controllers |
| 5. One params method | N/A | No controllers |
| 6. No render_many | N/A | No controllers |
| 7. snake_case backend | COMPLIANT | All names: `extract_structured_resume_data`, `structured_extraction`, `textract_result_id` |
| 8. Guard clauses bare return | COMPLIANT | Plan step 4.1: `return unless textract_result exists`, `return unless ... .present?`, `return unless organization` |
| 9. Never set undefined | N/A | Backend only |
| 10. Never fabricate fallback values | NOTED | `|| 0` for token counts (step 4.3) matches analog at `generate.rb:298-299`. Pre-existing pattern |
| 11. Don't use bang methods | COMPLIANT | `textract_result.update()`, `AiApiRequest.create()` (non-bang) |
| 12. Always check save/update return values | COMPLIANT | `textract_result.update()` checked with if/else (step 4.1). `AiApiRequest.create()` unchecked -- matches analog |

## cursor_rules/backend/services.md

| Rule | Status | Evidence |
|------|--------|----------|
| 1. No "Service" in class name | COMPLIANT | `ExtractStructuredResumeData` |
| 2. Descriptive method name, not `call` | COMPLIANT | `extract` |
| 3. Pass IDs from jobs, objects in request cycle | COMPLIANT | `def initialize(textract_result_id:)` |

## cursor_rules/backend/background_jobs.md

| Rule | Status | Evidence |
|------|--------|----------|
| 0a. Naming: {action}_{resource}_job.rb | COMPLIANT | `extract_structured_resume_data_job.rb` |
| 0b. External API calls in background jobs | COMPLIANT | GPT-4o-mini called in job, not in callback |
| 1. Pass ID, not object | COMPLIANT | `perform(textract_result_id)` |
| 3. Jobs delegate to services | COMPLIANT | `ExtractStructuredResumeData.new(...).extract` |
| 5. after_commit for job enqueuing | COMPLIANT | `after_commit :queue_structured_extraction_job` |

## Variable naming

| Variable | Model | Compliant? |
|----------|-------|-----------|
| `textract_result` | `TextractResult` | Yes |
| `structured_data` | N/A (parsed hash, not a record) | Yes |
| `flattened_text` | N/A (string, not a record) | Yes |
| `organization` | `Organization` | Yes |
| `work_experience_entry` | N/A (hash from array) | Yes |
| `education_entry` | N/A (hash from array) | Yes |

## Pipeline CLAUDE.md rules

| Rule | Status |
|------|--------|
| No direct psql | COMPLIANT -- no psql commands |
| No database drops | COMPLIANT -- only adds columns and trigger |
| No .env edits | COMPLIANT -- no .env changes |
| Never work on master | N/A -- plan review, not implementation |

## Pipeline known failure patterns

| Pattern | Relevant? | Status |
|---------|-----------|--------|
| #4 ActionMailer deliver_now/deliver_later | No | N/A |
| #6 Rename cascades: grep all references | No | N/A |
| #10 Fix agents must not add code beyond scope | No | N/A |
| #13 Never fabricate fallback values | Yes | `|| 0` matches analog (see rule 10 above) |
| #14 Analog structural matching | Yes | All reference patterns matched (see reference-fidelity.md) |

## Source accuracy (always-on)

| Claim | Verification |
|-------|-------------|
| `textract_results` table exists | schema.rb lines 1222-1231 |
| `GetResumeTextFromTextract` at expected path | Confirmed, `parse_resume_text` method at lines 8-49 |
| `TextractResult` has `after_commit :queue_ai_summary_job` | Confirmed at line 7 |
| `pg_search` 2.3.2 in Gemfile | Confirmed at line 125 |
| `fx` NOT in Gemfile | Confirmed via grep |
| `resume_structured_data.rb` exists | Confirmed with expected class methods and schema |
| `tsvector_update_trigger` is Postgres built-in | Confirmed -- signature: (tsvector_column, dictionary, source_columns...) |
| 4 models already use PgSearch::Model | Confirmed: Candidate, Organization, Job, User |
| AiApiRequest belongs_to :requestable, polymorphic: true | Confirmed at ai_api_request.rb line 5 |
| Existing call_types: extraction, assessment, comparison, summary | Confirmed via grep of generate.rb |
| AiClient.calculate_cost exists | Confirmed at ai_client.rb line 35-36 |

## Test coverage (always-on)

- Plan has test section (steps 8-11) with 3 new spec files
- Service tests (step 8.1): 10 test cases covering happy path, flattening, errors, guards, idempotency
- Job tests (step 9.1): 4 test cases covering delegation, retry, exhaustion
- Model/callback tests (step 10.1): 7 test cases covering callback firing, pg_search, search method
- Existing test review (step 11.1): `textract_result_ai_trigger_spec.rb` verified -- all `not_to have_enqueued_job` calls specify class, new callback will not break existing tests
- No spec files exist on reference branch

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW
