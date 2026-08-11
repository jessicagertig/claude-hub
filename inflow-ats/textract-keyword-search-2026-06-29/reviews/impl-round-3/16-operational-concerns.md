# Operational Concerns

## Verdict: PASS

### Findings

None.

### Verification

- Backfill rate limiting: `sleep 0.2` per record (5 requests/second max) -- stays under OpenAI rate limits
- Backfill does not block deploys -- data migration only enqueues a Sidekiq job
- Backfill is resumable -- `structured_extraction IS NULL` guard means re-running picks up failures
- Extraction job retry: `wait: 5.minutes, attempts: 3` -- 3 retries with 5-minute backoff; exhaustion logs and moves on
- Extraction job failure isolation: `rescue StandardError` catches non-retryable errors, logs, and does not re-raise; extraction is supplementary
- No N+1 queries in the service -- single `TextractResult.find_by`, single `update`, single `AiApiRequest.create`
- The `job_application&.job&.organization` chain loads 2 associated records -- acceptable for a background job (not a request cycle with many records)
- No new Sidekiq queues -- both jobs use `:default` queue, matching existing jobs
- No memory concerns -- the service processes one TextractResult at a time; the backfill uses `find_each(batch_size: 100)` for memory efficiency
- No new environment variables or configuration required
- No external service dependencies beyond OpenAI (already a dependency)
