# full-stack-analog-completeness (always-on check) — Round 1

The `referral`/`partner` analog threads through THREE transports; every analog layer was checked for a corresponding piece for the four new values:

| Analog layer | New-feature piece | Present |
|---|---|---|
| Capture into component state (`AuthForm.tsx:39-40`, `SignupForm.tsx:25`) | `trackingParams` state at `AuthForm.tsx:41`, `SignupForm.tsx:26` | ✓ |
| Magic-link mutation payload (`handleAuth` → `magicLink`) | four camelCase fields in the `magicLink({...})` variables | ✓ |
| Password mutation payload (`handleSignup` → `register`) | four fields in the `register({...})` variables | ✓ |
| Request-function threading (`useSession.ts` destructure/type/variables) | both functions extended | ✓ |
| Permit (`sign_up_params`) | three scalars + `utm_data: {}` | ✓ |
| Controller assignment (`magic_create` both branches; `create` via `expanded_params`) | four keys merged both branches; create inherits via permit | ✓ |
| SSO hidden inputs (`GoogleSSOButton.tsx` guard pattern) | three scalar inputs + per-key `utm_data[<key>]` inputs | ✓ |
| Setup-lambda whitelist (`omniauth.rb:14`) | four keys appended to `allowed_keys` | ✓ |
| Session recovery (`merged_tracking` string keys) | four `merged_tracking['...']` reads at the call site | ✓ |
| `from_omniauth` creation-time assignment (`first_or_create` block) | four assignments inside the block only | ✓ |
| Org copy at creation (`organizations_controller.rb` `created_via` copy) | four copy lines adjacent to the analog line | ✓ |
| Persistence layer (columns) | both migrations + schema | ✓ |

No missing layer. The PostHog-event layer (browser `trackEvent`/`identifyUser` analogs `NewJobCenterModal.tsx`/`CommentTemplateModal.tsx`/`AppAuthRouter.tsx`) is likewise complete for all five events + the identify.

## Findings

No issues found.
