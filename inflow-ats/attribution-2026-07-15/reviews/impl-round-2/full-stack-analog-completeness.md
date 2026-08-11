# full-stack-analog-completeness — Round 2 (always-on check)

The `referral`/`partner` analog pipeline enumerated in REVIEW-ANGLES.md, layer by layer, against the new four values — all three transports:

| analog layer | new-feature counterpart | present |
|---|---|---|
| Capture state (`AuthForm.tsx:37-38`, `SignupForm.tsx:23`) | `trackingParams` useState in both | YES |
| Magic-link mutation payload | four fields in `handleAuth` `magicLink` call | YES |
| Password mutation payload | four fields in `SignupForm` `register` call | YES |
| Request-function threading (`useSession.ts`) | destructure + type + variables (magicLink); destructure + variables (register) | YES |
| `allKeysToSnake` wire transform | camelCase → snake_case, recursion into `utmData` verified | YES (existing mechanism) |
| Permit (`sign_up_params`) | three scalars + trailing `utm_data: {}` | YES |
| Controller assignment — `magic_create` | merged into `user_params` in BOTH branches | YES |
| Controller assignment — `create` | via `expanded_params`/`build_resource` (permit-only, per spec) | YES |
| SSO hidden inputs (`GoogleSSOButton.tsx:46-51` analog) | four inputs incl. per-key Rails-nested `utm_data[<key>]` | YES |
| Setup-lambda whitelist (`omniauth.rb:14`) | `allowed_keys` grown by the four keys | YES |
| Session ride + recovery (`oauth_tracking`, `merged_tracking`) | string-key reads in the callback | YES |
| `from_omniauth` creation-block assignment | four assignments inside `first_or_create` | YES |
| Org copy at creation (`organizations_controller.rb:31` analog) | four `current_user` copies alongside `created_via` | YES |
| Persistence layer | users + organizations migrations, schema.rb | YES |
| Test layer (analog had none — new coverage required) | 5 RSpec files + 1 Jest file, all passing | YES |

No layer missing on any of the three transports.

## Findings

No issues found.
