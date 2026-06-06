# Round 3 — FAILURE REPORT

## HIGH-4: atexit handler kills server subprocesses on CLI exit

**File:** `src/qa_harness/server.py`, `_register_cleanup` method (lines 261-271)

**Problem:** `start()` registers `self.stop` as an `atexit` handler and installs `SIGINT`/`SIGTERM` signal handlers that call `stop()`. When the `qa-harness start` CLI exits after printing "READY", the atexit handler fires and kills all subprocesses immediately.

Confirmed by running:
```python
atexit.register(stop)
p = subprocess.Popen(['sleep', '10'])
# script exits -> atexit fires -> stop() kills the process
```

The analog (`InflowBootstrap`) uses atexit because it runs as a context manager within a long-running process. The QA harness CLI is designed as separate start/stop commands where `start` exits after spawning subprocesses. The atexit pattern is incompatible with this usage.

**Required fix:**
1. Remove `_register_cleanup()` call from `start()` in the CLI path
2. Keep atexit/signal handlers ONLY for context manager usage (`__enter__`/`__exit__`)
3. Best approach: add a `detach=True` parameter to `start()`. When `detach=True` (CLI mode), skip `_register_cleanup()`. When `detach=False` (context manager mode), register cleanup handlers.
4. `cmd_start` calls `start(detach=True)`. Context manager's `__enter__` calls `start(detach=False)`.
5. Update tests accordingly -- the existing tests mock Popen so they don't see the atexit issue, but a test should verify that `start(detach=True)` does NOT register atexit.
