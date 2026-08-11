# Impl round 1 — wire-format-integrity

## JSON paths (magicLink + register)

Re-verified empirically against the repo's installed lodash (`node -e` with `lodash/snakeCase`):

| camelCase (useSession.ts) | wire (allKeysToSnake) | permit / column |
|---|---|---|
| `gaClientId` | `ga_client_id` | ✓ |
| `gaSessionId` | `ga_session_id` | ✓ |
| `fbclid` | `fbclid` | ✓ |
| `fbp` | `fbp` | ✓ |
| `fbc` | `fbc` | ✓ |
| `liFatId` | `li_fat_id` | ✓ |
| `googleClickId` | `google_click_id` | ✓ |
| `adrollFirstPartyCookie` | `adroll_first_party_cookie` | ✓ |

- `useSession.ts`: eight added at all five positions — `register` destructure (`:39-46`) + variables (`:62-69`); `magicLink` destructure (`:88-95`) + inline type as `?: string | null` (`:110-117`) + variables (`:144-151`). `api.ts` untouched; `allKeysToSnake` (`structure.js:94-108`) transforms keys only, values untouched — the `=`/`;`-laden `ga_session_id` value arrives byte-exact.
- `ga_session_id` remains a plain string end-to-end — no object/jsonb shape reintroduced anywhere (the §13 decision 3 BLOCKER trap): migrations declare `:string`, the helper emits a joined string, the hidden input is a plain single-value input, the permit is a plain symbol.

## SSO form path

Hidden-input names are written snake_case directly (`GoogleSSOButton.tsx:95-118`) and equal the `allowed_keys` entries (`omniauth.rb:14-15`), which equal the `sign_up_params` permit names (`registrations_controller.rb:328`), which equal the `merged_tracking` string keys (`omniauth_callbacks_controller.rb:31-38`), which equal the `from_omniauth` keywords (`user.rb:379-382`), which equal the column names in both migrations and the committed `db/schema.rb` hunks. All 8 × 6 hops name-identical.

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
