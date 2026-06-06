# Playwright MCP Integration — Pass 2

## Pass 1 Corrections Verification

No amendments were applied in Pass 1 for this angle. N/A.

## Fresh Scrutiny

- **MCP tool availability assumption:** The plan assumes Playwright MCP tools are available in the Claude Code session. The spec says "If the MCP is unavailable, the `playwright_mcp` verification layer is unusable but the other layers (`script_runner`, regression suites) still work." The plan doesn't explicitly handle MCP unavailability in the harness code (because the harness doesn't use MCP), but the qa-prompt.md should handle it in agent instructions. The existing qa-prompt.md lists Playwright MCP as one of the tools in the agent template. If MCP is unavailable, the agent would simply not be able to use those tools. Acceptable degradation.

- **Evidence paths in agent findings:** The spec shows evidence paths like `/tmp/qa-round-1/agent-2/snapshot-003.md` and `/tmp/qa-round-1/agent-2/screenshot-003.png`. The qa-prompt.md instructs agents to save screenshots to `/tmp/qa-round-{round_number}/agent-{agent_index}/`. This matches. The plan's section 11 #4 lists this as an open question about how screenshots get saved, but the prompt already handles it.

- **browser_take_screenshot behavior:** The plan's spec says the MCP can take screenshots. The qa-prompt.md references `mcp__playwright__browser_take_screenshot` for evidence. The Playwright MCP's `browser_take_screenshot` tool is listed in the available deferred tools. The tool exists and is callable. Whether it saves to a file path or returns inline bytes is a runtime behavior question -- the prompt instructs agents to save to a path, which is correct for the MCP's file-saving behavior.

## Completeness Sweep

All spec requirements for Playwright MCP integration remain addressed. No gaps found.

## Findings

No BLOCKER, HIGH, or MED findings.

## Amendments Applied

None needed.
