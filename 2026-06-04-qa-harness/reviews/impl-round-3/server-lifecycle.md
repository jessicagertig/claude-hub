# server-lifecycle — Round 3 Findings

## Prior findings from Round 1/2:

### HIGH-1 (RAILS_ENV=test) -- RESOLVED (Round 1 fix verified in Round 2)
### HIGH-2 (config_path in state file) -- RESOLVED (Round 1 fix verified in Round 2)
### MED-1 (No supporting process premature exit check) -- STILL PRESENT (non-blocking)
### MED-2 (_extract_process_keyword hardcoded list) -- STILL PRESENT (non-blocking)

## NEW HIGH FINDING:

### HIGH-4: atexit handler kills server subprocesses immediately when `qa-harness start` exits

**Severity:** HIGH

**File:** `src/qa_harness/server.py`, lines 261-271 (specifically `_register_cleanup` and atexit registration)

**Finding:** The `start()` method calls `_register_cleanup()` which registers `self.stop` as an `atexit` handler. When `qa-harness start` completes and the CLI process exits (after printing "READY"), the atexit handler fires and calls `stop()`, which SIGTERM's all the subprocesses that were just started.

This is confirmed by test:
```python
atexit.register(stop)
p = subprocess.Popen(['sleep', '10'])
# script exits -> "STOP called" fires immediately
```

The analog (`InflowBootstrap`) doesn't have this problem because it's used as a context manager inside a long-running `runner.py` -- the bootstrap stays alive for the entire pipeline run. But the QA harness CLI is designed as separate start/stop commands. The `start` process exits after starting subprocesses; the `stop` process is a separate invocation that reads PIDs from the state file.

**Impact:** `qa-harness start` would appear to work (prints "READY") but the server would immediately die. The orchestrator's next command would fail because nothing is listening on the port.

**Fix:** `_register_cleanup` should NOT register atexit handlers when the CLI is used in start/stop mode. The atexit handler is only appropriate when `ServerManager` is used as a context manager (inline within a long-running process). Two options:

1. **Remove atexit entirely.** Orphaned processes are handled by the port-kill logic at the start of the next `start` invocation and by `stop`.
2. **Make atexit optional.** Add a `register_atexit=False` parameter to `start()` and only register when used as a context manager. The CLI's `cmd_start` would call `start(register_atexit=False)`.

Option 1 is simpler and matches how the CLI actually works. The signal handler registration is also problematic for the same reason -- SIGINT/SIGTERM handlers that call `stop()` and `sys.exit()` would also kill the subprocesses if the CLI process receives a signal during its brief lifetime. Remove both.
