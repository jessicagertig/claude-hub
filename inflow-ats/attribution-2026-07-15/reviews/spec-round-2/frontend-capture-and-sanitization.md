# frontend-capture-and-sanitization — Round 2

Round-2 focus: verify the round-1 §5.1 amendment against the library source a second time and sweep the amended text for new gaps.

## Round-1 amendment re-verification (holds)

- `query-string` 6.1.0 pinned in package.json — matches the vendored copy whose `parse()` was read in round 1. Alphabetical key sort (`Object.keys(ret).sort().reduce`) confirmed; no parse-side `sort` option in this version; `extract` is exported (the amendment's example mechanism is real).
- Array values (repeated params) skip `keysSorter` (`!Array.isArray(value)` branch) — occurrence order inside arrays preserved; "first occurrence = element [0]" stands.
- `parse` replaces `+` with space before decoding — relevant to §4.8's email param, not to utm values; `CGI.escape` percent-encodes `+` as `%2B`, so emails with plus-addressing round-trip correctly (checked under posthog angle round 1).

## Findings

- F1 [LOW] `utmData` KEY length is uncapped (D4 caps value length at 255 and key count at 10, not key length). A pathological 10k-char `utm_<garbage>` key name rides to jsonb on the JSON paths. Consistent with raw-as-sent (Risk 4 already covers value length server-side); cookie-overflow consequence on the SSO path already accepted as Risk 2. D4 is binding — recorded, no amendment.
- F2 [LOW] Percent-encoded keys (`utm%5Fsource`) decode to `utm_source` in `queryString.parse` but a naive raw-string order scan sees the encoded form. Plan-level: the order-derivation must decode key names before matching/ordering (the §5.1 contract "order comes from the raw string, values from the parse" leaves the decode to the plan). No amendment — the Jest occurrence-order test plus D4's rules pin observable behavior, and canonical utm links don't percent-encode underscores.

## Verified-clean

- §5.2/§5.5 amended capture text is consistent with §5.1's new input contract (raw string in, camelCase fields out); no stale "parsed object" reference anywhere in the spec (grepped the spec text).
- Absence semantics unchanged and rule-9/10 compliant.
- `react_hooks.md` (this round's conventions read): the capture state as one object of related tracking fields or per-field state both fit the file's guidance ("may combine related form fields when truly related"); §5.2 correctly leaves it plan-level. The no-setter choice matches "state synced with props" guidance inverse case (never re-captured).

## Amendments Applied

- None.
