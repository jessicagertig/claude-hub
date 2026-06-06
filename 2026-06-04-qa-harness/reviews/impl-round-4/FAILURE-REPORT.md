# Round 4 — FAILURE REPORT

## HIGH-5: subprocess.PIPE causes child process death in detach mode

**File:** `src/qa_harness/server.py`, `_start_subprocess` method, lines 221-229

**Problem:** `_start_subprocess` uses `stdout=subprocess.PIPE, stderr=subprocess.STDOUT` for all subprocesses. When the CLI process exits after `qa-harness start` (detach mode), the pipe's read end closes. The child subprocess receives SIGPIPE on its next stdout write and dies.

Confirmed by test: `subprocess.Popen(['bash', '-c', 'while true; do echo tick; sleep 0.5; done'], stdout=subprocess.PIPE)` -- child dies when parent exits. With `stdout=subprocess.DEVNULL` -- child survives.

**Required fix:**
1. Pass `detach` to `_start_subprocess` (or make it a constructor parameter)
2. When `detach=True`: use `stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL`
3. When `detach=False` (context manager): keep `stdout=subprocess.PIPE, stderr=subprocess.STDOUT`
4. Add a test that verifies the correct stdout setting per mode
