# server-lifecycle — Round 4 Findings

## Prior findings:

### HIGH-1 (RAILS_ENV) -- RESOLVED
### HIGH-2 (config_path) -- RESOLVED
### HIGH-4 (atexit kills subprocesses) -- RESOLVED in Round 3
### MED-1 (supporting process premature exit) -- STILL PRESENT (non-blocking)
### MED-2 (hardcoded keyword list) -- STILL PRESENT (non-blocking)

## NEW HIGH FINDING:

### HIGH-5: subprocess.PIPE causes child process death when parent exits (detach mode)

**Severity:** HIGH

**File:** `src/qa_harness/server.py`, `_start_subprocess` method, lines 221-229

**Finding:** `_start_subprocess` uses `stdout=subprocess.PIPE` for all subprocesses. When `detach=True` (CLI mode) and the parent Python process exits after `start`, the pipe's read end closes. The child process receives SIGPIPE on its next stdout write and dies.

Confirmed by test:
```
# With subprocess.PIPE: child dies when parent exits
# With subprocess.DEVNULL: child survives
```

This would cause `qa-harness start` to start the server, print "READY", exit, and then the server would die on its first log line to stdout -- identical behavior to HIGH-4 (atexit issue) but via a different mechanism.

**Impact:** Even with the HIGH-4 fix (detach=True skips atexit), the server still dies because of the broken pipe.

**Fix:** In detach mode, use `stdout=subprocess.DEVNULL` and `stderr=subprocess.DEVNULL` (or redirect to a log file). In context-manager mode, keep `stdout=subprocess.PIPE` so the parent can read subprocess output.

## NEW MED FINDING:

### MED-3: stop_from_state_file does not wait/SIGKILL

**Severity:** MED

**Finding:** `stop_from_state_file` only sends SIGTERM but does not wait for processes to exit or escalate to SIGKILL. The spec says "Wait up to 10 seconds for graceful shutdown. SIGKILL if they don't exit." However, `stop_from_state_file` works with raw PIDs (not Popen objects), so it cannot call `.wait()`. It would need `os.waitpid()` or a timed `os.kill(pid, 0)` loop followed by `os.kill(pid, signal.SIGKILL)`.

Non-blocking because the next `start` invocation kills anything on the port anyway.
