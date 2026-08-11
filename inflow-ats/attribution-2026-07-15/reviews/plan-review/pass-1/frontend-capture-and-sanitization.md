# Frontend Capture and Sanitization — Pass 1

## Fact Check

| Claim (plan) | Verified against | Result |
|---|---|---|
| `standardizeQueryParamsObject` at top of `utils.js` (lines 9–19) | `app/javascript/shared/lib/utils.js` | ✓ exact (lines 9–19) |
| `utils.js` imports are lodash `keys`/`isString`/`isArray`/`isPlainObject`, no `query-string` import today (F1.1 adds it) | `utils.js` lines 1–4 | ✓ — helper's `isArray`/`isString` uses are already imported |
| query-string pinned 6.1.0 | `package.json` (`"query-string": "6.1.0"`), `node_modules/query-string/package.json` | ✓ |
| v6.1.0 `parse` returns keys alphabetically sorted, no opt-out | `node_modules/query-string/index.js:157` — `return Object.keys(ret).sort().reduce(...)` | ✓ exact |
| Array values pass the final sort untouched via `!Array.isArray(value)` guard | index.js:159 — `if (Boolean(value) && typeof value === 'object' && !Array.isArray(value))` | ✓ exact — repeated-param arrays keep occurrence order (`default:` formatter builds `[].concat(accumulator[key], value)`) |
| `queryString.extract` handles `"?a=b"` and `""` (returns `""` when no `?`) | index.js:121–127 — `indexOf('?')`, `-1 → ''` | ✓ exact |
| Key decode mirror: `+`→space then decode | index.js parse: `param.replace(/\+/g, ' ').split('=')` then `decode(key, options)` | ✓ — plan's `param.replace(/\+/g, " ").split("=")[0]` + `decodeURIComponent` mirrors library order of ops; try/catch fallback covers `decode-uri-component` being more forgiving (recorded spec-review LOW) |
| `?utm_source` (no `=`) parses to `null` | index.js: `value = value === undefined ? null : decode(value, options)` | ✓ |
| `AuthForm.tsx:37–38` referral/partner state analog | live file | ✓ exact |
| `SignupForm.tsx:23` referral state analog | live file | ✓ exact |
| Jest configured; precedent `Button.test.tsx` | `jest.config.js` (default testMatch — a `*.test.js` under `app/javascript/shared/lib/` is picked up; not in testPathIgnorePatterns); `app/javascript/ats/src/components/shared/Button/Button.test.tsx` exists | ✓ |
| `sanitizeTrackingParams` does not exist anywhere (C.2) | `git grep sanitizeTrackingParams` → no matches | ✓ re-verified |

## Helper logic vs D4 (verbatim code block reviewed)

- 255-char truncation per value: `firstValue.slice(0, TRACKING_VALUE_MAX_LENGTH)` — ✓ (applies to `utmSource`/`utmCampaign`/`internalRef` and every `utmData` value via the shared `sanitizeTrackingValue`).
- First occurrence of repeated param: `isArray(value) ? value[0] : value` — ✓ (verified parse builds arrays in occurrence order).
- 10-key cap by RAW-STRING occurrence order: keys scanned from `queryString.extract(search).split("&")`, deduped, filtered to `utm_*` minus `utm_source`/`utm_campaign`, `.slice(0, UTM_DATA_MAX_KEYS)` — ✓ order comes from the raw string, not the sorted parse output (the D4-critical property).
- Exclusions: `key !== "utm_source" && key !== "utm_campaign"` — ✓; `internal_ref` does not start with `utm_` so it cannot leak into `utmData` — ✓.
- Absence semantics: fields added only under `parsedParams.<key> !== undefined` checks; `utmData` added only when `utmDataKeys.length > 0`; no `|| ""`, no `|| {}` — ✓ (D3/D6, core rule 10).
- `null` passthrough: `sanitizeTrackingValue(null)` → `isArray` false → `isString` false → returns `null` — ✓ property present with `null`, matching spec §5.1.
- The strict `!== undefined` deviation from rule 13's loose house guard is deliberate, documented in the plan with the correct rationale (`null` must count as PRESENT), and pinned against "fixing" by conventions reviewers — consistent with spec §5.1. Not a finding.
- Empty-string param edge (`""` → `split("&")` gives `[""]` → skipped by `param.length === 0`) — ✓ `sanitizeTrackingParams("")` returns `{}`.

## Completeness (spec §5.1, §5.2 capture, §5.5 capture)

- Helper input contract (raw string, not parsed object) — F1.2 ✓
- Placement next to `standardizeQueryParamsObject` — F1.2 ✓
- Capture in AuthForm before setState, no setter — F3.2 ✓ (`React.useState(sanitizeTrackingParams(location.search))`, one-object state = declared plan choice, spec leaves shape plan-level)
- Capture in SignupForm via `props.location.search` — F4.2 ✓
- Jest coverage of every rule — T1.2–T1.8 ✓ (see test angle)

## Findings

- F2 [LOW] plan.md F3.6 cites `AuthRegister.tsx:134` for the `location={props.location}` pass-through; the live line is 136 (`Auth.tsx:72` is correct). The claim itself — both render sites already pass `location`, so capture covers `/auth` and `/auth-register` with no parent change — is TRUE and verified. Reference-only (no edit in that file). Fix: cite :136.

## Amendments Applied

- plan.md F3.6: `AuthRegister.tsx:134` → `AuthRegister.tsx:136`.
