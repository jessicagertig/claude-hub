# Spec Review — Round 1 Verdict
**Date:** 2026-07-15 23:55

## Counts
- BLOCKER: 1 (posthog-events-and-identity F1 — §5.6 effect-ordering makes the D12 identify/event a silent no-op; resolved by spec amendment, no redesign required)
- HIGH: 1 (frontend-capture-and-sanitization F1 — query-string v6.1.0 parse sorts keys alphabetically; §5.1 input contract could not satisfy D4's occurrence-order rule)
- MED: 4
  - posthog-events-and-identity F2 — email_verified guard scope (stale bookmark → anonymous event)
  - test-coverage-and-ghost-tests F1 — Devise::Test::ControllerHelpers required for warden in the two Devise-controller specs
  - test-coverage-and-ghost-tests F2 — magic_create specs must send login_intent: 'hire' (pre-existing `organization.id`-on-nil crash branch)
  - sso-oauth-session-contract F1 — utm_data per-key hidden-input render guard unspecified
- LOW: 6 (case-sensitive utm_ prefix; literal ?utm_data param nests; utm_data-scalar direct POST; migrations.md index note; house != undefined guard reminder; NewJobCenterModal line drift)

## Amendments Applied
1. §5.6 rewritten: identify+track moved out of the mount effect into a `useEffect` keyed on the existing `emailConfirmed` state (fires after `posthog.init`); single both-params-present guard now covers BOTH `identifyUser` and `trackEvent("email_verified")`; timing mechanism documented.
2. §5.1 input contract: helper takes the raw `location.search` string; key order derived from the raw string, values from `queryString.parse` (library sort behavior cited); array-order fact recorded.
3. §5.2 and §5.5 capture bullets updated to pass `location.search` into the helper.
4. §9.6 Jest requirement: occurrence-order test must use non-alphabetical param order (anti-ghost).
5. §9.1: `include Devise::Test::ControllerHelpers` (precedent cited) + mandatory `login_intent: 'hire'` on every magic_create POST with do-not-fix note.
6. §9.3: `include Devise::Test::ControllerHelpers` for the omniauth callback spec.
7. §5.3: per-key `typeof value === "string" && value.length > 0` render guard for `utm_data` inputs + stated degenerate-value divergence.
8. §8 analog table: NewJobCenterModal.tsx line 47 → 46.

## Verdict: FAIL (findings found and amendments applied — loop continues)
