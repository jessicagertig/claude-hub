# playwright-mcp-integration -- Round 1

## Findings

- F1 [HIGH] Parallel agents sharing one browser session. The Playwright MCP maintains a single browser session per Claude Code process. If multiple QA agents run in parallel (the spec says "spawns a team of fresh QA agents in parallel"), they will either: (a) share one browser session, causing race conditions (agent A navigates to page X while agent B is asserting on page Y), or (b) each need their own MCP instance. The spec does not address this at all.

  The most likely architecture is that each QA agent is a separate Claude Code sub-agent (TaskCreate), each with its own Playwright MCP session. But this needs to be explicit -- if agents are threads within one process sharing one MCP, the entire parallel execution model is broken.

  **Fix:** Add explicit statement that each QA agent runs as a separate sub-agent with its own Playwright MCP browser session.

- F2 [MED] `browser_snapshot` limitations for visual verification. The spec says `browser_snapshot` is "preferred over screenshots for structural assertions" and returns an accessibility tree. This is correct for verifying element presence, text content, and form state. However, it cannot verify: visual layout issues (overlapping elements, wrong colors, z-index problems, missing icons, responsive breakpoints). The spec should acknowledge this limitation and clarify that screenshots should be used for visual regression evidence.

- F3 [MED] Screenshot file paths. The spec shows screenshot paths in evidence like `"/tmp/qa-round-1/agent-2/screenshot-003.png"`. The Playwright MCP's `browser_take_screenshot` tool returns screenshot data but the spec does not describe how screenshots get saved to specific file paths. The agent would need to either: (a) use `browser_take_screenshot` and then save the result via Bash, or (b) the MCP supports a `path` parameter. This needs clarification so the findings format is actionable.

- F4 [LOW] The spec says "The MCP's `browser_navigate` uses `domcontentloaded` by default." This is a claim about the MCP's default behavior that should be verified. If the MCP defaults to a different wait strategy, the auth flow and page navigation could time out or behave unexpectedly on inflow-ats.

## Amendments Applied

- Spec "Architecture" section: clarified that each QA agent runs as a separate sub-agent with its own Playwright MCP browser session.
