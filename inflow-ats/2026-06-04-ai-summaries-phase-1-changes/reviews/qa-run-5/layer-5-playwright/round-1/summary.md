# Layer 5: Playwright -- qa-run-5, Round 1

## Environment

Server running on port 5007 (RAILS_ENV=test). Frontend renders correctly.
Feature flags enabled: AI_APPLICANT_SUMMARY, AI_DAILY_CREDITS.
Data seeded: paid org (Acme Inc.), admin user (Rezu May), member user (Taylor Brooks), published job with 3 candidates.

## Agents dispatched: 16

All agents followed click-based navigation paths from navigation-map.md.

## HIGH Findings: 0

## MED Findings: 0

## LOW Findings: 0

## Verification Summary

| # | Agent | Area | Status | Evidence |
|---|-------|------|--------|----------|
| 1 | Container + redirect | Plato AI container exists, two-column layout, /plato-ai redirects to /plato-ai/settings | PASS | agent-01-plato-ai-container.png |
| 2 | Settings tab content | All 3 sections render: Auto-generate, Hiring team credit control, Notifications with correct defaults | PASS | Snapshot verified |
| 3 | Billing tab content | Credit balance (Monthly=25, Purchased=0, Total=25), Subscribe + Top-up buttons | PASS | agent-03-billing-tab.png |
| 4 | Usage tab content | Credit balance matches Billing, Usage this period bar, reset date (Jul 05, 2026) | PASS | agent-04-usage-tab.png |
| 5 | Tab navigation | Settings -> Billing -> Usage clicks work, correct URLs and active states | PASS | Verified by click sequence |
| 6 | Non-admin gate | Taylor Brooks (member) sees no Plato AI in sidebar; only Message templates, Review templates, User preferences | PASS | agent-06-non-admin-sidebar.png |
| 7 | Job AI Settings nav | Jobs list -> job title -> Job setup -> AI settings via clicks | PASS | Navigation successful |
| 8 | Enum values | Dropdown shows Use organization default, Enabled, Disabled (renamed from inherit/on/off) | PASS | agent-08-job-ai-settings-dropdown.png |
| 9 | Job AI Settings persist | Changed to Enabled, saved, reloaded -- value persists | PASS | Evaluated single-value text after reload |
| 10 | Plan and billing link | go to AI billing link points to /hire/settings/plato-ai/billing (correct), click navigates there | PASS | Verified href and click navigation |
| 11 | Old routes removed | No links to /hire/settings/ai, /ai-billing, /ai-usage in sidebar or page | PASS | No matching links found |
| 12 | Credit balance consistency | Billing tab: Monthly=25, Purchased=0, Total=25; Usage tab: identical values | PASS | DOM text extraction matched |
| 13 | API endpoints | /ai_credits (200), /ai_credit_purchases (200, null), /ai_credit_purchases/prices (200, 4 packs) | PASS | fetch() from browser context |
| 14 | Console errors | All 12 errors are pre-existing (Heap 404, history deprecation, combineReducers, billing/customer_subscription 500) | PASS | No new errors |
| 15 | Network requests | All AI API requests return 200 OK; only 500s are pre-existing billing/customer_subscription | PASS | Network request log reviewed |
| 16 | Settings save/persist | Toggled auto-generate checkbox, saved, reloaded -- value persists correctly | PASS | Checkbox state verified after reload |
