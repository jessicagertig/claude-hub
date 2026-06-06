# CLAUDE.md Compliance — Pass 1

## Global CLAUDE.md Hard Rules

### Database Safety

- **NEVER drop or recreate a database:** The plan uses only `DELETE /cypress/cleanup` (an HTTP request to a running Rails server in test mode). No `db:drop`, `db:reset`, `db:setup`, `db:test:prepare`, or `db:schema:load` anywhere in the plan. COMPLIANT.

- **Cypress cleanup endpoint MUST be called as a direct HTTP request:** The plan's `SeedExecutor.cleanup()` makes an HTTP request via `requests.Session`. This is a direct HTTP request to a running Rails server, not a Rake task or Rails command. COMPLIANT.

- **NEVER modify .env files:** The plan explicitly says in section 5 `cli.py`: "No env loading (`apply_env`) -- the harness does not read `.env` files." Spec constraint says "The harness must never modify `.env` files." COMPLIANT.

- **NEVER set DATABASE_URL:** The plan explicitly says in section 5 `server.py`: "The harness MUST NOT set `DATABASE_URL` per global hard rules." The plan notes that `InflowBootstrap` sets `env["RAILS_ENV"] = "test"` but the QA harness intentionally does NOT modify env because the config's server command includes `RAILS_ENV=test` inline. COMPLIANT.

- **Data written via app interaction or Cypress endpoints:** The plan's data seeding uses HTTP POST/DELETE to `/cypress/*` endpoints, which run inside the Rails app context with the test-env safeguard. No `psql`, no direct ORM scripts. COMPLIANT.

### Other Global Rules

- **Never work directly on main/master:** The plan creates code in `~/claude-hub/qa-harness/` (new directory in the hub). No source repo branches are directly modified. COMPLIANT.

- **Never delete git branches:** The plan does not mention deleting any branches. COMPLIANT.

- **Pattern Matching -- Find It First:** The plan extensively documents pattern precedents from the help pipeline in section 2. Every module has an "Analog" section comparing to the help pipeline equivalent. COMPLIANT.

## Hub CLAUDE.md Rules

- **Never write files into source repos from a hub session:** The plan creates files in `~/claude-hub/qa-harness/` and `~/claude-hub/inflow-ats/qa-config.yml`. Neither is inside a source repo. Temporary scripts go to `/tmp`. COMPLIANT.

- **Always create a subdirectory for new work:** The plan creates `~/claude-hub/qa-harness/` as a new subdirectory. The pipeline config goes to `~/claude-hub/inflow-ats/qa-config.yml`. COMPLIANT.

- **Source repo's own CLAUDE.md and cursor_rules/ are authoritative:** The plan does not override any source repo conventions. It adapts patterns from the help pipeline but creates new code. COMPLIANT.

## Findings

No compliance violations found.

## Amendments Applied

None needed.
