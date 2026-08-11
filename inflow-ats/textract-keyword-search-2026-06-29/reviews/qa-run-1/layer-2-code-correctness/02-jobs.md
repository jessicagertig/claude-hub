# Layer 2 — Jobs Code Correctness

**Files reviewed:**
- `app/jobs/extract_structured_resume_data_job.rb`
- `app/jobs/backfill_structured_extraction_job.rb`
- `app/errors/custom_error_structured_extraction.rb`
- `app/services/extract_structured_resume_data.rb` (to trace error flow)

**Analog files compared:**
- `app/jobs/get_resume_text_from_textract_job.rb`
- `app/jobs/generate_ai_job_application_summary_job.rb`

---

## ExtractStructuredResumeDataJob

### rescue ordering (CustomErrorStructuredExtraction vs StandardError)

`CustomErrorStructuredExtraction < StandardError`. Ruby rescues in declaration order — first match wins. Line 14 (`rescue CustomErrorStructuredExtraction`) appears before line 18 (`rescue StandardError`), so `CustomErrorStructuredExtraction` is caught first, logged, and re-raised. The `rescue StandardError` block only catches non-`CustomErrorStructuredExtraction` errors. **Correct.**

### retry_on + rescue + raise chain

1. Service raises `CustomErrorAiSummary` → service catches it and re-raises as `CustomErrorStructuredExtraction` (service lines 43-47)
2. Service raises `JSON::ParserError` → service catches it and re-raises as `CustomErrorStructuredExtraction` (service lines 48-52)
3. Job's `rescue CustomErrorStructuredExtraction` (line 14) catches, logs via `ap`, re-raises
4. `retry_on CustomErrorStructuredExtraction` (line 6) catches the re-raise, re-enqueues or runs exhaustion block

**Correct.** Matches the `GenerateAiJobApplicationSummaryJob` pattern exactly (lines 35-38 of that analog).

### StandardError swallowing

The `rescue StandardError` block (line 18) logs and does NOT re-raise. This means any error that is NOT a `CustomErrorStructuredExtraction` is silently swallowed — no retry, no exhaustion. This is the same pattern as `GenerateAiJobApplicationSummaryJob` (lines 39-45), which also swallows `StandardError` for non-retryable errors.

The service wraps both `CustomErrorAiSummary` and `JSON::ParserError` into `CustomErrorStructuredExtraction` before they reach the job. Any `StandardError` that reaches the job without being wrapped is genuinely unexpected (e.g., `ActiveRecord::RecordNotFound`, `NoMethodError`, `ArgumentError`). Swallowing these is a design choice — extraction is supplementary, so a bug crash doesn't take down Sidekiq.

**No bug.** Matches analog pattern.

---

## BackfillStructuredExtractionJob

### find_each + sleep interaction

`find_each(batch_size: 100)` loads 100 records at a time via `LIMIT 100 OFFSET ...` (or primary key batching). The `sleep 0.2` inside the block pauses between individual record processing, not between batches. This means 100 records take ~20 seconds, then the next batch loads. ActiveRecord releases the prior batch's objects for GC when loading the next batch. **Correct.**

### Per-record rescue

The `rescue StandardError => e` (line 25) is inside the `find_each` block, so it catches errors for a single record and continues to the next. The `failed` counter increments. **Correct.** Note: this also catches `CustomErrorStructuredExtraction` (which inherits from `StandardError`), meaning API failures during backfill are caught per-record and logged rather than retried. This is intentional — the backfill is resumable via the `structured_extraction IS NULL` scope, so failed records will be picked up on a re-run.

### Zero records

If the scope returns 0 records, `find_each` yields nothing. `processed` stays 0, `failed` stays 0. The final `ap` line prints "complete: 0 processed, 0 failed out of 0". **Correct.**

### Interruption (server restart)

If Sidekiq is killed mid-backfill, the job stops. No explicit checkpoint or resume mechanism — but the scope filters on `structured_extraction: nil`, so re-enqueuing the job picks up from where it left off (minus any in-flight record whose `update` didn't commit). **Correct.** The data migration won't re-enqueue automatically, but the job can be manually re-enqueued via `BackfillStructuredExtractionJob.perform_later`.

### Memory

`find_each` uses batched loading. Each batch of 100 TextractResult objects is loaded, iterated, and then the next batch is loaded (releasing the prior batch for GC). The service instantiates a new `ExtractStructuredResumeData` per record, which is short-lived. **No memory leak.**

### Analog comparison note

`GetResumeTextFromTextractJob` has a commented-out `rescue StandardError` (lines 28-31). The new extraction job's pattern matches `GenerateAiJobApplicationSummaryJob` more closely, which has an active `rescue StandardError` block. Backfill job has no direct analog but follows a standard batch-processing pattern.

---

## Findings

No HIGH or MED findings.

---

**VERDICT: CLEAN — 0 findings**
