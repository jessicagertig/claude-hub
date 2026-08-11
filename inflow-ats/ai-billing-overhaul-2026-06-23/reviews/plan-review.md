# Plan Review: Custom AI Credit Subscription Upgrade/Downgrade

## Verdict: APPROVED

Two passes completed. All HIGH findings amended. Plan is ready for implementation.

---

## Pass 1 summary

9 parallel review forks (8 angles + CLAUDE.md compliance) fact-checked the plan against the live billing-bonanza source tree.

| Severity | Count | Findings |
|----------|-------|----------|
| BLOCKER  | 0     | -- |
| HIGH     | 1     | `render_general_errors` expects array, plan passed bare strings |
| MED      | 3     | Cancel action variable name wrong in description; spec file line count 154 vs 193; test section lacks stub accuracy warning |
| LOW      | 8     | Various off-by-one line numbers, Sentry extra hash shape, analog description string |

### HIGH-1 (Angle 8): `render_general_errors` requires array argument

**Problem:** `render_general_errors(array = [])` renders `{ errors: { general: array } }`. Frontend indexes with `error?.data?.errors?.general?.[0]`. Passing a bare string makes `[0]` return the first character of the error message, not the full message.

**Fix:** Changed all `render_general_errors` calls to pass arrays. Also fixed Sentry extra hash to use `org_id` and include `:action` key, matching the cancel action analog.

### MED amendments

- Corrected cancel action variable name from `organization_ai_credit_purchase` to `subscription` with naming warning
- Corrected spec file line count from 154 to 193
- Corrected structural manifest description string to match actual analog
- MED-C1 (test stub accuracy) noted but not amended -- advisory, not a plan error

---

## Pass 2 summary

3 parallel review forks (backend angles, frontend angles, structural/compliance) verified corrections and performed fresh scrutiny.

| Severity | Count | Findings |
|----------|-------|----------|
| BLOCKER  | 0     | -- |
| HIGH     | 1     | Guard pattern mismatch -- `raise StandardError` unrescued with `rescue Stripe::StripeError` only |
| MED      | 0     | -- |
| LOW      | 0     | -- |

### HIGH-P2-1: Guard pattern mismatch

**Problem:** The plan mixed two patterns: the portal actions' `raise StandardError` guards with the cancel action's `rescue Stripe::StripeError` rescue. No global `StandardError` handler exists in `ApplicationController` (line 21 commented out). The three guards for missing Stripe customer, missing subscription, and missing subscription ID would bubble up as uncaught 500 errors.

**Fix:** Changed guards from `raise StandardError` to `render_general_errors(['...']) and return`, matching the cancel action pattern. Added NOTE explaining the pattern choice. This deviates from the spec's language ("raise `StandardError`") but the spec's guard style is incompatible with the spec's own error handling pattern.

### Pass 2 verification results

- All Pass 1 corrections verified as applied
- No new inconsistencies from corrections
- Frontend fresh scrutiny: `aiCreditCustomerSubscription` query key verified, `priceDollars` always a number, `currentCredits` and `currentPlanLookupKey` exist with correct types, `openModal`/`removeModal`/`addToast` all available, `handleSelectTier` replacement complete
- Backend fresh scrutiny: `determine_price_id` callers all in portal actions (no orphan risk), `context.purchase` key consistent between spec and plan, webhook handler line 489 verified

---

## Angle-by-angle results

| Angle | Pass 1 | Pass 2 |
|-------|--------|--------|
| 1. Stripe API contract | 0B 0H 1M 2L | 0B 0H 0M 0L |
| 2. Webhook event routing | 0B 0H 0M 0L | 0B 0H 0M 0L |
| 3. Credit granting correctness | 0B 0H 0M 2L | 0B 0H 0M 0L |
| 4. Downgrade scheduling | 0B 0H 0M 2L | 0B 0H 0M 0L |
| 5. Frontend data flow | 0B 0H 0M 1L | 0B 0H 0M 0L |
| 6. Portal flow removal | 0B 0H 1M 1L | 0B 0H 0M 0L |
| 7. Analog structural matching | 0B 0H 1M 0L | 0B 0H 0M 0L |
| 8. Authorization and errors | 0B 1H 1M 0L | 0B 1H 0M 0L |
| CLAUDE.md compliance | 0B 0H 1M 1L | 0B 0H 0M 0L |

---

## Files

- Amended plan: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/plan.md`
- Pass 1 findings: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/reviews/plan-review/pass-1/`
- Pass 2 findings: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/reviews/plan-review/pass-2/`
- Spec: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/SPEC.md`
