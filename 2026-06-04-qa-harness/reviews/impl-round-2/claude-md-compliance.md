# CLAUDE.md Compliance — Round 2

## Global CLAUDE.md Hard Rules

### Database Safety

- **NEVER drop or recreate a database:** PASS. No database commands in harness code. All data via `/cypress/*` HTTP endpoints.
- **NEVER modify .env files:** PASS. No `.env` file operations anywhere in the codebase.
- **NEVER set DATABASE_URL:** PASS. No `DATABASE_URL` references in the codebase. Server env uses `os.environ.copy()` without mutation.
- **Data via app interaction only:** PASS. Seed data via HTTP POST to Cypress endpoints on running Rails server.

### Other Global Rules

- **Platform (Mac M1):** PASS. No hardcoded `/usr/local/` paths.
- **Pattern Matching (find it first):** PASS. Implementation follows `inflow_bootstrap.py` and `cypress_api.py` patterns.

## Hub CLAUDE.md Rules

- **Never write files into source repos:** PASS.
- **Always create a subdirectory for new work:** PASS.

## qa-prompt.md Agent Constraints

The agent instructions in qa-prompt.md correctly include:
- "Temporary scripts go in `/tmp` only -- never write to the source repo"
- "Never modify `.env` files"
- "Never set `DATABASE_URL`"
- "`RAILS_ENV=test` always"
- "Do NOT start or stop the server"

## Verdict

All hard rules pass. No compliance issues. Identical to Round 1.
