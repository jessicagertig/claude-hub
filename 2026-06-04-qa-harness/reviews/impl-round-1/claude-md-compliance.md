# claude-md-compliance — Round 1 Findings

## Checked against global CLAUDE.md hard rules:

### Database safety rules
- **NEVER drop or recreate a database**: The harness does not perform any database operations directly. Data seeding is exclusively via Cypress HTTP endpoints (which are gated on `Rails.env.test?`). PASS.
- **Cleanup via DELETE /cypress/cleanup only**: The harness calls the configured cleanup endpoint, which for inflow-ats is `DELETE /cypress/cleanup`. PASS.
- **No direct psql access**: The harness does not make any direct database connections. PASS.
- **No .env file modification**: The harness does not read or write `.env` files. PASS.

### HIGH-3: Harness does NOT set DATABASE_URL (verified) but also does NOT enforce RAILS_ENV=test in subprocess env

Cross-reference with server-lifecycle HIGH-1. The global CLAUDE.md says:
- "NEVER set DATABASE_URL yourself" -- PASS, the harness does not set this.
- But the related rule "control it via RAILS_ENV ONLY" implies the harness should set `RAILS_ENV=test` in the subprocess environment. The current code (`env = os.environ.copy()` without modification) does NOT enforce this.

This is the same finding as server-lifecycle HIGH-1, cross-referenced here for completeness.

### Hub CLAUDE.md rules
- **Never write files into source repos from a hub session**: The harness writes to `/tmp` (state file) and to the feature working directory (via agents). It does not write to source repos. PASS.
- **Always create a subdirectory for new work**: The qa-harness package is at `~/claude-hub/qa-harness/`, which is a new directory at the hub level. The plan-review confirmed this is acceptable. PASS.

### Spec hard rules
- **`RAILS_ENV=test` always**: FAIL -- see server-lifecycle HIGH-1.
- **Data seeding via Cypress endpoints only**: PASS.
- **Temporary scripts in /tmp only**: QA agent instructions in qa-prompt.md correctly specify `/tmp` (line 70, 95, 106).
- **No .env modification**: PASS.
- **No DATABASE_URL**: PASS.
