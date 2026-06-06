# Server Lifecycle — Round 2 Findings

## Angle: server-lifecycle

### Prior findings review

**Round 1 Finding 2 (MED): No health check for supporting process death.** Still present, still MED. Matches analog behavior. No change.

**Round 1 Finding 3 (MED): `stop_from_state_file` no wait.** Still present, still MED. Mitigated by `_kill_existing_processes` in `start`.

### New findings

None. Reviewed:
- `_kill_existing_processes`: correctly handles both port-based and keyword-based process termination
- `_wait_for_health`: correct polling loop with premature exit detection, timeout handling
- `_register_cleanup`: atexit + signal handlers, idempotent via `_cleanup_registered` flag
- `stop`: SIGTERM/wait/SIGKILL pattern matches analog
- `_start_subprocess`: `bash -c` wrapper, correct `cwd`, `env` copy
- `_write_state_file`/`_read_state_file`/`_remove_state_file`: correct JSON serialization, defensive error handling
- `status`: verifies PID liveness via `os.kill(pid, 0)`, computes uptime from state file
- `stop_from_state_file`: fallback to `lsof` when state file missing
- `_extract_process_keyword`: handles nvm preamble, known keywords, fallback to exec-next-word
- State file at fixed path `/tmp/qa-harness-state.json` is acceptable for single-pipeline operation per spec
