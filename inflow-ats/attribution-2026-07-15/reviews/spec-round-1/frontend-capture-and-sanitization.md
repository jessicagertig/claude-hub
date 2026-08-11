# frontend-capture-and-sanitization — Round 1

Verified against live source: `app/javascript/shared/lib/utils.js` (helper placement, `standardizeQueryParamsObject` at line 9), `AuthForm.tsx` (referral state line 37, partner line 38), `SignupForm.tsx` (referral line 23), `node_modules/query-string/index.js` (v6.1.0 parse implementation, read in full).

## Findings

- F1 [HIGH] SPEC.md §5.1 "Input: the object returned by `queryString.parse(location.search)`" / **the installed `query-string` v6.1.0 `parse` returns keys alphabetically sorted, unconditionally** — `parse()` ends in `Object.keys(ret).sort().reduce(...)` (`node_modules/query-string/index.js`, no parse-side `sort` option exists in this version). Occurrence order in the query string is destroyed before the helper ever sees the object, so D4 rule 3 ("first 10 by occurrence order") is unimplementable from the spec's stated input. An implementer following the spec literally would ship an alphabetical-order cap and call it occurrence order — and the Jest test as previously written (no order-vs-alphabet discrimination) would pass anyway. / Fix: input contract changed to the raw `location.search` string; helper derives key order from the raw string, values from `queryString.parse` internally (D1's parse mechanism preserved). Verified secondary fact: repeated-param arrays are built in occurrence order by the `'none'` arrayFormat formatter and pass through the final sort untouched (`!Array.isArray(value)` branch), so rule 1's first-occurrence-is-element-0 still holds.
- F2 [LOW] Case sensitivity of the `utm_` prefix match is unstated. `?UTM_SOURCE=x` would not be captured. This is the letter of D2 ("params whose name starts with utm_"); canonical tags are lowercase. No amendment — noted for the record.
- F3 [LOW] A literal `?utm_data=xyz` URL param starts with `utm_` and would be captured INSIDE `utmData` as key `"utm_data"`, then posted as `utm_data[utm_data]=xyz`. Mechanical consequence of D2's rule; harmless, raw-as-sent. No amendment.

## Verified-clean

- Absence semantics (§5.1) comply with core_critical_rules 9/10: absent → absent field, no `|| ""`/`|| {}`; `?utm_source` → `null` passes through (parse yields `null` for missing `=` — verified in library source).
- 255-truncation, first-of-array, 10-key cap, source/campaign exclusion all restate D4 exactly (binding, not re-litigated).
- Helper placement matches the `standardizeQueryParamsObject` precedent.

## Amendments Applied

- SPEC.md §5.1 Input paragraph rewritten: raw `location.search` input, order-from-raw-string / values-from-parse contract, library-source citation, array-order fact.
- SPEC.md §5.2 capture bullet: "pass `location.search` through `sanitizeTrackingParams`" (was: parsed object through helper).
- SPEC.md §5.5 capture bullet: same for `SignupForm.tsx`.
- SPEC.md §9.6 Jest requirements: occurrence-order test must use a non-alphabetical param order so a sorted-parse implementation fails.
