# Params Threading Contract — Pass 2

## Pass 1 correction verification
No Pass 1 amendments touched this angle's sections (B3, F2, F3.3, F4.3, frontend preamble). Verified unchanged and still correct.

## Fresh scrutiny
- B3.1 permit line re-diffed character-by-character against live `registrations_controller.rb:302`: all eleven existing scalars preserved in order; `:utm_source, :utm_campaign, :internal_ref` appended; `utm_data: {}` is the trailing argument (the `questions_controller.rb:50` form). Commented-out line 301 preserved. ✓
- B3.2's branch-1 hash re-checked for Ruby syntax: `connect_login_intent_organization_id: organization.id, # Used to determine…` — comma before the inline comment, then the four new pairs — valid; branch semantics unchanged (the pre-existing nil-crash in that branch is correctly quarantined as out of scope, tests route around it with `login_intent: 'hire'`).
- Nil-for-absent chain re-traced end to end: absent helper field → `undefined` property read (F3.3/F4.3) → `allKeysToSnake` maps it to an `undefined`-valued snake key → axios `JSON.stringify` drops it → wire param absent → `sign_up_params[<key>]` nil → column nil (no default). Each hop verified in live code (structure.js, api.ts:52, schema). ✓
- `ActionController::Parameters` → jsonb write path re-confirmed: `as_json` delegation to `@parameters` present in installed actionpack 6.1.7.7; plan Risk 4 carries the `.to_h` contingency as a surfaced (not silent) deviation. ✓

## Completeness sweep (spec §4.1–4.3, D2/D3/D10)
All requirements mapped: permit (B3.1), both-branch merge (B3.2), create-path no-op (B3.3), raw storage, nil-for-absent, response shapes untouched, camel/snake conventions with the approved `utm_data` inner-key deviation. Nothing dropped.

## Findings
No issues found.

## Amendments Applied
None.
