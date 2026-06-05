# pipeline-scalability -- Round 2

## Findings

Round 1 findings addressed: `test_frr` corrected and generalized to `script_runner`.

- F1 [HIGH] Stale reference to `test_frr` in Pipeline scalability section. Line 429 still says "Non-web pipelines omit `server`, `auth`, and `playwright_mcp` — only `test_frr` and regression layers apply." This should reference `script_runner`, not `test_frr`, to be consistent with the Round 1 amendment.

  **Fix:** Update the reference to `script_runner`.

- F2 [MED] Non-web pipeline config example. The spec says "For a non-web pipeline, the config would omit `server`, `auth`, and the `playwright_mcp` layer" but does not show what such a config looks like. A brief example would help implementers understand the minimal config. Not HIGH because the pattern is clear from context.

## Amendments Applied

- Spec: fixed stale `test_frr` reference in Pipeline scalability section.
