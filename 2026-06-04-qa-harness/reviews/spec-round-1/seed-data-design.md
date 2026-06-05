# seed-data-design -- Round 1

## Findings

- F1 [HIGH] Missing seed endpoints from catalog. The spec's `available_endpoints` list in qa-config.yml is incomplete. The actual `lib/test_routes.rb` in inflow-ats includes two additional endpoints not listed:
  1. `POST /cypress/organizations/create_complete_subscription` -- creates a real-Stripe-backed complete subscription
  2. `GET /cypress/individual_app/careers_page_subscriptions/:id` -- careers page subscription lookup

  Additionally, `POST /cypress/users` accepts a `setFreeV2Subscription` param (boolean) that is not documented in the spec's params list.

  The seed planner agent can only produce correct seed plans if the catalog is complete. Missing endpoints mean missing test scenarios.

  **Fix:** Add the missing endpoints and parameter to the config example. Note that the catalog in qa-config.yml must be kept in sync with `lib/test_routes.rb`.

- F2 [HIGH] Endpoint ordering dependencies not documented. Several endpoints have implicit ordering requirements:
  - `POST /cypress/jobs` requires `POST /cypress/users` to have been called first (the job needs an org)
  - `POST /cypress/candidates` requires `POST /cypress/jobs` first (candidates attach to the first job)
  - `POST /cypress/users/add_users` requires `POST /cypress/users` first (adds to the first user's org)
  - `POST /cypress/users/add_second_org` requires `POST /cypress/users` with a god_admin role first (checks for `OrganizationUser.where(role: 99)`)
  - `POST /cypress/users/create_member_and_assign_to_job` requires both `POST /cypress/users` and `POST /cypress/jobs` first
  - `POST /cypress/organizations/*` endpoints require `POST /cypress/users` first (they act on `Organization.first`)

  Without documenting these dependencies, the seed planner agent has no way to produce valid ordering. Invalid ordering will cause 400 errors at seed time.

  **Fix:** Add a `requires` field to each endpoint in the config, listing prerequisite endpoints.

- F3 [MED] No seed plan validation. The analog's `seed_parser.py` validates seed commands at parse time -- unknown endpoints raise `SeedParseError` immediately. The spec says `qa-harness seed --plan <path>` executes calls sequentially but does not mention validating the plan file against the known endpoint catalog before execution. Invalid plans would fail at HTTP call time with opaque errors instead of at plan-validation time with clear errors.

- F4 [MED] Cleanup between scenarios within a single agent's run. The spec says cleanup happens at the start of `qa-harness seed --plan <path>` ("calls cleanup first"), which handles the case of switching between seed plans. But if an agent wants to test multiple scenarios in one session, it needs to explicitly call `qa-harness seed --plan <different-plan>` each time (which will cleanup + re-seed). This works but the spec should make it explicit that this is the expected pattern.

- F5 [LOW] The seed plan JSON format uses `"body"` as the key for endpoint parameters, but the config uses `"params"` as the key for documenting the available parameters. This naming inconsistency could confuse the seed planner agent.

## Amendments Applied

- Spec qa-config.yml example: added missing endpoints and `setFreeV2Subscription` param.
- Spec qa-config.yml example: added `requires` field to endpoints with ordering dependencies.
