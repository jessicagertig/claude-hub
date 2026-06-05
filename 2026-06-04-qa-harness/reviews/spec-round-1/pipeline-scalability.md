# pipeline-scalability -- Round 1

## Findings

- F1 [HIGH] `test_frr` is Rails-specific but described as a general verification layer. The spec defines `test_frr` as a verification layer available to all pipelines, but `test_frr` is literally `RAILS_ENV=test foreman run rails runner` (as defined in Jessica's `.bash_profile`). Note: the spec incorrectly describes it as `RAILS_ENV=test bundle exec rails runner` -- the actual alias uses `foreman run`, not `bundle exec`. For non-Rails pipelines (thought-leadership-automation is Python, wrk-marketing is likely JS), `test_frr` is meaningless.

  The spec says "Non-web pipelines omit `server`, `auth`, and `playwright_mcp` — only `test_frr` and regression layers apply." But `test_frr` ALSO doesn't apply to non-Rails pipelines. The spec needs a pipeline-agnostic mechanism for scripted verification, not a Rails-specific alias.

  **Fix:** (1) Correct the `test_frr` definition. (2) Rename the concept to something pipeline-agnostic in the config (e.g., `script_runner`) and let each pipeline define its own command. For inflow-ats, `script_runner` would be `test_frr`. For a Python pipeline, it might be `python -m pytest` or a custom script runner.

- F2 [MED] Auth instructions are prose, not structured. The spec says auth instructions are "documentation for the agent, not executable code." This is fine for inflow-ats (magic-link is simple), but for pipelines with more complex auth (OAuth, API keys, SSO), prose instructions could be ambiguous. This is acceptable for now since only inflow-ats is the current target, but should be noted as a limitation for future pipelines.

- F3 [MED] Non-web pipeline seed mechanisms. The spec's seed design is entirely HTTP-endpoint-based (POST/DELETE to /cypress/*). Non-web pipelines that don't have HTTP seed endpoints would need a different seeding mechanism (e.g., running a Python script, loading fixtures). The config format should support command-based seeding as an alternative to endpoint-based seeding.

- F4 [LOW] YAML footguns. The spec uses YAML for qa-config.yml. YAML has known issues with implicit type coercion (e.g., `on: true` becomes boolean, `3.10` becomes float). For a config that includes endpoint bodies with boolean and numeric parameters, this could cause subtle bugs. JSON would be safer but less readable. This is a known trade-off and not worth changing, but the implementer should use safe YAML loading.

## Amendments Applied

- Spec: corrected `test_frr` definition and added `script_runner` concept to pipeline config.
