# QA Run 1 — FAILURE REPORT (Layer 1, Round 1)

**Feature:** Plato re-score — per-stage bulk checkbox + single-send Regenerate
**Branch:** job-criteria-settings-qa @ f9ec4a80d (worktree /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings)
**Trigger:** 1 HIGH finding in Layer 1 (diff-to-spec), round 1.

## Finding to fix — l1-7-001 (HIGH)

**File:** spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb
**Test:** "rejects a request without rescore_requested" (the new spec's Test 1)

**Defect:** The test posts `params: { job_application_id: ..., ai_job_application_summary: {} }` and expects `ActionController::ParameterMissing`. Rails' outer `params.require(:ai_job_application_summary)` treats the empty hash as missing and raises BEFORE the inner `.require(:rescore_requested)` is evaluated. Mentally deleting the inner `.require(:rescore_requested)` from `ai_job_application_summary_params` (app/controllers/api/v1/ai_job_application_summaries_controller.rb) leaves the test green. The assertion is tautological (core rule 26 / pipeline known-failure #26): it proves only that the top-level key is required, not that `rescore_requested` is.

**Required fix (MINIMUM change — this and nothing else):** In that one test, change the posted payload so `ai_job_application_summary` is NON-EMPTY but missing only `rescore_requested` — e.g. `ai_job_application_summary: { irrelevant: "x" }` (any sibling key; permitted-ness is irrelevant since `require` runs first). The outer require then passes and ONLY the inner `.require(:rescore_requested)` raises `ActionController::ParameterMissing`. Removing the inner require must make the test FAIL.

**Do NOT:** touch Test 2 (threading — correct and falsifiable), the controller, any other spec, or any production code. Do not add new tests. Fix-agent scope rules (pipeline known-failures #10/#23) apply: minimum change resolving this one finding.

**Verification:** run `RAILS_ENV=test bundle exec rspec spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb` (must be green), and confirm falsifiability by temporarily reverting the inner `.require(:rescore_requested)` — the rejection test must then fail — then restore it. (Use nvm-correct env; do not commit the temporary revert.)
