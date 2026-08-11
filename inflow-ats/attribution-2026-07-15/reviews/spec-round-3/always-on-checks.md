# always-on checks — Round 3

## Source accuracy

New facts verified this round and reflected in the Risk 7 amendment: `routes.rb:591`, `Hire::PagesController#redirect_if_authed` (lines 24–31), `User#active_for_authentication?` override (user.rb:136–138), `User#devise_confirmation_url` (user.rb:157), `Api::V1::SessionSerializer#confirmation_url` (test/dev only), `devise.rb` `allow_unconfirmed_access_for` commented out, `bin/run-cypress-precommit` (full suite). No inaccuracies found in the spec's pre-existing text; the Risk 7 addition is new disclosure, not correction.

## Test coverage

No changes required this round (see test-coverage-and-ghost-tests.md — the coverage boundary is not testable within this diff's scope).

## Backward compatibility

The redirect params ride through `redirect_if_authed`'s bounce for signed-in users with no consumer on the other side (params dropped at `app_root_path`) — no new consumer, no breakage. Signed-out consumers (Auth.tsx) unchanged from rounds 1–2 analysis.

## Full-stack analog completeness

Unchanged — all layers spec'd; Risk 7 concerns event reach, not a missing layer.

## Analog structural matching

Unchanged — no new structural surface this round.
