# Layer 3: Script Runner -- qa-run-4, Round 1

Verified via rails runner (RAILS_ENV=test):

1. CREDIT_PACKS_BY_LOOKUP_KEY: all 4 packs have name/kind/credits. Class methods work.
2. BulkGenerateAiSummariesJob: retry_on index=1 > discard_on index=0. Correct order.
3. BulkJobApplicationAiSummaryResultMailer: defined, responds to :complete and :failed.
4. Routes: all 6 AI credit routes present and correct.
5. ResetDailyAiCredits: Flipper gate present.
6. OrganizationAiCreditPurchase validations: one_off requires checkout_session_id, subscription relaxation works.

## HIGH findings: 0
## Result: Round 1 clean.
