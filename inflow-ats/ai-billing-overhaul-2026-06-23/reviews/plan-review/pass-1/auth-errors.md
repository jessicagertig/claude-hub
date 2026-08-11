# Angle 8: Authorization and Error Surface — Pass 1

## Verified claims (PASS)

1. **`BillingPolicy#change_subscription?`**: Confirmed at line 24, returns `is_org_admin?`. PASS.

2. **Cancel action error handling**: Lines 209-214 confirmed: `rescue Stripe::StripeError => e`, `Rails.logger.error`, `ap e`, `Sentry.capture_exception(e, extra: {...})`, `render_general_errors(...)`. PASS.

3. **Portal action error handling**: Lines 268-281 confirmed: multi-rescue `Pundit::NotAuthorizedError`, `Stripe::InvalidRequestError`, `StandardError`. PASS.

4. **`render_general_errors`**: Defined at `application_controller.rb:40` as `def render_general_errors(array = [])`, renders `{ errors: { general: array } }` with `:unprocessable_entity`. PASS.

5. **Frontend error pattern**: Confirmed `error?.data?.errors?.general?.[0]` at lines 106, 146, 189, 240, 279 of `AiCreditSubscription.tsx`. Confirmed `delay: 30000` at lines 113, 152, 190, 203, 242, 281. PASS.

6. **Test directories**: `spec/controllers/api/v1/` exists. `spec/interactors/` exists. `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` exists. PASS.

7. **`create_credit_test_organization`**: Exists at `spec/support/ai_credits_test_helpers.rb:21` with `stripe_active: true` as default parameter. PASS.

## Findings

### MED-A8-1: Change subscription spec line count is wrong

**Plan claim (C.1.1):** "Remove `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb` entirely (154 lines)."

**Actual:** The file has 193 lines, not 154.

**Impact:** Cosmetic inaccuracy — does not affect implementation. The instruction to remove the file is still correct.

**Recommendation:** Update the line count from 154 to 193.

### MED-A8-2: Plan's cancel action rescue pattern deviates from actual in error message shape

**Plan claim (A.2.2 step 8):** The new preview action rescue uses `render_general_errors('Unable to load subscription preview. Please try again.')` — passing a bare string.

**Actual (cancel at line 213):** `render_general_errors(['Something went wrong with the payment processor. Please try again or contact support@polymer.co if the issue persists.'])` — passing an **array** of strings.

**`render_general_errors` signature (application_controller.rb:40):** `def render_general_errors(array = [])` — expects an array.

**Impact:** Passing a bare string to `render_general_errors` would still render valid JSON (`{ errors: { general: "some string" } }` instead of `{ errors: { general: ["some string"] } }`), but the frontend pattern `error?.data?.errors?.general?.[0]` indexes into an array. With a bare string, `[0]` would return the first character, not the full message. The plan must pass an array, matching the analog.

**Recommendation:** Change the `render_general_errors` calls to use arrays: `render_general_errors(['Unable to load subscription preview. Please try again.'])` and `render_general_errors(['Unable to change subscription. Please try again.'])`.

**Severity: HIGH** — Bare string causes frontend to display only the first character of the error message.

## Summary

| Severity | Count |
|----------|-------|
| BLOCKER  | 0     |
| HIGH     | 1     |
| MED      | 1     |
| LOW      | 0     |
