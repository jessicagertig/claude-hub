# Spec Review — Round 1 Verdict
**Date:** 2026-06-23 02:40

## Counts
- BLOCKER: 0
- HIGH: 4
- MED: 10
- LOW: 6

## Findings (by angle)
- source-accuracy: F1 MED (controller `@job_application`->`job_application`), F2 LOW (validate guards `69-83`->`65-83`)
- summary-lifecycle: F1 HIGH (C8 must route through `record_failure` or auto-failed never renders), F2 MED (C8 class-method call shape), F3 MED (no-broadcast-on-failed note), F4 LOW (C7 earlier-failed test)
- textract-trigger: F1 HIGH (PDF Textract DOUBLE-SUBMIT — DocxToPdfJob enqueue needs docx guard), F2 LOW (org ref ok)
- criteria-enqueue: F1 HIGH (description dirty-tracking reset in after_commit breaks description-change detection), F2 HIGH (skip_update_callback would newly gate criteria extraction), F3 MED (only the call relocates)
- websocket-broadcast: F1 MED (PlatoGenerationStatus union must also gain the 2 statuses — TS compile), F2 LOW (generate.rb:175 conversion drops error_message)
- status-row: F1 MED (each site passes its existing error_message verbatim), F2 LOW (PlatoOverviewCallout dead-code stale union — noted, not amended)
- credit-charging: F1 MED (assert exactly-one-on-success / zero-on-failure; CreateAiCreditBalanceTransaction has no idempotency guard)
- analog-structural: F1 MED (W3 should use `previous_changes` analog mechanism (option b primary), not the instance-flag (option a) as preferred)
- test-coverage: F1 MED (W3 ghost-test — needs deterministic timing test via previous_changes spy), F2 MED (W5 per-mechanism-class site coverage), F3 LOW (W1 C7 test cross-ref)

## Amendments Applied
- W2 controller: `@job_application.resume_is_docx` -> `job_application.resume_is_docx` (local block var).
- W1 validate guards: `69-83` -> `65-83`; named the 4 precondition guards (exclude textract_text_ready?).
- W1/C8: route the summary-failed write through `record_failure` (not bare `status::failed`); status row guaranteed at intake; keep manual-case broadcast. Added C8 to the W5 "route through record_failure" list.
- W5: note terminal `failed` emits no `ai_summary_status_change` by design (don't switch summary write to `.update`).
- W1/C7: test must include an earlier failed TextractResult, asserting the W1 summary is not cascade-destroyed.
- W2 DocxToPdfJob: gate the new `SubmitResumeToTextractJob` enqueue on `@job_application.resume_is_docx` (prevent PDF double-submit).
- W3: option (b) `previous_changes` (analog-matching) made PRIMARY; mandatory description rewrite to `previous_changes[:description]`; criteria extraction must fire irrespective of `skip_update_callback`; only the `auto_extract_job_criteria` call relocates.
- W4: extend `PlatoGenerationStatus` union (`:8-13`) in addition to STATUS_TO_STEP; generate.rb:175 conversion preserves `error_message`.
- W5: each converted failure site passes its existing error_message string verbatim to `record_failure`.
- W1: tests assert exactly ONE credit on auto success, ZERO on auto failure.
- W3 test: deterministic timing test (previous_changes spy), not a ghost `have_been_enqueued`.
- W5 test: direct record_failure unit test + one integration test per mechanism class (update_columns / .update / C8 destroy).

## Verdict: FAIL
Round 1 produced 4 HIGH + 10 MED findings, all amended. Re-review required (Round 2) to verify amendments are correct and complete and to catch any new issues introduced by the edits.
