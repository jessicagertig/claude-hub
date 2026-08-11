# SSO / OAuth Session Contract — Pass 1

## Fact Check

| Claim (plan) | Verified against | Result |
|---|---|---|
| `GoogleSSOButton.tsx` Props (lines 9–14: `isDisabled?`, `referral?`, `partner?`, `darkModeAllowed?`); destructured signature line 16 | live file | ✓ exact — F5.1's extended interface inserts the four before `darkModeAllowed`, preserving existing members |
| Hidden inputs at lines 46–51 with guard `typeof referral === "string" && referral.length > 0`; form `action="/api/v1/users/auth/google_oauth2" method="post"` | live file (comment at 45, inputs 46–51) | ✓ exact — F5.2 places new inputs after them with the identical guard, per-key for `utm_data` |
| `omniauth.rb` setup lambda lines 12–27; line 14 `allowed_keys = %w[partner referral]`; loop `value = rack_request.params[key]; tracking_params[key] = value if value && !value.empty?` | `config/initializers/omniauth.rb` | ✓ exact — B5.1 changes only line 14; `utm_data` arrives as a `Hash` from `utm_data[<key>]` inputs (Rack nested-param parsing) and `Hash#empty?` satisfies the guard |
| Cookie sessions use `:json` serializer (hash round-trips with string keys) | `config/initializers/cookies_serializer.rb` — `cookies_serializer = :json` | ✓ |
| Callback controller: `session.delete(:oauth_tracking) \|\| {}` line 9; `request_phase_params` line 14; `merged_tracking = request_phase_params.merge(tracking_from_session)` line 15 (string keys) | `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` | ✓ exact |
| Sole call site `User.from_omniauth(oauth_data, created_via_value, partner_param)` at line 22, positional today | live file line 22 | ✓ exact |
| `from_omniauth` definition at `user.rb:379`, signature `(auth, created_via, partner_source = nil)` | live file | ✓ exact |
| `first_or_create` block assigns `created_via`, `partner_source&.downcase`, `sign_on_provider`, `skip_confirmation!`; post-block `assign_attributes(remember_me: true)`, `update(first_name:, last_name:)`, `enqueue_complete_user_setup` | user.rb 385–406 | ✓ — B6.2's block matches the live structure; four new assignments slot after `partner_source`, before `sign_on_provider`; `ap` debug lines above the block acknowledged |
| C.5 census: `git grep -ln "from_omniauth"` returns exactly `app/models/user.rb` + the callbacks controller | re-ran live | ✓ re-verified (definition + one call site; no JS/TS references) |
| Keyword signature order (B6.1) matches D9 exactly | approved-decisions.md D9 | ✓ `auth:`, `created_via:` required; `partner_source:`, `utm_source:`, `utm_campaign:`, `utm_data:`, `internal_ref:` defaulting nil |
| B6.4 keyword call block matches spec §4.7 verbatim; nothing else in the action changes (Posthog jobs lines 26–28, redirect line 29) | live file + SPEC.md | ✓ |
| omniauth callback GET route exists (`get 'users/auth/google_oauth2/callback', to: 'users/omniauth_callbacks#google_oauth2'` in `devise_scope :api_v1_user`) | config/routes.rb ~127–129 | ✓ — T4's `get :google_oauth2` resolves |

## Completeness (spec §4.5–§4.7, §5.3, D7/D8/D9)

- Props + hidden inputs (render-only-when-present; `utm_data[<key>]` nested naming; snake_case names since plain form POST bypasses `allKeysToSnake`) — F5 ✓
- AuthForm passes four props to `GoogleSSOButton` (line 120) — F3.5 ✓ (live line 120 confirmed: `referral={referral} partner={partner} darkModeAllowed={darkModeAllowed}`)
- Whitelist growth, only line 14 — B5 ✓
- Session ride + string-key recovery — B6.4 ✓
- Keyword conversion + mandatory implementation-time census re-run with post-conversion re-grep — B6.1/B6.3 ✓ (Risk 1 names it highest-blast-radius)
- Assignment strictly inside `first_or_create`; existing SSO users untouched; post-block byte-identical — B6.2 ✓
- Accepted-risk (spec Risk 2, cookie overflow on direct unsanitized POST) not re-litigated — plan Risk 3 lists it as decision-bound ✓

## Findings

No issues found in the production-code tasks. (The T4 spec-skeleton gap that affects this angle's test file is filed under test-coverage-and-ghost-tests F1.)

## Amendments Applied

None required for this angle.
