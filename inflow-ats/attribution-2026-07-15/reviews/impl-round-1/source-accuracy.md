# source-accuracy (always-on check) — Round 1

Every file path, class, method, column, route, and component the spec references was checked against the committed tree:

- Controllers: `Api::V1::RegistrationsController` (`sign_up_params` now at 307-310; `magic_create` user_params conditional at 88-115; `create` expanded_params at 13-16), `Api::V1::OrganizationsController#create` (copy lines after `created_via` at 31), `Api::V1::Users::OmniauthCallbacksController#google_oauth2` (keyword call at 22-30), `Hire::ConfirmationsController#show` (redirects at 18/21) — all exist as described.
- Model: `User.from_omniauth` at `user.rb:379`; `first_or_create` block at 385-397; post-block at 399-409. ✓
- Initializers: `config/initializers/omniauth.rb` setup lambda `allowed_keys` at line 14; `config/initializers/cookies_serializer.rb` `:json`. ✓
- Frontend: `AuthForm.tsx` (referral/partner state at 39-40, capture at 41, SSO props at 128, onSuccess at 89-93), `SignupForm.tsx` (referral at 25, capture at 26, event at 75), `GoogleSSOButton.tsx` (inputs after partner at 62+), `Auth.tsx` (mount effect 19-21, new effect 23-31, banner fn 33-40), `OrganizationForm.tsx:71`, `ProfileForm.tsx:67-71`, `useSession.ts` (`register` 27-53, `magicLink` 56-109), `utils.js` helper at 22-87, `posthog.ts` helpers (identifyUser keys on `String(user.id)` at line 32). ✓
- Render sites: `Auth.tsx:83` and `AuthRegister.tsx:134-139` pass `location={props.location}` to `AuthForm`; `Signup.tsx:25` spreads route props to `SignupForm`; `OnboardingProfile.tsx` passes `isNewOwner`/`wasInvited` (untouched). ✓
- Library claims: query-string v6.1.0 installed; `parse` ends in `Object.keys(ret).sort().reduce(...)` (index.js:157); `extract` returns `''` when no `?`; `+`→space precedes the `=` split in parse — all spec §5.1 claims exact against the installed source. ✓
- Schema: the four columns present on both tables in `db/schema.rb` with no options; only other `utm_*` columns are on `ahoy_visits` (untouched). ✓

## Findings

No issues found.
