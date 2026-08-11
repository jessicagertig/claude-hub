# T5 — Customer API Import — Adversarial Review (pass 7)

Slice: T5. Re-verified every T5 statement in `backend-flow-map-2026-06-17.md` against current code from scratch.

## Files traced
- `app/controllers/api_public/v1/hire/job_applications_controller.rb:96-126,201-215` (import action, context builder)
- `config/routes.rb:502` (import route)
- `app/interactors/customer_api/validate_job_application_import.rb:1-84`
- `app/interactors/concerns/customer_api_file_validation.rb:4-136` (resolve_file_metadata / content-type 422)
- `app/interactors/customer_api/create_job_application.rb:1-105`
- `app/models/job_application.rb:45,83-91,160-171,589-590`
- `app/services/submit_resume_to_textract.rb:1-42`
- `app/jobs/submit_resume_to_textract_job.rb:1-14`
- `app/services/get_resume_text_from_textract.rb:1-54`
- `app/jobs/get_resume_text_from_textract_job.rb:1-32`
- `app/models/textract_result.rb:7,9-14,61-89,98-144`
- `app/jobs/generate_ai_job_application_summary_job.rb:24-34`
- `app/services/ai_job_application_action/orchestrate.rb:9-50`
- `app/models/job.rb:914-922`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`

## Verdicts — every claim AGREE

All T5 statements in the map (changelog lines 76-94; body lines 377-387; census line 614, 654, 706; flipper matrix 687) verified true against current code:

- Chain `import (:104 Validate, :107 Create)` inside `transaction (:103-109)`, omits CompleteJobApplication — AGREE (controller :103-109; apply contrast :75).
- Route `config/routes.rb:502 post :import` — AGREE.
- `created_via_customer_api_import` passed at controller :101; enum value 7 at job_application.rb:91 — AGREE.
- Duplicate terminal: `check_duplicate` fail at validate_job_application_import.rb:55-59, candidate-app check :52-53; controller rollback :105 → 409 — AGREE.
- question_responses rejection (import-only): `reject_question_responses` :21-27, fail :24-26 when present :22 — AGREE.
- Resume validation terminals: `validate_resume` body :62-83; file_too_large :69-75; decode/metadata accumulation :66,77; resume OPTIONAL :62-63 — AGREE.
- Content-type 422: `resolve_file_metadata` content_type_mismatch :116-119, invalid_file_type :123-127; allowed_types defaults RESUME_CONTENT_TYPES (:107) — AGREE.
- Outer-transaction commit timing; rollback at :105/:108 unwinds create, Textract never enqueued — AGREE.
- save_new_candidate failure (:62-67, fail :66) and existing-candidate validity failure (:38) terminals — AGREE.
- Callback ordering: NewJobApplicationJob :165, DocxToPdfJob :166 before gated SubmitResumeToTextractJob :168; status row via :170 — AGREE.
- Flipper gate TEXTRACT_RESUME_PROCESSING at job_application.rb:167-169; flag OFF → no TextractResult — AGREE.
- No-resume → submit_resume_to_textract.rb:10 'No resume attached' before build :22 / poll :27 — AGREE.
- Existing-candidate persists via job.candidates.push :40, new-candidate via candidate.save :63; both fire on:[:create] after_commit — AGREE.
- Status row created 'none' (find_or_create_…:33-34 assign, :37 save) — AGREE.
- in_progress advanced by GetResumeTextFromTextractJob (:25 → parse_resume_text; retry_on :6): succeeded via .update :31 (callback-firing, fires bridge), failed via update_columns :40 + raise CustomErrorTextract :41 — AGREE.
- Self-healing re-submit on nil textract_job_id: get_resume_text_from_textract.rb:14-17 — AGREE.
- stale update_all (:18-20) + waiting-summary relink (:25-26) no-ops on fresh import — AGREE.
- Bridge else/auto branch: textract_result.rb:121-123 selector nil → :137 else → :138 should_auto_generate gate → :140 validate → :142 enqueue (no requesting user) — AGREE.
- S-C no-op terminal: Orchestrate returns at orchestrate.rb:16 (no summary); generate_ai_summary_with_credit_flow returns at textract_result.rb:82 → no summary, no credit, no broadcast — AGREE.
- Matrix row 5 / census in_progress row / flipper matrix — AGREE.

## Omissions (T5 poll-path terminal enumeration incomplete)

1. **`InvalidJobIdException` poll-path failure terminal not enumerated.** The map's advancing-actor bullet (changelog :92) names only the succeeded path (get_resume_text_from_textract.rb:24-29,31), the failed-status path (:40-41), and the self-healing nil branch (:14-17). It omits the `rescue Aws::Textract::Errors::InvalidJobIdException` at `get_resume_text_from_textract.rb:46-47`, which does `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)`. This is a distinct reachable poll-path terminal for an import's in_progress TextractResult: it lands `failed` AND nils `textract_job_id`, so a subsequent poll would re-enter the self-healing re-submit at :14-17. Worth naming in the T5 poll-path terminal list.

2. **Retry-exhaustion `cleanup_orphaned_summary` not mentioned (minor, no-op for import).** `get_resume_text_from_textract_job.rb:6-8` runs `cleanup_orphaned_summary` (:10-23) after 3 exhausted `CustomErrorTextract` retries. For a fresh import there is no `status: :textract_processing, stale: false` summary (:14-16), so it returns at :16 — a no-op. Strictly out-of-terminal for import (import never builds a waiting summary), but the failed-poll bullet implies retries without naming what happens at exhaustion.

## clean = false
Reason: omission #1 (InvalidJobIdException poll terminal) is a genuine missing poll-path terminal for the import in_progress TextractResult.
