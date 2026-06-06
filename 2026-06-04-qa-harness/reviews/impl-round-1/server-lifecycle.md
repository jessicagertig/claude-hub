# server-lifecycle — Round 1 Findings

## HIGH-1: No defensive RAILS_ENV=test enforcement

**Severity:** HIGH

**File:** `src/qa_harness/server.py`, line 50

**Finding:** The `start` method copies the current environment verbatim (`env = os.environ.copy()`) without setting `RAILS_ENV=test`. The analog (`inflow_bootstrap.py`, line 72) explicitly sets `env["RAILS_ENV"] = "test"` as a safety measure.

The plan (section 5, server.py "Kept identical" notes) says this omission is intentional because "the config's server command includes RAILS_ENV=test inline." But the spec's hard rules (section "Constraints and requirements / Test environment safety") say `RAILS_ENV=test` always -- this is a HARD RULE. Relying on the config command to include it inline means:

1. A config author can omit it and the harness will silently start a dev/production server
2. The spec says the harness must enforce this, not delegate enforcement to config authors
3. The analog enforces it defensively even though its hardcoded commands also include it

The plan's reasoning directly contradicts the spec's hard rule. The harness MUST set `RAILS_ENV=test` in the subprocess environment, just as the analog does.

**Fix:** Add `env["RAILS_ENV"] = "test"` after `env = os.environ.copy()` in `ServerManager.start()`.

---

## HIGH-2: State file missing config_path

**Severity:** HIGH

**File:** `src/qa_harness/server.py`, lines 273-286 and `src/qa_harness/cli.py`, lines 57-79

**Finding:** The plan (section 5, CLI design, line ~389) specifies the state file must include `"config_path"`. The implementation's `_write_state_file` omits it. This causes a usability problem: `qa-harness stop` requires loading the config (to construct `ServerConfig` for the fallback kill-by-port), but if the user is in a different working directory than when they ran `start`, `resolve_config_path` fails because there's no `qa-config.yml` in the cwd.

The qa-prompt.md (Step 8, line 225) shows `qa-harness stop --config ~/claude-hub/<pipeline>/qa-config.yml` -- so the orchestrator always passes `--config`. But the state file SHOULD store config_path for robustness and to match the plan's specification.

**Fix:** Add `config_path` parameter to `_write_state_file` and store it in the state JSON. Have `cmd_stop` try reading it from the state file as a fallback before failing on config resolution.

---

## MED-1: No check for supporting process premature exit during health polling

**Severity:** MED

**File:** `src/qa_harness/server.py`, lines 225-228

**Finding:** `_wait_for_health` only checks premature exit on `self._procs[0]` (the main server process). If a supporting process (e.g., Sidekiq) dies during startup, the harness won't detect it until later. The analog only checks Rails too (line 196), so this matches the analog. Noting as MED because supporting process death during startup is a legitimate edge case.

---

## MED-2: _extract_process_keyword has a limited hardcoded keyword list

**Severity:** MED

**File:** `src/qa_harness/server.py`, lines 369-371

**Finding:** The keyword extraction for `pgrep -f` relies on a hardcoded list: `["sidekiq", "puma", "unicorn", "rails", "node", "next"]`. A pipeline with a non-listed supporting process (e.g., a custom worker) would fall through to the "first word after exec" heuristic, which may match too broadly or not at all. The plan acknowledges this risk (section 11, Risk 2) but doesn't mitigate it.

Not blocking because the primary kill mechanism uses tracked PIDs from Popen, and pgrep is only for orphan cleanup.
