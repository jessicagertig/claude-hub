# Re-verify: Pipeline (driving method / Orchestrate / stages / bridge-selector role)

Verdict: CLEAN

## Previously-flagged findings — all resolved

1. **Bridge-selector role must NOT be stated as determining the advancing record.**
   RESOLVED. NEW line 331: "This selection is read only to obtain `requested_by_organization_user_id` and to choose the branch; the job receives `textract_result_id` only (`:129`), never a summary id." No inversion. A second statement at NEW line 404 is consistent (selector role not used to advance).

2. **`generate.rb:30` must be cited as an independent ordered re-selection site.**
   RESOLVED. NEW line 331: "The advancing record is re-selected independently by an ordered query (`Orchestrate#call` `orchestrate.rb:15` and `Summary::Generate` `generate.rb:30`, both `order(created_at: :desc).first`)." Verified against source: generate.rb:30 and orchestrate.rb:15 are both `@job_application.ai_job_application_summaries.order(created_at: :desc).first`.

3. **S-E advancing-selector divergence window must be present.**
   RESOLVED. NEW line 331 final sentence: "When the latest-by-`created_at` summary is not the `textract_processing` one this selector found, the record that advances differs from the one whose `requested_by_organization_user_id` drove the branch decision." Matches OLD line 234.

## Fresh check (a) — dropped/altered facts

None. OLD load-bearing facts for this topic (OLD 232-235, 614-616) all present in NEW: driving-method/actor chain (NEW 342-349), credit charge on S-E success (NEW 349, 404), bridge guards/branches (NEW 329-336), X3 user-drop / no-toast across criteria boundary (NEW 356, 383, 400-404), auto-branch three downstream cases (NEW 385-392). Code references verified against source repo: textract_result.rb:121-123 (selector), :129 (textract_result_id), :130 (requested_by_organization_user_id), orchestrate.rb:15, generate.rb:30.

## Fresh check (b) — framing/judgment

None. Topic sections (NEW 325-405) contain no banned vocab (dead end, stuck, broken, orphan, no-op, silently, hazard, fails to, MAP-WRONG, gap-as-defect) and no subtler framing (prescriptive should, never recovers, incorrect, problem, defect, wrong). The two "never" occurrences ("never a summary id", "never `:retrying`") are factual descriptions of code behavior, not editorializing. The OLD file's defect-framing for this topic (STUCK, NO-OP, NOT, judgmental caps) has been fully neutralized.
