# claude-md-compliance — Round 2 Findings

## Prior findings reviewed:

### HIGH-3 (RAILS_ENV=test not enforced) -- RESOLVED
Cross-reference to server-lifecycle HIGH-1. `env["RAILS_ENV"] = "test"` is now set in `ServerManager.start()`.

## Rechecked all global CLAUDE.md hard rules:

- **NEVER drop or recreate a database**: PASS. Harness uses Cypress endpoints only.
- **Cleanup via DELETE /cypress/cleanup only**: PASS.
- **No direct psql access**: PASS. No database connections in harness code.
- **No .env file modification**: PASS. Harness does not touch .env files.
- **NEVER set DATABASE_URL**: PASS. Harness sets only `RAILS_ENV=test`.
- **RAILS_ENV=test always**: PASS (fixed in Round 1).
- **Data via app interaction / Rails console / rails runner only**: PASS. Seed data via Cypress HTTP endpoints (which run inside the Rails app context).
- **Temporary scripts in /tmp only**: PASS. qa-prompt.md specifies `/tmp`.

## Hub CLAUDE.md rules:

- **Never write files into source repos from a hub session**: PASS.
- **Always create a subdirectory for new work**: PASS.

No BLOCKER, HIGH, or MED findings.
