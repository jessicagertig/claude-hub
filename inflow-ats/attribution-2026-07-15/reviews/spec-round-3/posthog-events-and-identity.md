# posthog-events-and-identity — Round 3

Round-3 focus: what actually renders at the `/auth?email_confirmed=true` landing, traced from the server route down (motivated by the Cypress password-path flow, whose post-confirm assertions didn't fit round 1-2's mental model).

New verifications: `config/routes.rb:591` (`get 'auth', to: 'pages#auth'` under the "UNAUTHED ROUTES (will redirect to root if user is logged in)" block), `Hire::PagesController` (`before_action :redirect_if_authed, except: %i[root]`; `redirect_if_authed` 302s to `app_root_path` when `api_v1_user_signed_in? && !params.key?(:invite_token)`, else renders the SPA shell — lines 24–31), `User#active_for_authentication?` override (`super || organization.nil?` — user.rb:136–138; fresh signups have no organization, so `sign_up` succeeds while unconfirmed; `config/initializers/devise.rb` `allow_unconfirmed_access_for` is commented out, so the override is what makes this work), `User#devise_confirmation_url` (user.rb:157 — `/email_confirmation?confirmation_token=...`, i.e. `Hire::ConfirmationsController#show`), `Api::V1::SessionSerializer#confirmation_url` (test/dev only — the Cypress confirm link), `bin/run-cypress-precommit` (runs the full `yarn cy:run` suite — registration.cy.js does execute pre-commit, corroborating that its password path really does bounce through `redirect_if_authed` to reach "Create new organization" directly after the confirm click).

## Findings

- F1 [HIGH — factual coverage boundary of an approved decision; recorded for Jessica's ruling, mechanism unchanged] The D12 `email_verified` event and identify fire **only for confirmations clicked while signed out.** The typical same-browser flow — sign up, stay signed in (unconfirmed sessions are valid because `active_for_authentication?` returns true with no organization), click the email link minutes later — hits `confirmations#show` → 302 `/auth?email_confirmed=true&id&email` → `pages#auth` `redirect_if_authed` → 302 `app_root_path` with ALL query params dropped. `Auth.tsx` never renders; nothing fires. Cross-device/logged-out/browser-restarted clicks are the only reachable moments. Funnel impact: step 3 undercounts and has no server backup (funnel-audit: "server backup: none" for step 3). Neither funnel-audit.md, identify-findings.md, nor the D12 decision text mentions `redirect_if_authed` — the decision was made without this fact on the table. Per the binding-decisions rule this is NOT re-litigated: the spec'd mechanism stays exactly as D12 fixes it; the fact is now disclosed in the spec (Risk 7) and the ruling belongs to Jessica (options recorded in §10 and SPEC-REVIEW-COMPLETE: accept the boundary; or approve a follow-up decision — app-root landing event, or the never-approved D11 server-side identify/event at `confirmations#show`).

## Also checked (no findings)

- The signed-out landing (the reachable case) behaves exactly as §5.6 specifies; the round-1/round-2 mechanism analysis is unaffected (it concerns the signed-out render path).
- The stale-bookmark guard interacts consistently: signed-in stale bookmarks bounce before React runs; signed-out stale bookmarks hit the guard.
- No other spec claim assumes the landing renders for signed-in users; §4.8's "magic-link logins never reach this URL" and §5.6's "fires only on the email_confirmed=true landing" remain true.
- Cypress: the password-path test never renders `Auth.tsx` post-confirm (it bounces), so the D12 code doesn't execute in that test at all — further confirmation the diff cannot break it.

## Amendments Applied

- SPEC.md §11 Risk 7 added (full verified chain + funnel consequence + needs-ruling marker).
- SPEC.md §10: identify-at-confirmations bullet qualified; new bullet scoping any coverage fix as a new decision.
