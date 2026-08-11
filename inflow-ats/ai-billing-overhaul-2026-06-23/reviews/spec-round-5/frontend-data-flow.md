# Angle 5: Frontend Data Flow — Round 5

## Deep verification

- `newMonthlyPrice` sourced from `tier.priceDollars` (number type) — needs formatting to string. LOW implementation detail. PASS.
- `amountDueToday` from `previewData.amountDue` via `formatCents` — correctly formats cents to `$X.XX`. PASS.
- `creditForCurrentPlan` from negative line item via `formatCents` — correctly shows `-$X.XX`. PASS.
- `startDate` from `previewData.currentPeriodEnd` via `prettyDate` — correct. PASS.
- `paymentMethodLabel` capitalizes brand, appends last4, handles null. PASS.
- Commit mutation invalidates 3 query keys (`organizationAiCreditPurchase`, `organizationAiCreditBalance`, `aiCreditCustomerSubscription`) — appropriate for subscription change. PASS.
- Preview mutation does NOT invalidate queries (it's a read-only preview) — correct. PASS.

No new findings. PASS.
