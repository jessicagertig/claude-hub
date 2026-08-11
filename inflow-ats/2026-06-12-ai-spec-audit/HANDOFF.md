# AI Spec Audit — Handoff

## What this is

Deep investigation audit of all AI backend specs. 42 agents each did full investigation discipline (read spec, trace code under test, stub audit, ghost detection, drift check). Two rounds completed.

## Where everything lives

- **Audit dir:** `~/claude-hub/inflow-ats/2026-06-12-ai-spec-audit/`
- **Methodology:** `CLAUDE.md` in that dir — three-prong audit, ghost tests = BLOCKER
- **Category findings:** `interactors.md`, `jobs.md`, `models.md`, `services.md`, `other.md`
- **Raw JSON results (Round 2):** `/private/tmp/claude-501/-Users-jessica-claude-hub-inflow-ats-2026-06-08-ai-scoring/3545e406-5aa5-4cba-8cf2-54dbf0547021/tasks/wpaguslyk.output`
- **Workflow script:** `/Users/jessica/.claude/projects/-Users-jessica-claude-hub-inflow-ats-2026-06-08-ai-scoring/3545e406-5aa5-4cba-8cf2-54dbf0547021/workflows/scripts/ai-spec-audit-wf_26447ac5-6bf.js`
- **Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` branch `UI-polishes`

## Current state

**Round 2 (2026-06-18):** 42 specs on `UI-polishes`. 14 BLOCKER, 37 HIGH, 79 MED.

**6 specs DEFERRED** (billing still in progress):
1. `spec/interactors/apply_ai_credit_purchase_spec.rb`
2. `spec/interactors/apply_ai_credit_refund_spec.rb`
3. `spec/interactors/cancel_ai_credit_subscription_spec.rb`
4. `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
5. `spec/services/stripe/cancel_credit_pack_subscription_spec.rb`
6. `spec/models/organization_ai_credit_purchase_spec.rb`

**36 actionable specs: 12 BLOCKER, 30 HIGH, 69 MED**

## BLOCKER list (fix or delete)

1. `score_job_application_spec.rb` — ALL tests ghost. `structured_data` nil → `CustomErrorAiSummary` before any AI call. Entire spec is theater.
2. `score_job_application_spec.rb` — Error handling tests ghost for same reason.
3. `orchestrate_spec.rb` — "textract_result does not exist" only asserts `not_to raise_error`
4. `orchestrate_spec.rb` — "no summary exists" only asserts `not_to raise_error`
5. `generate_ai_job_application_summary_job_spec.rb` — zero-credits test ghost (pipeline no-op, not credits protection)
6. `generate_ai_job_application_summary_job_spec.rb` — textract_result not found only asserts `not_to raise_error`
7. `get_resume_text_from_textract_job_spec.rb` — "no textract_processing summary" only asserts `not_to raise_error`
8. `get_resume_text_from_textract_job_spec.rb` — "job_application does not exist" only asserts `not_to raise_error`
9. `find_or_create_ai_job_application_summary_status_spec.rb` — ghost: asserts state created by callback, not subject
10. `find_or_create_ai_job_application_summary_status_spec.rb` — tests clearing behavior that doesn't exist in production
11. `ai_job_application_summary_spec.rb` — `broadcast_status_change` payload drifted, spec will FAIL
12. `ai_job_criteria_spec.rb` — "does not raise" asserts nothing about behavior

## HIGH list (30 findings)

See category files for full details. Key clusters:

**Specs with zero coverage for major code paths:**
- `orchestrate_spec.rb` — 6 of 11 case branches untested + stubs without `.with()` argument verification
- `score_job_application_spec.rb` — boundary re-scoring (5 AI calls + median), `display_sentence` key rename, structured_data guards
- `extract_job_criteria_job_spec.rb` — all 3 error handling paths (retry exhaustion, CustomErrorAiSummary, StandardError)
- `get_resume_text_from_textract_job_spec.rb` — perform method has ZERO coverage (only cleanup_orphaned_summary tested)
- `submit_resume_to_textract_spec.rb` — guard clauses, rescue blocks, stale-marking all untested

**Model gaps:**
- `ai_job_application_summary_spec.rb` — `update_summary_status_record` callback + `destroy_previous_textract_results` happy path untested
- `ai_job_application_summary_status_spec.rb` — 5 score band scopes untested
- `ai_job_criteria_spec.rb` — enum missing `retrying` status (will FAIL)
- `textract_result_ai_trigger_spec.rb` — entire `ai_summary_waiting_on_textract` branch untested

## Key rule

**Ghost tests are BLOCKER.** A test that doesn't test what it claims is worse than no test — false confidence. Fix or delete, no middle ground. Saved in memory as `feedback_ghost_tests_are_blockers.md`.

## Next steps

Jessica wants to do as little manual work as possible. Options not yet decided:
- Fan out fix agents per BLOCKER (risky — fix agents can write bad code, per Known Failure Pattern #10)
- Delete ghost tests and file as known gaps
- Prioritize: fix the specs that guard critical paths, delete the ones guarding edge cases
