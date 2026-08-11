# Spec Review — Round 1 Verdict
**Date:** 2026-06-29 12:00

## Counts
- BLOCKER: 0
- HIGH: 3
- MED: 9
- LOW: 3

## HIGH Findings

1. **Missing trigger SQL file + .gitignore conflict** (reference-fidelity F1 + always-on F1/F3): The `fx` gem's `create_trigger` requires a SQL definition file at `db/triggers/tsvectorupdate_v01.sql`, but the spec didn't mention it. The main `.gitignore` has `*.sql` on line 43 which would prevent tracking. Amendment: switched to `sql_definition:` inline in the migration, avoiding the file and gitignore issue entirely.

2. **Flattening algorithm unspecified** (extraction-service F1): The spec said "flattens structured data" but never described how. Added a full "Flattening algorithm" subsection specifying which fields to include, how to handle nested objects and arrays, separators, and what to exclude.

3. **No test section** (always-on F2): Zero mention of tests in the spec. Per pipeline known failure pattern #3, this is required. Added a "Test requirements" section listing existing tests that may need updating and 5 categories of new tests needed.

## MED Findings

4. **pg_search 2.3.2 compatibility unresolved** (reference-fidelity F2): Spec said "verify" but didn't state the result. Amendment: explicitly confirmed 2.3.2 is compatible, used in 4 models, defer any upgrade.

5. **No AiApiRequest tracking** (extraction-service F2): Existing extraction creates AiApiRequest records for cost auditing; spec didn't mention this. Amendment: added AiApiRequest requirement with TextractResult as requestable.

6. **job_title parameter unspecified** (extraction-service F3): Spec said "same prompt" but didn't say whether to pass job_title. Amendment: explicitly include job_title to match existing extraction behavior.

7. **Service method name unspecified** (extraction-service F4): Amendment: specified `extract` as public method name, ID parameter for job context.

8. **Must run in background job** (call-site F1): Spec left inline-vs-callback open without stating the GPT-4o-mini call must be async. Amendment: specified background job pattern matching existing codebase.

9. **No retry/exhaustion spec** (call-site F2): Amendment: specified retry_on with exhaustion block matching GetResumeTextFromTextractJob pattern.

10. **Backfill scope missing text presence check** (backfill F1): `succeeded` status doesn't guarantee non-empty text. Amendment: added `textract_job_result_text IS NOT NULL AND != ''` guard.

11. **No batch/rate values** (backfill F2): Amendment: specified `find_each(batch_size: 100)` with `sleep 0.2`.

12. **Deploy-blocking data migration** (backfill F3): API calls per record could take hours. Amendment: changed to data migration that enqueues a background job, not inline iteration.

## LOW Findings (no amendments)

13. **Line number references fragile** (call-site F3): Spec uses line numbers that change with edits. Not blocking — identifiers are also used.
14. **Per-record backfill error handling** (backfill F4): Addressed as part of backfill amendments.
15. **total_months_experience correctly excluded** (extraction-service F5): Confirmed correct, no issue.

## Amendments Applied

1. Gems required: pg_search 2.3.2 confirmed compatible, fx 0.8.0 confirmed compatible
2. Migration item 4: switched from file-based trigger to `sql_definition:` inline, with full migration code example
3. Service section: added public method name (`extract`), ID parameter, job_title inclusion, AiApiRequest tracking requirement
4. Service section: added full "Flattening algorithm" subsection
5. Call site section: specified background job with `after_commit` callback, retry/exhaustion behavior
6. Backfill section: changed to data-migration-enqueues-job pattern, added text presence check, batch/rate values, per-record error handling
7. Added "Test requirements" section with existing tests to update and new tests needed

## Verdict: FAIL
