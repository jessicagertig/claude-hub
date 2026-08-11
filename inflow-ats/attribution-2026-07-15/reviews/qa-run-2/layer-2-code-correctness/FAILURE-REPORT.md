# QA Run 2 - Layer 2 FAILURE REPORT (input to fix agent)

**Date:** 2026-07-16 09:56 CT | **Branch:** attribution-work-qa at 299cf9465
**Scope: exactly one finding. Nothing else.**

## l2-B1 (HIGH) - surrogate-splitting truncation breaks the signup POST

**File:** app/javascript/shared/lib/utils.js - the 255-char truncation inside sanitizeTrackingParams' per-value sanitization (the .slice(0, 255) call).
**Defect:** .slice(0, 255) operates on UTF-16 code units. When unit 254 is the high half of a surrogate pair (astral char, e.g. emoji, straddling the boundary), the truncated string ends in a lone high surrogate. ES2019 well-formed JSON.stringify serializes it as a bare \udXXX escape; Rails' json 2.6.1 parser raises JSON::ParserError ("incomplete surrogate pair") on the request body, so the entire POST to /magic_login or /sign_up returns 400 - the user cannot sign up.
**Orchestrator-verified:** ruby -rjson: JSON.parse('{"a":"\ud83d"}') raises; node 16: ("x".repeat(254)+"\u{1F600}").slice(0,255) ends in a lone high surrogate, JSON.stringify tail is xxx\ud83d.
**Required fix (minimum change):** make the truncation surrogate-safe - after slicing to 255 units, if the last unit is a lone high surrogate (0xD800-0xDBFF), drop it (yielding 254 units). Do not switch to code-point semantics for shorter strings; do not touch anything else in the helper.
**Required test (utils.test.js, append only):** value of "x".repeat(254) + an astral char (e.g. "\u{1F600}") -> truncated result has length 254, ends with "x", and JSON.stringify(result) contains no lone-surrogate escape; plus confirm a plain 300-char ASCII value still truncates to 255.

## Fix-agent constraints
- ONLY app/javascript/shared/lib/utils.js and app/javascript/shared/lib/utils.test.js. No other files, no removals, no refactors, no package.json.
- Node 16 (source ~/.nvm/nvm.sh && nvm use). Verify: npx jest app/javascript/shared/lib/utils.test.js - all existing 11 + new must pass.
- TWO-PHASE COMMIT GATE: complete the edit + Jest verification immediately, report readiness, then WAIT (poll every 30s) for the go-file /tmp/qa-fix-commit-go-20260716 to appear before running git add/git commit. The gate serializes the shared test database (Layer 3 scripts + Layer 4 RSpec run before the pre-commit Cypress hook may start). Never --no-verify, never skip/weaken hooks or tests, never git stash. Commit detached, allow >=20 min for the hook, message ends with: Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
