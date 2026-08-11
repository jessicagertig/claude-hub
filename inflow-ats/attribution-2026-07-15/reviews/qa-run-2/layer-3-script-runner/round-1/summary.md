# QA Run 2 - Layer 3 (Script Runner) - Round 1 Summary (COMPRESSED)

**Date:** 2026-07-16 09:52-10:03 CT | **Server:** http://app.lvh.me:5007 (RAILS_ENV=test, orchestrator-started), sidekiq up
**Team:** 1 agent, 4 scenarios (deadline-compressed from 15 agents x 2 rounds; coordinator directive 09:29 CT, logged)
**Convergence rule for this run:** one clean round (coordinator relaxation, logged)

## Result: 4/4 scenarios PASS, 0 findings - GATE PASS

1. magic_create new-user (HTTP wire path): four values persisted raw (utm_source "QA-RawCase" no downcase; utm_data hash round-trip); no-params user -> all four nil (utm_data nil, NOT {}).
2. magic_create existing-user no-touch (HTTP): BOTH existing-user branches (unconfirmed resend + confirmed magic-link) POSTed WITH utm params; columns stayed nil.
3. from_omniauth keyword interface (rails runner): new user gets four raw values + partner_source downcased; same-email second call leaves columns unchanged (first_or_create block skipped); omitted keywords -> nil. Note: partner_source probe used "WwR" not "MiXeD" (partner_source is an integer enum permitting none/wwr; "mixed" would ArgumentError - pre-existing enum behavior, same &.downcase path exercised).
4. organizations#create copy (HTTP, real wire path incl. session cookie auth): org columns identical to creating user's; nil-column user -> nil-column org. Incidentally verified SPEC 4.3 password path.

Sequencing note (logged deviation): this layer ran while the Layer 2 fix agent held its commit at a gate (working tree carried the uncommitted frontend-only utils.js fix). Layer 3's scope is backend-only and disjoint from that fix; the gate serialized all test-DB users (L3 scripts -> L4 RSpec -> pre-commit Cypress hook).

Cleanup: qa-harness cleanup ran mid-run and at end.
