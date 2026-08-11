# Pass 1 — Verdict

## Finding Counts

| Severity | Count | Details |
|----------|-------|---------|
| BLOCKER | 0 | — |
| HIGH | 1 | F1: Orchestrator case statement omits `status_retrying?` |
| MED | 3 | F2: Wrong line number reference; F3: `SubmitResumeToTextract` omitted from enum audit; F4: Controller eager loading not a task step |
| LOW | 0 | — |

## Verdict: FAIL

One HIGH finding requires amendment.

## Amendments Applied

### Amendment 1 (F1 — HIGH): Add `status_retrying?` to orchestrator case statement

In `plan.md` Phase E, step E.1.3, the first `when` branch of the case statement must include `status_retrying?`:

```ruby
when @ai_job_application_summary.status_pending? ||
     @ai_job_application_summary.status_textract_processing? ||
     @ai_job_application_summary.status_extracting? ||
     @ai_job_application_summary.status_retrying?
  run_summary
  check_criteria_and_score
```

Also update R3/R6 to note this is now reflected in the code, not just stated as a "TODO."

### Amendment 2 (F2 — MED): Fix line number reference

In `plan.md` Phase C, step C.1.5, change "Line 35" to "Line 38".

### Amendment 3 (F3 — MED): Add `SubmitResumeToTextract` to enum audit

In `plan.md` Phase C, add a new step after C.6:

**C.7 `app/services/submit_resume_to_textract.rb`**
- C.7.1 Line 18: `status: :textract_processing` — **unchanged**
- C.7.2 Line 25: `status: :textract_processing` — **unchanged**

Renumber existing C.7 (Spec files) to C.8.

### Amendment 4 (F4 — MED): Add controller eager loading task step

In `plan.md` Phase H, add step H.4.2:

**H.4.2** Add `.includes(:ai_job_application_summary_status)` to the `ShallowJobApplicationSerializer` queries in `app/controllers/api/v1/job_applications_controller.rb`:
- Line 25: Add to existing `.includes(resume_attachment: :blob)` chain
- Line 35: Add to existing `.includes(resume_attachment: :blob)` chain

Add `app/controllers/api/v1/job_applications_controller.rb` to the "Modified Files" table with "Add eager loading for `ai_job_application_summary_status`" as the change description.
