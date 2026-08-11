# test-coverage-and-ghost-tests — Round 3

Round-3 focus: the Cypress claim, now fully traced.

- `bin/run-cypress-precommit` verified: boots a `RAILS_ENV=test` server + Sidekiq on port 5007 and runs the full `yarn cy:run` suite — `registration.cy.js` genuinely executes pre-commit; the spec's "must keep passing" constraint is live.
- The password-path test's post-confirm flow is now fully explained (signed-in bounce via `redirect_if_authed` to the app root → `needsNewOrganizationRoute` → "Create new organization"). Consequences for the diff: (a) the confirm click never renders `Auth.tsx`, so the new §5.6 code does not execute in Cypress at all; (b) the extra redirect params survive one extra 302 hop (`confirmations#show` → `/auth?...` → `app_root_path`) with no test-visible difference. The spec's claim that the diff cannot break this test is stronger than round 1 believed.
- §9.5's Hire spec remains the only automated pin on the new redirect URL — correct, since Cypress never observes it.
- Re-audited the §9 list after the round-2 additions: the five RSpec files + one Jest file cover every write path and every not-modified path; no ghost patterns introduced by the new bullets.

## Findings

- None. (Risk 7's coverage boundary needs no new test: the D12 code's reachable behavior is what §9.5 + Jessica's manual dev check verify; testing "the event does not fire for signed-in users" would require an integration test of `pages#auth`, which tests pre-existing behavior outside this feature's diff.)

## Amendments Applied

- None.
