# spec-round-1 — per-identifier-capture-contract

Verified live on `attribution-work-qa` @ `b4cb4463a`: `app/javascript/shared/lib/utils.js` (`sanitizeTrackingParams` 42-91, `sanitizeTrackingValue` 31-40, `TRACKING_VALUE_MAX_LENGTH = 255` line 28), `OrganizationForm.tsx` 24-36, `useCookieValue.ts`.

Spec claims confirmed accurate against source:
- `useCookieValue` truncation defect is real: `setCookieValue(cookie.split("=")[1])` — value cut at the second `=`. The §5.1 first-`=`-only rule is the correct non-inheritance.
- `useCookieValue` does not URL-decode; "verbatim" capture for `__adroll_fpc`/`_gcl_aw` matches the analog's no-decoding behavior.
- The `_gcl_aw` parse description (§4) is byte-accurate to `OrganizationForm.tsx:25-29` for the >1-segment branch, including the quoted comment and GTM-editable-prefix rationale.
- `sanitizeTrackingValue` behavior (first-of-array, `.slice(0, 255)`, trailing-lone-high-surrogate drop) matches §5.1/§9 descriptions; existing fields' 255 path untouched by the spec.
- §5.2 `"; "`-join reproduces the raw `document.cookie` slice — coherent with "verbatim".
- `_ga` strip rule internally coherent (4 segments → strip `GA1.1`/`GA1.2` → `1234567890.1699999999`; <4 → raw).
- `fbc` construction guard coherent with §8.6.

## Findings

- F1 [MED] SPEC §4 (fbclid/li_fat_id/gclid rows) + §5.1 / repeated-URL-param handling unstated for the three URL-sourced new fields / §4 fbclid says "Verbatim from the URL, same handling as `gclid`/`adct`" — but `adct`'s handling is `sanitizeTrackingValue` (first-of-array + 255 cap), which conflicts with "verbatim", and the gclid/li_fat_id rows say only "URL param verbatim"/"URL param first". `queryString.parse` returns an ARRAY for a repeated param (`?fbclid=a&fbclid=b` → `["a","b"]`, live `utils.js:32` handles this for existing fields). Without a stated first-occurrence rule the implementer may pass the array through: JSON path → Rails scalar permit silently drops it (nil column); SSO hidden input → React stringifies `"a,b"` — the two paths diverge / fix: state in §5.1 that the URL-sourced fields (`fbclid`, `li_fat_id` URL branch, `googleClickId` URL branch) keep the FIRST occurrence of a repeated param (same rule as `sanitizeTrackingValue`) before the 1024 cap; `fbc` construction uses that first-occurrence fbclid.
- F2 [MED] SPEC §4 gclid row / dotless `_gcl_aw` fallback behavior unstated / live analog `OrganizationForm.tsx:28-29` is `parsedArray && parsedArray.length > 1 ? parsedArray[parsedArray.length - 1] : null` — a single-segment (dotless) cookie value yields null, i.e. contributes NOTHING. The spec states only the >1-segment branch, while the adjacent `_ga` rule explicitly stores RAW on unexpected format — an implementer could carry that raw-fallback over to `_gcl_aw`, deviating from the analog parse the spec says must be preserved / fix: add to §4 gclid row: when the split yields a single segment, the cookie contributes nothing (analog behavior — null); `googleClickId` is then absent unless the `gclid` URL param was present. Mirror in T4h.
- F3 [MED] SPEC §5.1 cookie-parsing rule / exact cookie-NAME matching unstated — `_ga` vs `_ga_*` collision / the stated rule covers value extraction (split on first `=`) but not name matching. A `startsWith("_ga")`-style lookup matches `_ga_ABC123XYZ` first and corrupts `gaClientId`; the analog `useCookieValue` matches `` `${cookieKey}=` `` exactly. §5.2 simultaneously requires prefix matching for `_ga_*` — the spec never says the `_ga` lookup must be exact-name / fix: add to the §5.1 cookie-parsing rule: cookie name = the substring before the first `=`, compared by exact equality for named cookies (`_ga`, `_fbp`, `_fbc`, `li_fat_id`, `_gcl_aw`, `__adroll_fpc`); only `gaSessionId` uses prefix matching (`_ga_`). Mirror in T4a.
- F4 [LOW] SPEC §5.1 value cap / cap-vs-parse ordering unstated / the 1024 cap could be read as applying to the raw cookie value or the final field value; for constructed `fbc` (`fb.1.<Date.now()>.<fbclid>`) and the `ga_session_id` join the results differ at degenerate lengths. Realistic values unaffected / fix (one clause): the cap applies to the FINAL field value — after the `_ga` strip, the `fbc` construction, and the `ga_session_id` join.

## Amendments Applied

None — orchestrator applies amendments. Recommended:
1. §5.1: add first-occurrence-of-repeated-param rule for the three URL-sourced fields (+ fbc construction input); note in §4 fbclid row that "same handling as adct" means first-occurrence, with the 1024 cap instead of 255. (F1)
2. §4 gclid row: state the single-segment `_gcl_aw` outcome (contributes nothing — analog null); update T4h. (F2)
3. §5.1 cookie-parsing rule: exact-name matching for named cookies, prefix matching only for `_ga_*`; update T4a. (F3)
4. §5.1: one clause — cap applies to the final field value, post-parse/construction/join. (F4)
