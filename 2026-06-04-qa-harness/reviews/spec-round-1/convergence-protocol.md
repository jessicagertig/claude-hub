# convergence-protocol -- Round 1

## Findings

- F1 [HIGH] Team size unspecified. The spec says "the orchestrator spawns a team of fresh QA agents in parallel" but never specifies how many agents per team. This is not an implementation detail -- it affects cost, convergence speed, and deduplication quality. With 2 agents, independent discovery is weak. With 10, cost is high. The spec should declare a default team size and whether it is configurable.

  **Fix:** Add a default team size (3 agents) and note that this is configurable per pipeline in qa-config.yml.

- F2 [MED] Disagreement and convergence interaction. The spec says when agents disagree on a prior finding, it "stays alive for the next round to re-examine." The spec does not say whether a disagreement counts as a change for convergence purposes. If disagreement counts as a change (HIGH+ finding state changed), then a single disagreeing agent could prevent convergence indefinitely. If it does not count as a change, then a legitimately invalidated finding might be ignored. The spec should clarify: a disagreement is NOT a change for convergence -- only a unanimous invalidation (all agents who reviewed it agree it is invalid) counts as a finding-state change.

- F3 [MED] No agent diversity mechanism. The spec says nothing about how QA agents are given different angles or approaches. If all 3 agents receive identical instructions, they may test the same things and find the same bugs, providing no benefit over a single agent. The orchestrator prompt should assign agents different testing focuses (e.g., happy path, edge cases, permissions/roles), but the spec gives no guidance on this.

- F4 [LOW] Cost awareness. Teams of 3 agents for up to 5 rounds, each with Playwright MCP interactions, could be expensive. The spec does not mention token budgets or cost tracking. The analog has a `CostTracker` class. Consider whether the harness or the orchestrator should track costs.

## Amendments Applied

- Spec "Round mechanics" section: added default team size of 3, configurable in qa-config.yml.
