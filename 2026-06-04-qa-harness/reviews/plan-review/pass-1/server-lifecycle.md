# Server Lifecycle — Pass 1

## Fact Check

- **Claim:** "`InflowBootstrap` class in `inflow_bootstrap.py` (lines 55-227)."
  - Verified: `class InflowBootstrap:` is at line 55, file is 227 lines total. Correct.

- **Claim:** "Supporting processes are iterated from a list instead of being two named fields (`_rails_proc`, `_sidekiq_proc`)."
  - Verified: The analog uses `_rails_proc` and `_sidekiq_proc` as named fields (lines 60-61). The plan replaces this with `_procs: list[tuple[subprocess.Popen, str]]`. Design is consistent.

- **Claim:** "`_kill_pids_from_command` using temp file redirection via `os.system`."
  - Verified: The analog's `_kill_pids_from_command` (lines 163-189) uses `tempfile.NamedTemporaryFile` and `os.system`. Plan correctly preserves this pattern.

- **Claim:** "`_wait_for_health` polling loop with `time.sleep(1)`, premature exit detection via `proc.poll()`, `requests.get` with 5s timeout."
  - Verified: Analog `_wait_for_health` (lines 192-211) uses `time.sleep(1)`, `proc.poll()` for premature exit, `requests.get(url, timeout=5)`. All correct.

- **Claim:** "stop with SIGTERM, 10s wait, SIGKILL fallback."
  - Verified: Analog `stop` (lines 111-131) calls `proc.terminate()`, then `proc.wait(timeout=10)`, then `proc.kill()` on `TimeoutExpired`. Correct.

- **Claim:** "`env = os.environ.copy()` -- note: `InflowBootstrap` actually adds `env['RAILS_ENV'] = 'test'`, but the QA harness intentionally does NOT modify env because the config's server command includes `RAILS_ENV=test` inline."
  - Verified: Analog at line 72: `env["RAILS_ENV"] = "test"`. Plan acknowledges this and documents the intentional divergence. This is a sound decision since the config command string includes RAILS_ENV=test already.

- **Claim:** "The harness MUST NOT set `DATABASE_URL` per global hard rules."
  - Verified: Global CLAUDE.md explicitly prohibits setting `DATABASE_URL`.

- **Claim:** "State file written on start, removed on stop" -- plan describes `/tmp/qa-harness-state.json`.
  - The spec does NOT mention a state file. This is a plan addition. The spec says `stop` "terminates all processes started by `qa-harness start`" but doesn't specify how stop finds those processes. The state file is a reasonable mechanism.

## Completeness

Spec requirements covered by this angle:
1. Kill existing processes on port (spec: "Kill any existing processes on the configured port") -- plan: `_kill_existing_processes`
2. Kill existing sidekiq processes (spec: "Kill any existing sidekiq processes") -- plan: generalized to supporting_commands keyword extraction
3. Start server as subprocess with bash -c wrapper (spec: "Start the server command as a subprocess") -- plan: `_start_subprocess`
4. Start sidekiq as subprocess (spec: "Start the sidekiq command as a subprocess") -- plan: supporting_commands list
5. Register atexit + signal handlers (spec: "Register atexit + signal handlers for cleanup") -- plan: `_register_cleanup`
6. Poll health check (spec: "Poll health check endpoint until it returns < 500") -- plan: `_wait_for_health`
7. Print READY (spec: "Print 'READY' to stdout") -- plan: in `start()` and `cmd_start`
8. SIGTERM then SIGKILL on stop (spec: "SIGTERM both subprocesses, Wait up to 10 seconds") -- plan: `stop()`
9. Print STOPPED (spec: "Print 'STOPPED' to stdout") -- plan: in `stop()` and `cmd_stop`
10. Premature exit detection (spec: "check whether the server subprocess has exited") -- plan: `_wait_for_health` checks `proc.poll()`
11. Health check accepts < 500 (spec: "Accept any status < 500") -- plan: `_wait_for_health`
12. 180s default timeout (spec: "startup_timeout_seconds (default 180s)") -- plan: `ServerConfig` default

All spec requirements addressed.

## Findings

- F1 [MED] The plan describes a `_check_server_alive()` method on `ServerManager` AND a separate `check_server_alive` method on `SeedExecutor`. The spec says seed/cleanup should verify the server is alive before HTTP calls. Having both methods is somewhat redundant but not wrong -- `SeedExecutor.check_server_alive` takes a `health_url` parameter and raises `SeedError`, while `ServerManager._check_server_alive` returns bool. The distinction is clear enough.

- F2 [MED] The plan's Risk #2 about supporting command kill pattern fragility ("extracting a process name keyword from a shell command string for pgrep -f is fragile") is acknowledged but no concrete extraction algorithm is described. The implementation agent will need to decide how to extract keywords from command strings. This is implementation detail, not a plan gap.

## Amendments Applied

None needed -- no HIGH or BLOCKER findings.
