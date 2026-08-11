# Verify T4 — Customer API Apply

**Verdict: ISSUES**

## Files checked
- OLD: backend-flow-map-2026-06-17.md (changelog 64-81, 88; Part 383-396; census/matrix 639/649/679/712/730/843/845)
- NEW: backend-flow-map-2026-06-22-neutral.md (T4 section 202-219; shared infra 120-122; census/matrix 447/457/480/578/596/618/620/622/652)

## CHECK 1 — Fact preservation

Most facts preserved (chain, transaction range, created_via enum 6 + candidate created_via_customer_api enum 4, base64/StringIO attach, save-inside-CreateJobApplication, new/existing candidate persistence, CompleteJobApplication adds question responses only + outer-commit timing + rollback, status row 'none' + no summary, Flipper gate, S-C no-op terminal, no-resume fork, apply-path stale/relink no-effect, no synchronous textract-ready branch, callback ordering via shared infra line 120, all 7 rejection terminals with interactor/method citations, content-type 422 path, apply-vs-import question-response divergence).

### DROPPED
1. **HTTP 409 response code + controller `:81-88` for the apply duplicate terminal.** OLD line 74: "→ controller `:70` `raise ActiveRecord::Rollback` → 409 (controller `:81-88`)". NEW line 219 lists the duplicate rejection (`check_duplicate`, `validate_job_application_apply.rb:63-70`) but states no response code and no controller `:81-88` citation. 409 appears nowhere in NEW.
2. **HTTP 422 response code for the apply oversized/malformed-resume and content-type terminals.** OLD line 75 "→ 422" and OLD line 88 "→ 422". NEW lines 219 list `file_too_large` (`:80-85`) and content-type/`invalid_file_type` (`:88` → `customer_api_file_validation.rb:116-127`) but with no 422 code. 422 appears nowhere in NEW.
3. **Apply-vs-import required-fields divergence + `validate_job_application_import.rb:29-34` citation.** OLD line 78: apply's `validate_required_fields` validates `send_candidate_confirmation_email` as a mandatory boolean, "apply-only; import's `validate_required_fields` checks only `first_name`/`email`, `validate_job_application_import.rb:29-34`". NEW line 219 keeps the apply-side guard (`#validate_required_fields, :40-44`) but drops the import-comparison clause and the `:29-34` citation. (In-scope: the prompt names "the apply-vs-import chain difference" for T4.)

### ALTERED
None. All retained citations match OLD line-for-line.

## CHECK 2 — Neutrality

T4 text (NEW 202-219) and shared infra (120-122) contain no banned vocab and no defect-framing. "no effect" (line 214) replaces OLD "no-op" appropriately; rejection terminals are stated as neutral graph facts. CLEAN on neutrality.
