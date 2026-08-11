# sso-oauth-session-contract — Round 1

Verified against live source: `GoogleSSOButton.tsx` (Props lines 9–14; hidden inputs lines 45–51 with guard `typeof referral === "string" && referral.length > 0`; plain form POST to `/api/v1/users/auth/google_oauth2` — bypasses `allKeysToSnake`, snake_case names written directly), `config/initializers/omniauth.rb` (setup lambda lines 12–27; `allowed_keys = %w[partner referral]` at line 14; loop `value = rack_request.params[key]; tracking_params[key] = value if value && !value.empty?`; **session write guarded by `if tracking_params.any?`** — so the lambda's re-run on the callback phase, where no utm params exist, does not clobber the session), `config/initializers/cookies_serializer.rb` (`:json` — hash round-trips with string keys), `omniauth_callbacks_controller.rb` (lines 9–22: `session.delete(:oauth_tracking) || {}`, `merged_tracking = request_phase_params.merge(tracking_from_session)`, sole call `User.from_omniauth(oauth_data, created_via_value, partner_param)` at line 22), `user.rb` line 379 (`def self.from_omniauth(auth, created_via, partner_source = nil)`; `first_or_create` block assigns `created_via`, `partner_source&.downcase`, `sign_on_provider`, `skip_confirmation!`; post-block `assign_attributes(remember_me: true)` / `update(first_name:, last_name:)` / `enqueue_complete_user_setup` — spec §4.6 post-block claim accurate), `git grep -ln from_omniauth` → exactly `app/models/user.rb` + `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` (spec's two-file claim re-verified today).

## Findings

- F1 [MED] SPEC.md §5.3 `utm_data` hidden inputs: "rendered only for keys present in `utmData`" left the per-key guard unspecified. A key whose value is `null` (`?utm_medium` with no `=`) survives sanitization by design and would render `<input value={null}>` — a React controlled-input warning — or an empty `utm_data[utm_medium]=` that the setup lambda would keep (the Hash is non-empty) and persist as `""`, fabricating a value the JSON path stores as `null`. The analog guards every hidden input with `typeof x === "string" && x.length > 0`; the new per-key inputs must do the same (analog structural matching). / Fix applied: §5.3 now specifies the analog guard per key, with the accepted degenerate-value divergence stated.
- F2 [LOW] `utm_data` arriving as a scalar on a direct crafted POST to the request path (e.g. `utm_data=xyz`) rides the session as a String and persists as a JSON string, not an object. Raw-as-sent semantics; no guard exists for `partner`/`referral` shape either. No amendment.

## Verified-clean / not re-litigated

- Rack parses `utm_data[<key>]=v` nested naming into a Hash; `Hash` responds to `empty?` — the existing lambda loop handles all four new keys without modification. Spec §4.5's "only line 14 changes" holds.
- Keyword signature order in §4.6 matches D9 verbatim; required/optional split correct; assignment strictly inside `first_or_create` (existing SSO users untouched) matches the analog's creation-time-only structure.
- Call-site conversion mandate (§4.6) re-verified: one call site today; the spec correctly orders a re-search at implementation time.
- Cookie-overflow on unsanitized direct POST: spec Risk 2 — accepted property of the approved design (not re-flagged, per REVIEW-ANGLES).
- Approved deviations respected: raw storage (no `&.downcase` on the four), keyword conversion, `utm_data` inner keys verbatim.

## Amendments Applied

- SPEC.md §5.3 `utm_data` bullet: per-key render guard `typeof value === "string" && value.length > 0` + stated JSON/SSO divergence for degenerate values.
