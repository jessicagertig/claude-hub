# Server Lifecycle — Round 3 Findings

## Angle: server-lifecycle

### Prior findings review

**Round 1 MED (carried): No health check for supporting process death.** Unchanged. Matches analog.

**Round 1 MED (carried): `stop_from_state_file` no wait.** Unchanged. Mitigated by `start`.

### New findings

None. Deep-dived into:
- Error path in `cmd_start`: if `_wait_for_health` raises `ServerError`, the atexit handler (registered before health check) will clean up orphaned processes when the CLI process exits. Verified correct.
- Signal handler during startup: if SIGINT/SIGTERM arrives during `start()`, `_signal_handler` calls `stop()` which terminates all started processes, then exits. Correct.
- `env = os.environ.copy()` is a read-only copy. The harness does NOT mutate it (unlike `inflow_bootstrap.py` which adds `RAILS_ENV=test`). This is intentional -- the server command contains `RAILS_ENV=test` inline. No `DATABASE_URL` risk.
