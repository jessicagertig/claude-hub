# source-accuracy — Round 2 (always-on check)

Every file path, class, method, column, route, and component the spec references was re-verified against the committed tree at `8dcc2f06f`:

- Controllers: `Api::V1::RegistrationsController` (`sign_up_params` now line 308–311; `magic_create` branches lines 88–116; `create` lines 10–22), `Api::V1::OrganizationsController#create`, `Api::V1::Users::OmniauthCallbacksController#google_oauth2`, `Hire::ConfirmationsController#show` — all present, all changed exactly where the spec says.
- Model: `User.from_omniauth` at `app/models/user.rb:379` with the D9 signature; assignments inside the `first_or_create` block.
- Initializers: `config/initializers/omniauth.rb` setup lambda line 14; `config/initializers/cookies_serializer.rb` `:json` (verified — underpins the string-key session claim).
- Frontend: `AuthForm.tsx`, `SignupForm.tsx`, `GoogleSSOButton.tsx`, `useSession.ts`, `Auth.tsx`, `OrganizationForm.tsx`, `ProfileForm.tsx`, `posthog.ts`, `utils.js` — all edits present; `AuthRegister.tsx:136` passes `location={props.location}` to `AuthForm` as claimed; `OnboardingProfile.tsx:16–17/47–48` computes and passes `isNewOwner`/`wasInvited` unchanged.
- Library claims: `query-string` v6.1.0 installed; its `parse` alphabetizes keys and `extract` slices after `?` — both spec §5.1 claims verified in `node_modules/query-string/index.js`.
- Migrations/schema: timestamps `20260715233505`/`06`; class names match; `db/schema.rb` version `2026_07_15_233506`.
- greps: `from_omniauth` census, `user_signed_up_client_side` census, server `user_signed_up` untouched — all match the spec's §9 reviewer checks.

## Findings

No issues found.
