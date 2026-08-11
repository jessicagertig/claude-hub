# item2-single-send-gate — Round 2

Re-reviewed the amended SPEC 2.8 and SPEC 2.1 (2.1 unchanged).

## Amendment-correctness check
- SPEC 2.8 "double must stub `textract_pending: false`" — re-verified: `create_ai_summary_generation.rb:41` is `if validation_result.textract_pending`, reached on the rescore-true fall-through. The example double string is valid. Correct.

## Fresh checks
- Repeated re-score (2nd/3rd time) considered: `active_ai_summary` = `where.not(status: :failed).where(stale:false).order(created_at: :desc).first` always resolves to the newest non-failed non-stale row; with `rescore_requested` true the gate falls through and builds one new pending row each time. No accumulation/short-circuit bug. Consistent with SPEC 2.7's accepted "multiple succeeded rows" outcome.
- Downstream untouched gates (Orchestrate, charge-on-success + CreateAiCreditBalanceTransaction) operate on the new pending row identically to a first generation; one new summary → one charge. No double-charge. Credits pre-checked by ValidateAiSummaryGeneration. Consistent with SPEC 2.7.

## Findings
- No new findings.

## Amendments Applied
- None.
