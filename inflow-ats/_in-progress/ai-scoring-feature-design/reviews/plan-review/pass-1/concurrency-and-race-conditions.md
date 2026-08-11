# Pass 1 — concurrency-and-race-conditions

## Fact Check

### `AiJobCriteria.after_commit` uses `find_each` for multiple waiting summaries

Plan B.1.2 uses `find_each` to iterate waiting summaries. `find_each` batches in groups of 1000 by default. For the expected scale (dozens of applications per job, not millions), this is safe. CORRECT.

### `Job#extract_job_criteria` debounce via `pending` status

Plan G.2.1 checks `existing_ai_job_criteria&.status_pending?` and returns early if pending — preventing duplicate extraction jobs. CORRECT per spec Section 7.

### Multiple applications hitting `awaiting_job_criteria`

Plan R5 documents this scenario: bulk processing multiple applications for the same job, all reaching `awaiting_job_criteria` before criteria complete. The `AiJobCriteria.after_commit` callback (B.1.2) finds ALL waiting summaries. The `extract_job_criteria` debounce (G.2.1) prevents multiple extraction jobs. CORRECT.

### `regenerating` flag on `AiJobApplicationSummaryStatus`

Plan I.3 says this is "a future concern" and defers full regeneration support. The plan creates the column with `default: false` but only sets it for the basic lifecycle (I.1 create, I.2 update on success). CORRECT — spec Section 2 lifecycle is covered.

### Race between `awaiting_job_criteria` status set and `extract_job_criteria` call

In `ScoreJobApplication` (D.2.2), when criteria are absent:
1. Sets status to `awaiting_job_criteria` via `update_columns`
2. Calls `@job.extract_job_criteria` if criteria don't exist or are failed

If `extract_job_criteria` finishes and the `after_commit` fires between steps 1 and 2, the callback would find this summary with `awaiting_job_criteria` and re-enqueue. This is safe — the orchestrator's idempotent resume handles double-enqueue gracefully (it checks status and skips completed steps).

However, there's a subtler issue: `ScoreJobApplication` is called from the orchestrator, which is called from the job. If `ScoreJobApplication` calls `@job.extract_job_criteria` which enqueues `ExtractJobCriteriaJob` with a 2-minute delay, and then returns — the orchestrator returns, the credit flow returns, and the job exits. The 2-minute delayed `ExtractJobCriteriaJob` runs later, finishes, and the `after_commit` re-enqueues `GenerateAiJobApplicationSummaryJob`. This flow is correct.

But what about the orchestrator's `check_criteria_and_score` method (E.1.6)? It also calls `extract_job_criteria`. The flow is:
1. Orchestrator calls `run_summary` -> summary succeeds
2. Orchestrator calls `check_criteria_and_score` -> sets `awaiting_job_criteria`, calls `extract_job_criteria`, returns

Wait — there's a redundancy. Both the orchestrator (E.1.6) and `ScoreJobApplication` (D.2.2) can trigger `extract_job_criteria`. In practice, only one path fires because:
- If the orchestrator sees no criteria in `check_criteria_and_score`, it sets `awaiting_job_criteria` and returns BEFORE ever calling `ScoreJobApplication`.
- `ScoreJobApplication` is only called when the orchestrator's `check_criteria_and_score` confirms criteria are present.

So `ScoreJobApplication`'s criteria-absent path (D.2.2) only fires on resume from `awaiting_job_criteria` when the orchestrator calls `run_scoring` directly. But in the orchestrator's case statement (E.1.3), when status is `awaiting_job_criteria`, it calls `check_criteria_and_score` which checks criteria again. If criteria are now present, it calls `run_scoring` (which calls `ScoreJobApplication`). If not, it returns.

So the `ScoreJobApplication` criteria-absent path (D.2.2) is actually unreachable in normal flow — the orchestrator always checks criteria before calling `ScoreJobApplication`. The path exists as a safety net.

This is acceptable — defense in depth. No finding.

## Completeness

- [x] Multiple waiting summaries handled by `find_each` (B.1.2)
- [x] Debounce prevents duplicate extraction (G.2.1)
- [x] Bulk processing scenario documented (R5)
- [x] `regenerating` flag lifecycle (I.1-I.3)
- [x] Double-enqueue safety (orchestrator resume is idempotent)

## Findings

No findings. Concurrency handling is sound.
