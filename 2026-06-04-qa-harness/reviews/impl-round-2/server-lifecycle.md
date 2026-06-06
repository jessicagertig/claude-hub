# server-lifecycle — Round 2 Findings

## Prior findings reviewed:

### HIGH-1 (RAILS_ENV=test enforcement) -- RESOLVED
- `server.py` line 52-56 now sets `env["RAILS_ENV"] = "test"` defensively after `os.environ.copy()`
- Comment explains the rationale and references the analog
- New test `test_start_sets_rails_env_test` verifies all Popen calls receive `RAILS_ENV=test` in env
- Matches the analog's pattern (`inflow_bootstrap.py` line 72)

### HIGH-2 (State file missing config_path) -- RESOLVED
- `ServerManager.__init__` now accepts `config_path: Optional[str] = None` (line 35)
- `_write_state_file` includes `"config_path": self.config_path` in the state JSON (line 282)
- `cmd_start` passes `config_path=config_path` to `ServerManager` (cli.py line 48)
- `cmd_stop` reads `config_path` from state file before falling back to `resolve_config_path` (cli.py lines 65-73)
- `cmd_status` has the same fallback (cli.py lines 199-207)

### MED-1 (No supporting process premature exit check) -- STILL PRESENT (MED, non-blocking)
### MED-2 (_extract_process_keyword hardcoded list) -- STILL PRESENT (MED, non-blocking)

## New findings this round:

None.

## Verification of fixes:
- Tests pass: 72/72
- State file includes config_path (verified by reading `_write_state_file`)
- RAILS_ENV=test is set (verified by new test and reading `start()`)
- Cleanup of redundant `import json as _json` confirmed -- now uses module-level `json`
