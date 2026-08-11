# Angle 1: Stripe API Contract — Round 1

## Checks performed

1. Verified `Stripe::Invoice.create_preview` params in `preview_subscription_change` vs `Stripe::Subscription.update` params in `commit_subscription_change`
2. Verified `subscription_details` wrapper on preview maps to flat params on update (Stripe API difference)
3. Verified `determine_price_id` reuse across both actions
4. Verified subscription item ID extraction is consistent
5. Verified `proration_behavior` and `proration_date` match
6. Checked error handling pattern against existing controller analogs

## Findings

### S1: Preview response field `newMonthlyPrice` is derived from the wrong source — MED

**Location:** SPEC.md lines 618 and 428-434

**Problem:** The spec says the modal shows `newMonthlyPrice` derived from the preview's positive line item amount (`newLine ? formatCents(newLine.amount) : ""`). But the positive line item amount on a `subscription_update` invoice is NOT the full monthly price — it is the prorated charge for the remaining time. From the real invoice example: the positive line is `amount: 156777` with description "Remaining time on Polymer Growth after 24 Jun 2026" — that's a prorated amount, not the monthly price.

The modal's "What you'll pay monthly starting {startDate}" row should show the new plan's actual monthly price (from the prices endpoint or `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`), not the prorated line item amount. The `amountDueToday` correctly uses `previewData.amountDue`, but `newMonthlyPrice` should come from the tier's `priceDollars` (already available from the prices query), not from the invoice line.

**Impact:** Users would see the prorated amount as their future monthly price, which is misleading.

**Fix:** Use `tier.priceDollars` (or format from the prices endpoint) for `newMonthlyPrice` instead of the invoice line item amount.

### S2: Error handling pattern — spec says "same pattern as `cancel`" but portal actions have broader rescue — LOW (informational)

**Location:** SPEC.md lines 101, 140

**Problem:** The spec says error handling follows the `cancel` pattern (rescue `Stripe::StripeError`). But the portal actions being replaced (`change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`) rescue `Pundit::NotAuthorizedError`, `Stripe::InvalidRequestError`, and `StandardError` separately. The `cancel` action only rescues `Stripe::StripeError`.

Since both new actions call `authorize :billing, :change_subscription?`, Pundit errors are already handled by the framework's default (403 response). The `Stripe::StripeError` rescue covers `Stripe::InvalidRequestError` (it's a subclass). So the `cancel` pattern is sufficient. No spec change needed — this is informational context for the implementer.

**Severity:** LOW — no action needed.

## Verdict

1 MED finding (S1). Requires spec amendment.
