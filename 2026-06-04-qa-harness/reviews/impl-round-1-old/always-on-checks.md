# Always-On Checks — Round 1

## Source Accuracy

Verified references:
- File paths: `errors.py`, `config.py`, `server.py`, `seed.py`, `cli.py`, `__init__.py`, `__main__.py` -- all exist at `src/qa_harness/`
- Class names: `QAHarnessError`, `ConfigError`, `ServerError`, `SeedError`, `ServerConfig`, `SeedEndpoint`, `SeedConfig`, `AuthConfig`, `ScriptRunnerConfig`, `QAConfig`, `ServerManager`, `SeedExecutor` -- all exist in the correct files
- MCP tool names referenced in qa-prompt.md: `mcp__playwright__browser_navigate`, `browser_click`, `browser_fill_form`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests` -- all present in the system prompt tool list
- Cypress endpoints in qa-config.yml: `/cypress/users`, `/cypress/jobs`, `/cypress/candidates`, `/cypress/cleanup`, `/cypress/invites/{email_base64}`, etc. -- match the spec and the analog's `cypress_api.py`
- `qa-harness` console script entry point: `qa_harness.cli:main` in pyproject.toml -- matches the actual `main()` function in `cli.py`

All source references verified accurate.

## Reinventing the Wheel / Pattern Compliance

The implementation follows the analog (`inflow_bootstrap.py`, `cypress_api.py`) closely:

| Pattern | Analog | QA Harness | Match? |
|---|---|---|---|
| `_kill_pids_from_command` via `os.system` + temp file | `inflow_bootstrap.py:163-190` | `server.py:172-199` | Near-identical |
| `_wait_for_health` polling loop | `inflow_bootstrap.py:192-211` | `server.py:216-244` | Near-identical |
| Premature exit detection (`proc.poll()`) | `inflow_bootstrap.py:196-199` | `server.py:226-232` | Near-identical |
| `_register_cleanup` with atexit + signal | `inflow_bootstrap.py:213-221` | `server.py:255-265` | Identical |
| `_signal_handler` with `sys.exit(128+signum)` | `inflow_bootstrap.py:224-227` | `server.py:267-271` | Identical |
| `stop` with SIGTERM/SIGKILL/wait | `inflow_bootstrap.py:111-131` | `server.py:76-94` | Near-identical |
| `bash -c` wrapper for Popen | `inflow_bootstrap.py:86-92` | `server.py:206-213` | Identical |
| `requests.Session` with Content-Type header | `cypress_api.py:29-31` | `seed.py:28-30` | Identical |
| `_request` method (session.request, ok check, 204 handling, json parse) | `cypress_api.py:141-158` | `seed.py:209-235` | Near-identical |
| Health check accepts < 500 | `inflow_bootstrap.py:203` | `server.py:235` | Identical |

No wheels reinvented. All divergences are intentional and documented (config-driven vs. hardcoded, list of procs vs. named fields, generic endpoint execution vs. per-endpoint methods).

## Analog Completeness

| Help Pipeline Layer | QA Harness Equivalent | Status |
|---|---|---|
| Server lifecycle (`inflow_bootstrap.py`) | `server.py` | Complete |
| Data seeding (`cypress_api.py`) | `seed.py` | Complete |
| Seed parsing (`seed_parser.py`) | `seed.py` validate_plan + JSON plans | Complete (replaced, not adapted) |
| Auth (`login.py`) | `qa-config.yml` auth instructions + agent MCP | Complete (intentional substitution) |
| Browser actions (`fallback_executor.py`) | Playwright MCP tools | Complete (intentional substitution) |
| CLI (`cli.py`) | `cli.py` | Complete |
| Error hierarchy (`BootstrapError`, `CypressApiError`) | `errors.py` | Complete |
| Config (`InflowBootstrapConfig`) | `config.py` | Complete (expanded) |

No missing functional layers.
