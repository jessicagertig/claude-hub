# frontend-capture-and-sanitization — Round 2

Re-derived fresh. Verified against `app/javascript/shared/lib/utils.js`, `utils.test.js`, `AuthForm.tsx`, `SignupForm.tsx`, and the installed `node_modules/query-string` v6.1.0 source.

## Verified

- `sanitizeTrackingParams` placed directly after `standardizeQueryParamsObject` at the top of `utils.js` (spec §5.1 placement).
- Input is the raw `location.search` string at both capture sites; values come from `queryString.parse(search)`, key occurrence order from `queryString.extract(search).split("&")` — read the installed v6.1.0 source and confirmed both spec claims: `parse` ends in `Object.keys(ret).sort().reduce(...)` (keys alphabetized, order lost) and repeated-param arrays are built in occurrence order pre-sort (values pass the final key-sort untouched), so `value[0]` in `sanitizeTrackingValue` is genuinely the first occurrence.
- 255-char truncation (`slice(0, TRACKING_VALUE_MAX_LENGTH)`), first-of-array, 10-key cap applied AFTER the utm_/exclusion filter (`.filter(...).slice(0, UTM_DATA_MAX_KEYS)`) — first 10 by raw-string occurrence order, exactly D4.
- `utm_source`/`utm_campaign` excluded from `utmData`; `internal_ref` captured as scalar.
- Absence semantics: fields assigned only when `parsedParams.<key> !== undefined`; `utmData` set only when `utmDataKeys.length > 0`; no `|| ""`, no `|| {}` anywhere. `!== undefined` (not the house `!= undefined`) is required here: a valueless `?utm_source` parses to `null` and must pass through (spec §5.1) — the Jest test pins it.
- `sanitizeTrackingValue(null)` → `null` (isString guard); array-with-null-first → `null`. Correct pass-through.
- Capture in `AuthForm.tsx:41` and `SignupForm.tsx:26` via `React.useState(sanitizeTrackingParams(...))`, no setter, sanitize-before-state, exactly the adjacent `referral` analog shape. `AuthForm` receives `location={props.location}` from both `Auth.tsx` and `AuthRegister.tsx:136` (verified) — both pages covered.
- Jest: 8/8 pass; the 10-key-cap test's `utm_z…utm_q, utm_a` ordering falsifies a parse-sorted implementation as §9.6 requires.

## Findings

- F1 [LOW] `app/javascript/shared/lib/utils.js` (key scan inside `sanitizeTrackingParams`) / key-decode divergence on malformed input / the occurrence scan decodes keys with `decodeURIComponent` (try/catch → raw-key fallback) while `queryString.parse` v6.1.0 decodes with the `decode-uri-component` package, which recovers partially from malformed percent-encoding instead of throwing. For a malformed key such as `utm_%E0`, the occurrence list holds `utm_%E0` while `parsedParams` holds the recovered variant; the `parsedParams[key] !== undefined` filter then misses it and the param is silently dropped from `utmData`. Only malformed-encoding keys are affected; well-formed keys decode identically on both paths. No attribution signal lost in practice — informational, no fix required.
- F2 [LOW] `app/javascript/shared/lib/utils.js` / `extract` vs `parse` asymmetry on a '?'-less input / `queryString.parse` tolerates a search string without a leading `?` (it strips an optional leading `[?#&]`), but `queryString.extract` returns `''` when no `?` exists — a hypothetical `sanitizeTrackingParams("utm_medium=x")` would capture scalars but never `utmData`. Unreachable via both call sites (`location.search` is always `''` or starts with `?`). Informational only.

No BLOCKER/HIGH/MED findings.
