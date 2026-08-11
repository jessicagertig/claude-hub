# Backward Compatibility (always-on check, own file) — Round 1

- **`ExtractJobCriteriaJob` signature:** optional positional keeps old `perform_later(id)` payloads valid at deploy time; the three untouched enqueue sites (job.rb:707/:709/:723) still pass one arg; existing spec examples call `perform_now(id)` positionally, were left unmodified (append-only diff), and pass — that IS the backward-compat assertion, executed green.
- **`extract_job_criteria_immediately`:** kwarg defaults to nil; its one pre-existing caller (`extract_job_criteria_if_needed`) passes nothing and still works (lifecycle spec asserts `[id, nil]` default enqueue). `auto_extract_job_criteria`/`extract_job_criteria` untouched — pending-guard + Flipper semantics preserved, not harmonized.
- **Behavior shift within scope:** `_if_needed` no longer independently guards `in_progress`/`retrying` — those guards moved into `_immediately`, so the net gate set on the `_if_needed` path is unchanged (succeeded in `_if_needed`; description/in_progress/retrying in `_immediately`). DECISIONS-verbatim.
- **`QueueBulkAiSummaryJobs`:** `job` input optional via safe-nav; explicit job-less-call spec example passes; existing examples without `job:` pass unmodified.
- **Validators gain one `fail!`:** all existing callers receive the new failure through their existing failure channels — manual single → 422 toast; bulk per-record → claim row now `:failed` (flag 6); textract manual-waiting branch → destroy + `AI_SUMMARY_FAILED` broadcast carrying the message (existing mechanism, textract_result.rb:129-138); auto paths decline silently as they do for credits/description. No caller treats the new message specially or breaks on it.
- **`aiSummaryWebsocketPayloads.ts`:** header comment + appended interface only; existing interfaces byte-identical.
- **`JobSetupAiSettings.tsx`:** existing imports, dirty tracking, `onSubmit`, BottomBarContent, Plato reviews FormSection all preserved (additive diff). Adding `sidebar` switches SettingsContainer to the `hasSidebar` layout (Content 50vw at lg, sidebar hidden below lg) — a deliberate specced change; visual verification of the existing Plato-reviews form at lg belongs to Phase 8 QA (plan R-4).
- **WS handler:** new case is additive; all existing cases untouched.
- **Serializer/endpoint:** net-new — no existing consumer contracts affected; `Api::V1::JobSerializer` untouched.

## Findings

No issues found.
