# Impl round 1 — test-coverage (calibrated: Cypress top, other RSpec deprioritized)

## Executed

`bundle exec rspec` on the four extended files: **20 examples, 0 failures** (registrations, user_from_omniauth, omniauth_callbacks, organizations).

## Cypress (top priority)

`cypress/e2e/auth/registration.cy.js` untouched (read-only rule ✓). Read whole (72 lines): asserts navigation/visible text only; no payload-shape, cookie, or network-intercept assertions — the eight payload additions and hidden inputs cannot break it. Runs pre-commit; the commit exists, so the hook ran on it.

## Extended RSpec vs SPEC §10 — correctness check (WRONG tests / ghost tests / stub mismatches)

1. **registrations_controller_spec.rb:** eight params → raw persistence (incl. the `=`/`.`/`;` `ga_session_id` and the 302-char fbclid pinning no server-side truncation); all-nil; both existing-user contexts inert; password `#create` both ways; `login_intent: 'hire'` kept on every magic_create POST; header comment updated to thirteen. All assertions falsifiable: pre-feature, the columns don't exist / the merge keys are absent, so the raw-persistence examples error or fail.
2. **user_from_omniauth_spec.rb:** eight keywords raw; omitted → nil; existing user `'ShouldNotStick'` × 8 not assigned; header updated. Falsifiable: without the T15 assignments the raw example fails; without the keywords the calls raise `ArgumentError (unknown keyword)`.
3. **omniauth_callbacks_controller_spec.rb:** session seeded with the eight string keys; BOTH exhaustive `.with(...)` expectations extended (values + the eight nils); example renamed. `.with` argument types match production exactly (strings from `merged_tracking`, nil defaults absent). Not loosened to `hash_including` ✓. Falsifiable: without T16 the `.with` keyword match fails.
4. **organizations_controller_spec.rb:** thirteen-value copy; thirteen-nil; the inverted request-body example; header rewrite. The inversion fails against pre-feature code (body value landed then) — not a ghost test. LOW nuance (filed under collection-point-move): it cannot distinguish "permit removed" from "permit present but copy overwrites"; the permit-only observable (`#update`) is untested — missing coverage, never HIGH/MED per profile.

## Stubs masking type mismatches

The only stubbed boundary is `User.from_omniauth` in the callbacks spec; its `.with` keyword expectations mirror the production call site argument-for-argument. No external-API stub exists in scope. No mismatch.

## Findings

None here (the one LOW lives in collection-point-move). 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
