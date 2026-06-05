# Investigation — Note #8: daily credits config toggle

## Ground truth
- Every plan in `PlanFeatureGate` grants `DAILY_AI_CREDIT_ALLOCATION` (= 5) via `daily_ai_credit_allocation`.
- `ResetDailyAiCredits` is the SOLE daily-grant site (creates `plan_daily_allocation_credit`, `bucket: :daily`); already skips when allocation nil/zero. Called by `ai_credits:reset_daily` rake task per org.
- No daily grant at balance creation (`create_ai_credit_state_if_needed` does not create a daily row — grant grep returns only ResetDailyAiCredits).
- `ConsumeAiCredits` draws daily-first but guards `if balance.daily_credits_remaining >= CREDIT_COST` → falls through to monthly when daily is 0, so no gate needed at consumption.
- Frontend: `dailyCreditsRemaining` exists only in `organizationAiCreditBalance.ts` type; NO component renders it (exhaustive grep). Nothing to hide. (`lookups.js:598` "Daily"/"DAY" is unrelated.)
- Config-toggle convention: `Flipper.enabled?(:FLAG, organization)` (e.g. `:AI_APPLICANT_SUMMARY`).

## Decision: see approved-decisions.md Note #8 — Flipper flag `:AI_DAILY_CREDITS`, gate in `ResetDailyAiCredits`, default off, future UI behind same flag.
