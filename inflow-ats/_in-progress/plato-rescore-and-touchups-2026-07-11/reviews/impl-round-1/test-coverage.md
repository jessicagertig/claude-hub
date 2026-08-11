# test-coverage (always-on) — Round 1

Backend specs only (frontend coverage owner-ruled out — guardrail 3).

## Live result
`RAILS_ENV=test bundle exec rspec spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb spec/interactors/create_ai_summary_generation_spec.rb spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb`
→ **6 examples, 0 failures** (2.1s).

## Falsifiability audit (core rule 26 / known-failure #26)
- Interactor spec (2 examples): revert the gate → true-path returns existing + enqueues nothing → `not_to eq(existing.id)` AND `have_enqueued_job` both fail. Not tautological.
- Controller spec (2 examples): revert `require` → Test 1 no longer raises `ParameterMissing`; revert attribute-set line → Test 2 captures `false`, `.to be true` fails. Real controller code runs unstubbed (only interactors stubbed) — no masked type/param mismatch (known-failure #7).
- Mailer spec (2 examples): `active_member` is a distinct org_admin (not the triggering owner); revert B1 (send to `@user` only) → `include(active_member.user.email)` fails and `user_first_name` key reappears → `not_to have_key(:user_first_name)` fails. Pre-existing staleness (arity/subject/tags) reconciled to the real mailer, not layered on failing expectations.

## Coverage completeness vs SPEC 2.8 / 1.7
- Interactor: true builds+enqueues, false returns+no-enqueue — mirrors bulk spec pairs plus the single-send enqueue assertion. ✓
- Controller: missing-param rejection + value-threads-onto-record. ✓
- Mailer: active included / inactive excluded, both `complete` and `failed`; greeting variable removed. ✓
- No frontend tests (correct per owner ruling). Existing `queue_bulk_ai_summary_jobs_spec.rb` / bulk controller spec unchanged (shared enqueue threading already covered).

## Findings
No issues found.
