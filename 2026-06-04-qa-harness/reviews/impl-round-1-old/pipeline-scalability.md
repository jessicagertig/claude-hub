# Pipeline Scalability — Round 1 Findings

## Angle: pipeline-scalability

### Finding 1: Config schema correctly supports optional sections (PASS NOTE)

The `QAConfig` dataclass makes `server`, `seed`, `auth`, `script_runner` all `Optional`. A non-web pipeline can omit any or all of these. The `load_config` function handles missing sections gracefully (they parse as `None`). Tests verify minimal configs work (`test_load_minimal_config`, `test_load_server_without_seed`, `test_load_seed_without_server`).

### Finding 2: `cmd_seed` requires server config, which blocks non-web seed usage (MED)

In `cli.py`, `cmd_seed` checks `if config.server is None` and exits with error. But a non-web pipeline might have seed endpoints accessible at a known URL without needing the harness to manage a server process. The spec's pipeline scalability section says "Non-web pipelines omit `server`, `auth`, and `playwright_mcp`" but doesn't explicitly address whether seed endpoints require a server config.

This is MED because no non-web pipeline is configured yet, and when one is, the `base_url` for seed endpoints could be specified elsewhere. But the current code would reject a valid use case.

Similarly, `cmd_cleanup` also requires server config for the health check URL.

### Finding 3: `supporting_commands` + `sidekiq_command` alias works correctly (PASS NOTE)

The config parser accepts both `supporting_commands` (list) and `sidekiq_command` (string alias). When `sidekiq_command` is present and `supporting_commands` is absent, it promotes the alias to a single-element list. The test `test_sidekiq_command_alias` verifies this. The actual inflow-ats `qa-config.yml` uses `sidekiq_command` and loads correctly.

### Finding 4: `_extract_process_keyword` keyword list is limited but extensible (PASS NOTE)

The hardcoded keyword list (`sidekiq`, `puma`, `unicorn`, `rails`, `node`, `next`) covers common Ruby/Node processes. The fallback to "first word after `exec`" handles arbitrary commands. This is sufficient for current pipelines.
