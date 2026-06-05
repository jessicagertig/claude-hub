# playwright-mcp-integration -- Round 2

## Findings

Round 1 findings addressed: parallel agent browser session issue resolved by switching to sequential execution. Each agent still gets its own MCP session (separate sub-agent process).

No new BLOCKER or HIGH findings.

- F1 [MED] Screenshot file paths (Round 1 F3) still not clarified. The spec's evidence format shows paths like `/tmp/qa-round-1/agent-2/screenshot-003.png` but does not explain how these are created. The Playwright MCP's `browser_take_screenshot` returns screenshot data inline (as an image in the response). The agent would need to save it to disk via Bash. This is an implementation detail the orchestrator prompt or agent instructions should cover, not necessarily the spec.

- F2 [LOW] `browser_snapshot` visual limitations (Round 1 F2) still unacknowledged in spec. The spec says screenshots are used for "evidence in findings reports" which implicitly addresses this, but does not explicitly state that `browser_snapshot` cannot detect visual layout issues.

## Amendments Applied

- None.
