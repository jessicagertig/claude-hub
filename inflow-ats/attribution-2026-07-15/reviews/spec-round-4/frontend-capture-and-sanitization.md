# frontend-capture-and-sanitization — Round 4

Re-read the amended §5.1/§5.2/§5.5 against source and this round's conventions file (`cursor_rules/frontend/_base.md`, read in full).

- `_base.md` rule 2 (never deliberately set undefined) vs the helper's absent-field output: building the output object from only-present params is not the banned `x || undefined` pattern; payload construction passes values through as-is. No conflict.
- `_base.md` rule 3's "JSONB columns — use camelCase" is the rule the spec's `utm_data` inner keys deviate from — the deviation is declared in §5's case-convention note and approved (REVIEW-ANGLES Priority rule 4). Not flagged.
- `_base.md` rule 1 (no `??`): the spec proposes none.
- Nested-bracket key edge (`?utm_custom[a]=1`): queryString.parse treats it as a literal key; sanitizer captures it into `utmData`; JSON path flattens via lodash snakeCase; the SSO hidden-input name would nest brackets, which Rack tolerates or 400s on truly malformed crafted input — tampered-input-only, pre-existing behavior class for every Rails endpoint, no data damage. Recorded; no amendment.
- Helper output for a param-free URL: all fields absent (empty object) → no payload keys → nil columns. Consistent.

## Findings

- None.

## Amendments Applied

- None.
