# spec-compliance — Round 1

Full requirement-by-requirement diff of SPEC.md (amended) + approved-decisions.md (17 decisions) against commit 8dcc2f06f.

## Section-by-section

- **§3 Data model (D6):** two migrations, exact column sets/types, no defaults/nulls/indexes, no backfill, no model changes, `organization.rb` zero-diff. ✓
- **§4.1 permit (D3):** three scalars + trailing `utm_data: {}`. ✓
- **§4.2 magic_create (D3):** four keys merged in BOTH branches, raw, from `sign_up_params`; existing-user branches inert; no response-shape change. ✓
- **§4.3 create (D10):** no change beyond the permit. ✓
- **§4.4 organizations#create (D5):** four copy lines from `current_user`, `organization_params` unmodified, `authorize` untouched. ✓
- **§4.5 omniauth setup lambda (D8):** line 14 only; six-key `allowed_keys`. ✓
- **§4.6 from_omniauth (D9):** exact keyword signature in the decision's declared order; assignments inside `first_or_create` only; post-block byte-identical; call-site census re-run → zero positional callers. ✓
- **§4.7 callbacks controller (D9):** keyword call with the four `merged_tracking` string-key reads; nothing else in the action changed. ✓
- **§4.8 confirmations redirect (D12):** success redirect carries `id` + `CGI.escape`d `email`; failure redirect byte-identical. ✓
- **§5.1 helper (D4):** raw-string occurrence order (not parse order), 255 truncation, first-of-array, 10-key cap, exclusions, camelCase output fields, absence semantics, null passthrough. ✓
- **§5.2 AuthForm (D1/D2/D7/D14):** state capture matching the `referral` analog, sanitize-before-state, no setter; four fields in the `magicLink` payload; four props to `GoogleSSOButton`; `trackEvent("user_signed_up_client_side")` before `onComplete`; `trackEvent` imported from `@shared/lib/posthog`. Both parents already pass `location` — untouched. ✓
- **§5.3 GoogleSSOButton (D7):** Props + hidden inputs per the analog guard; `utm_data[<key>]` nested naming; per-key value guard. ✓
- **§5.4 useSession (D2/D10):** `magicLink` destructure + inline type + variables; `register` destructure + variables; hook wrappers untouched. ✓
- **§5.5 SignupForm (D10/D14):** capture via `props.location.search`; four fields in `register` payload; event before `props.onComplete()`. ✓
- **§5.6 Auth.tsx (D12):** second `useEffect` on `[emailConfirmed]` (NOT the mount effect); bare-return; both-params guard; `identifyUser({ id: Number(id), email })` then `trackEvent("email_verified")`; banner code untouched; `AuthRegister.tsx`/`Login.tsx` untouched. ✓
- **§5.7 OrganizationForm (D13):** event before `onComplete(data)`; no identify added. ✓
- **§5.8 ProfileForm (D16):** `isNewOwner` keying, else covers `wasInvited` + neither-true; before `onComplete`; `OnboardingProfile.tsx` untouched. ✓
- **§5.9 posthog.ts:** committed as-is — the diff is exactly the `identifyUser` `window.logger` additions (fire + skip paths), nothing else. ✓
- **§6 Authorization:** no new endpoints/policy changes; `authorize @organization` intact. ✓
- **§7 Constraints 1-10:** all verified — capture-side-only sanitization, nil-for-absent at every layer (proven by executed specs), no backfill, raw storage, creation-time only, zero serializer diff, zero PostHog-job diff, exact event names (grep census), raw `utm_data` inner keys, never-edit list respected. New files = 2 migrations + the 6 spec-§9-required test files only. ✓
- **§9 Test requirements:** all six files present, per-file requirements met item-by-item (see test-coverage-and-ghost-tests.md), all executed green. ✓
- **§10 Deferred items:** correctly absent — no `/auth-register` page event (D17), no browser login event (D15), no server identify at confirmations#show, no serializer exposure, no backfill. ✓
- **D15/D17 negative checks:** grep confirms no page-view event, no new server events. ✓

## Deviations from spec

**None found.** Every code block in the committed diff traces to a spec section or plan task; no extra methods, files, event handlers, migrations, or validation changes beyond spec scope (fix-agent-scope rules 10/23 have no material to bite on — this is the initial implementation, and it introduced nothing unspecced).

## Findings

No issues found.
