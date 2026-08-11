# Verify — AiJobApplicationSummary (data model + state-transition table)

**Verdict: CLEAN**

## Files checked
- OLD: backend-flow-map-2026-06-17.md (changelog lines 37, 222, 226; Part model def 575-593; state table 651-664; destroy-site census 850; rake-task note 855)
- NEW: backend-flow-map-2026-06-22-neutral.md (changelog line 37; model section 44-69; state table 459-474; destroy-site census 630; rake-task note 635; status-record cross-ref 518)

## CHECK 1 — Fact preservation

All load-bearing facts for the AiJobApplicationSummary model and its state-transition table appear in NEW:

- Associations `belongs_to :job_application`, `belongs_to :textract_result, optional: true`, `has_many :ai_api_requests, as: :requestable`, `has_one :ai_job_application_summary_status` (OLD 575-577 → NEW 48-51, with the `:8` citation added).
- 10-value status enum `{pending:0 … failed:9} _prefix:true` (OLD 579-581 → NEW 53-55).
- `BROADCAST_STATUSES` list and "omits awaiting_job_criteria and retrying" + `:23` citation (OLD 582-583, 222 → NEW 56-57).
- Columns list including `stale (boolean default false)`, nullable `textract_result_id` (OLD 585-587 → NEW 59-61).
- Callback `destroy_previous_textract_results` `:29`, `→succeeded` guards `:48`/`:49`, destroy_all of earlier non-succeeded TextractResults older than firing result `:47-55`,`:51-54` (OLD 590, 226 → NEW 65).
- Callback `update_summary_status_record` `:30`, method def `:57`, ap debug `:58-67`, guard `:69`, early return no-row `:72`, write `:74-80` to status `current` with denormalized columns, `ai_summary_succeeded` broadcast `:93-97`, `.update` semantics, unconditional re-point, `on: :update` only (OLD 591 → NEW 66).
- "Sole writer that recovers a regenerating (stale-pointer) row back to current" (OLD 591) preserved in NEW 518 (status-record cross-ref section).
- Callback `broadcast_status_change` `:31`, JobChannel `ai_summary_status_change`, BROADCAST_STATUSES gate `:100-102` (OLD 592 → NEW 67).
- "No create_status_record callback" (OLD 593, 37 → NEW 69, 37 with `:29-31`).
- State-transition table: every to-state row (pending, textract_processing, extracting, summarizing, awaiting_job_criteria, scoring, integrating, succeeded, retrying, failed) with writers, citations, preconditions, reached-by, resting/actor (OLD 655-664 → NEW 463-472). Succeeded fires update_summary_status_record + destroy_previous_textract_results (OLD 662 → NEW 470). GenerateAiJobApplicationSummaryJob failed-only-writer note (OLD 666 → NEW 474). extracting-via-C / auto-branch-case-2 note (OLD 667 → NEW 474).
- ai_bulk_extract.rake writes status `:in_progress`/`:extracted`/`:failed`, values not in current enum (OLD 855 → NEW 635).
- destroy_previous_textract_results destroy-site census entry (OLD 850 → NEW 630).

No dropped or altered file:line citations found. OLD's repeated statements of the same facts (e.g. destroy_previous_textract_results stated in changelog 226, model 590, census 850) are de-duplicated in NEW without loss.

## CHECK 2 — Neutrality

No banned vocab or framing in the NEW topic text. OLD's framing was neutralized:
- OLD "RESTING (terminal)" ALL-CAPS → NEW lowercase "resting (terminal)" (470, 472).
- OLD 664 "**no actor updates the status row on failure**" (bold) → NEW 472 plain "no actor updates the status row on a summary `failed`".
- OLD 591 "harmless" (judgment) → dropped in NEW 66; replaced by neutral "a summary created already-`succeeded` would not fire it".
- OLD 855 "STALE — would raise ArgumentError / would error" → NEW 635 neutral "not a value in the current 10-value enum".

The "REMOVED" / "MAP-WRONG" tokens that remain (NEW 37, 24) are structural DIVERGENCE-CHANGELOG markers describing changes-since-prior-map, and 24 concerns the sibling AiJobApplicationSummaryStatus record, not the AiJobApplicationSummary model under this topic.
