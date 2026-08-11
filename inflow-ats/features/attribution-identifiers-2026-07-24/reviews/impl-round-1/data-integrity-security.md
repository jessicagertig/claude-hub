# Impl round 1 — data-integrity-security

- **Permit narrowing is actually effective:** verified live — `organization_params` (`organizations_controller.rb:128`) no longer contains `:google_click_id`/`:adroll_first_party_cookie`; unpermitted keys are silently dropped by strong params, and the copy lines then assign from `current_user`, so request-body values cannot land on either `#create` or `#update`. Pinned by the green inverted spec example.
- **New mass-assignment surface:** `sign_up_params` gains eight plain string permits on an unauthenticated signup endpoint — identical in kind to the existing `utm_*`/`adroll_click_id` permits (the analog's approved surface). The columns are inert tracking strings: no validation, no callback, no serializer exposure (grep of `app/serializers/` clean), no policy read. A hostile caller can at worst store arbitrary strings on their own new row — same as today for `utm_source`. No privilege or data-exposure change.
- **Org copy source:** values come exclusively from `current_user`, never from `params` (`organizations_controller.rb:37-44`) — the copy runs before `authorize @organization` like every existing copy line (analog placement).
- **Session cookie ride:** eight more values in `session[:oauth_tracking]` (signed/encrypted cookie store) — contents are client-originated tracking strings the client already knows; no sensitive data added. Overflow risk is the accepted §14.1 note.
- **No server-side cap:** direct API callers bypass the frontend 1024 cap; Postgres `character varying` is unlimited — the accepted §14.2 design, consistent with the analog (no server-side sanitization for `utm_*` either). Not flagged per spec.
- **Logging:** the pre-existing `Rails.logger.info("[SSO][request_phase] tracking=...")` line now includes the new identifiers — same class of data (ad-click identifiers) it already logged; mechanism unchanged.
- **SQL/XSS surface:** values flow through ActiveRecord parameterized assignment only; nothing renders them (no serializer/view exposure).

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
