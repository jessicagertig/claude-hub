# spec-compliance — Round 2 (always-on impl angle)

Full walkthrough of SPEC.md §3–§10 against the committed diff; every requirement checked individually.

- §3 data model: both migrations exact (types, no defaults, nullable, no index); no model changes; `organization.rb` untouched. COMPLIANT.
- §4.1 permit: three scalars + trailing `utm_data: {}`. COMPLIANT.
- §4.2 `magic_create`: four keys in both branches, raw, existing-user branches inert, JSON responses untouched. COMPLIANT.
- §4.3 `create`: no change beyond permit. COMPLIANT.
- §4.4 org copy: four `current_user` copies beside `created_via`; `organization_params` unmodified. COMPLIANT.
- §4.5 omniauth setup lambda: line 14 only. COMPLIANT.
- §4.6 `from_omniauth`: exact keyword order; assignment inside `first_or_create` only; post-block unchanged; call-site census re-run (zero positional callers). COMPLIANT.
- §4.7 callback: keyword call with `merged_tracking` string-key reads; nothing else changed. COMPLIANT.
- §4.8 confirmation redirect: success branch gains `id` + `CGI.escape(user.email)`; failure branch unchanged. COMPLIANT (spec-proposed param names `id`/`email` used).
- §5.1 helper: name `sanitizeTrackingParams` (spec-proposed name used), placement, raw-string order derivation, parse-for-values — all as specified. COMPLIANT.
- §5.2 AuthForm: capture, payload, SSO props, `user_signed_up_client_side` before `onComplete`, `trackEvent` import. COMPLIANT.
- §5.3 GoogleSSOButton: optional Props, analog guards, per-key nested `utm_data[<key>]` inputs. COMPLIANT.
- §5.4 useSession: magicLink destructure+type+variables; register destructure+variables; hook wrappers untouched. COMPLIANT.
- §5.5 SignupForm: capture via `props.location.search`, payload, event before `onComplete`. COMPLIANT.
- §5.6 Auth.tsx: banner path untouched; second effect with `[emailConfirmed]` deps, bare-return, both-params guard, `identifyUser({ id: Number(id), email })` then `trackEvent("email_verified")`; imports added; `AuthRegister.tsx`/`Login.tsx` unmodified. COMPLIANT.
- §5.7 OrganizationForm: `organization_created` before `onComplete(data)`; no identify added. COMPLIANT.
- §5.8 ProfileForm: `isNewOwner` keying, else-catch-all. COMPLIANT.
- §5.9 posthog.ts: committed as-is, no further edit (trackEvent loggers verified pre-existing at base). COMPLIANT.
- §6 authorization: no policy/endpoint changes; `authorize @organization` intact. COMPLIANT.
- §7 constraints 1–10: capture-side-only sanitization, nil-for-absent at every layer, no backfill, raw storage, creation-time only, no serializer changes, server events untouched, exact event names, raw `utm_data` inner keys, never-edit list respected (no new source files beyond the two migrations — the new test files are required by §9). COMPLIANT.
- §9 tests: all six files present with every enumerated case; executed green. COMPLIANT.
- §10 deferred items: verified NOT implemented (no `/auth-register` page event, no browser login event, no SSO client-side signup event, no serializer exposure, no server-side identify at confirmations#show). COMPLIANT.

## Findings

No issues found.
