# Angle 8: Authorization and Error Surface — Round 1

## Checks performed

1. Verified `BillingPolicy#change_subscription?` exists and requires `is_org_admin?` — confirmed (line 24-26)
2. Verified both new actions use `authorize :billing, :change_subscription?` — confirmed in spec
3. Verified all backend error paths produce user-visible feedback
4. Verified all frontend error paths have `onError` handlers with toast messages
5. Verified error toast delay matches existing pattern (30000ms)
6. Verified `render_general_errors` usage pattern
7. Verified `ApplyAiCreditUpgrade` failure paths (missing balance, unrecognized lookup keys, non-positive credit difference)

## Findings

No MED, HIGH, or BLOCKER findings.

### A1: Authorization — PASS

Both new actions use `authorize :billing, :change_subscription?`, matching the portal actions they replace. `BillingPolicy#change_subscription?` requires `is_org_admin?` (confirmed at line 24). Non-admin users get Pundit's default 403 response. No new policy methods needed. PASS.

### A2: Backend error paths — PASS

All error paths produce user-visible feedback:
- Missing customer/subscription/subscription_id: `raise StandardError` with descriptive message, caught by method-level rescue
- `Stripe::StripeError`: rescued, logged (`Rails.logger.error`, `ap`, `Sentry.capture_exception`), rendered via `render_general_errors`
- Downgrade interactor failure: `context.fail!` with `:stripe_error`, controller checks `result.success?` and renders error
- `ApplyAiCreditUpgrade` failures: these happen asynchronously via webhook, not in the controller request cycle — they log and fail the context but don't affect the user's HTTP response. PASS.

### A3: Frontend error paths — PASS

Both `previewSubscriptionChange` and `commitSubscriptionChange` mutations have `onError` handlers that show error toasts with `error?.data?.errors?.general?.[0]` fallback and `delay: 30000`. This matches the existing pattern. PASS.

## Verdict

0 findings. PASS for this angle.
