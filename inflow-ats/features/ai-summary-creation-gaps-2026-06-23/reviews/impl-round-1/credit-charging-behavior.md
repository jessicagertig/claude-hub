# credit-charging behavior (W1 D2) — Round 1

Traced: `textract_result.rb#generate_ai_summary_with_credit_flow:61-89` (credit consume `:84` via `CreateAiCreditBalanceTransaction`, early-return `:68`/`:82`) → bridge if-branch `:125-136` → `ai_job_criteria.rb#resume_waiting_summaries:21-29` (W6) → `generate_ai_job_application_summary_job.rb#broadcast_completion:50-77`.

## Findings

No new payment-area code was introduced (BLOCKER check passed). Verified:
- `CreateAutoAiSummaryGeneration` does NOT charge or enqueue — it only builds the summary. The credit is charged on the existing bridge → `generate_ai_summary_with_credit_flow` path, exactly as the manual path (D2 behavioral change is achieved by routing auto through the same if-branch, not by new code).
- The single-charge is protected only by the `generate_ai_summary_with_credit_flow:68/:82` early-returns (no per-summary idempotency guard on `CreateAiCreditBalanceTransaction` — pre-existing, FYI-2, not introduced here).
- W6 passes `requesting_organization_user_id: ai_job_application_summary.requested_by_organization_user_id` through `resume_waiting_summaries` — this affects ONLY the completion toast (`broadcast_completion` no-ops on nil user), NOT charging. Correct.
- No double-charge path found; failure paths charge zero (the `return unless ...status_succeeded?` at `:82` precedes the consume).

No correctness issues. **However, the spec's required integration pin on the credit count is absent**: TP-1.3 (auto-gen success → exactly ONE `AiCreditBalanceTransaction`) and TP-1.4 (auto-gen failure → ZERO) have no test. Given the spec explicitly says the count "must be pinned at the integration level" because there is no idempotency guard, this absence is material — see `test-coverage.md` (folded into MED-3).
