# PostHog Events and Identity — Pass 1

## Fact Check

| Claim (plan) | Verified against | Result |
|---|---|---|
| `confirmations_controller.rb:18` success redirect `redirect_to '/auth?email_confirmed=true'`; line 21 failure; `OrgOwnerUpdateJob.perform_later` line 17 | live file | ✓ exact — B7.1/B7.2 correct; double-quoted interpolated replacement matches backend string-quoting rule |
| `/auth` server route → `Hire::PagesController#auth` with `before_action :redirect_if_authed` (Risk-7 boundary) | routes.rb:591; pages_controller.rb:24–31 | ✓ — plan F6.2's accepted-boundary note is accurate and marked do-NOT-redesign |
| `Auth.tsx` mount effect lines 18–20; `showEmailConfirmationBannerIfApplicable` lines 22–29; `emailConfirmed` state line 16; `queryString` already imported (line 4) | live file | ✓ exact — F6.1 correctly adds only the posthog import |
| `identifyUser` signature `id: number`, keys on `String(user.id)`; `trackEvent` → `ph.capture`; `getPosthog` null until `posthog.__loaded` | `app/javascript/shared/lib/posthog.ts` | ✓ — `Number(id)` satisfies the signature; distinct_id identical to `AppAuthRouter`'s |
| `AppAuthRouter.tsx` identify effect cited `:165-176` | live file — `const currentPlan` at 165, `React.useEffect` 166, deps close 177 | ✗ off-by-one: effect spans 166–177 — F3 [LOW], corrected to 165–177 |
| `useCreateOrganization` invalidates `currentOrganization` + `me` (`useOrganization.ts:87-102`) | live file 87–102 | ✓ exact (also `setQueryData("currentOrganization", data)`) |
| `OrganizationForm.tsx` `createOrganization` onSuccess lines 68–71; logger text `"[OrganizationForm] createOrganization onSuccess"`; destructured `onComplete(data)` | live file | ✓ exact |
| `ProfileForm.tsx` `updateMe` onSuccess lines 64–67; logger `"[ProfileForm] onSuccess"`; `props.isNewOwner` / `props.onComplete()` (props form, not destructured) | live file (props.isNewOwner used at line 44 already) | ✓ exact |
| `OnboardingProfile.tsx` computes `wasInvited`/`isNewOwner` at lines 16–17, passes at 47–48; not modified | live file | ✓ exact |
| `AuthForm.tsx` `magicLink` onSuccess lines 82–85 with logger `"[AuthForm] data"`; `SignupForm.tsx` onSuccess 66–69 with the `onScucess` typo preserved | live files | ✓ exact — F3.4/F4.4 blocks byte-match current code + one inserted `trackEvent` line |
| Event-name census (C.3): none of the five strings exists; only incidental `organization_created_via` (billing_controller ×3, organization.rb ×2) and the `email_verified:` comment at `smtp_email_validator.rb:113` | `git grep` live | ✓ re-verified |
| Analogs: `NewJobCenterModal.tsx:47` `trackEvent("job_created", ...)` in createJob onSuccess; `CommentTemplateModal.tsx:100` plain `trackEvent("review_template_created")` | live files | ✓ exact |
| posthog.ts working-tree diff = `window.logger` in `identifyUser` fire + skip paths ONLY; sole dirty file on the branch (C.6) | `git diff app/javascript/shared/lib/posthog.ts` + `git status --porcelain` | ✓ exact — F9.1's verify-and-commit-as-is is correct |
| Do-NOT-touch Posthog callsite census (registrations 51-52/181-182, omniauth 26-28, sessions/magic_links/invites controllers) | `git grep PosthogTrackJob\|PosthogIdentifyJob` | ✓ all cited lines exact; server `user_signed_up`/`user_logged_in` strings untouched by any task |

## Event names / placement vs decisions (D12–D17)

- `user_signed_up_client_side` — F3.4 (magicLink onSuccess) + F4.4 (register onSuccess), plain, no properties, before `onComplete` — ✓ D14 exact.
- `email_verified` + `identifyUser({ id, email })` — F6.2, second effect keyed `[emailConfirmed]`, both-params guard, identify FIRST then event, `/auth?email_confirmed=true` landing only — ✓ D12 exact (order per D12: "calls identifyUser..., then trackEvent").
- `organization_created` — F7.2, createOrganization onSuccess, before `onComplete(data)`, NO identify added — ✓ D13 exact.
- `organization_owner_user_name_submitted` / `invited_user_name_submitted` — F8.2, keyed on `props.isNewOwner`, else-branch covers `wasInvited` + neither-true edge — ✓ D16 exact.
- No browser login event (D15), no `/auth-register` page event (D17) — nothing in the plan adds either — ✓.
- Accepted semantics correctly pinned as do-not-re-litigate: shared-form firing (Risk 1), email in redirect URL (Risk 6/D12), signed-out-only `email_verified` (Risk 7), effect-timing rationale (state-keyed vs mount) — ✓ all present in F6.2/Risk 3.

## Completeness (spec §4.8, §5.6–§5.9, §7.7–7.8)

All spec requirements in this angle's scope map to plan tasks B7, F6, F7, F8, F9. No `PosthogTrackJob`/`PosthogIdentifyJob` add/remove/edit anywhere in the plan. V6 covers the reviewer's event-name grep requirement (spec §9).

## Findings

- F3 [LOW] Pattern-precedents table + F7.2: `AppAuthRouter.tsx:165-176` → actual effect spans lines 166–177 (165 is the `currentPlan` const the effect depends on). Reference-only citation (no edit at that site). Fix: cite 165–177.

## Amendments Applied

- plan.md pattern table row "Browser identify": `165-176` → `165-177`.
- plan.md F7.2: `AppAuthRouter.tsx:165-176` → `AppAuthRouter.tsx:165-177`.
