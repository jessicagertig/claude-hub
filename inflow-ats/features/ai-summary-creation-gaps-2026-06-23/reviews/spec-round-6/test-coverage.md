# test-coverage — Round 6

Completed the exhaustive #6 ripple sweep across ALL changed surfaces (enum, broadcast, enqueue-`.with`, destroy).

## Findings
No NEW findings beyond the W4 broadcast-test ripple (see websocket-broadcast.md F1). The Round-5 ripples (W6 `ai_job_criteria_spec.rb:62`; C8 `get_resume_text_from_textract_job_spec.rb:32-78`) remain correctly flagged.

## Ripple completeness (confirmed)
- W5 enum: NO `described_class.statuses).to eq` assertion exists in `ai_job_application_summary_status_spec.rb` (the file W5 changes) -> `failed: 4` breaks no exhaustive-enum test. The two `.statuses).to eq` assertions in spec/ are on AiJobApplicationSummary (`ai_job_application_summary_spec.rb:8`) and AiJobCriteria (`ai_job_criteria_spec.rb:20`), neither changed. SAFE.
- W6 enqueue `.with`: only `ai_job_criteria_spec.rb:62` (resume_waiting_summaries, single-key, breaks). `textract_result_ai_trigger_spec.rb:93` `.with(textract_result_id:)` matches the auto-gen ELSE-branch enqueue (single-key, unchanged by W6). SAFE.
- RSpec `have_enqueued_job(...).with(...)` is EXACT arg-hash matching -> the single-key matcher at `:62` will mismatch the two-key W6 enqueue (Round-5 finding confirmed correct).
- C8 destroy assertions: `get_resume_text_from_textract_job_spec.rb:32-36/72-78` (Round-5). SAFE-flagged.

## Amendments Applied (Round 6)
None (the W4 ripple amendment is recorded under websocket-broadcast.md).
