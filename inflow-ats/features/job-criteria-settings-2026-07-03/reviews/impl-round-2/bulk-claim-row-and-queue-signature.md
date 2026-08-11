# Angle 2 — Bulk claim-row lifecycle fix and QueueBulkAiSummaryJobs signature (flags 6/7) — Round 2

Round-2 focus: the merge (68e5e6a4e) resolved conflicts in exactly this angle's files. The resolution was UNREVIEWED until now — scrutinized as fresh implementation.

## Claim-row fix survived the merge

`BulkGenerateAiSummariesJob#each_iteration:62-66` at HEAD:
validation failure → `job_application_bulk_job_status.update_columns(status: :failed); return`. Interdiff confirms the feature hunk is byte-identical pre-merge (05c9513ef..e7b8cef0a) and post-merge (639458b9d..HEAD); develop's 2-line `ai_summary_rescore_requested` assignment (:36) merged cleanly ABOVE it and does not touch the claim-row lifecycle. `update_columns` sibling writes at :57, :74, :92 unchanged; `on_complete` counting (`failed = size - done - deferred`) unchanged; no new statuses, no `notify_*` rewrites.

## Controller resolution (the one true conflict)

Merged `bulk_ai_job_application_summaries_controller.rb`:
- `#create` (:13-19): passes `job: @job,` AND `params: bulk_ai_job_application_summary_params` — feature's input + develop's input, both present.
- `#all_stages` (:39-46): passes `job: @job,` + `kind: 'all_stages'` + `params: bulk_ai_job_application_summary_params`. Base's top-level `rescore_requested:` context key (present at 05c9513ef:42) correctly dropped in favor of develop's `params:` form — that is develop's own PR #3054 change, not a lost feature hunk.

Verified against the merged consumer `QueueBulkAiSummaryJobs`:
- `context.job` consumed ONLY by the zero-criteria guard (:19) — safe-nav, optional.
- `context.params[:rescore_requested]` consumed at :41 (already-summarized filter) and :97 (job payload) — both actions now supply `params:`. The guard at :19 fires before :41, so a zero-criteria failure never reaches the params read.
- `context.kind || 'single_hiring_stage'` (:96) — `create` passing no `kind` still works.

## Spec reconciliations (merge-authored, reviewed as fresh code)

- `bulk_ai_job_application_summaries_controller_spec.rb`: `rescore_requested:` added to every request (required param since PR #3054 — `bulk_params.require(:rescore_requested)`, controller :81); the all_stages interactor expectation updated to `params: hash_including('rescore_requested' => 'true')` while KEEPING the feature's `job: kind_of(Job)`; both zero-criteria 422 examples and the `#create` job-passing example intact. All pass (suite run below).
- `queue_bulk_ai_summary_jobs_spec.rb`: feature's zero-criteria context intact — fail-fast example passes `job:` and (correctly) NO `params:` since the guard fires first; the job-less example now passes `params: { rescore_requested: false }` because develop's interactor reads `context.params[:rescore_requested]` unconditionally on the success path. Reconciliation is the minimum change to the merged contract.
- Suite: both spec files green at HEAD (140-example run, 0 failures outside the pre-existing on_complete set).

## Notes (not findings against this branch)

- **Upstream develop spec breakage, fixed here by the merge:** at develop (639458b9d), `bulk_ai_job_application_summaries_controller_spec.rb` examples at :54/:93/:104/:120 post WITHOUT `rescore_requested` while develop's controller `require`s it — those examples fail ON DEVELOP. The merge's `rescore_requested: false` additions are what make them pass on this branch. Worth telling the develop owner; nothing to fix here.
- Controller-spec params stringify booleans (`'true'`/`'false'`), so `rescore_requested: false` arrives as the truthy string `'false'` inside `context.params` in controller specs. This only affects develop's already-summarized filter branch (skipped instead of exercised in those examples), never the zero-criteria guard (fires earlier). Develop-side test-fidelity note; out of scope.

## Findings

No issues found.
