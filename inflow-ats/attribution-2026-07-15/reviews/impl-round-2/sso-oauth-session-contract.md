# sso-oauth-session-contract — Round 2

Re-derived fresh across the full SSO branch.

## Verified

- **Hidden inputs (`GoogleSSOButton.tsx`):** `Props` gains `utmSource?`/`utmCampaign?`/`utmData?: Record<string, any>`/`internalRef?`. Scalars render with the exact analog guard `typeof x === "string" && x.length > 0`; `utm_data` renders one input per key with Rails-nested `name={"utm_data[" + key + "]"}`, per-key guarded by the same analog guard (null/"" values skipped — spec §5.3's stated consequence), outer guard `utmData != undefined` (house form). snake_case names written directly — correct, the plain form POST bypasses `allKeysToSnake`.
- **Props from `AuthForm.tsx`:** the four passed alongside `referral`/`partner` at the `GoogleSSOButton` callsite. `AuthForm` is `GoogleSSOButton`'s only consumer (grep) — new optional props break nothing.
- **Setup lambda (`config/initializers/omniauth.rb`):** exactly one line changed — `allowed_keys = %w[partner referral utm_source utm_campaign utm_data internal_ref]`. The existing loop's `value && !value.empty?` handles the `utm_data` Hash (Hash responds to `empty?`); `cookies_serializer.rb` is `:json`, so the nested hash round-trips the session cookie with string keys.
- **Callback (`omniauth_callbacks_controller.rb`):** the sole change is the keyword `User.from_omniauth(auth:, created_via:, partner_source:, utm_source: merged_tracking['utm_source'], ...)` — string-key reads from `merged_tracking = request_phase_params.merge(tracking_from_session)` (session wins, pre-existing). PosthogIdentifyJob/PosthogTrackJob calls and redirect untouched.
- **`User.from_omniauth`:** signature matches D9's exact order — `auth:, created_via:, partner_source: nil, utm_source: nil, utm_campaign: nil, utm_data: nil, internal_ref: nil`. The four assignments sit inside the `first_or_create` block alongside `created_via`/`partner_source&.downcase`, raw (no downcase). Post-block behavior (`assign_attributes(remember_me: true)`, `update(first_name:, last_name:)`, `enqueue_complete_user_setup`) byte-identical.
- **Call-site census re-run at review time:** `git grep -ln from_omniauth` → `app/models/user.rb` (definition), `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` (sole production call site, keyword form), plus the two new spec files (both keyword form). Zero positional callers remain.
- **Specs:** `user_from_omniauth_spec.rb` pins the keyword interface (ArgumentError on missing `auth:`/`created_via:`), raw storage, `partner_source` downcasing preserved, existing-user non-assignment (`not_to change(User, :count)` + nil columns). `omniauth_callbacks_controller_spec.rb` pins the keyword call shape and string-key session recovery via `have_received(:from_omniauth).with(auth: anything, ..., utm_data: { 'utm_medium' => 'cpc' }, ...)` — a positional-call regression fails the kwargs match on Ruby 3. All pass.
- Accepted-risk items (cookie overflow on direct un-sanitized POST to the request path — spec Risk 2) not re-litigated per REVIEW-ANGLES.

## Findings

No issues found.
