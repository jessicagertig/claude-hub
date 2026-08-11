# test-coverage-and-ghost-tests — Round 2

Round-2 focus: completeness of the not-modified invariants across every `magic_create` branch, and coherence of the round-1 §9 amendments.

## Findings

- F1 [MED] §9.1 covered the existing-CONFIRMED-user branch's not-modified invariant but not the existing-UNCONFIRMED-user branch (resend-confirmation path, the second branch of `magic_create`). Both existing-user branches must be pinned: the paths that create a User (magic_create new-user, create, from_omniauth block) all had persistence tests, and the paths that must NOT write were only half-covered. A branch-specific violation (e.g., an implementer updating the found `user` with the four values "while there") would pass the confirmed-branch test. / Fix applied: new §9.1 bullet for the unconfirmed branch (notes it exercises `sign_in`, reinforcing the warden requirement).
- F2 [MED] §9 preamble's quoted convention ("no Devise controller helpers wired into rails_helper") read in isolation contradicts items 1 and 3's `include Devise::Test::ControllerHelpers` instruction — a stale-reference hazard of the round-1 amendment (pipeline failure pattern: amendments must update every related reference). / Fix applied: preamble now says Devise-controller specs opt in per-file, pointing at items 1 and 3.

## Verified-clean

- The round-1 `login_intent: 'hire'` instruction re-verified against `magic_create` control flow: `login_intent = sign_up_params[:login_intent] || 'connect'` (line 81), `CareersPage.find_by_slug(nil)&.organization` → nil, first-branch hash literal evaluates `organization.id` → `NoMethodError`. Solid.
- The round-1 warden claim re-verified: `magic_create` confirmed branch has no `sign_in`/`sign_up` before render (MagicLink.generate only) — but the new-user branch calls `sign_up` and the unconfirmed branch calls `sign_in`; `create` calls `sign_up`. The include is required for those paths; harmless for the rest.
- §9.4 organizations spec: `organization_params` is `params.require(:organization).permit(...)` — the POST must nest under `organization`; plan-level detail, the ai-credit stubbing pattern covers auth/Pundit; `create` also touches real `organization_users` records (`org_owner!`), which the manual factories support.
- §9.5 Hire spec: `Hire::ConfirmationsController < Hire::BaseController` (not a Devise controller) — no mapping/warden needed; two routes map to `confirmations#show` (routes 577, 684), controller specs resolve fine.
- Jest collection re-verified: no `roots`/`testMatch` restriction in `jest.config.js`.

## Amendments Applied

- SPEC.md §9.1: added existing-unconfirmed-branch not-modified bullet.
- SPEC.md §9 preamble: per-file Devise-helpers opt-in clarification.
