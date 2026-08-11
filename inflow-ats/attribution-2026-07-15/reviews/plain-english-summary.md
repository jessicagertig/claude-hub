# Plain English Summary + Blast Radius

**Written before Round 1 of spec review (2026-07-15). Verdict-independent context for a quick sanity check.**

## Plain English Summary

When someone arrives at the app's signup or login pages from an ad or a marketing link, the address bar often carries little tags describing where they came from (which campaign, which source). Today those tags are thrown away. This change catches them at the door, cleans them up (trims absurdly long values, keeps only a sane number of extras), and writes them onto the person's account record at the moment the account is created — and later copies them onto the company workspace the person creates. Nothing is ever guessed or backfilled: people who arrive without tags simply have blank fields, and accounts that already exist stay untouched.

Separately, the product's analytics currently only hears about signups from the server, which can't always connect the dots to what the person's browser was doing before they signed up. This change makes the browser itself announce the key funnel moments — "submitted their email," "verified their email," "entered their name," "created a company workspace" — directly to the analytics tool, and tells the analytics tool who the person is at the moment they click the email-verification link. The existing server-side announcements stay exactly as they are, as a backup. Together this lets marketing spend be tied to real signups end to end.

## Blast Radius

**What existing behavior changes?**
- The email-confirmation redirect URL gains two query params (`id`, `email`). Same path (`/auth`), same `email_confirmed=true` flag; the failure redirect is untouched.
- `User.from_omniauth` changes from positional to keyword arguments (one call site in the repo; the spec mandates a repo-wide re-search at implementation time).
- The omniauth `setup` lambda whitelists four more tracking keys into the session cookie.
- Signup request payloads (magic-link, password, SSO form) carry up to four additional fields. Servers ignore unknown params today, so old clients/new servers and new clients/old servers are both safe.

**What existing code is modified?** 2 backend controllers get param additions (`registrations`, `organizations#create`), 1 controller call-site conversion (`omniauth_callbacks`), 1 model method signature (`from_omniauth`), 1 initializer line (`omniauth.rb`), 1 redirect line (`hire/confirmations`), plus 8 frontend files (capture, payload threading, hidden inputs, 5 event callsites). Two new migrations add four nullable columns each to `users` and `organizations`.

**Callers/consumers affected:**
- `from_omniauth`: exactly one call site (verified `git grep`), converted in the same PR.
- `/auth?email_confirmed=true` landing: read by `Auth.tsx` only for the banner today; `AuthRegister.tsx`/`Login.tsx` also read the param but are never the redirect target. Cypress `registration.cy.js` (password path) traverses the redirect; extra params don't affect its assertions, and PostHog is disabled under `IS_TEST_ENV`.
- No serializer exposes the new columns; no policy, job, or Sidekiq change.

**If this is wrong, what breaks?**
- Worst structural risk: a missed positional `from_omniauth` call site would raise `ArgumentError` on every SSO login (mitigated: one call site, mandatory re-search, new specs pin the keyword interface).
- The confirmation redirect is on the critical signup path — a malformed URL would break email verification for all non-SSO signups (mitigated: trivial string change, covered by new controller spec + existing Cypress flow).
- Everything else is additive: nil columns and skipped events degrade to today's behavior.
