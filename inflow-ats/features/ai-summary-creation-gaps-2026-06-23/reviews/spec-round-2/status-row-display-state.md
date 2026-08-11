# status-row display-state & denormalization (W5 + C1) — Round 2

Re-verified the choke-point site list completeness and error_message-verbatim requirement.

## Findings
No new MED+ findings.

## Re-verified correct
- W5 site list COMPLETE: grep `status: :failed` across app/ confirms the 8 summary-side writers (generate_ai_job_application_summary_job:19,44; generate:180,184; score:134,138; integrate:64,68) + C8 destroy:19, with all AiJobCriteria/other-model `status: :failed` writers correctly excluded. CONFIRMED.
- error_message verbatim per site (Round-1 F1 fix): strings match live code (`"Failed to parse AI response: ..."` for JSON::ParserError sites; `e&.message`/`error&.message` for StandardError/exhaustion; C8 string). CONFIRMED.
- counter_culture idempotent decrement; C1 stale guard; PlatoOverviewCallout dead-code stale union (LOW, dead, not amended); NavItem/Activity/bulkAiSummaryCount safe with new value. CONFIRMED.
- record_failure callable from all site contexts incl. the class-block at generate_ai_job_application_summary_job:19 (instance method on `ai_summary` instance). CONFIRMED.

## Amendments Applied (Round 2)
None.
