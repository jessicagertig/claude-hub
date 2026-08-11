# source-accuracy — Round 2

Re-verified the Round-1 amendments against live code and re-swept for new citation drift introduced by the edits.

## Findings
- F1 [HIGH] -- (introduced by the Round-1 W3 amendment) symbol vs string keys on `previous_changes`. My Round-1 W3 amendment wrote `previous_changes.key?(:status)` / `previous_changes[:description]` (SYMBOL keys). `previous_changes` is a plain STRING-keyed Hash (confirmed: the analog `handle_after_update_commit` does `previous_changes.keys.map(&:to_sym)` at `job.rb:497,501,507` precisely because the keys are strings). Symbol access returns nil/false -> the W3 detection would silently never fire. Fixed in Round 2: spec now specifies string keys (`previous_changes['status']`/`['description']`) or the `saved_change_to_*` API, and explicitly warns against symbol keys. APPLIED (Round 2).

## Re-verified correct (Round-1 amendments)
- W2 controller local var `job_application` (not `@job_application`): confirmed `exists(...) do |job_application|` at `:90`. Amendment correct.
- W1 validate guards `:65-83` (private methods), 4 precondition guards named, `textract_text_ready?` excluded: confirmed `flipper_enabled?:65`, `has_resume?:69`, `textract_text_ready?:73`, `credits_available?:77`, `has_job_description?:81`. Amendment correct.
- W1/C8 `record_failure` call shape, `cleanup_orphaned_summary` is `self.` class method holding `summary` (`:14-15`, guard `:16`): confirmed. Amendment correct.
- W2 DocxToPdfJob `@job_application.resume_is_docx` guard: confirmed `DocxToPdfJob#perform` uses `@job_application` (`:7-8`). Amendment correct.
- W4 generate.rb:175 var `ai_summary`, rescue var `e`: confirmed. Amendment correct.
- W5 site list COMPLETE for AiJobApplicationSummary terminal-failed writes: grep `status: :failed` across app/ confirms exactly `generate_ai_job_application_summary_job.rb:19,44`, `integrate_analysis.rb:64,68`, `score_job_application.rb:134,138`, `generate.rb:180,184` on the summary; all OTHER `status: :failed` writers are on AiJobCriteria / other models (correctly excluded). C8 destroy `:19` added. Amendment correct + complete.
- W5 error_message strings per site: confirmed `:19` uses `error&.message` (block param), `:44` uses `e&.message`. Amendment correct.

## Amendments Applied (Round 2)
- SPEC.md W3 (line 74): `previous_changes` STRING keys (`'status'`/`'description'`), or `saved_change_to_*` API; warned against symbol keys.
