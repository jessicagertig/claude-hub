# Plan Review — QA Verification Harness

## Pass 1: Fact Check + Completeness

### Factual Findings

**1. Line number: `InflowBootstrap` class range (CORRECTED)**
Plan stated "lines 55-228." Actual range is lines 55-227 (file is 227 lines; line 228 is an empty trailing line). Corrected in plan.md.

**2. `env = os.environ.copy()` "kept identical" claim (CORRECTED)**
Plan listed `env = os.environ.copy()` with no modifications as "Kept identical from `InflowBootstrap`." In `InflowBootstrap.start()` (line 72), env IS modified: `env["RAILS_ENV"] = "test"`. The QA harness intentionally does NOT modify env because the spec's `start_command` includes `RAILS_ENV=test` inline. This is a correct design decision but was misrepresented as "kept identical." Corrected in plan.md to clarify the difference.

**3. `_check_server_alive` "extracted for reuse" claim (CORRECTED)**
Plan said `_check_server_alive()` is "extracted for reuse by `seed.py`." In reality, `ServerManager._check_server_alive()` returns `bool` and `SeedExecutor.check_server_alive()` takes a `health_url: str` parameter and raises `SeedError`. These are two separate implementations, not shared code. Corrected in plan.md.

**4. Prompt file location vs LIFECYCLE.md convention (FLAGGED, not blocking)**
The plan puts `qa-prompt.md` at `~/claude-hub/qa-harness/prompts/qa-prompt.md`. The existing LIFECYCLE.md convention searches `~/claude-hub/<pipeline>/features/` then `~/claude-hub/features/` for prompt files. The qa-harness package path fits neither location. The Phase 8 section added to LIFECYCLE.md will need to either (a) reference the non-standard path explicitly, or (b) the prompt file should be placed at `~/claude-hub/features/qa-prompt.md` to follow convention. The implementation agent can resolve this -- it does not change the plan's substance.

**5. All file paths verified**
- `~/polymer-help-pipeline/src/help_pipeline/inflow_bootstrap.py` -- exists, contains `InflowBootstrap`, `BootstrapError`, `InflowBootstrapConfig`
- `~/polymer-help-pipeline/src/help_pipeline/cypress_api.py` -- exists, contains `CypressApi`, `CypressApiError`
- `~/polymer-help-pipeline/src/help_pipeline/seed_parser.py` -- exists, contains `parse_seed_command`, `run_seed`, `SeedCommand`, `SeedParseError`
- `~/polymer-help-pipeline/src/help_pipeline/cli.py` -- exists, contains `_setup_logging`, `main`, argparse with subcommands
- `~/polymer-help-pipeline/src/help_pipeline/runner.py` -- exists, contains `_execute_navigation_phases` at line 443, `_check_rails_health` at line 29
- `~/polymer-help-pipeline/src/help_pipeline/fallback_executor.py` -- exists, contains `execute_action`, `VALID_KINDS`
- `~/polymer-help-pipeline/src/help_pipeline/coordinator.py` -- exists, contains `RunState`, `ArticleRun`, `RunOutcome`
- `~/polymer-help-pipeline/src/help_pipeline/login.py` -- exists, contains `login_via_magic_link`, `LoginError`
- `~/polymer-help-pipeline/pyproject.toml` -- exists, matches claimed structure
- `~/polymer-help-pipeline/tests/test_inflow_bootstrap.py` -- exists
- `~/polymer-help-pipeline/tests/test_cypress_api.py` -- exists, uses `@responses.activate`
- `~/claude-hub/features/LIFECYCLE.md` -- exists, Phases 0-7 confirmed

**6. All class/method names verified**
- `BootstrapError` -- correct (line 42)
- `InflowBootstrapConfig` -- correct (line 46), has `repo_path`, `port`, `base_url`, `startup_timeout_seconds`
- `InflowBootstrap._kill_existing_processes` -- correct (line 144)
- `InflowBootstrap._kill_pids_from_command` -- correct (line 163), uses `os.system` with temp file
- `InflowBootstrap._wait_for_health` -- correct (line 192), polls with `requests.get`, timeout 5s, accepts `status_code < 500`, premature exit detection via `proc.poll()`
- `InflowBootstrap._register_cleanup` -- correct (line 213), uses atexit + signal loop
- `InflowBootstrap._signal_handler` -- correct (line 224), calls `self.stop()` then `sys.exit(128 + signum)`
- `InflowBootstrap.stop` -- correct (line 111), SIGTERM then 10s wait then SIGKILL
- `CypressApiError.__init__` -- correct (line 19), takes `status`, `endpoint`, `body`
- `CypressApi.__init__` -- correct (line 29), `requests.Session()`, `Content-Type: application/json`, timeout 120
- `CypressApi._request` -- correct (line 141), `session.request(method, url, json=json, timeout=self.timeout)`
- `_execute_navigation_phases` -- correct (line 443 of runner.py), uses `domcontentloaded`

**7. Behavior claims verified**
- "Health check accepts any status < 500" -- confirmed at `inflow_bootstrap.py` line 202: `if response.status_code < 500: return`
- "Premature exit detection via proc.poll()" -- confirmed at line 196: `if self._rails_proc.poll() is not None`
- "`bash -c` wrapper for subprocess commands" -- confirmed at line 87: `["bash", "-c", rails_cmd]`
- "`stop` with SIGTERM, 10s wait, SIGKILL fallback" -- confirmed at lines 120-126: `terminate()`, `wait(timeout=10)`, `kill()`
- "help pipeline cli.py has `_setup_logging`" -- confirmed at line 27
- "help pipeline pyproject.toml has `[project.scripts]` entry point" -- confirmed at line 34: `help-pipeline = "help_pipeline.cli:main"`
- "help pipeline uses `[tool.setuptools.packages.find]` with `where = ["src"]`" -- confirmed at line 38
- "seed_parser.py uses string parsing regex" -- confirmed at line 36: `_LINE_RE`
- "fallback_executor.py NOT used -- Playwright MCP replaces" -- correct conceptual claim
- "coordinator.py state machine pattern, dataclass-based state tracking" -- confirmed (uses `RunState` enum, `ArticleRun` dataclass)

### Completeness Check

**Spec requirement coverage:**

| Spec Requirement | Plan Coverage | Status |
|---|---|---|
| Python CLI at `~/claude-hub/qa-harness/` | Section 3, Package Structure | Covered |
| Server lifecycle (start/stop) | Section 5, `server.py` | Covered |
| Data seeding via HTTP calls | Section 5, `seed.py` | Covered |
| Cleanup | Section 5, `seed.py` `cleanup()` | Covered |
| Auth is NOT harness code | Sections 2, 5 explicitly state this | Covered |
| CLI commands: start, stop, seed, seed-endpoints, cleanup, status | Sections 5-6 | Covered |
| Pipeline config at `~/claude-hub/<pipeline>/qa-config.yml` | Section 4, 7 | Covered |
| Convergence loop (5-round cap, 2 consecutive clean passes) | Section 8, Steps 5-7 | Covered |
| Severity scale (BLOCKER/HIGH/MED/LOW) | Section 8, Step 4 | Covered |
| Findings report format (per-agent JSON, consolidated, summary) | Section 8, Steps 4-5 | Covered |
| Failure loop back to Phase 5 | Section 8, Step 7 | Covered |
| QA-COMPLETE.md gate file | Section 8, Step 8 | Covered |
| Seed planning (planner agent) | Section 8, Step 1 | Covered |
| Sequential agent execution | Section 8, Step 3 | Covered |
| Fresh agents per round | Section 8, Step 3 | Covered |
| `qa_team_size` configurable, default 3 | Section 7, `QAConfig` dataclass | Covered |
| Script runner verification layer | Section 7, `ScriptRunnerConfig` | Covered |
| Three verification layers | Section 7, `verification_layers` | Covered |
| Health check before seed/cleanup | Section 5, `seed.py` | Covered |
| Premature process exit detection | Section 5, `server.py` | Covered |
| LIFECYCLE.md Phase 8 addition | Section 4, Feature lifecycle integration | Covered |
| Temporary scripts to /tmp only | Section 8, agent instructions | Covered |
| Never modify .env | Section 5, cli.py differences | Covered |
| Never set DATABASE_URL | Section 5, server.py "Kept identical" | Covered |
| `sidekiq_command` alias support | Section 7, Implementation note | Covered |

All spec requirements are accounted for in the plan.

### Safety Check

**Global CLAUDE.md hard rules:**

1. **NEVER drop or recreate a database** -- The harness uses `DELETE /cypress/cleanup` via HTTP request to a running Rails server, which is the ONLY allowed method per global rules. Correct.

2. **Cypress cleanup endpoint MUST be called as a direct HTTP request** -- The `SeedExecutor` uses `requests.Session` to make HTTP calls to the running server. Correct.

3. **NEVER modify .env files** -- Plan explicitly states "No env loading (`apply_env`) -- the harness does not read `.env` files." Correct.

4. **NEVER set DATABASE_URL** -- Plan explicitly states "the harness MUST NOT set `DATABASE_URL` per global hard rules." The env pattern uses `os.environ.copy()` with no modifications. Correct.

5. **Data written via app interaction only** -- All data seeding goes through `/cypress/*` HTTP endpoints on a running `RAILS_ENV=test` Rails server. Correct.

6. **No direct psql access** -- Plan uses no direct database access. Correct.

7. **Hub rule: Never write files into source repos from a hub session** -- The harness writes to `/tmp` (temporary scripts) and `reviews/` (findings). No source repo writes. Correct.

No safety violations found.

---

## Pass 2: Verify Corrections + Fresh Scrutiny

### Correction Verification

**Finding 1 (line number):** Re-read plan line 247. Now reads "lines 55-227." Verified correct against `inflow_bootstrap.py` (class starts line 55, last method body ends line 227).

**Finding 2 (env modification):** Re-read plan line 264. Now reads: "note: `InflowBootstrap` actually adds `env["RAILS_ENV"] = "test"`, but the QA harness intentionally does NOT modify env because the config's server command includes `RAILS_ENV=test` inline." This is accurate. The spec's `start_command` (SPEC.md line 64-66) has `RAILS_ENV=test` as part of the shell command string. Correction is clean, no inconsistencies introduced.

**Finding 3 (_check_server_alive):** Re-read plan line 254. Now reads: "_check_server_alive() is new -- a quick health check returning bool. seed.py has its own check_server_alive method that takes a health_url parameter and raises SeedError." Accurate. The two are separate implementations. Correction is clean.

### Fresh Scrutiny Findings

**8. Context manager not in ServerManager API (NOTED)**
The plan's `ServerManager` API listing (lines 204-245) does not include `__enter__`/`__exit__`. But `test_server.py` includes "Context manager calls start and stop." The analog `InflowBootstrap` has both methods (lines 133-138). The implementation agent will see the test and add the methods. Not a blocking gap -- the test plan documents the expected behavior, and the analog provides the pattern.

**9. `SeedExecutor.check_server_alive` health URL construction (NOTED)**
`SeedExecutor.__init__` receives `base_url` but `check_server_alive` takes `health_url`. The full health URL is `base_url + health_check_path` from `ServerConfig`. The CLI handler (`cmd_seed`, `cmd_cleanup`) would need to construct this from the config and pass it in. The plan does not explicitly document this wiring, but it is straightforward and the implementation agent will handle it.

**10. Spec `status` command says "what user is logged in" (NOTED)**
The spec's `qa-harness status` says "Report whether the server is running, what port, what user is logged in." The plan omits "what user is logged in" from the status output, replacing it with PIDs and uptime. This is architecturally correct -- the harness CLI has no way to know browser session state (that lives in the Playwright MCP). The spec has a stale mention here. The plan's decision is sound.

**11. Prompt file location (reiterated from Pass 1)**
No new information. The implementation agent should either place `qa-prompt.md` at `~/claude-hub/features/qa-prompt.md` to follow the LIFECYCLE.md convention, or explicitly reference `~/claude-hub/qa-harness/prompts/qa-prompt.md` in the Phase 8 section of LIFECYCLE.md.

**12. No inconsistencies introduced by Pass 1 corrections**
All three corrections are contained to their specific lines and do not affect surrounding text or other sections.

---

## Verdict: APPROVED

Three minor factual corrections applied (line number, env modification characterization, _check_server_alive reuse claim). Four non-blocking notes for the implementation agent. No safety violations. Every spec requirement has corresponding plan coverage. Plan substance is unchanged by corrections.

---

## Reviewed Plan

The plan at `/Users/jessica/claude-hub/2026-06-04-qa-harness/plan.md` has been corrected in place and is ready for the implementation agent. The three corrections were:

1. **Line 247:** `InflowBootstrap` class range corrected from "lines 55-228" to "lines 55-227"
2. **Line 264:** `env = os.environ.copy()` clarified as a deliberate divergence from `InflowBootstrap` (which modifies env), not "kept identical"
3. **Line 254:** `_check_server_alive()` described as a new method with separate `SeedExecutor.check_server_alive` implementation, not "extracted for reuse"

### Implementation notes for the agent

- **Prompt file location:** Decide whether `qa-prompt.md` goes at `~/claude-hub/features/qa-prompt.md` (follows LIFECYCLE.md convention) or `~/claude-hub/qa-harness/prompts/qa-prompt.md` (plan's current location). If the latter, reference the full path in the Phase 8 section of LIFECYCLE.md.
- **ServerManager context manager:** Add `__enter__`/`__exit__` methods to `ServerManager` (the test plan expects them, the analog has them).
- **Health URL wiring:** CLI handlers for `seed` and `cleanup` need to construct `health_url` from `config.server.base_url + config.server.health_check_path` and pass it to `SeedExecutor.check_server_alive`.
- **`status` command:** Omit "what user is logged in" (architecturally impossible for the CLI). PIDs and uptime are correct.
