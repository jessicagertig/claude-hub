# QA Run 2 — FAILURE REPORT (Layer 1, Round 1)

**Branch:** job-criteria-settings-qa @ 970b0f4b2 (worktree /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings)

## Finding to fix — l1-3-001 (HIGH)

**File:** spec/interactors/create_ai_summary_generation_spec.rb (false-path example, ~lines 55-63)

**Defect:** SPEC 2.8 requires "the same assertion pairs `create_bulk_ai_summary_generation_spec.rb` makes for the bulk interactor." The bulk analog's rescore-false example (create_bulk_ai_summary_generation_spec.rb:96-112) wraps the call in `expect { ... }.not_to change { job_application.ai_job_application_summaries.count }` in addition to asserting the existing summary is returned. The new spec's false-path example asserts `result.ai_summary.id eq existing.id` and `.not_to have_enqueued_job(GenerateAiJobApplicationSummaryJob)` but omits the count-invariance assertion.

**Required fix (MINIMUM change):** In that one example only, add the count-invariance assertion so the pair matches the analog: the call must be asserted `.not_to change { job_application.ai_job_application_summaries.count }` in addition to (not instead of) the existing assertions. Match the analog's compound style (read create_bulk_ai_summary_generation_spec.rb:96-112 for the exact shape; `.and` chaining or a separate expect block per the analog).

**Do NOT:** touch the true-path example, any other spec, or any production code. Do not add new examples. Known-failures #10/#23 apply.

**Verification:** `RAILS_ENV=test bundle exec rspec spec/interactors/create_ai_summary_generation_spec.rb` green (nvm-correct env).
