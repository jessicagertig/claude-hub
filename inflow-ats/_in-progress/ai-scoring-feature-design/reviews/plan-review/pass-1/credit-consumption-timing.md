# Pass 1 — credit-consumption-timing

## Fact Check

### `TextractResult#generate_ai_summary_with_credit_flow` status check (line 79)

Plan C.2.1 says line 79 `status_succeeded?` is unchanged and correct. Actual line 79: `return unless ai_job_application_summary&.status_succeeded?`. CORRECT.

In the new enum, `succeeded` means "full evaluation complete" (value 7). Credit consumption stays gated by this check. Since `succeeded` is now only set after `IntegrateAnalysis` completes (D.4.4), credits are consumed after the entire pipeline — not after just the summary portion. This is the correct timing per spec Section 8.

### `GenerateAiJobApplicationSummaryJob` broadcast check (line 61)

Plan C.3.3 says line 61 `status_succeeded?` is unchanged. Actual line 61: `status = ai_job_application_summary&.status_succeeded? ? 'succeeded' : 'failed'`. CORRECT.

The broadcast fires only when `requesting_organization_user_id` is provided (line 34). After the full pipeline, `status_succeeded?` means the complete evaluation passed. CORRECT timing.

### `AiJobApplicationSummary#destroy_previous_textract_results` (line 40)

Plan B.3.3 says `status_succeeded?` continues to work because `succeeded` is still in the enum. Actual line 40: `return unless saved_change_to_status? && status_succeeded?`. CORRECT — `succeeded` remains in the enum at value 7. The semantic meaning holds: destroy old textract results only after full evaluation completes.

### Exhaustive enum reference search

Ran `grep -rn` for all status enum references. Results (filtering to AiJobApplicationSummary status only):

| File | Reference | Plan treatment | Verified |
|------|-----------|----------------|----------|
| `generate.rb:31` | `status_in_progress?` | C.1.1: change to `status_extracting?` | CORRECT |
| `generate.rb:32` | `status: :in_progress` | C.1.4: change to `status: :extracting` | CORRECT |
| `generate.rb:38` | `status: :in_progress` | C.1.5: change to `status: :extracting` | CORRECT (plan says line 35, see pipeline-status-lifecycle F2) |
| `generate.rb:65` | `status: :extracted` | C.1.6: change to `status: :summarizing` | CORRECT |
| `generate.rb:163` | `status: :succeeded` | C.1.7: REMOVE status key | CORRECT |
| `generate.rb:174` | `status: :retrying` | C.1.8: unchanged | CORRECT |
| `generate.rb:179,183` | `status: :failed` | C.1.9: unchanged | CORRECT |
| `textract_result.rb:79` | `status_succeeded?` | C.2.1: unchanged | CORRECT |
| `textract_result.rb:103` | `status: :textract_processing` | C.2.2: unchanged | CORRECT |
| `generate_job.rb:19` | `status: :failed` | C.3.1: unchanged | CORRECT |
| `generate_job.rb:44` | `status: :failed` | C.3.2: unchanged | CORRECT |
| `generate_job.rb:61` | `status_succeeded?` | C.3.3: unchanged | CORRECT |
| `bulk_job.rb:50` | `status: %i[succeeded failed]` | C.4.1: unchanged | CORRECT |
| `bulk_job.rb:89` | `status: :succeeded` | C.4.2: unchanged | CORRECT |
| `create_ai_summary_generation.rb:31` | `status: :failed` | C.5.1: unchanged | CORRECT |
| `create_ai_summary_generation.rb:49` | `status: :textract_processing` | C.5.2: unchanged | CORRECT |
| `create_ai_summary_generation.rb:59` | `status: :pending` | C.5.3: unchanged | CORRECT |
| `get_resume_text_from_textract_job.rb:15` | `status: :textract_processing` | C.6.1: unchanged | CORRECT |
| `submit_resume_to_textract.rb:18` | `status: :textract_processing` | Not listed in plan | NOT COVERED BY PLAN |
| `submit_resume_to_textract.rb:25` | `status: :textract_processing` | Not listed in plan | NOT COVERED BY PLAN |

## Completeness

- [x] Credit consumption gated by terminal `succeeded` (line 79)
- [x] Broadcast gated by terminal `succeeded` (line 61)
- [x] `destroy_previous_textract_results` gated by terminal `succeeded` (line 40)
- [x] All references to removed enum values (`in_progress`, `extracted`) identified and updated
- [x] All references to unchanged enum values verified

## Findings

**F3 [MED] — `SubmitResumeToTextract` status references not listed in plan**

Where: Phase C — status enum ripple audit.

What: `app/services/submit_resume_to_textract.rb` has two references to `status: :textract_processing` (lines 18 and 25). These are not listed in the plan's exhaustive audit, even though the plan includes other files referencing `status: :textract_processing` (like `create_ai_summary_generation.rb` at C.5.2).

Evidence: `grep -rn` shows `submit_resume_to_textract.rb:18` and `submit_resume_to_textract.rb:25` both use `status: :textract_processing`.

Impact: LOW — the references use `textract_processing` which is unchanged in the new enum (same symbol name). The plan's omission means an implementing agent might not verify them, but they require no code change. Still, the plan claims to be exhaustive ("EXHAUSTIVE AUDIT") and should list them with "unchanged" verdicts.

Fix: Add `SubmitResumeToTextract` to Phase C with two entries referencing `status: :textract_processing` — both unchanged.
