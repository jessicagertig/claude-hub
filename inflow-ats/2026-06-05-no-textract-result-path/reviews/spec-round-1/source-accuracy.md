# Source Accuracy — Round 1

## Findings

Verified every file path, line number, method name, and behavioral claim:

- `app/services/submit_resume_to_textract.rb` line 24: `if @textract_result.save` — CORRECT
- `app/services/submit_resume_to_textract.rb` line 22: `@job_application.textract_results.build` — CORRECT
- `app/services/submit_resume_to_textract.rb` line 27: `GetResumeTextFromTextractJob` — CORRECT
- `app/jobs/get_resume_text_from_textract_job.rb` line 6: `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` — CORRECT
- `app/models/ai_job_application_summary.rb` line 37: `def destroy_previous_textract_results` — CORRECT
- `app/models/ai_job_application_summary.rb` line 38: `return unless saved_change_to_status? && status_succeeded?` — CORRECT (spec says line 37 for the guard, but the guard is the EXISTING line 38; the spec says to add a NEW guard at line 37 before the existing one — this is a line-numbering ambiguity since inserting a line shifts subsequent lines)
- `app/models/ai_job_application_summary.rb` line 41: `textract_result.created_at` — CORRECT
- `app/models/textract_result.rb` line 127: `def broadcast_ai_summary_failed` — CORRECT
- `app/models/textract_result.rb` line 128: `return unless requesting_organization_user` — CORRECT
- `app/models/textract_result.rb` line 5: `has_many :ai_job_application_summaries, ... dependent: :destroy` — CORRECT
- `belongs_to :textract_result, optional: true` on `AiJobApplicationSummary` — CORRECT (line 5)
- Spec claim "SubmitResumeToTextract is the sole creator" of TextractResult records — Verified. `@job_application.textract_results.build` only appears in `submit_resume_to_textract.rb`. CORRECT.

No issues found.

## Amendments Applied

None.
