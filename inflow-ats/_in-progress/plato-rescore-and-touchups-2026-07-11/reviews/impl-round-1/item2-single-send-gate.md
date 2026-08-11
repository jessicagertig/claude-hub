# item2-single-send-gate — Round 1

Reviewed `app/interactors/create_ai_summary_generation.rb` + `spec/interactors/create_ai_summary_generation_spec.rb` (commit f9ec4a80d) against SPEC 2.1/2.8 and pinned gate `create_bulk_ai_summary_generation.rb:45`.

## Verified
- `:36` changed from `if active_ai_summary` to `if active_ai_summary && !job_application.ai_summary_rescore_requested` — byte-identical to the pinned bulk gate (confirmed `create_bulk_ai_summary_generation.rb:45`).
- Diff shows exactly ONE line changed in the interactor; nothing else touched (the `ap` debug lines, `active_ai_summary` query, `textract_pending` branch, `pending` build + `GenerateAiJobApplicationSummaryJob` enqueue, `requested_by_organization_user_id` all retained). Bulk staleness-refresh block NOT ported (guardrail 1 respected).
- No `update_columns` introduced (rule 25); no bang methods added.
- Spec setup mirrors bulk interactor spec (ActiveJob::TestHelper, around adapter block, credit-test helpers). `validation_result` double stubs `textract_pending: false` (SPEC A3 — required for the fall-through path at `:41`).
- Rescore-true: builds new pending row (`id not_to eq existing`, `status == 'pending'`), existing row untouched (`succeeded`, `stale false`), AND `have_enqueued_job(GenerateAiJobApplicationSummaryJob)` — the single-send enqueue assertion the bulk spec lacks.
- Rescore-false: returns existing (`id == existing.id`), `not_to have_enqueued_job`.
- Falsifiable (core rule 26): reverting the gate makes the true-path return existing and enqueue nothing → both `not_to eq(existing.id)` and `have_enqueued_job` fail.

## Findings
No issues found.
