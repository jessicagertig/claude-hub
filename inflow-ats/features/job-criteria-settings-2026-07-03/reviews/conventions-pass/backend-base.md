# Conventions Pass — cursor_rules/backend/_base.md

Reviewed: `git diff develop...HEAD -- app/models app/controllers app/serializers app/jobs app/interactors app/services config spec` at HEAD 68e5e6a4e in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings
Rules file: cursor_rules/backend/_base.md (rules 1–9; spec/ files exempt per the rules file's own scope)

## Findings

- F1 [MED] app/jobs/extract_job_criteria_job.rb:46 / §8 No `reload` in Application Code / `broadcast_completion` calls `ai_job_criteria.reload` in application code (`app/`), which §8 prohibits: "Do not use `reload` in application code (`app/`). It is almost always a sign of a data flow problem — you have a stale reference because the record was mutated through a different code path." That is exactly the situation here — the `perform` path holds the `AiJobCriteria` instance fetched at line 16, while `AiJobApplicationAction::Scoring::ExtractCriteria` fetches its own instance and mutates `status`/`error_message` via `update_columns`, leaving the job's reference stale. (This call is SPEC-mandated, but this pass owns the conventions ruling.) / Evidence: line 46 `ai_job_criteria.reload` inside `broadcast_completion` / Fix: replace the `reload` with a fresh read, per §8's compliant pattern — e.g. in `broadcast_completion`, re-fetch instead of reloading:
  ```ruby
  ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)
  return unless ai_job_criteria
  ```
  (or pass `ai_job_criteria.id` into `broadcast_completion` and do the `AiJobCriteria.find_by(id: ...)` read there).

## Rules checked with no violations

- §1 No begin blocks in methods — no `begin ... rescue ... end` in the diff.
- §2 Rescue specific exception classes — `ExtractJobCriteriaJob#perform` rescues `CustomErrorAiSummary` first, `StandardError` only as fallback; no bare `Exception`.
- §3 No class/module-level rescue — none added (the `retry_on ... do |job, error|` block is a retry exhaustion block, not a rescue).
- §4 No empty rescue blocks — both rescue blocks in extract_job_criteria_job.rb log via `Rails.logger.error`/`ap` and update record state.
- §5 `=> e`/`=> exc` for rescued exception variables — both rescues use `=> e`. (The `error` name at extract_job_criteria_job.rb:5 is the pre-existing `retry_on` block parameter, not a rescued exception variable, and its signature line is not part of the diff.)
- §6 Avoid `ensure` blocks — none in the diff.
- §7 Single quotes for string literals — all new string literals in app/ and config/routes.rb are single-quoted; the only double-quoted string (extract_job_criteria_job.rb:29) uses interpolation and is pre-existing context.
- §9 Variable names match model names — `ai_job_criteria`, `requesting_organization_user`, `user`, `job`, `new_ai_job_criteria` all match their models (prefixes permitted by the rule); no generic/truncated record variable names introduced.

## Re-verification (post 9ed954142)

Re-reviewed at HEAD 9ed954142 in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings against cursor_rules/backend/_base.md only.

### F1 [MED] — RESOLVED

app/jobs/extract_job_criteria_job.rb:46-47 — `broadcast_completion` no longer calls `reload`. The shipped code uses the exact compliant pattern the finding suggested:

```ruby
ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)
return unless ai_job_criteria
```

`git grep '\.reload' -- app` confirms no `reload` remains anywhere in the feature's application code. §8 satisfied.

### Full backend diff re-check (anything NEW from the fix)

Commit 9ed954142's backend Ruby footprint is exactly two files (everything else in the commit is TSX/TS under app/javascript — outside this rules file's scope — plus one spec file, exempt per the rules file):

- app/jobs/extract_job_criteria_job.rb:46-47 — the fresh-read replacement itself. Compliant: no `reload` (§8), variable named `ai_job_criteria` matching the `AiJobCriteria` model (§9), no new rescue/ensure/begin constructs (§1-§6).
- app/jobs/bulk_generate_ai_summaries_job.rb:63 — new line `Rails.logger.error "BulkGenerateAiSummariesJob validation failed for job_application #{job_application_id}: #{result.error}"`. The double-quoted string contains interpolation, which §7 explicitly permits. Not inside a rescue block, so §1-§6 unaffected. `result` is an `Interactor::Context`, not a database record, so §9 does not apply.

Re-swept the full `git diff develop...HEAD` backend Ruby diff (app/controllers, app/interactors, app/jobs, app/models, app/serializers, app/services, config/routes.rb) against §1-§9: no violations beyond what the original pass already cleared. No new findings.

**Outcome: F1 RESOLVED, 0 new findings.**
