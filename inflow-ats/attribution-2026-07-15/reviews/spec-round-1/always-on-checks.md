# always-on checks — Round 1

## Source accuracy

Every file path, class, method, column, route, and line reference in SPEC.md was checked against the live tree (branch `attribution-work`, clean except the intentional `posthog.ts` diff). Verified exact: `registrations_controller.rb` 300–303/88–107/13–16, `organizations_controller.rb` 26–49 (copy at 31, authorize at 33), `omniauth_callbacks_controller.rb` 9–22, `user.rb:379`, `omniauth.rb:14`, `cookies_serializer.rb` (`:json`), `confirmations_controller.rb` 18/21, routes 81–82 (`/sign_up`, `/magic_login`), `questions_controller.rb:50`, `AuthForm.tsx` 37/38/78/82–84/120, `SignupForm.tsx` 23/66–69, `GoogleSSOButton.tsx` 45–51, `useSession.ts` 27–39/41–82, `Auth.tsx` 22–29/72, `AuthRegister.tsx` 134–136, `OrganizationForm.tsx` 68–71, `ProfileForm.tsx` 64–67, `OnboardingProfile.tsx` 16–17/47–48, `AppAuthRouter.tsx:168` (file lives at `app/javascript/ats/src/views/layouts/`), `structure.js:94`, `utils.js:9`, migration analog, schema shapes (`settings jsonb default {} null false` on both tables; no pre-existing utm columns on users/organizations — repo's only utm columns are `ahoy_visits`).

Corrections found: `NewJobCenterModal.tsx` trackEvent is at line 46, not 47 (spec §8 table fixed — cosmetic, folded into this FAIL round). The §5.1 input-contract inaccuracy and §5.6 mechanism flaw are reported under their angle files (HIGH F1, BLOCKER F1).

## Test coverage

No existing specs cover any touched backend surface (re-verified). New coverage requirements exist for every layer; two MED workability gaps found and amended (Devise::Test::ControllerHelpers; `login_intent: 'hire'`) — see test-coverage-and-ghost-tests.md.

## Backward compatibility

- `from_omniauth`: one caller, converted in-PR, repo-wide re-search mandated. New specs pin the keyword interface.
- `/auth` query params: no existing reader of `id`/`email` on /auth (checked `Auth.tsx`, `AuthForm.tsx`, `AuthRegister.tsx` — its `email` read is commented out, `Login.tsx`); banner logic keys on `email_confirmed` only. Cypress password path traverses the new redirect; `include`-based URL assertions unaffected; PostHog inert under `IS_TEST_ENV`; `window.logger` always defined (no-op outside dev).
- Unknown-param tolerance: old frontend / new backend and new frontend / old backend both degrade to nil columns (permit drops, absent params nil).
- `sign_up_params` widening does not change `magic_create` existing-user responses (branches read only email).
- Anonymization: none exists for users/organizations (only candidates) — the `created_via`/`partner_source` analog has no scrub path either; the new columns follow the analog.

## Full-stack analog completeness

All analog layers have a spec'd counterpart: capture state (§5.2/5.5), mutation payload (§5.2/5.5), request functions (§5.4), permit (§4.1), controller assignment (§4.2/4.3), SSO hidden inputs (§5.3), setup whitelist (§4.5), session recovery (§4.7), `from_omniauth` assignment (§4.6), org copy (§4.4). All three transports thread all four values. No missing layer.

## Analog structural matching

- Hidden-input render guards: matched after F5 amendment (per-key guard on `utm_data`).
- Session ride mechanics: identical to `partner`/`referral` (whitelist loop untouched; `tracking_params.any?` guard preserves callback-phase safety).
- `first_or_create`-block-only assignment: matches `created_via`/`partner_source` structure.
- Org copy shape: matches the adjacent `created_via` copy exactly (assignment before authorize/save, `organization_params` untouched).
- onSuccess event placement: matches `NewJobCenterModal.tsx:46` / `CommentTemplateModal.tsx:100` (before completion callback, plain call).
- Approved deviations (raw storage, keyword conversion, browser-side events, raw inner keys, no-default migrations) recognized and not reported as mismatches.
