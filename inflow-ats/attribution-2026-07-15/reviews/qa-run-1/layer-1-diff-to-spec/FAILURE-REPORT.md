# QA Run 1 — Layer 1 FAILURE REPORT (input to fix agent)

**Date:** 2026-07-16 ~01:05 CT
**Branch:** attribution-work-qa at 8dcc2f06f (repo /Users/jessica/wrk/wrk-corp/inflow-ats)
**Verdict:** Layer 1 round 1 found 2 HIGH findings. Both are in the frontend capture area. Fix scope is EXACTLY these two findings — nothing else.

## Finding F1 — sanitizeTrackingParams drops utm_* params with malformed percent-encoded keys

**File:** app/javascript/shared/lib/utils.js (sanitizeTrackingParams key-occurrence scan)
**Spec:** SPEC.md §5.1 (D4) — utmData must hold "every other param whose name starts with utm_"; mechanism contract: "order comes from the raw string, values from the parse".
**Defect:** The occurrence-order key scan decodes each raw key token with native `decodeURIComponent` (falling back to the raw key on throw). `queryString.parse` (query-string v6.1.0) decodes keys with `decode-uri-component` 0.2.0, which best-effort-decodes malformed sequences instead of throwing. For keys mixing valid and malformed percent sequences the two decoders produce different strings, the scan key fails the `parsedParams[key] !== undefined` membership filter, and the param is silently dropped from utmData (not captured, not counted toward the 10-key cap).
**Empirical reproductions (against installed node_modules, Node 16 via nvm use):**
- `sanitizeTrackingParams("?utm_x%C2=1&utm_medium=m")` returns `{utmData:{utm_medium:"m"}}` — but `queryString.parse` captures key `utm_x�`, which starts with `utm_` and must land in utmData.
- Same class: `utm_%C3%A9%`, `utm_a%FE%FF`, `utm_%E2%98%83%E2`, `utm_100%25%E2`.
**Required fix (minimum change):** make the scan's key decoding identical to `queryString.parse`'s for ALL inputs, so scan keys and parse keys can never diverge. Preferred mechanism: decode scanned keys with the same `decode-uri-component` module (already in node_modules as query-string 6.1.0's own dependency) in place of the native `decodeURIComponent`+catch. Any alternative must guarantee key-set identity with the parse output. Do NOT restructure the helper, do NOT change its output contract, do NOT touch any other function in utils.js.

## Finding F2 — §9.6 Jest gap: utmData inner-value sanitization unpinned

**File:** app/javascript/shared/lib/utils.test.js
**Spec:** SPEC.md §9.6 + §5.1 (D4 — "each value sanitized" applies to utmData values); pipeline rule 26 (falsifiable tests).
**Defect:** The 255-truncation and repeated-param-first-occurrence tests exercise only top-level `utm_source`. An implementation that assigned `utmData[key] = parsedParams[key]` without `sanitizeTrackingValue` would pass all 8 existing tests.
**Required fix:** add test assertions:
1. `sanitizeTrackingParams("?utm_medium=" + "b".repeat(300))` → `result.utmData.utm_medium.length` is 255
2. `sanitizeTrackingParams("?utm_medium=first&utm_medium=second")` → `result.utmData.utm_medium === "first"`
3. Regression pin for F1: a mixed-validity percent-encoded utm_* key (e.g. `"?utm_x%C2=1"`) lands in utmData keyed exactly as `queryString.parse` decodes it.
Do NOT modify or weaken any existing test.

## Fix-agent constraints (binding)

- Work ONLY on branch `attribution-work-qa` in /Users/jessica/wrk/wrk-corp/inflow-ats. Verify `git branch --show-current` first.
- Minimum-change discipline (pipeline rules 10/23): no code beyond the two findings, no removals beyond scope, no refactors, no touching shared infrastructure, no new dependencies in package.json (decode-uri-component is resolvable from node_modules as an existing transitive dependency — import it directly, matching what query-string itself uses).
- Node 16 required: `source ~/.nvm/nvm.sh && nvm use` before any Jest run.
- Verify with: `npx jest app/javascript/shared/lib/utils.test.js` — all tests (existing 8 + new) must pass.
- Also verify the F1 reproductions now capture the params (quick node script through the helper is fine — script in /tmp, never in the repo).
- Commit on attribution-work-qa with a focused message. Commit DETACHED with >=20-minute allowance (pre-commit hook runs the Cypress suite — WAIT for it; never --no-verify, never skip or weaken hooks/tests). End the commit message with:
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
- NEVER: git stash (any form), .env edits, DATABASE_URL, db:reset/setup/schema:load, psql.
