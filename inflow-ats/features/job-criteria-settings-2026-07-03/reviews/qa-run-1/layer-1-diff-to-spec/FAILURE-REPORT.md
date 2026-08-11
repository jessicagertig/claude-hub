# QA Layer 1 FAILURE REPORT — qa-run-1 (input for the Phase 5 fix agent)

Two HIGH findings from diff-to-spec round 1. Fix BOTH with minimal, scoped changes. Phase 5 discipline applies: pipeline rules 10 and 23 — no code beyond defect scope, no removals/rewrites of anything not named here, no "improvements" to adjacent code.

Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`, branch `job-criteria-settings-qa`.

## Finding 1 — exhaustion-site broadcast raises NoMethodError (never fires)

**File:** `app/jobs/extract_job_criteria_job.rb:11`

The `retry_on CustomErrorAiSummary` exhaustion block calls `broadcast_completion(ai_job_criteria, job.arguments.second)`. `broadcast_completion` is a private INSTANCE method. In ActiveJob 6.1 (repo bundle: activejob-6.1.7.7), the exhaustion block is invoked via plain `yield self, error` — the block's `self` is its lexical definition context, the ExtractJobCriteriaJob CLASS. The bare call therefore raises `NoMethodError: undefined method 'broadcast_completion' for ExtractJobCriteriaJob:Class` on retry exhaustion. Consequence: row correctly marked failed (line 10 runs first), then the job dies; the SPEC §7-required broadcast never fires; requesting user's button spins until manual reload. Verified empirically with a probe job against the repo bundle and by source analysis.

**Required fix:** make the exhaustion-site broadcast actually execute, preserving the existing guard (broadcast only when the row exists). The `job` block parameter IS the job instance — the minimal mechanical fix is `job.send(:broadcast_completion, ai_job_criteria, job.arguments.second)`. Before choosing the form, grep other `retry_on` exhaustion blocks in `app/jobs/` for an established pattern of calling instance helpers from inside the block; if a precedent exists, match it; if none, use `job.send(...)`. Do NOT restructure the helper, do NOT convert it to a class method, do NOT change the perform/rescue sites.

**Required test (falsifiability rule 26):** add ONE behavioral example to `spec/jobs/extract_job_criteria_job_spec.rb` that drives the job to retry exhaustion (third consecutive `CustomErrorAiSummary`), and asserts (a) the row ends `failed` and (b) `GlobalChannel` receives `broadcast_to` with `action: 'JOB_CRITERIA_EXTRACTION_COMPLETE'` and `status: 'failed'` when a requesting_organization_user_id was enqueued. The example MUST fail against the current code (NoMethodError) — verify by running it before applying the fix, then confirm it passes after.

**Scope guard:** `app/jobs/generate_ai_job_application_summary_job.rb:20` has the IDENTICAL defect. It is OUTSIDE this diff — DO NOT touch it. It is already recorded in the MED report for Jessica.

## Finding 2 — intro "job description" link is not keyboard-accessible

**File:** `app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:39`

The inline link renders as `<a onClick={() => history.push(...)}>job description</a>` with no `href` and no `tabIndex`. It is never in the tab order: keyboard users cannot reach or activate it, and the conventions-pass focus ring (lines ~195-198) is dead CSS. No other `<a onClick>` without href exists in ats/src.

**Required fix:** make the anchor focusable and keyboard-activatable while preserving SPA navigation and the exact copy/styling. Preferred form: `href={`/jobs/${job.id}/setup/description`}` plus `onClick={(e) => { e.preventDefault(); history.push(...); }}`. Before choosing, grep ats/src for the codebase's dominant inline-text-link navigation pattern (e.g., react-router `Link` styled as inline text); match it if one exists, otherwise use href + preventDefault. The existing focus-ring CSS must remain and become functional. Do not change copy, do not change any other element.

## Commit requirements

- Work on branch `job-criteria-settings-qa` in the worktree above. Commit when both fixes and the new test are in place.
- Run the touched specs first: `RAILS_ENV=test bundle exec rspec spec/jobs/extract_job_criteria_job_spec.rb` (9 pre-existing failures exist in bulk_generate_ai_summaries_job_spec.rb on_complete examples at base — those are NOT yours; everything you touch must be green). Frontend: `nvm use` then tsc/eslint on the changed file.
- Commit rules: run the commit in the background/detached with ≥20-minute tolerance for the pre-commit Cypress hook; NEVER `--no-verify`; never rewrite tests to pass. `source ~/.nvm/nvm.sh && nvm use` before commit so hooks run under Node 16.
- Report back: files changed, diff summary, test results, commit SHA.
