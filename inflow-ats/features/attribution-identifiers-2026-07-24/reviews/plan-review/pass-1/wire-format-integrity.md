# Plan review pass 1 — wire-format-integrity

Reviewed: plan.md T8 (esp. T8c), T7c, T10, T14, T1/T2, §5.1 rows 11-13 against SPEC §5.6/§6.1/§14.5 and live code @ `b4cb4463a`.

## Fact checks performed (all verified live)

- All eight lodash `snakeCase` transforms re-executed against the repo's installed lodash (node, `require('lodash/snakeCase')`): `gaClientId→ga_client_id`, `gaSessionId→ga_session_id`, `fbclid→fbclid`, `fbp→fbp`, `fbc→fbc`, `liFatId→li_fat_id`, `googleClickId→google_click_id`, `adrollFirstPartyCookie→adroll_first_party_cookie`. T8c's list is correct in full.
- `api.ts:52` — `data: skipKeysToSnake ? variables : allKeysToSnake(variables)` confirmed; `structure.js:94-108` — `snakeCase(key)` applied to keys only, values passed through (`allKeysToSnake(object[key], ...)` recursion), so the `=`/`;`-laden `ga_session_id` string value arrives byte-exact. The jsonb-rejection rationale (recursion into nested objects) is visible at :104.
- `useSession.ts` anchors exact: `register` destructure `adrollClickId` :38, variables :53; `magicLink` destructure :71, inline type `adrollClickId?: string | null` :85, variables :111.
- Name-identity chain: T7c hidden-input names = T14 `allowed_keys` additions = T10 permit symbols = T1/T2 column names = the eight snake_case wire names (compared list-to-list across the plan; all four sets identical: `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie`).
- `sign_up_params` permit at `registrations_controller.rb:312` currently ends `:adroll_click_id, utm_data: {}` — T10 keeps `utm_data: {}` trailing, per SPEC §6.1.
- No object/jsonb shape anywhere in the plan for `ga_session_id` (T4c single raw string; T7c plain input; T10 plain symbol permit) — decision 3 respected at every hop.

## Findings

None. 0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.
