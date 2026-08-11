# Impl round 1 — per-identifier-capture-contract

Reviewed: committed diff `b4cb4463a..a0d59115d`, `app/javascript/shared/lib/utils.js` read whole in committed state.

## Verification per identifier (all against SPEC §4/§5.1/§5.2)

- **gaClientId** (`utils.js:95-102`): `_ga` cookie via exact-equality `getCookieValue`; `split(".")`, `length >= 4 → slice(2).join(".")`, else raw cookie value; capped at `ATTRIBUTION_IDENTIFIER_MAX_LENGTH` (1024). Matches §4 including the <4-segment raw fallback. VERIFIED — `"GA1.1.1234567890.1699999999"` → `"1234567890.1699999999"`.
- **gaSessionId** (`utils.js:105-115`): `cookieEntry.name.indexOf("_ga_") === 0` prefix filter — excludes bare `_ga` (`"_ga".indexOf("_ga_")` = −1); serialized `<name>=<value>` joined `"; "`; single raw string, NOT jsonb; cap applied AFTER the join. Matches §5.2 / §13 decision 3.
- **fbclid** (`utils.js:118-123`): `parsedParams.fbclid !== undefined` guard + `sanitizeTrackingValue(..., 1024)` — byte-identical handling to the `adct` analog (`utils.js:87-89`) at the 1024 cap, exactly as §4 directs ("the same handling adct gets"). Note: `?fbclid` (parses to `null`) rides as `null` and `?fbclid=` as `""` — identical to the analog's `adct` behavior; both end as nil/"" server-side exactly as `adct` does. Verified NOT a deviation.
- **fbp** (`utils.js:126-129`): `_fbp` verbatim, cap only. Matches.
- **fbc** (`utils.js:131-142`): `_fbc` cookie verbatim first; else constructed `"fb.1." + Date.now() + "." + fbclidParamValue` ONLY when `typeof fbclidParamValue === "string" && fbclidParamValue.length > 0` where `fbclidParamValue` is the first-of-array occurrence. `?fbclid` (null) and `?fbclid=` ("") cannot construct. Cap applied to the FINAL constructed string; construction uses the UNCAPPED fbclid (correct — §5.1 says cap the final value). Matches §4 + §8.6.
- **liFatId** (`utils.js:145-161`): URL param first (non-empty-string guard, first-of-array), else `li_fat_id` cookie. Matches §4.
- **googleClickId** (`utils.js:164-181`): `gclid` URL param first (non-empty-string guard); else `_gcl_aw` split-on-`.`, last element only when `length > 1`; dotless cookie contributes nothing; NO raw fallback (correct — §4 says the `_ga` raw-fallback rule does not apply). The two comment lines are preserved verbatim from `OrganizationForm.tsx:25-29` ("Expected format for cookie value: GCL.1719852261.actualGoogleClickIdHere" / "Since the beginning can be edited in GTM, get last element of array"). Matches §4 / §13 decision 1.
- **adrollFirstPartyCookie** (`utils.js:184-190`): `__adroll_fpc` verbatim + cap. Matches.

## Cookie-entry mechanics (§5.1)

- `getCookieEntries` (`utils.js:43-54`): splits `document.cookie` on `"; "`, then each entry on the FIRST `=` only (`indexOf("=")` + two `substring` calls — value = everything after the first `=`). Does NOT inherit `useCookieValue`'s `split("=")[1]` truncation defect. `useCookieValue.ts` itself untouched (verified via grep — remaining consumers: itself + `useReferrerCookie.ts`).
- Name matching: `getCookieValue` uses `cookieEntry.name === cookieName` strict equality for `_ga`, `_fbp`, `_fbc`, `li_fat_id`, `_gcl_aw`, `__adroll_fpc` — a `_ga_<CONTAINER>` cookie cannot shadow `_ga`. Only `gaSessionId` uses the `_ga_` prefix filter. Matches §5.1 exactly.
- Empty-value cookie (`cookieValue.length === 0`) skipped = treated as absent ✓. Entry without `=` skipped ✓. Empty `document.cookie` → `[""].forEach` → no `=` → empty entries array ✓.

## Cap rule (§13 decision 2)

- `ATTRIBUTION_IDENTIFIER_MAX_LENGTH = 1024` (`utils.js:29`) applied to all eight; `sanitizeTrackingValue` gained a DEFAULTED `maxLength = TRACKING_VALUE_MAX_LENGTH` param (`utils.js:32`) so all four existing call sites (`utm_source`, `utm_campaign`, `internal_ref`, `adct`, plus the `utmData` loop at `utils.js:205`) remain byte-identical at 255. Surrogate-safe truncation logic unchanged.
- Cap applied to the FINAL value in every case: after the `_ga` strip, after the `"; "` join, after the `fbc` construction. ✓

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
