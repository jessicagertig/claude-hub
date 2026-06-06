# Server Lifecycle — Round 1 Findings

## Angle: server-lifecycle

### Finding 1: `_execute_step` hardcodes status_code 200 (HIGH)

In `seed.py`, `_execute_step` always returns `"status_code": 200` in the result dict regardless of the actual HTTP response status code. The response object is not propagated from `_request`, so the actual status code is lost.

```python
def _execute_step(self, step: dict) -> dict:
    ...
    try:
        result = self._request(method, path, body)
        return {
            "endpoint": f"{method} {path}",
            "status_code": 200,          # <-- hardcoded
            "response_body": result,
        }
```

The `_request` method returns the parsed JSON body (or None for 204), not the response object. So `_execute_step` cannot report the actual status code.

This is a HIGH because the CLI's `cmd_seed` prints `result['status_code']` to stdout, and QA agents use this output to verify seed operations succeeded. A misleading "200" when the actual status was 201 or 204 produces incorrect evidence in QA findings.

**Fix:** Have `_request` return a tuple of `(status_code, body)` or a result dict, so `_execute_step` can include the real status code.

### Finding 2: No health check for supporting process death during QA rounds (MED)

`_wait_for_health` checks for premature exit of the **main server process** only (via `self._procs[0]`). If a supporting process (e.g., Sidekiq) dies during a QA round, the harness does not detect it. The spec mentions this as an open question (REVIEW-ANGLES.md: "Does the spec handle Sidekiq dying independently of Rails?").

The analog (`inflow_bootstrap.py`) also only checks the Rails process, so this is consistent with the analog. But in the QA harness context, where rounds may run for extended periods, a dead Sidekiq could cause async-dependent features to silently fail.

This is MED because it matches the analog behavior and is documented as an open question.

### Finding 3: `stop_from_state_file` does not wait for graceful shutdown (MED)

The `stop_from_state_file` function sends SIGTERM to PIDs from the state file but does not wait for them to actually terminate. Contrast with `ServerManager.stop()` which does `proc.wait(timeout=10)` with SIGKILL fallback.

If the orchestrator calls `qa-harness stop` and then immediately starts a new round or exits, processes may still be running. The next `start` mitigates this (it kills by port first), but the `STOPPED` output printed by `cmd_stop` is premature.

This is MED because the `start` command's `_kill_existing_processes` provides a safety net.

### Finding 4: Analog match is strong (PASS NOTE)

The core lifecycle -- `_kill_pids_from_command` via `os.system` with temp files, `_wait_for_health` polling with premature exit detection, `_register_cleanup` with atexit + signal handlers, `stop` with SIGTERM/SIGKILL/wait -- matches `inflow_bootstrap.py` almost line-for-line. The `bash -c` wrapper, `cwd` setting, and `env = os.environ.copy()` are all preserved. Good.
