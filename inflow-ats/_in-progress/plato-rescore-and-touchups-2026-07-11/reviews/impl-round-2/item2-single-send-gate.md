# item2-single-send-gate — Round 2

Independent re-verification of `create_ai_summary_generation.rb` against SPEC 2.1 and the new interactor spec against SPEC 2.8.

Interactor:
- Line 36: `if active_ai_summary && !job_application.ai_summary_rescore_requested` — byte-identical to the pinned bulk gate `create_bulk_ai_summary_generation.rb:45` (verified: same string). ✓
- Everything else unchanged: the `ap` debug lines, `active_ai_summary` query (30-34), `validation_result.textract_pending` branch (41-53, reads `textract_pending` at :41 — justifies the spec double stub), pending build + `GenerateAiJobApplicationSummaryJob.perform_later` enqueue (55-72), `requested_by_organization_user_id` set. ✓
- Bulk interactor's staleness-refresh block (`create_bulk...rb:40-43`) NOT ported (guardrail 1 / known-failure #10). ✓
- No `update_columns` introduced (rule 25); no bang methods (rule 11). ✓
- The eight untouched gates confirmed untouched (only this file's line 36 changed; controller/policy/validate/job/textract/orchestrate all outside this diff). ✓

Interactor spec (`create_ai_summary_generation_spec.rb`, CREATE):
- Setup mirrors `create_bulk_ai_summary_generation_spec.rb` (ActiveJob test helper, adapter `around`, organization/org_user/user/job/job_application with succeeded TextractResult, textract_result). ✓
- Double stubs `textract_pending: false` (SPEC 2.8 note) — required because the single-send interactor reads it on the fall-through path. ✓
- rescore-true: builds a new pending row (`result.ai_summary.id != existing.id`, `status == pending`), leaves `existing` succeeded/non-stale, AND `have_enqueued_job(GenerateAiJobApplicationSummaryJob)` (the single-send enqueue difference from bulk). ✓ Falsifiable: reverting the gate returns `existing` and enqueues nothing → both assertions fail (core rule 26). ✓
- rescore-false: returns `existing`, `not_to have_enqueued_job`. ✓ Falsifiable.
- `existing` variable name mirrors the pinned analog spec verbatim (plan T2.3/T2.4) — pin wins over rule 9 (priority rule); not a finding.

Live rspec: 6 examples, 0 failures (interactor examples included).

## Findings
No issues found.
