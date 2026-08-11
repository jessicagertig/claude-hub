# PostHog Events and Identity — Pass 2

## Pass 1 correction verification
- F3: both `AppAuthRouter.tsx:165-176` citations (pattern table "Browser identify" row; F7.2) now read `165-177` — matches the live file (`const currentPlan` at 165, effect 166–177). ✓ Grep confirms no `165-176` remains in plan.md.

## Fresh scrutiny
- F6.2 effect re-read against spec §5.6: second effect (not the mount effect), deps `[emailConfirmed]`, bare return, both-params guard with the loose house form, identify BEFORE event, `Number(id)` for the `id: number` signature, `email as string` for the parse union type, fires once per landing, `email_confirmed=false` gets nothing, `AuthRegister.tsx`/`Login.tsx` untouched. `props.location.search` prefix matches the file's existing usage (line 23). `queryString` already imported (line 4) — F6.1 correctly adds only the posthog import. Risk-7 boundary carried verbatim as decision-bound. ✓
- B7.1 re-read: `CGI.escape(user.email)`; success-branch-only; failure redirect byte-identical (B7.2); `user.errors.blank?` guarantee re-verified in the live controller. ✓
- Event placements re-diffed against the live onSuccess callbacks one more time — all four blocks reproduce current code exactly plus one inserted `trackEvent` line before the respective `onComplete` (AuthForm 82–85, SignupForm 66–69 incl. the preserved `onScucess` typo, OrganizationForm 68–71, ProfileForm 64–67 keyed on `props.isNewOwner`). ✓
- Import additions re-checked: none of the five components imports `@shared/lib/posthog` today — no duplicate imports. ✓
- Server-events invariant re-checked: no plan task touches any `PosthogTrackJob`/`PosthogIdentifyJob` callsite; V6's greps match spec §9's reviewer checks; the C.3 event-name census re-ran clean this pass (only `organization_created_via` substrings and the `email_verified:` comment at `smtp_email_validator.rb:113`). ✓
- F9.1 re-checked: `posthog.ts` diff still the sole working-tree change; content = `window.logger` on fire + skip paths of `identifyUser` only. ✓

## Completeness sweep (spec §4.8, §5.6–5.9, §7.7–7.8, D12–D17)
All five event names exact, all plain no-property calls, placements per decisions; D15/D17 deferrals respected (no login event, no page-view event anywhere in the plan). Nothing dropped; Pass 1 amendments introduced no inconsistency.

## Findings
No issues found.

## Amendments Applied
None.
