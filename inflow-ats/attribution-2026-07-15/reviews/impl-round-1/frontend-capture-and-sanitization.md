# frontend-capture-and-sanitization — Round 1

Reviewed: committed diff `62dd55867..8dcc2f06f` (working tree clean, HEAD = 8dcc2f06f — pipeline rule 15 satisfied).

## Verification performed

- **Helper** (`app/javascript/shared/lib/utils.js:22-87`): `sanitizeTrackingParams` matches the plan F1.2 block verbatim. Placed directly after `standardizeQueryParamsObject` (placement analog satisfied). `import queryString from "query-string";` added to the existing lodash imports.
- **Sanitization rules (D4), verified against installed query-string v6.1.0 source** (`node_modules/query-string/index.js`):
  - 255-char truncation via `firstValue.slice(0, TRACKING_VALUE_MAX_LENGTH)` — strings only; non-strings (null) pass through untouched. Confirmed by Jest run.
  - Repeated param → `isArray(value) ? value[0] : value` — library builds arrays in occurrence order and the final `Object.keys(ret).sort()` does not reorder array VALUES (verified `!Array.isArray(value)` guard at index.js:157-160), so `[0]` is genuinely the first occurrence.
  - 10-key cap by occurrence order derived from the RAW string (`queryString.extract(search).split("&")` key scan), not from `parse`'s alphabetically-sorted output — the exact mechanism the spec §5.1 mandates. Key decode mirrors the library's own (`param.replace(/\+/g, ' ').split('=')` at index.js:145 — the library does treat `+` as space in keys, so the helper's `replace(/\+/g, " ")` before `decodeURIComponent` matches).
  - `utm_source`/`utm_campaign` excluded from `utmData`; `internal_ref` captured as `internalRef`; prefix match `key.indexOf("utm_") === 0` case-sensitive (recorded spec-review LOW, accepted).
- **Absence semantics (D3/D6, core rule 10):** no `|| ""`, no `|| {}` anywhere in the helper or its consumers. Fields added only when `parsedParams.<key> !== undefined`; `utmData` added only when `utmDataKeys.length > 0`. `?utm_source` (valueless) parses to `null` and passes through — confirmed by the Jest "passes a valueless param through as null" case. The strict `!== undefined` is the spec-pinned deliberate choice (loose `!= undefined` would misclassify the null passthrough as absent) — NOT a rule-13 violation; conventions reviewers must not "fix" it.
- **Capture sites:**
  - `AuthForm.tsx:41` — `const [trackingParams] = React.useState(sanitizeTrackingParams(location.search));` — same state mechanism as the `referral` analog at line 39, sanitize-before-state, no setter. `location` is the destructured prop passed by both parents (`Auth.tsx:83`, `AuthRegister.tsx:134-139` both pass `location={props.location}`) — capture covers `/auth` and `/auth-register` with no parent change (verified live).
  - `SignupForm.tsx:26` — same via `props.location.search` (`referral` analog at line 25). `Signup.tsx:25` spreads route props (`{...props}`), so `location` arrives.
- **Jest coverage** (`app/javascript/shared/lib/utils.test.js`): all 8 cases pass (ran `yarn jest app/javascript/shared/lib/utils.test.js` — 8 passed). Includes the anti-ghost non-alphabetical 10-key-cap case (utm_z first, utm_a dropped).
- **Known-accepted divergence, not re-opened:** helper decodes keys with `decodeURIComponent` + try/catch fallback while the library uses the more lenient `decode-uri-component`; on a malformed percent-encoded key the two can disagree and the key drops from `utmData`. Recorded spec-review LOW, plan-level mechanism, accepted.

## Findings

No issues found.
