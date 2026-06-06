# Playwright MCP Integration — Round 1 Findings

## Angle: playwright-mcp-integration

The harness intentionally does NOT contain Playwright MCP code. All browser interaction is agent-driven. This angle verifies the prompt instructions are correct and complete for agents to use the MCP tools.

### Finding 1: Agent instructions correctly delegate all browser work to MCP (PASS NOTE)

The qa-prompt.md Step 4 (agent instructions template) lists all the relevant MCP tools:
- `mcp__playwright__browser_navigate`
- `mcp__playwright__browser_snapshot`
- `mcp__playwright__browser_click`
- `mcp__playwright__browser_fill_form`
- `mcp__playwright__browser_take_screenshot`
- `mcp__playwright__browser_console_messages`
- `mcp__playwright__browser_network_requests`

This is comprehensive and matches the available MCP tools listed in the system prompt.

### Finding 2: Auth instructions in qa-config.yml are well-structured (PASS NOTE)

The inflow-ats qa-config.yml auth instructions describe the magic-link login flow step by step, referencing MCP tool actions without naming specific tools (the agent maps the instructions to tools). The instructions reference `{base_url}` which the agent template fills in. Good.

### Finding 3: `domcontentloaded` wait strategy is not mentioned in agent instructions (LOW)

The REVIEW-ANGLES.md notes that `domcontentloaded` instead of `networkidle` is important for inflow-ats (the app never settles due to WebSocket polling). The Playwright MCP's `browser_navigate` uses `domcontentloaded` by default, which is correct. But the agent instructions don't explicitly mention this constraint.

If a QA agent tries to use `mcp__playwright__browser_wait_for` with `networkidle`, it would hang. This is LOW because the MCP default is correct and agents would likely not override it without reason.

### Finding 4: Screenshot evidence paths are documented (PASS NOTE)

The agent instructions specify `/tmp/qa-round-{round_number}/agent-{agent_index}/` for screenshots and snapshots. The Playwright MCP's `browser_take_screenshot` saves to a path. The evidence format in the findings JSON references these paths. This is complete.
