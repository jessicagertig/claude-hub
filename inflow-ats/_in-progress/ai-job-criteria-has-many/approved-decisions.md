# Approved decisions — ai_job_criteria has_many

## Decision 1 — summary pipeline calls `extract_job_criteria` (immediate)

The summary-pipeline call sites that trigger criteria extraction when a candidate's summary is blocked on missing criteria — `score_job_application.rb:27`, `score_job_application.rb:47`, and `orchestrate.rb:81` — call `extract_job_criteria` (runs immediately), not `auto_extract_job_criteria` (the 30-second debounce).

## Decision 2 — on-publish calls `auto_extract_job_criteria`

The on-publish callback (`job.rb:560`) calls `auto_extract_job_criteria`. At publish there is expected to be no existing `AiJobCriteria` record, and `auto_extract_job_criteria`'s no-record branch enqueues immediately with no delay, so it runs right away in the normal publish case; the 30-second debounce only applies if a record already exists.

## Decision 3 — description-change trigger calls `auto_extract_job_criteria`

`handle_description_change` (`job.rb:734`), which fires on a meaningful description edit of a published job, calls `auto_extract_job_criteria`. This is the repeated-edit case the 30-second debounce exists for.

## Resulting call-site wiring

- `job.rb:560` (on publish) — `auto_extract_job_criteria`
- `job.rb:734` (`handle_description_change`) — `auto_extract_job_criteria`
- `score_job_application.rb:27` — `extract_job_criteria`
- `score_job_application.rb:47` — `extract_job_criteria`
- `orchestrate.rb:81` — `extract_job_criteria`
