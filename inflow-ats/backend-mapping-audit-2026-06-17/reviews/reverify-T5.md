# Re-verify T5 — Customer API Import: resume content-type rejection

**Verdict: CLEAN**

## Previously-flagged finding (two distinct error codes) — RESOLVED

NEW `backend-flow-map-2026-06-22-neutral.md:234` now states both error codes:
- `content_type_mismatch` when decoded bytes match no supported format → `customer_api_file_validation.rb:116-119`
- `invalid_file_type` when resolved content type is not in `RESUME_CONTENT_TYPES` → `customer_api_file_validation.rb:123-127`
- reached via `resolve_file_metadata` (`:77` = `validate_job_application_import.rb:77`)

Code verification (`app/interactors/concerns/customer_api_file_validation.rb`):
- `:116-119` `context.fail!(error_code: 'content_type_mismatch', ...)` in the `else` branch when `detect_content_type` returns nil and the text fallback fails — CONFIRMED.
- `:123-127` `context.fail!(error_code: 'invalid_file_type', ...)` under `unless content_type.in?(allowed_types)`, where `allowed_types:` defaults to `RESUME_CONTENT_TYPES` (`:107`, constant defined `:4`) — CONFIRMED.
- `validate_job_application_import.rb`: `def validate_resume` at `:62`, `file_too_large` at `:71`, `resolve_file_metadata` call at `:77` — all CONFIRMED.

## Fresh check (a) — other OLD T5 load-bearing facts retained

Every OLD fact (source lines 84-103) maps to NEW (221-234):
no-CompleteJobApplication (84→222), duplicate terminal (85→234), reject_question_responses (86→234),
file_too_large/decode (87→234), content-type pair (88→234), outer-transaction commit (89→234),
save_new_candidate failure (90→234), existing-candidate validity (91→234), created_via enum 7 (92→224),
status row 'none' (93→226), callback ordering (94→227), Flipper gate (95→229), resume optional (96→228),
existing-vs-new persist (97→224), auto-path no-pre-existing-summary (98→230),
advancing actor succeeded/failed (99→232), self-healing re-submit (100→232), stale/relink (101→227),
InvalidJobIdException (102→232), cleanup_orphaned_summary exhaustion (103→232).

`DocxToPdfJob` → `resume_docx_to_pdf` "prefers" detail (OLD 94) is de-duplicated to the shared-callback
section (NEW 120, 128) rather than repeated in T5 — legitimate de-dup, not a drop.

No newly dropped or altered fact.

## Fresh check (b) — framing

No banned vocab in NEW 221-234. Only match is the allowed method name `cleanup_orphaned_summary`.
OLD line 103's "no-op" was neutrally rephrased to "returns at `:16` (no waiting summary)" — a de-framing
improvement. No prescriptive should, no judgment, no defect-framing introduced by the corrections.
