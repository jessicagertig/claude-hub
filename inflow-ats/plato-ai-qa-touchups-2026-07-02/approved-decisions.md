# Approved decisions — bulk AI summary claim/ordering work (2026-07-03)

Decisions explicitly confirmed by Jessica, one per section. Pending items are NOT in this file.

## Credit cap on claims

`QueueBulkAiSummaryJobs` claims only as many job applications as `organization.total_ai_credits_remaining` — claim rows are created only for job applications that can actually be scored this run. Confirmed: "Yes, we need to claim only what the credits cover." IMPLEMENTED.

## Variable rename mapping in QueueBulkAiSummaryJobs

Confirmed item by item:

1. `input_ids` → `requested_job_application_ids`
2. `ready_ids` → `eligible_job_application_ids`
3. `pending_textract_ids` → `textract_pending_job_application_ids` ("Three is fine")
4. `already_summarized_ids` → `scored_job_application_ids` ("go with scored" — "reviewed" is UI language; backend language is summarized/scored)
5. `already_claimed_ids` → `claimed_by_other_batch_job_application_ids` ("Claimed by other batch, that's fine")
6. `working_set` → `claimed_job_application_ids`
7. `claimed_ids` → `final_claimed_job_application_ids` (6 and 7 differ by `final_` — "the diff between the names... shows that the first one was not settled")

IMPLEMENTED.

## Scopes: has_succeeded_textract_results + has_succeeded_latest_textract_result (replaces has_textract_results decision)

Two scopes on `JobApplication`; the earlier bare-existence `has_textract_results` removed per instruction "create those two scopes. Remove the scope you created. Do nothing else."

- `has_succeeded_textract_results` — at least one textract result with `textract_job_status: :succeeded` exists (existence subquery, no join, safe under `limit`). The more reusable general fact.
- `has_succeeded_latest_textract_result` — builds on the first, excluding job applications whose newest textract result is non-succeeded (`DISTINCT ON` newest-per-job-application). Singular name because the latest textract result is one per job application — plurality follows the codebase pattern (`has_logo`/`with_resume` singular, `with_textract_results` plural).

Confirmed: "Okay, that works. So create those two scopes." IMPLEMENTED.

## Claim rows deferred on validation failure

In `BulkGenerateAiSummariesJob#each_iteration`, when `ValidateAiSummaryGeneration` fails for a claimed job application, the claim row is set to `deferred` before returning — reports as skipped, eligible next run — instead of remaining stranded at `processing`. Confirmed: "Yes, it should be set to deferred." IMPLEMENTED.

## NOT approved (implemented in error, awaiting ruling)

1. Relation-composition rewrite of `QueueBulkAiSummaryJobs` steps 2–5 (filters as `where.not` subqueries; `order(updated_at: :desc).limit(credits)` composed at the claim point; skipped-count from `scored_job_application_count` instead of array subtraction). Shown in chat for review, never confirmed, implemented anyway.
2. Earlier: ordering by `updated_at: :desc` applied alongside the renames without a go (superseded by item 1's composed form, itself unapproved).

Jessica has said she will not require a revert; both remain in the working tree pending her ruling.
