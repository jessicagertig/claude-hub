# Signup funnel audit — browser-first ruling (2026-07-15)

Rule: the funnel depends on browser events only. Existing server events stay untouched as backup. Server-side only as worst case (no browser moment).

Funnel scope: starts at the app's signup page. The marketing site is not part of the funnel (not under this PR's control; nothing decided for it — its items live on the deferred list only).

| # | Step | Browser event | Server backup | Status |
|---|------|--------------|---------------|--------|
| 1 | Signup page viewed | DEFERRED to marketing-site round — bare pageview says nothing about in-page actions; page gets full instrumentation then (D17) | — | deferred |
| 2 | Email submitted (shared form) | `user_signed_up_client_side` — `magicLink` onSuccess in `AuthForm.tsx`; password path at `register` onSuccess in `SignupForm.tsx` | `user_signed_up` ✔ | DECIDED (D14) |
| 3 | Email verified | `email_verified` — confirmation landing in `Auth.tsx` | none | DECIDED (D12) |
| 4 | Logged in | none — browser login event deferred (no distinct browser moment without extra signaling) | `user_logged_in` ✔ (the funnel step) | DECIDED (D15) |
| 5 | Profile name submitted | `organization_owner_user_name_submitted` when `isNewOwner`, else `invited_user_name_submitted` — `ProfileForm.tsx` `updateMe` onSuccess | none | DECIDED (D16) |
| 6 | Organization created | `organization_created` — `OrganizationForm.tsx` create onSuccess | none | DECIDED (D13) |

Branches:
- SSO signups: auto-confirmed (`skip_confirmation!`) — step 3 never fires for them; steps 1–2 need checking against the SSO path (no `magicLink` onSuccess; browser moment is the post-OAuth app load)
- Invited users: skip most steps — treat funnel as self-serve signups only
- Password `/register` path: shares steps 1, 3–6; step 2's browser moment there is `register` onSuccess in `SignupForm.tsx`

Identify (browser): app-load identify ✔ (`AppAuthRouter.tsx:168`, fires pre-confirmation for new signups — verified chain); verification-landing identify DECIDED (D12); org-creation re-identify happens via existing effect (D13 — to be confirmed in dev by Jessica).

Open decisions: step 1 name · step 2 name (+ SSO/password variants) · step 4 mechanism + name · step 5 name. Queued after funnel: marketing CTA events, marketing utm forwarding.
