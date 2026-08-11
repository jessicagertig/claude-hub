# Attribution — 2026-07-15

Scope: attribution work in inflow-ats — PostHog, UTM params → multiple attribution types.

- Source checkout: `/Users/jessica/wrk/wrk-corp/inflow-ats` (see REPO-PATH); on `develop` at setup time
- Spec: not yet written
- Working branch: `attribution-work` (off `develop`, main checkout)
- Uncommitted: `posthog.ts` — `window.logger` added to `identifyUser` (fire + skip paths), for staging visibility
- Lifecycle run (night 2026-07-15→16): fully autonomous, NO human gates (Jessica's explicit instruction — orchestrator reviews angles itself). QA Layer 5 (Playwright) OMITTED. HARD DEADLINE (revised): QA Layers 1-4 complete by 11:00 AM Central 2026-07-16; clean-stop 10:45. Session-limit outage ~01:20→09:29 killed qa-run-2 Layer 1 (restart watch chain also died in the outage); QA restarted 09:29 with compressed time-boxing — single-round-per-layer convergence relaxation under deadline, reductions logged in QA artifacts. Final branch topology: `attribution-work` = implementation only (8dcc2f06f); `attribution-work-qa` = the shipped branch = 8dcc2f06f + 299cf9465 (key decode) + fa51c91a5 (surrogate-safe truncation) + fc3f047f9 (Decisions 18/19: email-verified events → onboarding page) + 6c50e7221 (onboarding fixes: name-submitted event moved before mutation; AdRollScript Helmet memoized for the react-helmet/deep-equal stack overflow).

SHIPPED: PR #3067 (https://github.com/wrk-corp/inflow-ats/pull/3067) against develop, pushed 2026-07-20. Full-rigor QA (Layers 1-4) APPROVED (reviews/QA-COMPLETE-run5.md); full Cypress 56/56. Merge to develop is Jessica's.

Still open for Jessica: INCIDENT-stash-2026-07-16.md (one unresolved stash-entry-count question); §10/§11 spec trim (proposed, not applied — approved to cut the "not-doing" content, awaiting go); dev server needs `foreman start`.
