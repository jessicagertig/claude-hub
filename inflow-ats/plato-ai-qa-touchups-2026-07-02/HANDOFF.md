# Plato AI — QA & Touch-ups Handoff (2026-07-02)

Source repo: `/Users/jessica/wrk/wrk-corp/inflow-ats` (see REPO-PATH)
Working branch: **`qa-refinements`** (branched off `develop`). Session ended with the repo checked out on `develop`.

Context: Jessica is doing manual QA + small touch-up fixes on the Plato AI feature (candidate AI summaries + scoring + credits). This handoff captures what's committed, what's stashed, and what's still to do.

---

## 1. Committed & already on `develop` (via PR #3052)

- `fbf7c2df6` — Plato tab loading flashes + zero-score stars (serializers `score_percentage` → `&.to_f`) + Accordion count 2px alignment.
- `fc4e1656d` — auto-generate AI summary on **resume upload to an existing candidate** (`JobApplication#auto_generate_ai_summary_if_enabled`, called from `enqueue_new_job_application` and the resume-upload controller path).

## 2. Committed on `qa-refinements`, NOT yet on `develop` (need to go up)

- `c89ebea53` — kick off job-criteria extraction at the **start** of the summary pipeline (`Job#extract_job_criteria_if_needed`, called from `TextractResult#generate_ai_summary_with_credit_flow`).
- `7b441550f` — bulk-generate modal **shortfall copy inlined** into the description (RunPlatoReviewAllModal + BulkGenerateAiSummariesConfirmModal, callouts removed) + **`Job#clone` resets `ai_job_application_summaries_count = 0`** (clone was carrying the original's stale counter_culture count via `dup`).

**ACTION:** get these two onto `develop` (new PR from `qa-refinements`, or merge). First verify they're pushed to `origin/qa-refinements` — `7b441550f` may only be local (its commit ran commit-only, no push).

## 3. STASHED — `stash@{0}` "force_regenerate + always-show-Regenerate (QA follow-up, WIP)"

The **single-candidate regenerate** feature (#1). 5 files. **Restore with `git stash apply` (NOT pop — keep the backup).**

What it does:
- **Always show Regenerate**: `PlatoTab.tsx` headerRight gate changed from `statusValue === "current" && fullSummary?.stale` → `statusValue === "current" && fullSummary`, so Regenerate shows on ANY completed review (not just stale) — for re-running after a job-description change. Stale banner untouched.
- **force_regenerate flag** (mirrors the `skip_hiring_stage_message_automation` analog exactly):
  - `job_application.rb`: `attribute :force_regenerate_ai_summary, :boolean, default: false`
  - `ai_job_application_summaries_controller.rb`: sets it from `ai_job_application_summary_params[:force_regenerate]` + a strong-params `permit(:force_regenerate)` (mirrors `bulk_ai_job_application_summary_params`).
  - `create_ai_summary_generation.rb`: guard `if active_ai_summary && (job_application.force_regenerate_ai_summary || textract-changed)` → marks the current review stale + regenerates against current job criteria.
  - `useAiJobApplicationSummary.ts`: `forceRegenerate?` on the mutation params.
  - `PlatoTab.tsx`: `handleGenerate(forceRegenerate = false)`; regenerate confirm → `handleGenerate(true)`; empty-state `onClick` wrapped `() => handleGenerate()` so the click event can't leak in as `forceRegenerate`.

Needs its own commit + QA once restored.

## 4. NOT yet implemented — the other change

- **#2 Per-stage bulk rescore.** The whole-job "Run Plato" modal has the rescore option (`rescore_requested` param → bulk path). The **per-stage** bulk (`BulkGenerateAiSummariesConfirmModal` → `CreateBulkAiSummaryGeneration` / `QueueBulkAiSummaryJobs`) always excludes already-scored candidates. Add the same "re-review already-scored" option there, **mirroring the whole-job `rescore_requested` analog exactly** (not a functional look-alike — same param names / structure).

---

## Related scratchpads

- **QA guide**: `~/claude-hub/inflow-ats/qa-guides/plato-ai-manual-qa-2026-07-01/` — D1 manual QA guide, D2 scoring manifest, D3 changelog, Fable/Sonnet review outputs, CORRECTIONS.md.
- **Textract backfill console**: `~/claude-hub/inflow-ats/_in-progress/textract-backfill/textract_backfill_console.txt` — production console functions (run/dry-run bulk + per-org, delete-scheduled). Backfill re-enqueued at 3s (~48,371 jobs, last fires ~2026-07-04 19:29 UTC).

## Open verifications

- `c89ebea53` + `7b441550f` are now BOTH pushed to `origin/qa-refinements` (verified 2026-07-02). They still need a PR/merge `qa-refinements` → `develop` to ship.
- Staging: the drifted `Job.ai_job_application_summaries_count` on the cloned job still needs the one-off recompute (the code fix prevents future drift only). Console: `AiJobApplicationSummaryStatus.counter_culture_fix_counts(where: { jobs: { id: <job_id> } })` — or, once the session-2026-07-03 changes are deployed, `job.reset_ai_summaries_count`.

---

# Session update 2026-07-03 (QA touch-ups session)

Companion docs in this directory: `rescore-fix-plan.md` (bulk rescore fix, partially implemented), `decisions.md` (all rulings + OPEN items).

## Session changes — ALL COMMITTED on `qa-refinements` (update, end of session)

Two commits, both with Cypress pre-commit green:
- `18ff6745a` — items 1–3 below (counter fix, stale write, latest-record unification).
- `d9f08ec5d` — the bulk rescore fix per `rescore-fix-plan.md` (all backend steps + item 4 below + spec updates; both interactor spec files pass 20/20; the 9 failures in `bulk_generate_ai_summaries_job_spec.rb` are pre-existing at HEAD, verified, untouched).

Branch is now 8 commits ahead of `origin/qa-refinements` — still unpushed. Staging deploy needed before the rescore fix can be QA'd there. Note: the pre-commit hook stopped the local dev server ("Run 'foreman start' to restart it").

Original session notes below (statuses superseded by the commits above):

1. **Bug #7 counter fix** — `app/models/job.rb`: new `Job#reset_ai_summaries_count` (scoped `counter_culture_fix_counts`), called from `Job#reset_counters`; `app/models/job_application.rb`: `track_movement` calls it on both jobs when `saved_change_to_job_id?`. Root cause: `counter_culture [:job_application, :job]` on `AiJobApplicationSummaryStatus` fires only on status-row saves; a move saves only the `JobApplication`, so neither job's `ai_job_application_summaries_count` updated.
2. **`SubmitResumeToTextract` stale write** — replaced the conditional skip (`unless ... textract_processing ... exists?`) with an explicit write: find the waiting summary via `latest_ai_job_application_summary` + state check, then `where.not(id: ...).update_all(stale: true)` unconditionally. Also removed the duplicate `find_by` in the save branch.
3. **Latest-record unification** — `SubmitResumeToTextract`, `GetResumeTextFromTextractJob.cleanup_orphaned_summary`, `TextractResult#queue_ai_summary_job` all now derive the waiting summary from `latest_ai_job_application_summary` and verify state, instead of attribute-first `find_by`. Consequence: a non-latest `textract_processing` row is never operated on and is retired (staled) on the next resume submission.
4. **Per-stage frontend parameter** — `rescoreRequested: boolean` added to `BulkGenerateParams` (`useBulkGenerateAiSummaries.ts`); `rescoreRequested: false` literal at the `bulkGenerate(` call in `BulkGenerateAiSummariesConfirmModal.tsx`. Part of the rescore fix plan (backend NOT yet implemented — see `rescore-fix-plan.md`).

## New bug found (root-caused, fix planned, not implemented)

Whole-job bulk run with re-score checked regenerates nothing and reports all candidates as succeeded. Full analysis + decided fix design in `rescore-fix-plan.md`. OPEN items (including three unaccepted consequences) in `decisions.md` — do not implement past them without rulings.

## Cross-branch warning

The concurrent agent on `job-criteria-settings` (own worktree, `../inflow-ats.job-criteria-settings`) modifies `queue_bulk_ai_summary_jobs.rb`, `bulk_generate_ai_summaries_job.rb`, `job.rb`, `textract_result.rb`, and both bulk spec files. Merge conflicts with this session's work are expected and accepted; sequencing is Jessica's call. Also: the planned per-stage rescore work item says to "mirror the whole-job rescore_requested analog exactly" — that reference implementation is the broken one; the instruction must point at the fixed pipeline instead.

## `qa-refinements` branch state

6 commits ahead of `origin/qa-refinements` (unpushed), including the develop merge `05c9513ef`.
