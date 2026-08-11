# test-coverage (always-on) — Round 2

Backend specs only (frontend coverage owner-ruled out — guardrail 3).

## Live result (independent re-run)
`RAILS_ENV=test bundle exec rspec spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb spec/interactors/create_ai_summary_generation_spec.rb spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb`
→ **6 examples, 0 failures** (Finished in 2.44s; seed 45650).

## Falsifiability audit (core rule 26 / known-failure #26)
- Interactor (2 ex): revert gate → rescore-true returns `existing` + enqueues nothing → `not_to eq(existing.id)` AND `have_enqueued_job(GenerateAiJobApplicationSummaryJob)` both fail. Not tautological; the enqueue assertion is the single-send-specific behavior the bulk spec omits.
- Controller (2 ex): revert `require` → missing-param test no longer raises `ParameterMissing`; revert the attribute-set line → captured `job_application.ai_summary_rescore_requested` is `false` → `.to be true` fails. Real controller code runs; only interactors stubbed, stubbed with the real param shape (no masked type/param mismatch — known-failure #7).
- Mailer (2 ex): `active_member` is a distinct org_admin, not the triggering owner; revert B1 (send to `@user` only) → `include(active_member.user.email)` fails and `user_first_name` key returns → `not_to have_key(:user_first_name)` fails. Pre-existing arity/subject/tags staleness reconciled to the real mailer (6-arg `complete` call, "Your Plato reviews..." subject, `['polymer','user-facing']` tags), not layered on failing expectations.

## Coverage vs SPEC 2.8 / 1.7
- Interactor: true builds+enqueues / false returns+no-enqueue — mirrors bulk spec pairs plus the enqueue assertion. ✓
- Controller: missing-param rejection + value-threads-onto-record. ✓
- Mailer: active included / inactive excluded (both `complete` and `failed`), `user_first_name` removed, `total_count` asserted. ✓
- No frontend tests (correct). Existing `queue_bulk_ai_summary_jobs_spec.rb` / bulk controller spec unchanged.

## Findings
No issues found.
