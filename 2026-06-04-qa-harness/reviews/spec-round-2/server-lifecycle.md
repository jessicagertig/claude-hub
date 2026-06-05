# server-lifecycle -- Round 2

## Findings

- F1 [HIGH] Multiple agents calling `qa-harness start` on the same port. The spec says each QA agent calls `qa-harness start` (step 1 in "What the QA agent does"). But if 3 agents run in parallel and each calls `qa-harness start`, the first agent starts the server, the second agent's `start` kills the first agent's server (because start kills existing processes on the port) and starts a new one, and the third agent does the same. This is a race condition that will cause intermittent failures.

  The server should be started ONCE by the orchestrator before dispatching agents, not by each agent individually. Or `qa-harness start` should be idempotent -- detecting an already-running healthy server and returning "READY" without restarting.

  **Fix:** Clarify that the orchestrator calls `qa-harness start` once before dispatching the agent team, and agents do NOT call start/stop individually. Agents call seed/cleanup for their own scenarios, and the orchestrator calls stop after all agents complete.

All other server-lifecycle issues from Round 1 have been addressed.

## Amendments Applied

- Spec "What the QA agent does" section: removed start/stop from individual agent duties, moved to orchestrator responsibility.
