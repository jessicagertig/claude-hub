# async-timing-and-race-conditions — Pass 1

## Fact Check

| Claim | Verified? |
|---|---|
| Change 1 runs synchronously inside `submit_resume` before `GetResumeTextFromTextractJob` is enqueued | YES — line 24 (save) before line 27 (enqueue) |
| `GetResumeTextFromTextractJob` argument is `job_application_id` | YES — `submit_resume_to_textract.rb:27`: `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(@job_application.id)` |
| Exhaustion block gets `job.arguments.first` = `job_application_id` | YES — ActiveJob stores positional args in `arguments` array |
| `CustomErrorTextract` is a valid error class | YES — defined at `app/errors/custom_error_textract.rb:3` |
| `retry_on ... do |job, _error|` is valid Rails syntax for exhaustion | YES — matches `bulk_generate_ai_summaries_job.rb:17` pattern |

## Completeness

- Spec Change 2 requirement: exhaustion block that finds summary, destroys it, broadcasts failure — Plan Task B.1 covers this fully.
- The plan correctly handles the case where `job_application` is nil (`next unless job_application`) and where no summary exists (`next unless summary`).

## Findings

No issues found.

## Amendments Applied

None.
