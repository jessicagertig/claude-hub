# Impl round 1 — sso-session-ride

Reviewed: committed diff + `GoogleSSOButton.tsx`, `config/initializers/omniauth.rb`, `omniauth_callbacks_controller.rb`, `user.rb:375-424`, both SSO spec files read whole in committed state.

## End-to-end ride, all eight

1. **Hidden inputs** (`GoogleSSOButton.tsx:95-118`): eight inputs, snake_case names (`ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie`), all plain single-value (nothing uses the `utm_data[<key>]` nested form), each behind the exact existing guard `typeof x === "string" && x.length > 0`, placed after `adroll_click_id` and before the `utmData` map. Props interface (`:18-25`) and destructure (`:38-45`) extended with the eight optional strings; `darkModeAllowed` untouched.
2. **Setup lambda** (`omniauth.rb:14-15`): `allowed_keys` gains the eight snake_case keys, exactly the SPEC §6.5 `%w[...]` shape. The loop (`value if value && !value.empty?` → `session[:oauth_tracking]`) untouched. The `ga_session_id` value (contains `=`, `;`, spaces) arrives as a percent-encoded form value and rides as a plain non-empty string — intact (Rack parses POST bodies on `&` only; verified during spec review).
3. **Callback** (`omniauth_callbacks_controller.rb:31-38`): eight string-key `merged_tracking['<key>']` reads added after `adroll_click_id`, passed as keywords. Nothing else in the action changed.
4. **Model** (`user.rb:379-382`): 16-keyword signature, per-keyword form per §13 decision 4; eight nil-defaulted keywords. Assignments (`user.rb:397-404`) inside the `first_or_create` block only, after `adroll_click_id`, before `sign_on_provider = 'google'`. Post-block behavior (`new_user_created_via_google_sso`, `assign_attributes(remember_me: true)`, names `update`, `enqueue_complete_user_setup`) byte-identical.

## Call-site check (SPEC §6.6 mandatory grep)

`git grep -ln "from_omniauth"` returns exactly four files: `app/models/user.rb` (definition), `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` (sole app call site — extended), `spec/models/user_from_omniauth_spec.rb` (extended), `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb` (both exhaustive `have_received(:from_omniauth).with(...)` expectations extended with the eight keywords, including the no-tracking example's eight nils and its renamed example string `'passes nil for all thirteen attribution values...'`). No site missed.

## Spec-file infrastructure (pipeline failure patterns 30/31)

- `omniauth_callbacks_controller_spec.rb`: `include Devise::Test::ControllerHelpers` (`:15`) AND `@request.env['devise.mapping'] = Devise.mappings[:api_v1_user]` (`:35`) retained; queue-adapter `around` block (`:17-22`) retained. The expectations were NOT loosened to `hash_including` ✓.
- All examples green (part of the 20/20 run).

## Session-cookie ceiling (§14.1)

Up to 8 more ≤1024-unit values in `session[:oauth_tracking]` — the accepted risk, implemented exactly as specced (no mitigation added, none removed). The implementation does not worsen the spec's own analysis. Note-only per the angle definition; not filed.

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
