# Playwright MCP Integration — Pass 1

## Fact Check

- **Claim:** "Authentication is NOT a harness command. The harness is a Python CLI invoked via Bash -- it cannot call Playwright MCP tools."
  - Verified: The spec says "Authentication is performed by the QA agent directly using Playwright MCP tools -- NOT by the harness CLI." Plan section 5 `server.py` has no auth code. Plan section 2 explicitly notes login.py is "NOT adapted into code." Correct.

- **Claim:** "Each agent runs as a separate sub-agent process with its own Playwright MCP browser session."
  - Verified: Spec says "Each agent runs as a separate sub-agent process with its own Playwright MCP browser session. Separate sessions are inherent to the sub-agent model (each TaskCreate gets its own tool context)." Plan section 8 says "Each agent is a fresh sub-agent with its own context." Consistent.

- **Claim:** "The MCP's `browser_navigate` uses `domcontentloaded` by default."
  - Verified: Spec says "The MCP's `browser_navigate` uses `domcontentloaded` by default, which is correct for inflow-ats." The analog's `login.py` (line 46) and `fallback_executor.py` (line 51) both use `wait_until="domcontentloaded"`. This claim is about the MCP's default behavior, which I cannot independently verify from the codebase -- it's a claim about the Playwright MCP tool's built-in behavior. The spec states it as fact.

- **Claim:** The plan says auth instructions go in `qa-config.yml` and are read by the agent.
  - Verified: Spec defines the auth config block with `default_user` and `instructions`. The qa-prompt.md (Step 4) passes `{auth_instructions}` to each agent. Consistent.

- **Claim:** Plan says "browser_snapshot is preferred over visual screenshots for assertions."
  - Verified: Spec says "`browser_snapshot` is preferred over visual screenshots for assertions because it returns structured element data." qa-prompt.md Step 4 says "Use `mcp__playwright__browser_snapshot` to read page state (preferred over screenshots for structured assertions)." Consistent.

## Completeness

Spec requirements covered by this angle:
1. Auth via MCP tools, not harness code -- plan: no auth in harness, instructions in config
2. browser_snapshot for structural assertions -- plan: documented in prompt, spec
3. Screenshots for evidence in findings -- plan: qa-prompt instructs saving to /tmp paths
4. domcontentloaded wait strategy -- plan: config's server command, spec states MCP default
5. 60s default timeouts -- plan: no explicit harness code for this (agent-side MCP config), spec mentions it
6. Each agent gets own browser session -- plan: sub-agent model, spec confirms

All spec requirements for Playwright MCP addressed.

## Findings

No BLOCKER, HIGH, or MED findings.

## Amendments Applied

None needed.
