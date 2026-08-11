# Layer 1 — Focus Area: Background Job + Error Class

## Files reviewed

- `app/errors/custom_error_structured_extraction.rb` (new)
- `app/jobs/extract_structured_resume_data_job.rb` (new)

## Analog files compared

- `app/errors/custom_error_textract.rb`
- `app/errors/custom_error_ai_summary.rb`
- `app/jobs/get_resume_text_from_textract_job.rb`
- `app/jobs/generate_ai_job_application_summary_job.rb`

## Error class checks

| Check | Result |
|---|---|
| Extends `StandardError` | MATCH |
| `attr_reader :param` | MATCH |
| `initialize(msg = '...', param = '')` signature | MATCH |
| `@param = param.to_s` | MATCH |
| `super(msg)` | MATCH |
| `frozen_string_literal: true` | MATCH |
| Default message `'Custom Error - Structured Extraction'` | Pattern-consistent |

Exact structural match with both `CustomErrorTextract` and `CustomErrorAiSummary`.

## Job checks

| Spec requirement | Code | Result |
|---|---|---|
| `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` | Line 6 — exact match | MATCH |
| Exhaustion block logs and moves on | Lines 6-9 — `ap`, `Rails.logger.error`, no re-raise, no cleanup | MATCH (spec: "extraction is supplementary") |
| Takes `textract_result_id` (ID, not object) | Line 12 — `def perform(textract_result_id)` | MATCH |
| Delegates to `ExtractStructuredResumeData` service | Line 13 — `.new(textract_result_id: textract_result_id).extract` | MATCH |
| Rescues `CustomErrorStructuredExtraction` and re-raises | Lines 14-17 — rescue + raise | MATCH |
| Rescues `StandardError` and does NOT re-raise | Lines 18-21 — rescue, log, no raise | MATCH |
| Pattern matches `GetResumeTextFromTextractJob` | `wait: 5.minutes` matches Textract job; rescue/raise pattern matches `GenerateAiJobApplicationSummaryJob` | MATCH |
| `queue_as :default` | Line 4 | MATCH |
| `frozen_string_literal: true` | Line 1 | MATCH |
| Inherits `ApplicationJob` | Line 3 | MATCH |

## VERDICT: CLEAN — 0 findings
