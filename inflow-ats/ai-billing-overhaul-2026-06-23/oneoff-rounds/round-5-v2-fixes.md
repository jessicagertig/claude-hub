# One-Off Purchase — Round 5 Fixes (v2)

## Controller Error Handling Alignment

### File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

**Change 1: `#charge_top_up` save-failure branch (line 103)**
- Replaced: `render_general_errors(['Failed to create purchase record'])`
- With: `render_errors(purchase)`
- Rationale: Exposes the record's field-level AR errors instead of a fixed generic string, matching the analog `BoardWwrListingsController#create` (`render_errors(@listing)`).

**Change 2: `#create_top_up_checkout_session` save-failure branch (line 158)**
- Replaced: `render_general_errors(['Failed to create purchase record'])`
- With: `render_errors(purchase)`
- Rationale: Same as Change 1. Matches the analog `BoardWwrListingsController#create_checkout_session` (`render_errors(@listing)`).

**Logging preserved:** Both changes kept the preceding `Rails.logger.error` line intact. The analog doesn't log at this point, but the existing log is additive and harmless; the deviation scope is about error rendering, not logging.

**Verification:** Line 56 (`checkout` action, AI credit subscription path) was correctly left untouched—it is NOT part of the one-off purchase flow and NOT in the deviation list.

---

## Frontend Impact

**No frontend changes required.** The deviation is purely backend error-response shape.

**Success paths** (`charge_top_up` → serialized record; `create_top_up_checkout_session` → `{ url, sessionId }`) are untouched.

**Error shape change:** From `{ errors: { general: [...] } }` to field-keyed `{ errors: { <field>: [...] } }`.

**Frontend tolerance:** Existing `onError` handlers in `AiCreditSubscription.tsx` (`lines 171, 192`) read `error?.data?.errors?.general?.[0]`; on the new field-keyed shape, `general` is undefined so they fall back to the hardcoded toast `"Top-up checkout failed"`. This is functional and crashes nowhere. The change mirrors how the analog frontend tolerates field-keyed shapes: `JobDistributionWeWorkRemotely.tsx:277` checks `response.data.errors["general"] != undefined` and falls back gracefully when it's absent.

OUR frontend has no inline field-error display affordance (no `Object.values(errors).map` rendering), so adding field-level error display would be unscoped invention beyond the stated deviation. The existing string fallback is the correct behavior and matches every other `onError` handler in OUR billing frontend.

---

## Test Coverage

**No test changes required.** The spec file `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` has no test exercising `purchase.save == false`.

All its `errors['general']` assertions target:
- Lookup-key guard
- Price-not-found guard
- Stripe rescue handler

None of these paths were modified. The save-failure path remains untested by the existing suite, so no test breaks.

---

## Summary

- **Backend errors:** 2 error-render calls aligned with the analog pattern.
- **Frontend:** No changes; tolerance for new error shape verified.
- **Tests:** No coverage exists for the changed path; no regressions.
- **Whitelist items:** None.
- **Revert items:** None.
