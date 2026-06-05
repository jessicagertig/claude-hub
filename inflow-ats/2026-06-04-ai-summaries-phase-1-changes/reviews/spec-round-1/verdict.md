# Round 1 Verdict

## Counts

| Severity | Count |
|---|---|
| BLOCKER | 1 |
| HIGH | 2 |
| MED | 4 |
| LOW | 1 |

## BLOCKER and HIGH findings (amended in SPEC.md)

1. **[BLOCKER]** angle-1, F1: `invoice.paid` handler — `CustomStripeSubscriptionMissingError` guard at line 204 blocks the new `ai_credit_pack_top_up` branch from being reached for orgs without a base plan subscription. Amended Note #4 to place the branch before the guard.

2. **[HIGH]** angle-1, F2: `OrganizationAiCreditPurchase` validation relaxation incomplete — `amount_cents_paid` and `currency` are unconditionally required but unknown at checkout time. Amended Note #9B-5 to include conditional validation for these fields.

3. **[HIGH]** angle-2, F1: Missing ripple site — `AiCreditPacks.registered_keys` reference on `organization_ai_credit_purchase.rb` line 14 not listed in Note #6A's ripple sites. Amended Note #6A to include it.

## MED findings (not amended, for implementer awareness)

4. **[MED]** angle-1, F3: `OrganizationAiCreditBalance#apply_top_up_checkout` becomes dead code when `mode == 'payment'` branch is removed. Amended Note #4 to include removal.

5. **[MED]** angle-4, F1: `newLookups.ts` TypeScript type name `AutoGenerateAiSummariesSetting` should be renamed to `AutoGenerateAiSummaries` alongside the enum value renames.

6. **[MED]** angle-5, F1: `failed` mailer `total_queued_count` calculation needs to happen in caller (`notify_failure`), not mailer — implicit but clear from context.

7. **[MED]** angle-5, F2: `notify_failure` block parameter threading for `discard_on`/`retry_on` — follows existing pattern, implicit.

## Verdict: **FAIL** (1 BLOCKER + 2 HIGH amended)

Proceed to Round 2.
