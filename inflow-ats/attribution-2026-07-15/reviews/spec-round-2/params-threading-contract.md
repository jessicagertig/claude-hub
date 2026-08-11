# params-threading-contract — Round 2

Round-2 sweep of the amended spec against the wire contract. No new findings.

- Nested-`Parameters`-to-jsonb write path re-confirmed: actionpack 6.1.7.7 delegates `:as_json` to `@parameters` (strong_parameters.rb line 247), so `sign_up_params[:utm_data]` (permitted nested Parameters) serializes to the plain inner hash exactly as the `questions.options` production analog does. Both `magic_create` (plain-Hash `user_params` with a Parameters value) and `create` (`expanded_params` Parameters) shapes are safe.
- Absent-field drop re-confirmed end-to-end: `variables` built with `utmSource: <undefined>` → `allKeysToSnake` copies the key but axios JSON-serialization drops undefined values → param never arrives → permit omits it → nil column. Rule-9-compliant (pass value as-is, no deliberate undefined).
- Existing-user branches re-read after the §9 amendments: still read only `user_params[:email]`; merge remains inert; responses unchanged.
- `login_intent`/`organization_slug` interplay documented in §9.1 does not alter §4.2's production description (frontends always send `loginIntent: "hire"` — `AuthForm.tsx:78`; connect flows carry a slug).
- The §5.4 asymmetry (magicLink has an inline TS type, register does not) matches source exactly — no phantom "add type to register" instruction.

## Findings

- None.

## Amendments Applied

- None.
