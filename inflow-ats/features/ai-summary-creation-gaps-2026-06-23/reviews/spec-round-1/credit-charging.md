# credit-charging behavior (W1 D2) — Round 1

Traced the auto-gen success credit path and confirmed W1/W6 add NO new charge site and do not double-charge.

Chain: `textract_result.rb:114-144 (bridge if-branch)` -> `generate_ai_job_application_summary_job.rb:24-46` -> `textract_result.rb:61-89 (generate_ai_summary_with_credit_flow, early-return :68, charge :84)` -> `create_ai_credit_balance_transaction.rb` -> `ai_job_criteria.rb:24-27 (W6 re-enqueue)`.

## Findings

- **F1 [MED]** -- W1/W6 financial test coverage must assert EXACTLY ONE credit on auto success and ZERO on auto failure. This is the financially load-bearing slice and the historically highest-risk area (the AI-credits Known Failure Patterns). `CreateAiCreditBalanceTransaction` (`create_ai_credit_balance_transaction.rb`) has NO idempotency guard -- it creates a new `AiCreditBalanceTransaction` debit on every call, with no `find_by(summary:)`/uniqueness tie to a summary. The ONLY thing preventing a double-charge is the early-return at `generate_ai_summary_with_credit_flow:68` (`return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`). This guard is PRE-EXISTING and identical for the manual path, so W1 introduces no NEW double-charge vector (and the spec correctly says the new interactor does NOT charge; the bridge drives it via the same path). But because the auto path now charges where it previously did not (D2), the test plan must lock the count: SPEC.md W1 (line 43) says "Textract success -> ... + credit" but does not pin "exactly one" nor "zero on failure". Fix: W1 tests must assert (a) auto success charges exactly ONE credit (`AiCreditBalanceTransaction.count` delta == 1, not 0, not 2), and (b) auto FAILURE (Textract fail or pipeline fail) charges ZERO. APPLIED.

## Verified-correct (no change)
- No new charge site: `CreateAutoAiSummaryGeneration` builds the summary only (SPEC.md line 28 "Do NOT enqueue any job"); the credit is charged solely by the existing `generate_ai_summary_with_credit_flow:84` via the bridge if-branch. W1 adds no payment-area code -> not a BLOCKER (angle 6 / hub "any new payment-area method is BLOCKER unless spec'd" -- none added). CONFIRMED.
- Single charge across the awaiting_job_criteria detour: bridge-fire run parks at `awaiting_job_criteria` -> `generate_ai_summary_with_credit_flow` returns at `:82` (not succeeded) -> no charge; W6 re-enqueue on criteria success resumes -> succeeded -> charges once at `:84`. Intermediate runs never reach `:84`. CONFIRMED single charge.
- W6 does not alter charging: `resume_waiting_summaries` (`ai_job_criteria.rb:24-27`) adds only `requesting_organization_user_id` (for the toast); the re-enqueued job runs the same credit path. No credit param, no extra charge. CONFIRMED.
- No charge on failure: Textract failure -> bridge never fires (no `textract_job_result_text`) -> no charge. Pipeline failure -> `generate_ai_summary_with_credit_flow` returns at `:82` (not succeeded) -> no charge. CONFIRMED.
- Early-return guard holds for auto: a second bridge fire after success returns at `:68` (latest summary succeeded + non-stale) -> no re-charge. CONFIRMED.
- The missing idempotency in `CreateAiCreditBalanceTransaction` is PRE-EXISTING and out of this spec's scope (not introduced by W1/W6; identical for manual). NOT flagged as a finding against this spec; noted so the W1 financial tests guard the count at the integration level.

## Amendments Applied
- SPEC.md W1 (line 43): tests must assert auto success charges EXACTLY ONE credit (delta == 1, not 0, not 2) and auto failure (Textract or pipeline) charges ZERO credits.
