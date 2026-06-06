# Server Lifecycle — Pass 2

## Pass 1 Corrections Verification

No amendments were applied in Pass 1 for this angle. N/A.

## Fresh Scrutiny

- **State file location:** The plan uses `/tmp/qa-harness-state.json`. On macOS, `/tmp` is a symlink to `/private/tmp` and is periodically cleaned. If the machine reboots between `start` and `stop`, the state file is gone. The plan acknowledges this in Risk #1 and mitigates with PID liveness checks and lsof fallback. Acceptable.

- **Signal handler re-registration:** The plan says `_register_cleanup` registers atexit + SIGINT/SIGTERM handlers. The analog (inflow_bootstrap.py lines 213-221) uses a `_cleanup_registered` flag to avoid re-registration. The plan's `ServerManager` should do the same. This is implied by "adapted from inflow_bootstrap.py" but not explicitly stated. Implementation detail, not a plan gap.

- **cwd for subprocesses:** The plan says "`cwd` for subprocesses is `source_repo` from the top-level config, not a `repo_path` on the server config." The analog uses `self.config.repo_path` (inflow_bootstrap.py line 89). The plan passes `source_repo` as a constructor parameter to `ServerManager`. This is correct -- the cwd needs to be the source repo so `bundle exec` finds the Gemfile.

- **Health check URL construction:** The plan's `_wait_for_health` polls `GET base_url+health_check_path`. The analog polls `requests.get(self.config.base_url, timeout=5)` which is just the base URL. The plan adds `health_check_path` (default "/") which is more flexible. No conflict.

- **Context manager support:** The plan's `server.py` test list includes "Context manager calls start and stop." The analog has `__enter__` and `__exit__` (lines 133-138). The plan's `ServerManager` class definition doesn't mention `__enter__`/`__exit__` but the test implies it. Implementation detail.

## Completeness Sweep

All spec requirements for server lifecycle remain addressed after Pass 1. No gaps found.

## Findings

No BLOCKER, HIGH, or MED findings.

## Amendments Applied

None needed.
