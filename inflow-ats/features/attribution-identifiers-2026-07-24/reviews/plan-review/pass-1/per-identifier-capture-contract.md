# Plan review pass 1 — per-identifier-capture-contract

Reviewed: plan.md §3 (precedents), §5.1 rows 4-6, §5.2, T4 (T4a-T4k) against SPEC §4/§5.1/§5.2 and live code on `attribution-work-qa` @ `b4cb4463a`.

## Fact checks performed (all verified live)

- `utils.js`: `TRACKING_VALUE_MAX_LENGTH = 255` at :28, `sanitizeTrackingValue` :31-40 (first-of-array, slice, trailing-lone-high-surrogate drop), `sanitizeTrackingParams` :42-91, per-field `!== undefined` guards :59-70, `adct` block :68-70, `utmDataKeys` derivation starts :72. Plan's insertion point (after :70, before the derivation) is valid — the derivation reads `keysInOccurrenceOrder`/`parsedParams`, not the new fields.
- `isArray`/`isString` imported at utils.js:2-3 — the T4 snippet's identifiers exist.
- Defaulted `maxLength = TRACKING_VALUE_MAX_LENGTH` param: existing call sites pass one argument → default 255 → existing fields byte-identical. Verified all existing `sanitizeTrackingValue` call sites are inside `sanitizeTrackingParams` (:60, :63, :66, :69, :85).
- `OrganizationForm.tsx:24-29` — `_gcl_aw` split-dot-last parse with the GTM format comment; :34 `__adroll_fpc` verbatim. T4h preserves the parse rule and comment byte-faithfully.
- query-string v6.1.0 (package.json + node_modules both 6.1.0), verified live against the installed package: `?fbclid` → `{"fbclid":null}`, `?fbclid=` → `{"fbclid":""}`, `?fbclid=a&fbclid=b` → `["a","b"]`. The T4 snippet's fbc-construction guard (`typeof x === "string" && x.length > 0` on the first-occurrence value) correctly excludes null and "", and both fall through to cookie fallbacks for `li_fat_id`/`gclid` — matches SPEC §4 notes exactly.
- `gaClientId` strip: `gaSegments.length >= 4 ? gaSegments.slice(2).join(".") : gaCookieValue` — matches SPEC §4 (strip first two dot-segments; <4 segments → raw).
- `gaSessionId`: `indexOf("_ga_") === 0` prefix filter excludes bare `_ga`; `<name>=<value>` `"; "`-join; single raw string (decision 3 respected). Matches the house prefix-match idiom (`key.indexOf("utm_") === 0` at utils.js:75).
- Cookie helper: first-`=` split via `indexOf("=")`/`substring`, exact-equality name match in `getCookieValue`, empty-value cookie skipped — all three SPEC §5.1 rules present. `document.cookie.split("; ")` matches `useCookieValue.ts:7`'s own separator.
- 1024 cap applied to FINAL values (after strip/join/construction) in every T4 block — decision 2 respected; fbc constructs from the uncapped first-occurrence fbclid then caps, per SPEC §5.1.
- Valueless `?fbclid` yields `trackingParams.fbclid = null` through `sanitizeTrackingValue` — identical to the analog's `adct` behavior (SPEC: "the same handling `adct` gets"), not a fabrication finding.

## Findings

### F1 — MED — plan.md misattributes a "shadowing defect" to `useCookieValue`

Plan §3 precedents row "Cookie read + parse" states useCookieValue's "`startsWith` name match is the shadowing defect not to inherit," and §12 deviation ledger item 2 says its "`split("=")[1]` truncation and `startsWith` matching are defects not to inherit." Live code (`app/javascript/shared/hooks/useCookieValue.ts:8`) matches `cookie.startsWith(\`${cookieKey}=\`)` — the appended `=` means a `_ga` lookup cannot match `_ga_<CONTAINER>=...`; no shadowing defect exists there. Only the `cookie.split("=")[1]` value truncation (:10) is a real defect. SPEC §5.1's warning is about a bare startsWith-style name lookup and is correct as written; the plan wrongly pins it on useCookieValue. No task changes — T4a's exact-equality directive comes from SPEC §5.1 and stands.

**Amendment applied:** both plan.md passages corrected to attribute only the truncation defect to useCookieValue. code-task-list.md T4a needs no change (its startsWith warning is the spec's generic directive, not a claim about useCookieValue).

## Verdict for this angle

1 MED (amended), 0 HIGH, 0 BLOCKER. All eight §4 capture rules present and correct in T4; all §13 decisions respected.
