# Pass 2 — CLAUDE.md and cursor_rules compliance

## Pass 1 corrections
None needed. Pass 1 found 0 findings.

## Fresh scrutiny

### Plan step ordering for implementation safety
1. Gemfile (fx gem) — must come before trigger migration
2. Migrations (columns, then tsvector, then trigger) — columns must exist before trigger references them
3. Error class — must exist before service references it
4. Service — must exist before job references it
5. Job — must exist before callback references it
6. Model changes — callback references job class
7. Backfill job — must exist before data migration enqueues it
8-11. Tests — after implementation

Every dependency is satisfied by the plan's ordering. **Correct.**

### Plan internal consistency check
- Files to Create table lists 11 files — matches the 11 plan steps that create files
- Files to Modify table lists 2 files (Gemfile, textract_result.rb) — matches steps 1.1 and 6.1-6.5
- Structural Manifest has 27 rows, all marked SAME — matches plan-to-spec comparison
- Risk #3 (fx sql_definition: support) is mitigated — verified fx 0.8.0 supports it
- **No inconsistencies found**

### Existing test review (step 11.1)
- Plan says existing tests will still pass because new callback only enqueues a job
- All `not_to have_enqueued_job` calls in `textract_result_ai_trigger_spec.rb` specify `GenerateAiJobApplicationSummaryJob`
- The new `ExtractStructuredResumeDataJob` being enqueued alongside does not interfere with class-specific assertions
- `have_enqueued_job` without class could fail — but all existing tests specify the class
- **Re-verified** — existing tests safe

### Custom error class pattern
- Plan step 3.1: `class CustomErrorStructuredExtraction < StandardError` with `attr_reader :param`, `def initialize(msg = 'Custom Error - Structured Extraction', param = '')`
- Matches `custom_error_textract.rb` and `custom_error_ai_summary.rb` exactly (different default message string)
- `param = ''` uses empty string default — matches analogs
- **Correct**

### Job queue
- Plan step 5.1: `queue_as :default`
- Plan step 7.1: `queue_as :default` (backfill job)
- Standard Sidekiq queue for non-priority work
- Extraction is not time-critical — default queue is appropriate
- **Acceptable**

### Variable naming in plan code
Re-checking against cursor_rules variable naming rules:
- `textract_result` for `TextractResult` record — full model name ✓
- `textract_results_scope` for ActiveRecord relation — descriptive ✓
- `organization` for `Organization` record — acceptable (single-word model name) ✓
- `work_experience_entry` for hash from array — descriptive, not a record ✓
- `education_entry` for hash from array — descriptive, not a record ✓
- `structured_data` for parsed JSON hash — not a record, descriptive ✓
- `flattened_text` for string — not a record, descriptive ✓
- No violations of the "never use generic names for records" rule

## Final completeness sweep against spec

| Spec section | Plan coverage |
|-------------|---------------|
| Goal | Covered by plan summary |
| Architecture: structured_extraction column | Step 2.1 |
| Architecture: structured_extraction_text column | Step 2.1 |
| Architecture: tsvector + GIN | Step 2.2 |
| Architecture: service | Steps 4.1-4.3 |
| Reference implementation: match patterns | Steps 2.2, 2.3, 6.3, 6.4 |
| Reference: trigger SQL | Step 2.3 |
| Reference: pg_search_scope | Step 6.3 |
| Reference: gems | Steps 1.1, noted pg_search already present |
| Existing extraction to reuse | Step 4.1 (uses ResumeStructuredData prompt class) |
| Extraction schema fields | Step 4.2 (flattening covers all fields) |
| Textract success handler | Step 6.5 (callback approach) |
| Integration point: after_commit | Step 6.5 |
| Background job | Step 5.1 |
| Custom error class | Step 3.1 |
| Retry/exhaustion | Step 5.1 |
| Model changes: PgSearch | Step 6.1 |
| Model changes: ai_api_requests | Step 6.2 |
| Model changes: pg_search_scope | Step 6.3 |
| Model changes: search method | Step 6.4 |
| Model changes: callback | Step 6.5 |
| Flattening algorithm (7 rules) | Step 4.2 |
| Backfill scoping | Step 7.1 |
| Backfill rate limiting | Step 7.1 |
| Backfill error handling | Step 7.1 |
| Data migration | Step 7.2 |
| Parallel redundancy | No changes to generate.rb |
| Test requirements: existing tests | Step 11.1 |
| Test requirements: new tests | Steps 8.1, 9.1, 10.1 |
| Out of scope: frontend, controller, serializer | Confirmed not in plan |

**All spec requirements have corresponding plan steps. No gaps found.**

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW
