# backward-compatibility — Round 2 (always-on check)

Consumers of every modified interface identified and verified:

- **`User.from_omniauth` (breaking signature change):** repo-wide census re-run — sole production call site (`omniauth_callbacks_controller.rb`) converted to keyword form in the same commit; the two new specs use keyword form. Zero positional callers remain; the model spec pins ArgumentError on missing required keywords.
- **`useSession.ts` `magicLink`/`register`:** consumers are `AuthForm.tsx` (`useMagicLink`) and `SignupForm.tsx` (`useRegister`) only — the `useRegisteredWebhooks.ts`/`AccountIntegrationsPolymerWebhooks.tsx` grep hits are substring false-positives on `useRegister`. New params are optional additions; both consumers updated anyway.
- **`GoogleSSOButton`:** sole consumer `AuthForm.tsx`; new props optional.
- **`sanitizeTrackingParams`:** new export; two consumers, both new. `standardizeQueryParamsObject` and every other `utils.js` export untouched (only an import line added above them).
- **`identifyUser`/`trackEvent` (`posthog.ts`):** signatures unchanged — only `window.logger` lines added; all pre-existing callers unaffected. Full `yarn jest` confirms nothing importing `utils.js`/`posthog.ts` broke (only the known FormCheckbox baseline fails).
- **`sign_up_params`:** permit-list extension only — existing readers (`create`, `magic_create`, `login_intent`/`organization_slug` reads) unaffected.
- **Confirmation redirect URL:** additive query params. The only consumer of the `email_confirmed=true` landing is `Auth.tsx` (`AuthRegister.tsx`/`Login.tsx` read the param but are not the redirect target and are unmodified); the banner path is untouched, the new effect is additive. `cypress/e2e/auth/registration.cy.js` asserts only `/needs-email-confirmation` and `/jobs` URLs — unaffected.
- **`session[:oauth_tracking]`:** existing `partner`/`referral` riders unchanged; new keys additive; the callback's `|| {}` default preserved.
- **DB:** additive nullable columns, no defaults — zero impact on existing rows or writers (verified no other code references the new column names outside the diff).

## Findings

No issues found.
