# S-D Pass 2 — Adversarial Review: Resume-replacement re-generation

Slice S-D: a prior summary already exists for the job_application and a new resume/Textract result arrives.

Files re-read from scratch:
- `app/services/ai_job_application_action/orchestrate.rb`
- `app/models/textract_result.rb`
- `app/services/submit_resume_to_textract.rb`
- `app/models/job_application.rb` (associations + find_or_create wrapper)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/ai_job_application_summary.rb`
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/interactors/create_ai_summary_generation.rb`
- credit-consumption census via grep.

## The central dispute — the credit-burn claim is WRONG

The map asserts (lines 86, 121, 508, 456, 577) that on the resume-replacement AUTO path,
`generate_ai_summary_with_credit_flow` "re-fetches the same stale-succeeded summary", passes the
`status_succeeded?` check at `textract_result.rb:82`, and charges 1 credit at `:84` for the OLD summary.

This conflates two different associations:

- `textract_result.rb:77` literal: `ai_job_application_summary = ai_job_application_summaries.order(created_at: :desc).first`.
  The bare `ai_job_application_summaries` here is `self.ai_job_application_summaries` — the **TextractResult's**
  `has_many :ai_job_application_summaries` (`textract_result.rb:5`). `self` is the **NEW** TextractResult.
- `orchestrate.rb:15` literal: `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first`.
  This is the **JobApplication's** association — job-application-scoped — and DOES pick up the old stale-succeeded summary.

On the auto path the new TextractResult has **no** associated summaries:
- `submit_resume_to_textract.rb:22` builds the new TextractResult with no summaries.
- `submit_resume_to_textract.rb:25-26` relinks only a `textract_processing, stale:false, textract_result_id:nil`
  waiting summary onto the new result — the prior summary is `succeeded`, not `textract_processing`, so it stays
  attached to the OLD result.
- Orchestrate returns at `orchestrate.rb:46-48` on the `succeeded` branch BEFORE `run_summary`, so
  `Summary::Generate` (the only first-summary creator) never runs and never attaches a new summary to the new result.

Therefore `textract_result.rb:77` returns **nil**, `:82` `return unless ai_job_application_summary&.status_succeeded?`
returns, and `CreateAiCreditBalanceTransaction.call` at `:84` is NEVER reached. `:84` is the ONLY credit-consumption
site in the app (grep over `app/`). No credit is burned on the auto path.

The same scoping appears in `generate_ai_job_application_summary_job.rb:18,43,60`, all
`textract_result.ai_job_application_summaries...` — TextractResult-scoped — reinforcing that the job/credit-flow
operates on the NEW result's (empty) summary set, not the JobApplication's.

## What the map gets RIGHT on S-D

- Staling: `submit_resume_to_textract.rb:18-19` `update_all(stale: true)` marks all summaries stale (the prior succeeded
  one becomes `succeeded + stale:true`; `update_all` does not touch `status`). AGREE.
- `textract_result.rb:67-68` guard `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`
  does NOT short-circuit the stale-succeeded case (`!stale?` is false), so the flow continues. AGREE.
- Orchestrate selects the latest summary with no stale filter (`orchestrate.rb:15`), latest is the stale-succeeded one,
  succeeded branch returns (`orchestrate.rb:46-48`), `run_summary`/`Summary::Generate` never runs → no new summary. AGREE.
- Status row → `regenerating`: `find_or_create_ai_job_application_summary_status.rb:14-15`. On the auto path the existing
  status row's `ai_job_application_summary` (`:12`) is the OLD succeeded summary → `summary&.status_succeeded?` true →
  `update_columns(status: 'regenerating')`. Reset to `current` only via
  `ai_job_application_summary.rb:69,74` on a summary→succeeded transition, which never happens → stuck `regenerating`. AGREE.
- Manual regen variant: `create_ai_summary_generation.rb:30-34` filters `where(stale: false)`, excludes the stale-succeeded
  summary; `:36-39` stales any active summary whose `textract_result_id` mismatches `latest_textract_result`; `:60-74`
  builds a NEW `:pending` summary attached to the new TextractResult and enqueues the job. On the manual path
  `textract_result.rb:77` then DOES find that new summary, the pipeline drives it to succeeded, and 1 credit is charged
  for the NEW summary. AGREE.

## Net for the desync/dead-end claims

The "stuck `regenerating` with stale denormalized data" portion is correct; the "+ 1 credit burned" rider attached to it
(map lines 456, 508, 577) is incorrect for the auto path. The auto path is a pure no-op dead end: no new summary, no
credit, status row stuck `regenerating` with stale denormalized score/headline/analysis.

## Omissions

1. The map never states that the new TextractResult has zero associated summaries on the auto path, which is the precise
   reason `textract_result.rb:77` returns nil. Without this, the credit reasoning cannot be evaluated and the map
   reached the wrong conclusion.
2. The map does not note the scope difference between `orchestrate.rb:15` (JobApplication-scoped) and
   `textract_result.rb:77` (TextractResult-scoped) — the exact distinction that makes the auto path a no-op for credit.
3. On the auto path `find_or_create_ai_job_application_summary_status.rb:12` keys off the STATUS ROW's
   `ai_job_application_summary` (its denormalized `ai_job_application_summary_id`), not
   `job_application.latest_ai_job_application_summary`. The map's prose at line 451 ("existing row whose associated
   summary status_succeeded?") is technically consistent but the map never makes explicit that the `regenerating`
   decision is driven by the OLD pointer, not the latest summary.
