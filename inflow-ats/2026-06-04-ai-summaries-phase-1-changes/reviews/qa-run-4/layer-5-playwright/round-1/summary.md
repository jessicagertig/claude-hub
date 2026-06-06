# Layer 5: Playwright -- qa-run-4, Round 1

## Environment

Server started with `NODE_OPTIONS=--openssl-legacy-provider` to work around pre-existing OpenSSL/webpack incompatibility (error:0308010C). Frontend renders correctly with this flag.

## Agents dispatched: 17

## HIGH Findings: 1

### H1: Stale "go to AI billing" link in Plan & billing page

**Severity:** HIGH
**File:** `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx`
**URL:** `/hire/settings/billing`
**Evidence:** Screenshot `billing-stale-link.png`, git diff confirms this link was ADDED by the feature

The feature added a new `<Link to="/hire/settings/ai-billing">go to AI billing</Link>` in the Plan & billing page (AccountBilling.tsx). However, the `/hire/settings/ai-billing` route was removed by this same feature (replaced by `/hire/settings/plato-ai/billing`). Clicking the link navigates to a page with no content -- just the settings sidebar with an empty content area.

**Fix:** Change the `<Link to>` from `/hire/settings/ai-billing` to `/hire/settings/plato-ai/billing`.

## MED Findings: 0

## LOW Findings: 0

## Verification Summary

| Area | Status | Evidence |
|------|--------|----------|
| Plato AI container exists | PASS | `/hire/settings/plato-ai` renders two-column layout with internal sidebar |
| Default redirect | PASS | `/plato-ai` redirects to `/plato-ai/settings` |
| Settings tab content | PASS | Auto-generate toggle, Hiring team credit control, Notifications sections render |
| Settings save/persist | PASS | Toggle auto-generate, save, reload -- value persists |
| Billing tab content | PASS | Credit balance (Monthly/Purchased/Total), Subscribe button, Top-up button |
| Usage tab content | PASS | Credit balance, "Usage this period" bar, reset date |
| Tab navigation | PASS | Settings/Billing/Usage tabs navigate correctly with proper URLs |
| Credit balance consistency | PASS | Both Billing and Usage tabs show identical values (Monthly=25, Purchased=0, Total=25) |
| Admin-only gate | PASS | Non-admin user (Taylor Brooks) sees no Plato AI container, no AI tabs, no AI settings |
| Old routes removed | PASS | `/hire/settings/ai`, `/ai-billing`, `/ai-usage` show empty content area (no redirect, as spec states) |
| Job Setup AI Settings | PASS | `/jobs/{id}/setup/ai` renders with renamed enum dropdown |
| Enum values renamed | PASS | Dropdown shows "Use organization default", "Enabled", "Disabled" |
| Job AI Settings save/persist | PASS | Changed to "Enabled", saved, reloaded -- value persists |
| API /ai_credits | PASS | 200 OK, returns credit balance JSON |
| API /ai_credit_purchases | PASS | 200 OK, returns `null` (no active subscription) |
| API /ai_credit_purchases/prices | PASS | 200 OK, returns 4 Stripe prices matching spec lookup keys |
| Console errors | PASS | All 7 errors are pre-existing (history deprecation, combineReducers, Heap 404) |
| Network requests on Billing tab | PASS | All AI API requests return 200 OK |
| Stale billing link | **FAIL** | "go to AI billing" link points to removed route `/hire/settings/ai-billing` |
