# T7 — External Resume URL Lazy Attachment (AttachExternalResumeUrlJob)

## Files traced
- `app/controllers/api/v1/job_applications_controller.rb:56-60` (show action — job enqueue)
- `app/jobs/job_application/attach_external_resume_url_job.rb:1-18`
- `app/models/job_application.rb:641-657` (`attach_external_resume_url`)
- `app/models/job_application.rb:709-711` (`should_attach_external_resume_url?`)
- `app/models/job_application.rb:589-602` (`has_resume`)
- `app/models/job_application.rb:94-98` (`external_resume_status` enum, `_prefix: true`)
- `app/models/job_application.rb:45-46` (`after_commit` callbacks — only `:create` and `:update`)
- `app/models/job_application.rb:164-171` (`enqueue_new_job_application` — the ONLY caller of `SubmitResumeToTextractJob`)
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:152-154` (`attachExternalResumeComplete` handler)

Chain: `job_applications_controller.rb:56-60` -> `attach_external_resume_url_job.rb:9` -> `job_application.rb:641 attach_external_resume_url` -> `job_application.rb:709 should_attach_external_resume_url?` -> `job_application.rb:589 has_resume`. Broadcast: `attach_external_resume_url_job.rb:11` -> `WebsocketGlobalChannelHandler.tsx:152`.

## Trigger
`app/controllers/api/v1/job_applications_controller.rb:58-59`:
```ruby
JobApplication::AttachExternalResumeUrlJob.perform_later(organization_user_id: current_organization_user.id,
                                                         job_application_id: params[:id]) if @job_application.should_attach_external_resume_url?
```
Fires in the `show` action only when `should_attach_external_resume_url?` is true.

`app/models/job_application.rb:709-711`:
```ruby
def should_attach_external_resume_url?
  external_resume_status_pending? && !has_resume
end
```

## Job body
`app/jobs/job_application/attach_external_resume_url_job.rb:6-16`:
```ruby
def perform(job_application_id:, organization_user_id:)
  @organization_user = OrganizationUser.find(organization_user_id)
  @job_application = JobApplication.find(job_application_id)
  @job_application.attach_external_resume_url

  GlobalChannel.broadcast_to(@organization_user.user, action: 'attachExternalResumeComplete',
                             payload: { jobApplicationId: job_application_id })
rescue StandardError => e
  ap 'Attach External Resume Url Error'
  ap e
end
```

## Attachment + terminal status
`app/models/job_application.rb:641-657`:
```ruby
def attach_external_resume_url
  return unless should_attach_external_resume_url?

  begin
    downloaded_resume = URI.open(external_resume_url)

    if downloaded_resume.content_type == 'application/pdf'
      resume.attach(io: downloaded_resume, filename: 'resume.pdf')
      update_column(:external_resume_status, :uploaded)
    else
      update_column(:external_resume_status, :error)
    end
  rescue StandardError => e
    update_column(:external_resume_status, :error)
    Rails.logger.error e
  end
end
```

Three terminal outcomes, all via `update_column` (no callbacks, no `after_commit`, no dirty tracking, no validations):
- PDF downloaded: `resume.attach(...)` + `external_resume_status: :uploaded` (line 648-649)
- Non-PDF: `external_resume_status: :error` (line 651)
- Exception: `external_resume_status: :error` (line 654)

## TEXTRACT VERDICT — still NOT triggered (gap persists, CONFIRMED)

The only code path that enqueues `SubmitResumeToTextractJob` from a `JobApplication` is `enqueue_new_job_application`:

`app/models/job_application.rb:164-171`:
```ruby
def enqueue_new_job_application
  NewJobApplicationJob.perform_later(id)
  DocxToPdfJob.perform_later(id)
  if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)
    SubmitResumeToTextractJob.perform_later(id)
  end
  find_or_create_ai_job_application_summary_status
end
```

This method runs ONLY via `after_commit :enqueue_new_job_application, on: [:create]` (`job_application.rb:45`). The lazy-attach path:
1. Uses `update_column` (line 649) which bypasses callbacks and does not fire `after_commit` of any kind.
2. `resume.attach` (Active Storage) does not run `enqueue_new_job_application` — that callback is `on: [:create]` of the JobApplication record, not on attachment.

So no Textract job is enqueued after the external resume is lazily attached. **TEXTRACT IS NOT TRIGGERED** — same as the old map flagged.

Backfill remains the only path to Textract for these records: `QueueBulkAiSummaryJobs` (Trigger 8 in map) submits resume-but-no-textract candidates, and manual AI summary generation (Trigger 9). Neither is automatic on attach.

## Re-entry / dead end
After the job runs once and sets `external_resume_status: :uploaded` with resume attached, a subsequent `show` request re-evaluates `should_attach_external_resume_url?` (`external_resume_status_pending? && !has_resume`) -> false, so the job does not re-fire. On the `:error` path the record rests at `external_resume_status: :error`; `external_resume_status_pending?` is false, so it never re-enqueues either — a dead end with no further automatic actor (no resume, no Textract). No actor advances an attached-but-no-Textract record to Textract automatically; it rests until a bulk backfill or manual generate run picks it up.

## Broadcast
`attach_external_resume_url_job.rb:11` broadcasts `attachExternalResumeComplete`. Frontend handler `WebsocketGlobalChannelHandler.tsx:152-154` only invalidates `["jobApplication", id]` (refetch). It does NOT call any Textract endpoint.

## Map verdicts
- Trigger 7 chain (Controller show -> AttachExternalResumeUrlJob -> attach_external_resume_url): CONFIRMED.
- Condition `external_resume_status_pending? && !has_resume`: CONFIRMED (line 710).
- `update_column(:external_resume_status, :uploaded)` no callbacks: CONFIRMED (line 649).
- "TEXTRACT IS NOT TRIGGERED": CONFIRMED (still a gap; no actor enqueues Textract on this path).
- Map line "File: app/models/job_application.rb:626-642": MAP-WRONG on line numbers — current method is at lines 641-657 (`should_attach_external_resume_url?` at 709-711). The map cites 626-642, which in current code is `resume_encoded_s3_url` (626) plus the first two lines of `attach_external_resume_url`.

## Record-write sites on this slice
| file:line | literal | column | op |
|---|---|---|---|
| app/models/job_application.rb:648 | `resume.attach(io: downloaded_resume, filename: 'resume.pdf')` | resume (Active Storage attachment) | attach |
| app/models/job_application.rb:649 | `update_column(:external_resume_status, :uploaded)` | external_resume_status | update_column |
| app/models/job_application.rb:651 | `update_column(:external_resume_status, :error)` | external_resume_status | update_column |
| app/models/job_application.rb:654 | `update_column(:external_resume_status, :error)` | external_resume_status | update_column |

No writes to TextractResult, AiJobApplicationSummary, AiJobApplicationSummaryStatus, or AiJobCriteria occur on this slice.
