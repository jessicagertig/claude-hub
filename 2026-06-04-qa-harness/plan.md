# QA Verification Harness — Implementation Plan

## 1. Summary

The QA harness is a Python CLI package (`qa-harness`) that lives at `~/claude-hub/qa-harness/`. It provides pipeline-specific infrastructure for the new Phase 8 (QA Verification) of the feature development lifecycle. After implementation passes code review (Phase 6) and hardening (Phase 7), Phase 8 dispatches fresh QA agents to verify the feature actually works in a running test environment.

The harness handles three things the Playwright MCP and agents cannot: server lifecycle (start/stop test servers), data seeding (HTTP calls to seed endpoints), and cleanup (resetting the database between tests). Everything else -- browser automation, authentication, judgment about what to test -- is agent-driven, not harness code.

The orchestration logic (convergence loop, agent dispatch, findings consolidation) lives in the Phase 8 prompt file, not in the harness Python code. The harness is a dumb CLI that agents call via Bash.

## 2. Pattern Precedents

### From the help pipeline (`~/polymer-help-pipeline/src/help_pipeline/`)

| Help pipeline file | What we take | How the QA harness differs |
|---|---|---|
| `inflow_bootstrap.py` | Server lifecycle: `_kill_existing_processes`, subprocess Popen with `bash -c` wrapper for nvm, `_wait_for_health` polling, `_register_cleanup` with atexit+signal handlers, `stop` with SIGTERM/SIGKILL fallback | Config-driven instead of hardcoded. Server commands come from `qa-config.yml`, not code. Supporting processes (like sidekiq) are a list, not a named field. Health check URL and timeout are config values. |
| `cypress_api.py` | HTTP request wrapper with `requests.Session`, Content-Type header, error class with status+endpoint+body, timeout parameter | Generic instead of per-endpoint methods. The QA harness does not have `create_default_user()` etc. It reads endpoint definitions from the config and executes seed plans (JSON arrays of `{method, path, body}` objects) generically. |
| `seed_parser.py` | Concept of structured seed commands and sequential dispatch | Replaced entirely by JSON seed plans. No string parsing needed -- agents and the seed planner produce JSON directly. Validation is against the config's `available_endpoints` catalog. |
| `cli.py` | argparse CLI with subcommands, `_setup_logging`, return codes, lazy imports | Same pattern: argparse with subcommands (`start`, `stop`, `seed`, `seed-endpoints`, `cleanup`, `status`). |
| `runner.py` | Bootstrap lifecycle wrapping work (`bootstrap.start()` / `try` / `finally: bootstrap.stop()`), health check before each unit of work | Pattern applies to the Phase 8 orchestrator prompt (start once, run agents, stop once), not to harness code. The harness CLI commands are stateless -- `start` starts, `stop` stops, agents call them separately. |
| `coordinator.py` | State machine pattern, dataclass-based state tracking | NOT used. The QA harness is stateless between CLI invocations. State (round counts, findings, convergence) is tracked by the orchestrator prompt using filesystem artifacts. |
| `login.py` | Magic-link login flow documentation | NOT adapted into code. The login flow is documented in `qa-config.yml` `auth.instructions` and executed by QA agents via Playwright MCP tools. The help pipeline's `login.py` is a useful reference for what the auth instructions should describe. |

### From the help pipeline packaging

| File | What we take |
|---|---|
| `pyproject.toml` | Package structure: `[build-system]` with setuptools, `[project]` metadata, `[project.scripts]` entry point, `[tool.setuptools.packages.find]` with `where = ["src"]`, `[tool.pytest.ini_options]` |
| `__init__.py` | Version string |
| `__main__.py` | `python -m qa_harness` support |
| `tests/test_inflow_bootstrap.py` | Test pattern: mock subprocess.Popen and requests.get, test start/stop/health-check-timeout |
| `tests/test_cypress_api.py` | Test pattern: `@responses.activate` decorator for HTTP mocking |

## 3. Package Structure

```
~/claude-hub/qa-harness/
├── pyproject.toml
├── src/
│   └── qa_harness/
│       ├── __init__.py
│       ├── __main__.py
│       ├── cli.py
│       ├── config.py
│       ├── server.py
│       ├── seed.py
│       └── errors.py
└── tests/
    ├── __init__.py
    ├── conftest.py
    ├── test_cli.py
    ├── test_config.py
    ├── test_server.py
    └── test_seed.py
```

The Phase 8 orchestrator prompt already exists at `~/claude-hub/features/qa-prompt.md` (the standard location per the lifecycle's prompt file resolution mechanism). It is not part of the qa-harness Python package.

## 4. Files to Create

### Python package (`src/qa_harness/`)

| File | Purpose |
|---|---|
| `__init__.py` | Package init with `__version__` |
| `__main__.py` | `python -m qa_harness` entry point |
| `cli.py` | argparse CLI with subcommands: `start`, `stop`, `seed`, `seed-endpoints`, `cleanup`, `status` |
| `config.py` | Load and validate `qa-config.yml`, expose typed dataclass config |
| `server.py` | Server lifecycle: kill existing, start subprocesses, health check, stop, signal handlers |
| `seed.py` | Seed plan execution: load JSON, validate against catalog, execute HTTP calls. Also cleanup and seed-endpoints listing |
| `errors.py` | Custom exception classes: `QAHarnessError`, `ServerError`, `SeedError`, `ConfigError` |

### Tests (`tests/`)

| File | Purpose |
|---|---|
| `__init__.py` | Empty |
| `conftest.py` | Shared fixtures: sample configs, temp directories |
| `test_cli.py` | CLI argument parsing, subcommand dispatch, return codes |
| `test_config.py` | Config loading, validation, defaults, missing fields |
| `test_server.py` | Server start/stop/health-check lifecycle (mocked subprocesses) |
| `test_seed.py` | Seed plan loading, validation, HTTP execution, cleanup |

### Config

| File | Purpose |
|---|---|
| `pyproject.toml` | Package metadata, dependencies, entry point, test config |

**Note:** The Phase 8 orchestrator prompt already exists at `~/claude-hub/features/qa-prompt.md`. It does not need to be created.

### Pipeline config (NOT in the qa-harness package -- lives in the pipeline scratchpad)

| File | Purpose |
|---|---|
| `~/claude-hub/inflow-ats/qa-config.yml` | Inflow-ats pipeline QA configuration (first pipeline to support) |

### Feature lifecycle integration (verification of existing files, NOT in qa-harness)

| File | Change |
|---|---|
| `~/claude-hub/features/LIFECYCLE.md` | Verify existing Phase 8 section is consistent with the spec (Phase 8 already exists in LIFECYCLE.md) |

## 5. Module-by-Module Design

### `errors.py`

**What it does:** Defines exception hierarchy for the harness.

**Classes:**
- `QAHarnessError(Exception)` -- base class for all harness errors
- `ConfigError(QAHarnessError)` -- config loading/validation failures
- `ServerError(QAHarnessError)` -- server lifecycle failures (start timeout, premature exit, health check)
- `SeedError(QAHarnessError)` -- seed execution failures (HTTP errors, validation errors)

**Analog:** `BootstrapError` in `inflow_bootstrap.py`, `CypressApiError` in `cypress_api.py`.

**Differences:** Unified hierarchy under `QAHarnessError` instead of separate standalone exception classes.

---

### `config.py`

**What it does:** Loads `qa-config.yml`, validates it, and exposes a typed dataclass.

**Key classes/functions:**

```python
@dataclass
class ServerConfig:
    start_command: str
    base_url: str
    port: int
    health_check_path: str = "/"
    startup_timeout_seconds: int = 180
    supporting_commands: list[str] = field(default_factory=list)
    # supporting_commands replaces hardcoded sidekiq_command --
    # it's a list so any pipeline can declare N supporting processes

@dataclass
class SeedEndpoint:
    method: str           # GET, POST, DELETE
    path: str
    params: dict[str, str] = field(default_factory=dict)    # param_name -> type_hint
    requires: list[str] = field(default_factory=list)        # paths that must be called first
    creates: str = ""     # human-readable description
    returns: str = ""     # human-readable description of return value

@dataclass
class SeedConfig:
    cleanup_endpoint: str  # e.g., "DELETE /cypress/cleanup"
    available_endpoints: list[SeedEndpoint]

@dataclass
class AuthConfig:
    default_user: str
    instructions: str

@dataclass
class ScriptRunnerConfig:
    command: str
    file_extension: str = ".rb"

@dataclass
class QAConfig:
    pipeline: str
    source_repo: str
    server: ServerConfig | None = None    # None for non-web pipelines
    seed: SeedConfig | None = None
    auth: AuthConfig | None = None
    script_runner: ScriptRunnerConfig | None = None
    verification_layers: list[str] = field(default_factory=list)
    qa_team_size: int = 3

def load_config(config_path: str) -> QAConfig:
    """Load and validate qa-config.yml. Raises ConfigError on problems."""

def resolve_config_path(explicit_path: str | None = None) -> str:
    """Find the config file. Checks explicit path first, then cwd for qa-config.yml."""
```

**Analog:** `InflowBootstrapConfig` in `inflow_bootstrap.py` (a single dataclass with hardcoded defaults).

**Differences:** Multiple nested dataclasses reflecting the YAML structure. All pipeline-specific values come from the config file, not code. `supporting_commands` is a list instead of a single `sidekiq_command` field, so any pipeline can declare multiple supporting processes. `server`, `seed`, `auth` are all optional for non-web pipeline support.

**Validation rules in `load_config`:**
- `pipeline` and `source_repo` are required strings
- If `server` is present: `start_command`, `base_url`, `port` are required
- If `seed` is present: `cleanup_endpoint` is required, `available_endpoints` must be a list
- Each `SeedEndpoint` must have `method` and `path`
- `verification_layers` entries must be from the known set: `script_runner`, `rspec`, `cypress`, `playwright_mcp`
- `qa_team_size` must be a positive integer, defaults to 3

---

### `server.py`

**What it does:** Manages the test server and supporting processes as subprocesses. Directly adapted from `inflow_bootstrap.py`.

**Key classes/functions:**

```python
class ServerManager:
    def __init__(self, config: ServerConfig, source_repo: str):
        ...

    def start(self) -> None:
        """Kill existing processes on port, start server + supporting processes,
        poll health check, print READY."""

    def stop(self) -> None:
        """SIGTERM all subprocesses, wait 10s, SIGKILL if needed, print STOPPED."""

    def status(self) -> dict:
        """Return dict with is_running, port, pid, uptime."""

    def is_running(self) -> bool:
        ...

    # Internal methods (private, adapted from inflow_bootstrap.py):
    def _kill_existing_processes(self) -> None:
        """Kill PIDs on configured port via lsof, kill supporting processes via pgrep."""

    def _kill_pids_from_command(self, command: str, label: str) -> bool:
        """Run a shell command that prints PIDs, SIGTERM each."""

    def _start_subprocess(self, command: str, label: str) -> subprocess.Popen:
        """Start a subprocess via bash -c wrapper. Logs command and PID."""

    def _wait_for_health(self) -> None:
        """Poll GET base_url+health_check_path every 1s. Accept status < 500.
        Check for premature process exit on each iteration.
        Raise ServerError on timeout."""

    def _register_cleanup(self) -> None:
        """atexit + SIGINT/SIGTERM handlers."""

    def _signal_handler(self, signum, frame) -> None:
        """Stop all subprocesses, exit with 128+signum."""

    def _check_server_alive(self) -> bool:
        """Quick health check -- hit the health endpoint, return True if < 500."""
```

**Analog:** `InflowBootstrap` class in `inflow_bootstrap.py` (lines 55-227).

**Differences from `InflowBootstrap`:**
1. `start_command` and `supporting_commands` come from config, not hardcoded Rails/Sidekiq strings
2. Supporting processes are iterated from a list instead of being two named fields (`_rails_proc`, `_sidekiq_proc`)
3. `_procs: list[tuple[subprocess.Popen, str]]` stores `(process, label)` pairs instead of named fields
4. `status()` method is new (returns machine-readable status for the `qa-harness status` CLI command)
5. `_check_server_alive()` is new -- a quick health check returning bool. `seed.py` has its own `check_server_alive` method that takes a `health_url` parameter and raises `SeedError` (seed/cleanup commands verify server is alive before making HTTP calls -- spec amendment from Round 1)
6. The `_kill_existing_processes` method also kills processes matching names from `supporting_commands` (not just sidekiq). It extracts a process name keyword from each supporting command for `pgrep -f`.
7. `cwd` for subprocesses is `source_repo` from the top-level config, not a `repo_path` on the server config

**Kept identical from `InflowBootstrap`:**
- `_kill_pids_from_command` using temp file redirection via `os.system` (not `subprocess.run`, to avoid interfering with Popen mocks in tests)
- `_wait_for_health` polling loop with `time.sleep(1)`, premature exit detection via `proc.poll()`, `requests.get` with 5s timeout
- `_register_cleanup` with atexit + signal loop
- `stop` with SIGTERM, 10s wait, SIGKILL fallback
- `bash -c` wrapper pattern for subprocess commands
- `env = os.environ.copy()` -- note: `InflowBootstrap` actually adds `env["RAILS_ENV"] = "test"`, but the QA harness intentionally does NOT modify env because the config's server command includes `RAILS_ENV=test` inline. The harness MUST NOT set `DATABASE_URL` per global hard rules

---

### `seed.py`

**What it does:** Executes seed plans, runs cleanup, and lists available endpoints.

**Key classes/functions:**

```python
class SeedExecutor:
    def __init__(self, seed_config: SeedConfig, base_url: str):
        self.seed_config = seed_config
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({"Content-Type": "application/json"})
        self.timeout = 120

    def check_server_alive(self, health_url: str) -> None:
        """Hit health check endpoint. Raise SeedError with actionable message
        if server is not responding."""

    def cleanup(self) -> None:
        """Parse cleanup_endpoint (e.g., 'DELETE /cypress/cleanup'), execute it.
        Verify server alive first."""

    def execute_plan(self, plan_path: str) -> list[dict]:
        """Load JSON seed plan from file, validate against catalog,
        call cleanup first, then execute each step sequentially.
        Return list of results [{endpoint, status, response}].
        Verify server alive first."""

    def validate_plan(self, plan: list[dict]) -> list[str]:
        """Validate a seed plan against the available_endpoints catalog.
        Return list of error messages (empty = valid).
        Checks: method+path exists in catalog, required params present,
        ordering respects 'requires' dependencies."""

    def list_endpoints(self) -> str:
        """Format available_endpoints as human-readable text for the seed planner.
        Shows method, path, params with types, creates/returns description,
        and dependency ordering."""

    def _execute_step(self, step: dict) -> dict:
        """Execute one seed plan step: {method, path, body?}.
        Return {endpoint, status_code, response_body}."""

    def _request(self, method: str, path: str, body: dict | None = None) -> dict:
        """HTTP request wrapper. Adapted from CypressApi._request."""
```

**Analog:** `CypressApi` in `cypress_api.py` + `seed_parser.py`.

**Differences:**
1. No per-endpoint methods (`create_default_user`, `create_default_job`, etc.). The QA harness is generic -- it reads `{method, path, body}` from JSON plans and executes them via `_request`. This is the key architectural difference from the help pipeline.
2. Seed plans are JSON files, not parsed strings. No string parsing regex needed.
3. `validate_plan` checks plans against the config catalog at parse time, not at HTTP call time (spec review MED finding #6).
4. `check_server_alive` is called before any HTTP operation (spec amendment from Round 1).
5. `cleanup` parses the `cleanup_endpoint` config string (e.g., `"DELETE /cypress/cleanup"`) into method+path, rather than hardcoding the endpoint.
6. `list_endpoints` is new -- formats the catalog for the seed planner agent to read.

---

### `cli.py`

**What it does:** argparse CLI with subcommands. Entry point for the `qa-harness` console script.

**Key functions:**

```python
def _setup_logging(verbose: bool) -> None:
    """Configure logging. Adapted from help pipeline cli.py."""

def cmd_start(args) -> int:
    """Start the test server. Loads config, creates ServerManager, calls start().
    Prints READY on success, returns 0. Returns 1 on ServerError."""

def cmd_stop(args) -> int:
    """Stop the test server. Reads PID file or finds processes.
    Prints STOPPED. Returns 0."""

def cmd_seed(args) -> int:
    """Execute a seed plan. Loads config, creates SeedExecutor,
    calls execute_plan(args.plan). Prints each step result. Returns 0/1."""

def cmd_seed_endpoints(args) -> int:
    """List available seed endpoints. Loads config, creates SeedExecutor,
    calls list_endpoints(). Prints to stdout. Returns 0."""

def cmd_cleanup(args) -> int:
    """Run cleanup. Loads config, creates SeedExecutor, calls cleanup().
    Returns 0/1."""

def cmd_status(args) -> int:
    """Report server status. Loads config, creates ServerManager,
    calls status(). Prints status dict. Returns 0."""

def main(argv: list[str] | None = None) -> int:
    """Main entry point. Parse args, dispatch to handler."""
```

**CLI argument structure:**

```
qa-harness [-v|--verbose] <subcommand> [args]

Subcommands:
  start           --config PATH    Start test server (default: ./qa-config.yml)
  stop            --config PATH    Stop test server
  seed            --plan PATH --config PATH    Execute seed plan
  seed-endpoints  --config PATH    List available seed endpoints
  cleanup         --config PATH    Run cleanup
  status          --config PATH    Report server status
```

All subcommands accept `--config` to specify the config file path. Default resolution: look for `qa-config.yml` in the current directory, then check `QA_CONFIG_PATH` env var.

**Analog:** `cli.py` in the help pipeline.

**Differences:** Subcommands are `start`/`stop`/`seed`/etc. instead of `run-drift`/`reads`/`writes`. No env loading (`apply_env`) -- the harness does not read `.env` files. No pipeline-specific setup (Intercom client, etc.).

**Process state between start and stop:** The `start` command writes a small JSON state file to `/tmp/qa-harness-state.json` containing the PIDs of all started processes, the config path used, and the base URL. The `stop` command reads this file to find processes to kill. The `status` command reads it to report state. This avoids needing a daemon or persistent server -- each CLI invocation is stateless except for the state file.

State file format:
```json
{
  "config_path": "/Users/jessica/claude-hub/inflow-ats/qa-config.yml",
  "base_url": "http://app.lvh.me:5007",
  "port": 5007,
  "pids": [12345, 12346, 12347],
  "labels": ["server", "sidekiq"],
  "started_at": "2026-06-04T18:00:00Z"
}
```

---

### `__init__.py`

```python
"""QA Verification Harness for the Claude Code feature development lifecycle."""
__version__ = "0.1.0"
```

---

### `__main__.py`

```python
"""Allow `python -m qa_harness` to run the CLI."""
from qa_harness.cli import main
import sys
if __name__ == "__main__":
    sys.exit(main())
```

## 6. CLI Design

### Entry points

The package provides a console script `qa-harness` via `pyproject.toml`:

```toml
[project.scripts]
qa-harness = "qa_harness.cli:main"
```

Also runnable as `python -m qa_harness`.

### Subcommands

```
qa-harness start [--config PATH]
```
Start the test server and supporting processes. Kills existing processes on the port first. Polls health check until ready or timeout. Writes state file. Prints "READY" to stdout on success.

```
qa-harness stop [--config PATH]
```
Terminate all processes started by `qa-harness start`. Reads state file for PIDs. Falls back to `lsof -ti tcp:<port>` if state file is missing. Removes state file. Prints "STOPPED" to stdout.

```
qa-harness seed --plan PATH [--config PATH]
```
Execute a seed plan (JSON file with an array of endpoint calls). Verifies server is alive first. Calls cleanup first (implicit -- always resets before seeding). Runs each endpoint call in order. Prints each call and its result to stdout.

```
qa-harness seed-endpoints [--config PATH]
```
List all available seed endpoints from the config, formatted for the seed planner agent. Shows method, path, parameters with types, what each creates/returns, and dependency ordering.

```
qa-harness cleanup [--config PATH]
```
Call the cleanup endpoint. Verifies server is alive first. Prints result.

```
qa-harness status [--config PATH]
```
Report whether the server is running, what port, PIDs, and uptime. Reads state file and checks process liveness.

### Return codes

- `0` -- success
- `1` -- error (ServerError, SeedError, ConfigError)

### Output

All user-visible output goes to stdout. Logging goes to stderr. The `--verbose` flag sets logging to DEBUG level.

Commands that agents consume programmatically print machine-parseable markers: `READY`, `STOPPED`. Other output is human-readable.

## 7. Pipeline Config Schema (`qa-config.yml`)

```yaml
# Required
pipeline: string          # Pipeline name (e.g., "inflow-ats")
source_repo: string       # Absolute path to the source repo

# Optional -- omit for non-web pipelines
server:
  start_command: string   # Required if server is present. Shell command to start the server.
                          # Will be wrapped in bash -c for nvm/env support.
  base_url: string        # Required. e.g., "http://app.lvh.me:5007"
  port: int               # Required. e.g., 5007
  health_check_path: string  # Optional, default "/". Path to GET for health check.
  startup_timeout_seconds: int  # Optional, default 180. Max seconds to wait for health.
  supporting_commands:    # Optional. List of additional commands to start (e.g., sidekiq).
    - string              # Each is a shell command, wrapped in bash -c.

# Optional -- omit if no seed endpoints
seed:
  cleanup_endpoint: string  # Required if seed is present. e.g., "DELETE /cypress/cleanup"
  available_endpoints:      # Required if seed is present. List of endpoint definitions.
    - method: string        # Required. HTTP method (GET, POST, DELETE).
      path: string          # Required. URL path. May contain {placeholders}.
      params: object        # Optional. Map of param_name to type_hint string.
      requires: [string]    # Optional. List of paths that must be called first.
      creates: string       # Optional. Human description of what this creates.
      returns: string       # Optional. Human description of what this returns.

# Optional -- omit if no auth needed
auth:
  default_user: string     # Required if auth is present. Default login email.
  instructions: string     # Required if auth is present. Multi-line instructions
                           # for the QA agent on how to log in via Playwright MCP.

# Optional -- omit if no script runner
script_runner:
  command: string           # Required if present. Command to run temp scripts.
  file_extension: string    # Optional, default ".rb". File extension for scripts.

# Optional
verification_layers:       # List of layer names. Default: infer from what's configured.
  - string                 # Valid values: script_runner, rspec, cypress, playwright_mcp

# Optional
qa_team_size: int          # Default 3. Number of QA agents per round.
```

### Config for the inflow-ats pipeline

The full config shown in the spec goes to `~/claude-hub/inflow-ats/qa-config.yml`. Key note: the `sidekiq_command` from the spec maps to `supporting_commands: [<the sidekiq command>]` in the schema. This is a change from the spec's structure -- the spec shows `sidekiq_command` as a named field, but the plan generalizes it to `supporting_commands` for pipeline scalability.

**Implementation note:** The spec's `server.sidekiq_command` should be accepted as an alias during config loading. If `sidekiq_command` is present and `supporting_commands` is not, treat `sidekiq_command` as `supporting_commands: [<value>]`. This maintains backward compatibility with the spec's example config.

## 8. Phase 8 Orchestrator Prompt (already exists at `~/claude-hub/features/qa-prompt.md`)

The orchestrator prompt already exists at `~/claude-hub/features/qa-prompt.md` (260 lines). It is NOT Python code. It is a markdown file read by the feature lifecycle orchestrator agent. The implementation agent should verify the existing prompt is consistent with the spec and the plan below. If discrepancies exist, edit the existing file -- do not create a new one.

### What the prompt must cover

**Preamble:**
- You are the Phase 8 orchestrator. Your job is to verify a feature works by dispatching QA agents.
- Read the qa-config.yml for the pipeline. Determine what verification layers are available.
- Server lifecycle is YOUR responsibility: call `qa-harness start` once, run all rounds, call `qa-harness stop` at the end.

**Step 1: Seed planning**
- Before the first QA round, spawn a seed planner sub-agent.
- Give it: the feature spec (SPEC.md), the implementation diff (`git diff main...HEAD` in the source repo), and the output of `qa-harness seed-endpoints --config <path>`.
- The seed planner produces one JSON seed plan file per data scenario in `reviews/seed-plans/`.
- Each plan is a JSON array: `[{method, path, body?}, ...]`.
- The planner should think about what data scenarios the feature needs: different user roles, subscription states, data quantities, edge cases.

**Step 2: Server start**
- Run `qa-harness start --config <path>`.
- Wait for "READY" in stdout.
- If it fails, report the error and stop.

**Step 3: Round dispatch**
- For each round (up to 5):
  - Spawn `qa_team_size` QA agents sequentially via TaskCreate.
  - Each agent is a fresh sub-agent with its own context -- no memory of other agents or prior rounds.
  - Wait for each agent to complete before starting the next (sequential execution).
  - Each agent receives:
    - The feature spec
    - The implementation diff
    - The seed plans from `reviews/seed-plans/`
    - Consolidated findings from all prior rounds (empty for round 1)
    - The auth instructions from the config
    - The script_runner config
    - The verification layers available
  - Each agent's instructions: pick a seed plan, run `qa-harness seed --plan <path>`, authenticate using MCP tools per the auth instructions, exercise the feature using Playwright MCP and/or script_runner, validate/invalidate prior findings, record new findings, run `qa-harness cleanup` between scenarios.

**Step 4: Agent instructions template**
- The prompt must include a template for the instructions given to each QA agent.
- The template covers: what tools are available (Playwright MCP for browser, `qa-harness` CLI for seed/cleanup, script_runner for verification scripts), the severity scale, how to write findings JSON, evidence requirements (snapshots, screenshots, console errors, network requests), and the per-agent findings file format.
- Findings file location: `reviews/qa-round-N/agent-M.json`.

**Step 5: Consolidation**
- After all agents in a round complete, consolidate findings.
- Deduplication: by reproduction steps. If two agents found the same bug, keep the one with better evidence.
- Disagreements: if agents disagree on a prior finding (one confirms, one invalidates), the finding stays alive for the next round.
- Write `reviews/qa-round-N/consolidated.json` and `reviews/qa-round-N/summary.md`.

**Step 6: Convergence evaluation**
- Compare consolidated HIGH+ findings to the previous round.
- If no HIGH+ findings changed (no new ones, no invalidated ones): increment clean pass counter.
- If any HIGH+ findings changed: reset clean pass counter to 0.
- Two consecutive clean passes: converged. Go to Step 8.
- Otherwise: go to Step 7.

**Step 7: Failure loop**
- If HIGH+ findings exist and haven't converged:
  - Write `reviews/qa-round-N/FAILURE-REPORT.md` with the confirmed HIGH+ findings.
  - Go back to Phase 5 (implementation) -- spawn an impl agent with the failure report.
  - Skip Phase 6 (impl review) on re-entry.
  - After the fix, resume QA at the next round number (don't restart).
  - Round cap: 5 total rounds. If round 5 finishes without convergence, escalate.

**Step 8: Completion**
- Write `reviews/QA-COMPLETE.md` with the final verdict.
- List any MED/LOW findings for Jessica to review.
- Call `qa-harness stop --config <path>`.
- Phase 8 is complete.

**Step 9: Escalation (round cap hit)**
- Write `reviews/QA-ESCALATION.md` with all findings and convergence history.
- Call `qa-harness stop`.
- Stop and present to the user.

### Prompt verification note

The existing `~/claude-hub/features/qa-prompt.md` is 260 lines. The implementation agent should verify it covers all the steps described above. If any step is missing or inconsistent, edit the existing file.

## 9. Test Plan

### Unit tests (all in `tests/`)

**`test_config.py`** (~15 tests):
- Load valid YAML config, verify all fields parsed correctly
- Load minimal config (pipeline + source_repo only), verify defaults
- Load config with server but no seed (non-seed pipeline)
- Load config with seed but no server (non-web pipeline)
- Missing required field `pipeline` raises ConfigError
- Missing required field `source_repo` raises ConfigError
- Server config missing `start_command` raises ConfigError
- Invalid `verification_layers` entry raises ConfigError
- `qa_team_size` non-positive raises ConfigError
- `sidekiq_command` alias accepted when `supporting_commands` absent
- Config file not found raises ConfigError
- Invalid YAML raises ConfigError
- `resolve_config_path` finds file in cwd
- `resolve_config_path` uses explicit path
- `resolve_config_path` uses QA_CONFIG_PATH env var

**`test_server.py`** (~12 tests, adapted from `test_inflow_bootstrap.py`):
- Config defaults (health_check_path, startup_timeout_seconds)
- Constructed but not started: `is_running()` returns False
- `start` launches main + supporting subprocesses via Popen
- Popen called with `bash -c` wrapper
- Popen called with correct `cwd` (source_repo)
- `start` raises ServerError on health check timeout
- `start` raises ServerError on premature process exit (proc.poll() returns non-None)
- `stop` terminates all processes
- `stop` kills if terminate times out
- `status` returns dict with is_running, port, pids
- Context manager calls start and stop
- State file written on start, removed on stop
- Signal handler calls stop and exits

**`test_seed.py`** (~15 tests, adapted from `test_cypress_api.py` + `test_seed_parser.py`):
- `cleanup` calls correct HTTP method and path from config
- `cleanup` checks server alive first, raises SeedError if down
- `execute_plan` loads JSON file correctly
- `execute_plan` calls cleanup before seeding
- `execute_plan` executes steps in order
- `execute_plan` checks server alive first
- `execute_plan` raises SeedError on HTTP error
- `validate_plan` accepts valid plan
- `validate_plan` rejects unknown endpoint (method+path not in catalog)
- `validate_plan` rejects missing required params
- `validate_plan` checks dependency ordering (requires)
- `list_endpoints` formats all endpoints with params and descriptions
- HTTP error raises SeedError with status code and endpoint
- Network error raises SeedError with message
- Empty plan is valid (just runs cleanup)

**`test_cli.py`** (~10 tests):
- `start` subcommand parses --config
- `stop` subcommand parses --config
- `seed` subcommand parses --plan and --config
- `seed-endpoints` subcommand parses --config
- `cleanup` subcommand parses --config
- `status` subcommand parses --config
- Default config resolution (no --config flag)
- `--verbose` flag sets debug logging
- Commands return 0 on success
- Commands return 1 on error

### Testing approach

- Mock `subprocess.Popen` for server tests (same pattern as `test_inflow_bootstrap.py`)
- Use `responses` library for HTTP mocking in seed tests (same pattern as `test_cypress_api.py`)
- Use `tmp_path` pytest fixture for temp config files and seed plans
- No integration tests in the initial build -- the harness will be integration-tested by actually running Phase 8 on a real feature

## 10. Build Sequence

### Phase 1: Foundation (no dependencies)

1. **`pyproject.toml`** -- package metadata, dependencies (`requests`, `pyyaml`), dev dependencies (`pytest`, `responses`, `pytest-mock`), entry point, test config
2. **`errors.py`** -- exception hierarchy (needed by everything else)
3. **`__init__.py`** and **`__main__.py`** -- package boilerplate

### Phase 2: Configuration (depends on errors.py)

4. **`config.py`** -- load and validate qa-config.yml
5. **`test_config.py`** -- tests for config loading
6. **`~/claude-hub/inflow-ats/qa-config.yml`** -- first pipeline config (used by tests as a realistic fixture)

### Phase 3: Server lifecycle (depends on config.py, errors.py)

7. **`server.py`** -- server start/stop/health-check
8. **`test_server.py`** -- server lifecycle tests

### Phase 4: Seed execution (depends on config.py, errors.py)

9. **`seed.py`** -- seed plan execution, cleanup, endpoint listing
10. **`test_seed.py`** -- seed execution tests

### Phase 5: CLI (depends on all modules)

11. **`cli.py`** -- argparse CLI wiring all modules together
12. **`test_cli.py`** -- CLI tests
13. **`conftest.py`** -- shared test fixtures

### Phase 6: Lifecycle integration verification

14. **Verify `~/claude-hub/features/qa-prompt.md`** -- Phase 8 orchestrator prompt already exists; verify it is consistent with the spec and plan
15. **Verify `~/claude-hub/features/LIFECYCLE.md`** -- Phase 8 section already exists; verify it is consistent with the spec

### Dependency graph

```
errors.py
  ├── config.py
  │     ├── server.py
  │     └── seed.py
  └─────────── cli.py (imports config, server, seed)
```

## 11. Risks and Open Questions

### Risks

1. **State file reliability.** The `/tmp/qa-harness-state.json` state file could be stale if the machine reboots or processes are killed externally. Mitigation: `stop` and `status` verify PID liveness (check if process exists), don't just trust the file. `start` kills processes on the port regardless of state file contents.

2. **Supporting command kill pattern.** Extracting a process name keyword from a shell command string for `pgrep -f` is fragile. For `bundle exec sidekiq`, we'd extract "sidekiq". For a more complex command, the extraction might be wrong. Mitigation: document that `supporting_commands` entries should contain a distinctive keyword for process identification. Alternatively, track PIDs directly from subprocess.Popen (which we already do) and only use pgrep as a fallback for orphaned processes.

3. **Seed plan validation depth.** The `requires` field in seed endpoints describes ordering dependencies (e.g., `/cypress/jobs` requires `/cypress/users`). Validating this against a plan means checking that required paths appear earlier in the array. This is straightforward for direct dependencies but gets complex for transitive ones. Mitigation: validate only direct dependencies in v1.

4. **Config schema drift.** The spec shows `sidekiq_command` as a named field in the server config. The plan generalizes to `supporting_commands`. Need to support both during config loading to avoid breaking the spec's example config.

### Open questions (deferred from spec review, not blocking)

1. **Disagreement semantics for convergence** (spec review MED #1): Should agent disagreement on a prior finding count as a "change" for convergence? The spec says "if agents disagree, the finding stays alive." The prompt should treat a disagreed-on finding as unchanged (it stays, but it's not new and it's not invalidated). Only unanimous invalidation counts as a change. This is an orchestrator prompt decision, not harness code.

2. **Agent diversity** (spec review MED #2): How agents get assigned different testing focuses. The prompt could assign focuses (e.g., "agent 1: happy path, agent 2: edge cases, agent 3: regressions") or let agents self-direct. Start with self-directed (each agent reads the same context and naturally diverges due to fresh context) and add explicit focus assignment if convergence is too slow.

3. **Cost tracking** (spec review MED #3): The help pipeline has a `CostTracker`. The QA harness has no equivalent because it does not make LLM API calls -- agents do. Agent cost is tracked by Claude Code's native session cost tracking, not by harness code.

4. **Screenshot file paths for evidence** (spec review MED #4): The Playwright MCP's `browser_take_screenshot` saves to a path. The agent needs to know where screenshots end up. The orchestrator prompt should instruct agents to save evidence to `/tmp/qa-round-N/agent-M/` and reference those paths in findings.

5. **Non-web pipeline config example** (spec review MED #7): Deferred to when a non-web pipeline actually needs QA. The schema supports it (omit server, auth, playwright_mcp), but no example config is written in v1.

## 12. Estimated Scope

### Files

| Category | Count |
|---|---|
| Python modules | 7 (`__init__`, `__main__`, `cli`, `config`, `server`, `seed`, `errors`) |
| Test files | 5 (`conftest`, `test_cli`, `test_config`, `test_server`, `test_seed`) |
| Config/packaging | 1 (`pyproject.toml`) |
| Pipeline configs | 1 (`inflow-ats/qa-config.yml`) |
| Lifecycle verification | 2 (`qa-prompt.md` and `LIFECYCLE.md` -- verify existing, not create) |
| **Total** | **14 new files + 2 verifications** |

### Lines of code (rough estimates)

| File | Est. LOC |
|---|---|
| `errors.py` | 20 |
| `config.py` | 150 |
| `server.py` | 200 |
| `seed.py` | 170 |
| `cli.py` | 130 |
| `__init__.py` + `__main__.py` | 10 |
| `pyproject.toml` | 40 |
| `test_config.py` | 180 |
| `test_server.py` | 160 |
| `test_seed.py` | 200 |
| `test_cli.py` | 120 |
| `conftest.py` | 40 |
| `qa-config.yml` | 60 |
| **Total** | **~1,480 LOC** (excludes existing qa-prompt.md and LIFECYCLE.md) |
