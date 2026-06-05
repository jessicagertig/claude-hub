# seed-data-design -- Round 2

## Findings

- F1 [HIGH] Parallel agents sharing one database. The amended spec clarifies that the orchestrator starts the server once and agents share it. But agents also share the same test database. If agent A seeds "solo user" and agent B calls `qa-harness cleanup` (which TRUNCATEs all tables) followed by its own seed, agent A's data is destroyed. The agents cannot run in parallel against the same database with cleanup between scenarios.

  Two solutions:
  (a) **Sequential execution within a round** — agents run one at a time, each doing cleanup + seed + test. Simpler but slower.
  (b) **Parallel execution with isolated sessions** — each agent gets its own server on a different port with its own database. More complex but truly parallel.

  Option (a) is pragmatic for v1. The spec already says QA rounds use "teams of agents" but the execution can still be sequential within a round while maintaining independent agent contexts (fresh agent per scenario, no memory sharing). The "team" concept provides diversity of approach, not necessarily parallelism.

  **Fix:** Clarify that agents within a round execute sequentially (not in parallel) against the shared server. Each agent does cleanup + seed + test + cleanup. The orchestrator dispatches them one at a time. The "team" provides independent perspectives (fresh context), not parallel execution.

All Round 1 seed-data-design findings have been addressed by the amendments.

## Amendments Applied

- Spec: clarified that agents execute sequentially within a round, sharing the server but not running simultaneously.
