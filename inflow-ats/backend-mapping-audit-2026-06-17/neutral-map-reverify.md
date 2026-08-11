# Neutral Map Re-Verification — Corrections Audit

OLD: `backend-flow-map-2026-06-17.md`
NEW: `backend-flow-map-2026-06-22-neutral.md`

Independent re-verification of corrections applied to the neutral map. Each topic re-verifier read the NEW file against source and confirmed whether every previously-flagged finding is now resolved, and whether any fact was dropped/altered or any framing residue remains.

## Per-topic results

### T4 — Trigger 4 Customer API apply: collapsed validation/rejection line (NEW line 219) + HTTP response codes
- **HTTP 409 on duplicate application** — RESOLVED. NEW:219 cites `ValidateJobApplicationApply#check_duplicate` (validate_job_application_apply.rb:63-70; HTTP 409, controller :81-88). Verified: controller :81-88 is the `@result.duplicate` → `status: :conflict` (409) block.
- **HTTP 422 on oversized/content-type rejection** — RESOLVED. NEW:219 cites `#validate_resume` :77-89, `file_too_large` :80-85, content-type/invalid_file_type via `resolve_file_metadata` :88 → customer_api_file_validation.rb:116-127; all return HTTP 422. Verified: controller renders `:unprocessable_entity` (422) at :90 when `@result.error_code.present?`.
- **apply-vs-import required-fields divergence** — RESOLVED. NEW:219 records import's `validate_required_fields` checks only first_name/email (validate_job_application_import.rb:29-34). Verified import :29-34 (first_name :32, email :33); apply `send_candidate_confirmation_email` checks at :40-44.

New dropped/altered: none. Residual framing: none. **CLEAN**

### T5 — Trigger 5 Customer API import: resume content-type rejection (two distinct error codes)
- **Two distinct error codes** — RESOLVED. NEW:234 carries both `content_type_mismatch` (customer_api_file_validation.rb:116-119, else branch) and `invalid_file_type` (:123-127, under `unless content_type.in?(allowed_types)`, allowed_types defaults to RESUME_CONTENT_TYPES :107/:4), reached via `resolve_file_metadata` called at validate_job_application_import.rb:77.

New dropped/altered: none. Residual framing: none. **CLEAN**

### T6 — Trigger 6 CSV bulk import: candidate build/retrieve (NEW:236-251)
- **Build-vs-retrieve asymmetry** — RESOLVED. NEW:245 records new-candidate branch retrieving job_application via `@candidate.job_applications.first` (create_candidate_job_application.rb:19), the auto-built join from `@job.candidates.build` (:18; job.candidates is `through: :job_applications`, job.rb:38).

New dropped/altered: none. Residual framing: none. **CLEAN**

### Bridge-SCDE — TextractResult#queue_ai_summary_job + generation-job exhaustion
- **Bridge selector read only for requesting user + branch choice (not advancing record)** — RESOLVED. NEW:331 states textract_result.rb:121-123 is read only for `requested_by_organization_user_id` and branch choice; advancing record re-selected by separate ordered query (orchestrate.rb:15, generate.rb:30), with the divergence window noted.
- **Generation-job retry-exhaustion also broadcasts completion** — RESOLVED. NEW:356 records the exhaustion block (:19) ALSO broadcasts completion (:20), not just the `:failed` write.

New dropped/altered: none. Residual framing: none. **CLEAN**

### Pipeline — AI driving method / Orchestrate / stages + bridge-selector role statement (NEW ~331, 340-405)
- **Bridge-selector role not stated as determining advancing record** — RESOLVED. NEW:331 frames selector as read only for requesting user + branch choice.
- **generate.rb:30 cited as independent ordered re-selection site** — RESOLVED. NEW:331.
- **S-E advancing-selector divergence window present** — RESOLVED. NEW:331.

New dropped/altered: none. Residual framing: none. **CLEAN**

### Coverage — Write-site coverage / rake-layer write sites (NEW ~634-635)
- **ai_bulk_extract.rake stale enum-writes must state runtime consequence (ArgumentError), not just "invalid value"** — RESOLVED. NEW:635 states the first two assign enum values not present in the current 10-value `AiJobApplicationSummary` enum, which raises ArgumentError at runtime (Rails enum setter on unknown value). Verified against ai_job_application_summary.rb:10-21 (10-value enum, :in_progress/:extracted absent) and ai_bulk_extract.rake:37/60/89.

New dropped/altered: none. Residual framing: none. **CLEAN**

## Tally

- **All-prior-resolved:** TRUE — every previously-flagged finding across all six topics is resolved with a verified NEW file:line citation.
- **New fact issues (dropped/altered facts):** 0
- **Framing issues (residual framing):** 0

## Overall: CLEAN

Every prior finding is resolved, no fact was dropped or altered by the corrections, and no residual framing remains. The neutral map corrections are confirmed clean.
