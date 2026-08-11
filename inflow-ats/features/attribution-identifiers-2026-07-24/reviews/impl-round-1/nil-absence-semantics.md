# Impl round 1 — nil-absence-semantics

## Layer-by-layer, absent source → nil column

1. **Helper** (`utils.js`): every new field is set only inside its presence guard — absent cookie/param means the key is never set on `trackingParams`. No `|| ""`, `|| null`, `|| 0`, `|| {}`, `|| []` anywhere in the new code (grepped the diff). The `fbc` never-fabricate guard (§8.6) holds: construction requires `_fbc` absent AND a genuinely non-empty-string fbclid.
2. **JSON payloads**: `AuthForm.tsx`/`SignupForm.tsx` pass `trackingParams.<field>` directly — absent field → `undefined` → key dropped from the serialized body (same as the analog's `adrollClickId`) → `sign_up_params[:<key>]` nil → nil column.
3. **SSO**: unrendered hidden input (guard) → key absent from `rack_request.params` → setup lambda never writes it → `merged_tracking['<key>']` nil → nil-defaulted keyword → nil column.
4. **Org copy**: nil user column copies as nil org column (`organizations_controller.rb:37-44` plain assignment).
5. **Nil pinning in specs**: all-nil examples extended in all four files and green (registrations magic_create + create, from_omniauth omitted-keywords, organizations nil context — 13 nil assertions each).

## Edge parity with the analog

`?fbclid` (parses to `null`) sets `trackingParams.fbclid = null` and `?fbclid=` sets `""` — byte-identical to the existing `adct` handling, which SPEC §4 explicitly mandates for fbclid ("the same handling adct gets"). Neither value triggers `fbc` construction ✓. Both end as nil/"" columns exactly as `adct` does today — verified NOT a rule-10 violation (no fabrication; the URL genuinely carried the key, and the analog behavior is the binding contract).

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
