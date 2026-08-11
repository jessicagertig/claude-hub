# Params Threading Contract (three signup paths × four values) — Pass 1

## Fact Check

| Claim (plan) | Verified against | Result |
|---|---|---|
| `sign_up_params` at lines 300–303, permit at line 302; current permit list exact | `app/controllers/api/v1/registrations_controller.rb:300-303` | ✓ exact, including the commented-out line 301 the plan preserves |
| `magic_create` `user_params` two-branch conditional at lines 88–107 | live file | ✓ exact — plan's B3.2 block reproduces the current code byte-for-byte (incl. the `# Used to determine where to redirect a customer` comment) plus the four new keys in BOTH branches |
| Existing-user branches read only `user_params[:email]` (line 109) | line 109 `user = User.find_by(email: user_params[:email])` | ✓ — added keys inert in the two existing-user branches; row creation only at `build_resource(user_params)` line 158 |
| `create` builds `expanded_params = sign_up_params.merge(created_via:, partner_source:)` at lines 13–16 | live file | ✓ exact — B3.3 "no change beyond the permit" holds |
| `questions_controller.rb:50` `options: {}` trailing hash-permit analog | live file line 50 | ✓ exact |
| `allKeysToSnake` at `structure.js:94-105`, lodash `snakeCase` per key, recurses into nested objects | `app/javascript/ats/src/lib/utils/structure.js:94+` | ✓ (`newObject[snakeCase(key)] = allKeysToSnake(object[key], ...)`) |
| `apiPost` runs `allKeysToSnake` | `app/javascript/shared/queryHooks/api.ts` `apiMutate` line ~52: `data: skipKeysToSnake ? variables : allKeysToSnake(variables)` | ✓ |
| Absent fields drop out of the JSON body | axios `JSON.stringify` omits `undefined`-valued keys; `allKeysToSnake` maps `undefined` → `undefined` (non-plain-object passthrough) | ✓ — wire param never arrives → `sign_up_params[<key>]` nil → column nil |
| `useSession.ts` `magicLink` lines 41–82 (destructure + inline TS type + variables); `register` lines 27–39 (no inline type today) | live file | ✓ exact — F2.2's "do not add one" matches the file |
| Hook wrappers `useMagicLink`/`useRegister` at lines 141–166 unchanged | live file (141–152, 154–166) | ✓ |
| `ActionController::Parameters` → jsonb assignment serializes as plain hash; `as_json` delegated to `@parameters` at actionpack 6.1.7.7 `strong_parameters.rb:247` | installed gem: `delegate :keys, ..., :as_json, :to_s, :each_key, to: :@parameters` at ~line 246–247; Gemfile.lock actionpack (6.1.7.7) | ✓ |
| C.1: no `utm_*` columns on `users`/`organizations`; only `ahoy_visits` has them; `settings` jsonb is `default: {}, null: false` on both tables | `db/schema.rb` — `ahoy_visits` (line 89) carries utm_source/medium/term/content/campaign (104–108); users table (1244+) and organizations table (1033+) have `t.jsonb "settings", default: {}, null: false` and zero `utm_*` columns | ✓ re-verified |
| Unpermitted request params are ignored (server params tolerance) | `action_on_unpermitted_parameters` not overridden anywhere in `config/` → Rails 6.1 default `:log` in test/dev, false otherwise | ✓ |
| Route claims: `POST /sign_up` → registrations#create, `POST /magic_login` → registrations#magic_create under `devise_scope :api_v1_user` | `config/routes.rb` (~81–82) | ✓ |

## Completeness (spec §4.1–§4.3, §5, D2/D3/D10)

- Permit: 3 scalars + trailing `utm_data: {}` — B3.1 ✓ (trailing-argument requirement stated)
- `magic_create` merge in BOTH branches — B3.2 ✓
- Raw storage, no downcase/mapping — B3.2 facts ✓ (approved deviation 1 from analog)
- Nil-for-absent at every hop — B3.2 + frontend preamble ✓
- `magic_create` JSON responses byte-identical — B3.2 ✓ (also in Do-NOT-touch list)
- `create` path automatic via `expanded_params` — B3.3 ✓ (verify-by-reading, not editing)
- camelCase payload fields / snake_case wire — frontend preamble ✓; `utm_data` inner keys raw (approved deviation 4) ✓
- Payload additions in AuthForm (F3.3) and SignupForm (F4.3), request-function additions (F2.1/F2.2) ✓

## Findings

No issues found.

## Amendments Applied

None required for this angle.
