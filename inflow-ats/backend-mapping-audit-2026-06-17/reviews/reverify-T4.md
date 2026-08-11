# Re-verify T4 — Trigger 4 Customer API Apply (collapsed validation/rejection line + HTTP codes)

**NEW under re-check:** backend-flow-map-2026-06-22-neutral.md, T4 section lines 202-219 (rejection enumeration at line 219).
**OLD source:** backend-flow-map-2026-06-17.md (prose 383-396; apply changelog 64-81).

## Verdict: CLEAN

All three previously-flagged corrections landed and are verified correct against current code. No load-bearing OLD fact dropped/altered at document level. No defect-framing or banned vocab in the corrected line or surrounding prose.

## Previously-flagged corrections — confirmed present AND correct

1. **HTTP 409 on duplicate (controller :81-88)** — RESOLVED.
   NEW :219 — "duplicate application (`ValidateJobApplicationApply#check_duplicate`, `validate_job_application_apply.rb:63-70`; HTTP 409, controller `:81-88`)".
   Verified: controller `:81-88` is the `@result.duplicate` → `status: :conflict` (409) block. `check_duplicate` lookup `:63-64`, `context.fail!` `:66-70` (NEW range `:63-70` spans both — accurate).

2. **HTTP 422 on oversized/content-type rejection** — RESOLVED.
   NEW :219 — "`#validate_resume`, `:77-89`, `file_too_large` at `:80-85`); content-type/`invalid_file_type` (via `resolve_file_metadata`, `:88` → ... `customer_api_file_validation.rb:116-127`) — the resume and content-type rejections return HTTP 422".
   Verified: `validate_resume` `:73-94`, `file_too_large` fail `:80-85`, `resolve_file_metadata` call `:88`; file-validation `content_type_mismatch` `:116-119`, `invalid_file_type` `:123-127`. Controller renders `:unprocessable_entity` (422) on `@result.error_code.present?` at `:90`. All three error_codes set `error_code`, so all route to 422. Correct.

3. **apply-vs-import required-fields divergence (import checks only first_name/email, validate_job_application_import.rb:29-34)** — RESOLVED.
   NEW :219 — "missing/non-boolean `send_candidate_confirmation_email` (`#validate_required_fields`, `:40-44`; import's `validate_required_fields` checks only `first_name`/`email`, `validate_job_application_import.rb:29-34`)".
   Verified: import `validate_required_fields` `:29-34` has only `first_name` (`:32`) + `email` (`:33`). Apply `validate_required_fields` body `:21-44`; the `send_candidate_confirmation_email` nil/non-boolean checks are exactly at `:40-44`. Correct.

## Fresh fact check (a) — load-bearing OLD facts still present

All OLD prose (383-396) facts present in NEW 202-219: chain+transaction `:68-77` (203); created_via 6, base64 `:77`/`:91`, StringIO attach `:70-78,:74` (205); no-resume fork `:36-38` (215); Flipper gate `:167-169` (216); save-inside-CreateJobApplication, new/existing candidate branches (207-209); CompleteJobApplication QR+email only, outer-commit after_commit (210-211); stale/relink no-ops (214); status row `'none'`, no summary (213); no synchronous textract-ready branch `:114` (211); succeeded→auto-path no-summary outcome (217).

The OLD prose `DocxToPdfJob`/`resume_docx_to_pdf`-preference fact (OLD :392) is NOT duplicated in NEW prose 202-219, but it is retained in the NEW changelog (line 70). Document-level de-dup, not a drop.

All apply rejection terminals from the OLD changelog (64-80) are collapsed into NEW :219 and all eight survive: duplicate(409), oversized/base64/metadata(422), content-type/invalid_file_type(422), question-response validation `:96-132,:106-151`, send_candidate_confirmation_email `:40-44`, existing-candidate invalidity `create_job_application.rb:38`, new-candidate save failure `:62-67`, CompleteJobApplication QR save failure `complete_job_application.rb:25-29`. All file:line verified against code.

## Fresh framing check (b)

No banned vocab in 202-219 (no dead end, stuck, broken, no-op, silently, hazard, gap-as-defect, MAP-WRONG, benign — OLD's "benign terminal" :386 and "S-C NO-OP dead end" :396 were neutralized in NEW 215/217). Line 219 wording — "reject on", "reject", "unwound", "uniquely" — is descriptive of `context.fail!`/rollback/structural-distinction behavior, not severity editorializing. No prescriptive "should", no "incorrect/wrong/problem/defect".
