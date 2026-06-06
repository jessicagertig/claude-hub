# Review Angles — No TextractResult Path Fix

Generated from: SPEC.md
Date: 2026-06-05

## Subsystems touched

**Directly modified:**
- `app/services/submit_resume_to_textract.rb` — Change 1: update `textract_result_id` on waiting `AiJobApplicationSummary`
- `app/jobs/get_resume_text_from_textract_job.rb` — Change 2: retry exhaustion cleanup
- `app/models/ai_job_application_summary.rb` — Change 3: nil guard on `destroy_previous_textract_results`

**Indirectly affected (not modified but dependent on changes):**
- `app/interactors/validate_ai_summary_generation.rb` — prerequisite already applied, triggers the new path
- `app/interactors/create_ai_summary_generation.rb` — creates the `textract_processing` summary with nil `textract_result_id`
- `app/models/textract_result.rb` — owns `queue_ai_summary_job` callback, `broadcast_ai_summary_failed`, `destroy` cascades to `AiJobApplicationSummary`
- `app/services/get_resume_text_from_textract.rb` — creates TextractResult, raises `CustomErrorTextract` on failure
- `app/services/ai_job_application_action/summary/generate.rb` — consumes `textract_result_id`, updates existing summaries
- `app/jobs/generate_ai_job_application_summary_job.rb` — dispatches summary generation after Textract completes
- `app/interactors/queue_bulk_ai_summary_jobs.rb` — also handles resume-but-no-textract candidates

## Angles

### angle-1: trigger-interaction

**What this covers:** Whether the 3 changes interact correctly with ALL 8 Textract triggers and ALL 5 AI summary triggers. The "no TextractResult" path we're fixing is one entry point, but `SubmitResumeToTextract#submit_resume` is called from 8 different triggers. Change 1 (updating `textract_result_id` after save) fires for ALL of them — not just the "no TextractResult" path. Does that cause problems for the other 7 triggers where a `textract_processing` summary may or may not exist?

**Files across all layers:**
- `app/services/submit_resume_to_textract.rb` (Change 1 lives here)
- `app/models/job_application.rb:150-156` (Trigger 1: `enqueue_new_job_application`)
- `app/controllers/api/v1/job_applications_controller.rb:106-111` (Trigger 2: manual resume upload)
- `app/interactors/queue_bulk_ai_summary_jobs.rb:22-30` (Trigger 8: bulk AI summary backfill)
- `app/interactors/validate_ai_summary_generation.rb` (triggers the new no-TextractResult path)

**Key questions:**
- When `SubmitResumeToTextract` fires from Trigger 1 (new job app), is there ever a `textract_processing` summary? (No — summary creation happens later. Change 1 is a no-op here.)
- When `SubmitResumeToTextract` fires from Trigger 2 (resume replacement), `SubmitResumeToTextract` destroys the previous TextractResult first (line 17-20). Does that cascade-destroy a `textract_processing` summary before Change 1 can update it?
- When `QueueBulkAiSummaryJobs` (Trigger 8) kicks off `SubmitResumeToTextractJob` for resume-but-no-textract candidates, does it also create a `textract_processing` summary? Does that conflict with our path?

### angle-2: async-timing-and-race-conditions

**What this covers:** The async handoff points where timing matters. `ValidateAiSummaryGeneration` creates the summary, then `SubmitResumeToTextractJob` runs later (async). Between those two events, the summary has nil `textract_result_id`. What happens if the user clicks "generate" again? What happens if `SubmitResumeToTextract` fails before creating the TextractResult? What happens if `GetResumeTextFromTextract` succeeds before Change 1 runs (race between `SubmitResumeToTextractJob` and `GetResumeTextFromTextractJob`)?

**Files across all layers:**
- `app/interactors/validate_ai_summary_generation.rb` (kicks off async job, returns immediately)
- `app/interactors/create_ai_summary_generation.rb` (active summary check at lines 30-38 — handles double-click)
- `app/services/submit_resume_to_textract.rb` (Change 1 runs here — but what if `save` fails?)
- `app/services/get_resume_text_from_textract.rb` (polls Textract, updates TextractResult — triggers `queue_ai_summary_job`)
- `app/models/textract_result.rb:95-125` (`queue_ai_summary_job` — finds `textract_processing` summary, but what if `textract_result_id` is still nil at this point?)

**Key questions:**
- If `SubmitResumeToTextract#submit_resume` fails at the AWS call (lines 31-40), no TextractResult is created. The `textract_processing` summary is orphaned with nil `textract_result_id`. Nobody cleans it up. Change 2 only handles `GetResumeTextFromTextractJob` exhaustion, not `SubmitResumeToTextract` failure.
- `queue_ai_summary_job` at line 109 calls `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)`. The Generate service at line 30-33 finds the summary and updates it to `in_progress`. But it does NOT update `textract_result_id` on the summary — it only updates `status`. Is `textract_result_id` guaranteed to be set by Change 1 before this point? (Yes — Change 1 runs synchronously inside `submit_resume`, and `queue_ai_summary_job` fires on the `update` commit of the same TextractResult. But verify the ordering.)

### angle-3: cascade-and-cleanup

**What this covers:** The cascading delete chain and all cleanup paths. `TextractResult has_many :ai_job_application_summaries, dependent: :destroy`. When `SubmitResumeToTextract` destroys a previous TextractResult (line 17-20), all its summaries are cascade-destroyed. But our new `textract_processing` summary has nil `textract_result_id` — it's NOT associated with any TextractResult. Does the cascade miss it? Is that correct behavior, or does it leave an orphan?

Also covers: all the paths where a `textract_processing` summary gets cleaned up or left behind.

**Files across all layers:**
- `app/services/submit_resume_to_textract.rb:17-20` (destroys previous TextractResult)
- `app/models/textract_result.rb:5` (`has_many :ai_job_application_summaries, dependent: :destroy`)
- `app/models/ai_job_application_summary.rb` (Change 3: nil guard, plus `destroy_previous_textract_results` callback)
- `app/jobs/get_resume_text_from_textract_job.rb` (Change 2: exhaustion cleanup)
- `app/services/ai_job_application_action/summary/generate.rb:30-40` (existing summary reuse — stale check)

**Key questions:**
- If a `textract_processing` summary has nil `textract_result_id` and `SubmitResumeToTextract` runs again for the same job application (resume re-upload), the old TextractResult is destroyed but the orphaned summary survives (not associated via FK). Is that a problem? Should `SubmitResumeToTextract` also destroy `textract_processing` summaries on the job application?
- Gap 5 from the trace doc: if AWS Textract succeeds but `GetResumeTextFromTextract`'s `update` call fails, the TextractResult stays `in_progress` forever. The `textract_processing` summary is also stuck forever. Change 2 only covers `CustomErrorTextract` exhaustion. This `update` failure path is a different code path — does it need coverage?

### angle-4: notification-and-user-feedback

**What this covers:** Whether the user gets correct feedback in every scenario. The frontend shows "Resume is being processed. Summary will generate automatically." for `textract_processing` status. But what if processing takes 15+ minutes (3 retries × 5 min)? What if the user leaves and comes back? What if the exhaustion notification fires but the user has already navigated away?

**Files across all layers:**
- `app/jobs/get_resume_text_from_textract_job.rb` (Change 2: broadcasts `AI_SUMMARY_FAILED` on exhaustion)
- `app/models/textract_result.rb:127-141` (`broadcast_ai_summary_failed` — requires `requesting_organization_user`)
- `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx:84-85` (frontend `textract_processing` display)
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` (`AI_SUMMARY_FAILED` handler)
- `app/serializers/api/v1/ai_job_application_summary_serializer.rb` (what's sent to frontend)

**Key questions:**
- Auto-generated summaries have nil `requested_by_organization_user_id`. Change 2's exhaustion block calls `broadcast_ai_summary_failed` which guards `return unless requesting_organization_user`. So for auto-generated summaries, the orphaned summary is destroyed but nobody is notified. Is silent failure acceptable for auto-generation?
- If the user reloads the page while `textract_processing`, the serializer returns the summary with `status: textract_processing`. The frontend shows "processing." Correct. But if exhaustion happens and the summary is destroyed, the next reload returns no summary — the user sees nothing, no error message. The WebSocket notification was the only signal, and if they missed it, there's no indication anything was attempted.

## Always-on checks

### Source accuracy
Verify every file path, line number, method name, and behavioral claim in the spec against the current source.

### Test coverage
Verify the spec's test requirements are sufficient. Check existing test files for the affected code. Verify no existing tests break.

### Backward compatibility
Verify all consumers of modified code are addressed. The `optional: true` change on `belongs_to :textract_result` affects every caller that assumes `textract_result` is non-nil.
