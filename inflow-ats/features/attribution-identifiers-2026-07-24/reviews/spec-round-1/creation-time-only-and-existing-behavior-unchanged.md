# spec-round-1 — creation-time-only-and-existing-behavior-unchanged

Reviewed against live source, branch `attribution-work-qa` tip `b4cb4463a`.

## Verification record

- **magic_create conditional** — `registrations_controller.rb:88-117`, exactly two branches, both build `user_params`; existing merges `utm_source`…`adroll_click_id` at 97-101 (connect branch) and 111-115 (default branch). Spec §6.2's "BOTH branches of the two-branch conditional (lines 88-117)" is accurate.
- **Existing-user branches inert** — confirmed branch (121-147) reads `user_params[:email]` at 128 only; unconfirmed branch (148-159) reads nothing from `user_params`. Only the `else` branch creates a row (`build_resource(user_params)` at 168). Adding eight keys to the merge cannot touch existing users. Responses are static JSON hashes (139-147, 159, 197-201) — no response-shape effect.
- **Password path** — `expanded_params = sign_up_params.merge(...)` at 13 → `build_resource(expanded_params)` at 20. §6.3 "no change beyond the permit" is correct.
- **from_omniauth** — `user.rb:379` currently has exactly the 8 keywords the spec's proposed 16-keyword signature extends (same order); all attribution assignment inside the `first_or_create` block (385-398); post-block writes only `remember_me`, `first_name`, `last_name` (404-408). Existing SSO users cannot receive the new columns. §6.6 accurate.
- **Org copy block** — `organizations_controller.rb:31-36` (`created_via` at 31, `utm_source`…`adroll_click_id` at 32-36). §6.4's extension point accurate. No other write moment for attribution columns in the controller: `#update` flows `organization_params` (line 120 permits `:google_click_id, :adroll_first_party_cookie` today — the two the spec removes; after removal `#update` stops accepting them, as §6.4 states).
- **Existing capture behavior** — `utils.js:28` `TRACKING_VALUE_MAX_LENGTH = 255` and per-field guards at 59-70; spec directs no change to existing fields, occurrence-order `utm_data` logic (45-88), or `adct`.
- **Serializers** — no `users`/`organizations` attribution column is exposed by any Api::V1 serializer today. The only grep hits for `utm_source`/`utm_campaign` in `app/serializers/` are `ahoy_visit_serializer.rb:14,18`, which serialize `Ahoy::Visit` (`ahoy_visits` table) — a different model, not affected. §8.5 holds.
- **Jobs/services/interactors** — zero references to any attribution column.

## Findings

No issues found.

Notes (not findings):
- N1 — `Api::V1::AhoyVisitSerializer` exposes `utm_source`/`utm_campaign` of `Ahoy::Visit`, not of users/organizations. Recorded to preempt a false positive against §8.5.
- N2 (out of this angle's scope, for the source-accuracy angle) — `git grep -l from_omniauth` returns 4 files (adds `spec/models/user_from_omniauth_spec.rb`, `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`), vs §6.6's "sole call site" claim.

## Amendments Applied

None — orchestrator applies amendments. None recommended from this angle.
