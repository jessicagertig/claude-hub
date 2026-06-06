# pipeline-scalability — Round 1 Findings

## MED-1: No config example or documentation for non-web pipelines

**Severity:** MED

**Finding:** The spec says non-web pipelines omit `server`, `auth`, and `playwright_mcp` from the config. The code supports this (all are optional in `QAConfig`). But there is no example config for a non-web pipeline, and no test verifies that the CLI commands work correctly when `server` is None (e.g., `seed-endpoints` with no server sets `base_url` to `"http://localhost"` -- line 138 of cli.py).

Deferred per plan section 11, Open Question 5: "Deferred to when a non-web pipeline actually needs QA."

---

## MED-2: seed-endpoints command silently uses a dummy base_url when server is None

**Severity:** MED

**File:** `src/qa_harness/cli.py`, line 138

**Finding:** `cmd_seed_endpoints` does:
```python
base_url = config.server.base_url if config.server else "http://localhost"
```
This creates a `SeedExecutor` with a dummy base URL. If someone then calls `list_endpoints()` (which only formats text), this is fine. But if the same executor were used for HTTP calls, the URL would be wrong. Currently `seed-endpoints` only calls `list_endpoints()`, so this is functionally harmless but architecturally misleading -- the executor looks like it could make real HTTP calls when it actually can't.

---

No BLOCKER or HIGH findings.
