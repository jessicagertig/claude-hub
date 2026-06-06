# Round 1 — FAILURE REPORT

## HIGH-1: No defensive RAILS_ENV=test enforcement in subprocess environment

**File:** `src/qa_harness/server.py`, line 50

**Problem:** `start()` copies `os.environ` without setting `RAILS_ENV=test`. The spec's hard rules say "`RAILS_ENV=test` always. Never dev, never production." The analog (`inflow_bootstrap.py`, line 72) explicitly sets `env["RAILS_ENV"] = "test"`.

**Required fix:** After `env = os.environ.copy()`, add `env["RAILS_ENV"] = "test"`. Add a test verifying the env passed to Popen includes `RAILS_ENV=test`.

---

## HIGH-2: State file missing config_path

**File:** `src/qa_harness/server.py`, lines 273-286 and `src/qa_harness/cli.py`, lines 57-79

**Problem:** The plan specifies the state file should contain `config_path`. The implementation omits it. This makes `qa-harness stop` fail if run from a different working directory than `start` (because `resolve_config_path` can't find the config).

**Required fix:**
1. Add a `config_path` parameter to `ServerManager.__init__` (or to `_write_state_file`) and store it in the state JSON.
2. In `cmd_stop`, before loading config via `resolve_config_path`, try reading `config_path` from the state file as a fallback.
3. Same for `cmd_status`.
