# Plan review pass 1 — sso-session-ride

Reviewed: plan.md T5b, T7, T14, T15, T16/T16a, T18, T19, §5.1 rows 10/16/17/18 against SPEC §5.5/§6.5/§6.6/§6.7/§10.2-10.3 and live code @ `b4cb4463a`.

## Fact checks performed (all verified live)

- `GoogleSSOButton.tsx`: `Props` with `adrollClickId?: string` at :17, destructure at :29, hidden inputs `utm_source` :67-69 / `internal_ref` :73-75 / `adroll_click_id` :76-78, guard form `typeof x === "string" && x.length > 0` — T7a/T7b/T7c anchors exact. Insertion after :78 lands before the `utm_data[<key>]` nested block (:79-85); all eight new inputs are plain single-value per SPEC §5.5.
- `config/initializers/omniauth.rb`: `allowed_keys` at :14 exactly `%w[partner referral utm_source utm_campaign utm_data internal_ref adroll_click_id]`; loop :17-20 with `value if value && !value.empty?` (:19); session write :22-24 — T14's extension matches SPEC §6.5 verbatim.
- `omniauth_callbacks_controller.rb`: `User.from_omniauth` call at :22, string-key `merged_tracking` reads :26-30 ending `adroll_click_id: merged_tracking['adroll_click_id']` (:30) — T16's insertion point exact.
- `user.rb`: `from_omniauth` signature at :379 (currently single-line, 8 keywords); `first_or_create` block :385-398; assignments `utm_source` :389 … `adroll_click_id` :393, then `sign_on_provider = 'google'` :394 — T15's insertion (after :393, before sign_on_provider) exact. Post-block behavior (:400 `new_user_created_via_google_sso`, :404 `assign_attributes(remember_me: true)`, :405-408 names `update`, :410 `enqueue_complete_user_setup`) untouched by the plan.
- `git grep -ln "from_omniauth"` → exactly the 4 files T16a lists: `user.rb`, `omniauth_callbacks_controller.rb`, `spec/models/user_from_omniauth_spec.rb`, `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`.
- `omniauth_callbacks_controller_spec.rb`: session seed :44-52, exhaustive `have_received(:from_omniauth).with(...)` :56-65, no-tracking example `'passes nil for all five attribution values when no tracking rode the session'` :69-83 with exhaustive nil keywords :72-81 — T19's line refs and the "fails at dispatch without extension" claim verified (both expectations are exact keyword matches, no `hash_including`). `Devise::Test::ControllerHelpers` (:15), `devise.mapping` (:35), queue-adapter `around` (:17-22) present — T19 correctly preserves all three (failure patterns 30/31).
- `user_from_omniauth_spec.rb`: raw-storage :25-44, omitted-keywords :46-55, existing-user :57-84, header :5-9 — T18 refs exact.
- `ga_session_id` riding the form: the setup lambda's `value && !value.empty?` guard passes any non-empty string; the `=`/`;`-laden value is a plain form value (spec-review round already verified Rack parses POST bodies on `&` only). Plan adds nothing that worsens the §14.1 ~4KB cookie ceiling beyond the accepted risk (plan risk 1, "Do not add mitigation").

## Findings

None. 0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.
