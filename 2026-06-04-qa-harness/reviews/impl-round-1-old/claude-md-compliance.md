# CLAUDE.md Compliance — Round 1

## Global CLAUDE.md Hard Rules

### Database Safety

- **NEVER drop or recreate a database:** PASS. The harness does not execute any database commands directly. All data operations go through `/cypress/*` HTTP endpoints, which are gated on `Rails.env.test?`. The harness never imports Rails, never runs `bundle exec rails db:*`, never uses `psql`.

- **NEVER modify .env files:** PASS. No code in the harness reads, writes, or modifies `.env` files. `grep -rn "\.env" src/` returns zero hits for file operations on `.env` files. The config module reads `QA_CONFIG_PATH` from `os.environ.get()` (read-only) -- this is an env var, not a `.env` file.

- **NEVER set DATABASE_URL:** PASS. `grep -rn "DATABASE_URL" src/` returns zero hits. The server module uses `env = os.environ.copy()` but never mutates it. No `env["DATABASE_URL"]` or `os.environ["DATABASE_URL"]` anywhere.

- **Data written only via app interaction, Rails console, or rails runner:** PASS. Seed data is written via HTTP POST to `/cypress/*` endpoints on the running Rails test server. This is "actual app interaction" per the rules.

### Other Global Rules

- **Never work directly on main/master:** N/A -- the harness is infrastructure code in claude-hub, not a source repo with branches.

- **Never delete git branches:** N/A.

- **Platform (Mac M1):** PASS. No hardcoded `/usr/local/` paths. Uses `bash -c` wrapper for shell commands. No architecture-specific assumptions.

## Hub CLAUDE.md Rules

- **Never write files into source repos from a hub session:** PASS. The harness writes only to `/tmp` (state file, agent evidence) and to the feature working directory (`reviews/`). No writes to source repos.

- **Always create a subdirectory for new work:** PASS. The harness package is at `~/claude-hub/qa-harness/`, a new top-level directory. The pipeline config is at `~/claude-hub/inflow-ats/qa-config.yml`, inside an existing pipeline directory.

- **Source repo's CLAUDE.md and cursor_rules/ are authoritative:** N/A for the harness itself. The qa-prompt.md instructs agents to respect source repo conventions.

## Verdict

All hard rules pass. No compliance issues.
