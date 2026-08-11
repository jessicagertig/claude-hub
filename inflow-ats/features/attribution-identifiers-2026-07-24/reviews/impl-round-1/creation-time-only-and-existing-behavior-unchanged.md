# Impl round 1 — creation-time-only-and-existing-behavior-unchanged

## Creation-time only (§8.3)

Write moments for the eight, exhaustively (grepped every new column name across `app/`):
- `users`: `magic_create` `user_params` merge — present in BOTH branches of the conditional (`registrations_controller.rb:102-109` and `:124-131`); password `#create` via `build_resource(expanded_params)` (permit only, no extra code — §6.3 ✓); SSO via `from_omniauth` assignments inside the `first_or_create` block only (`user.rb:397-404`).
- `organizations`: `#create` copy block only (`organizations_controller.rb:37-44`).
- NO other write moment exists: no update path, no login-time backfill, no callback, no job. The existing-user `magic_create` branches read only `user_params[:email]` (`:135`) and remain inert; existing SSO users are untouched (assignments are inside the create block). No response-shape change in any action.
- Pinned by tests: existing-user magic_create contexts (both), from_omniauth `'does not assign attribution values to an existing user'` with `'ShouldNotStick'` values — all green.

## Existing behavior unchanged (§8.7)

- `utm_source`/`utm_campaign`/`internal_ref`/`adct` guards and calls in `sanitizeTrackingParams` byte-identical; they call `sanitizeTrackingValue` with no second argument → 255 default. The only textual change to `sanitizeTrackingValue` is the parameter and the removal of the `// truncate to 255` inline comment (behavior identical).
- `utm_data` occurrence-order logic (`keysInOccurrenceOrder`, `UTM_DATA_MAX_KEYS`, `utmDataKeys` derivation) untouched — the new field blocks sit between the `adct` block and the `utmDataKeys` derivation without altering either.
- `adroll_click_id` untouched at every layer.
- No serializer exposes any attribution column: grep of `app/serializers/` for all eight names returns nothing.
- No policy, route, job, context, `api.ts`, or `structure.js` change (diff file list is exactly the 18 planned files). `heard_about_us_from` remains a user-entered org-form field.

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
