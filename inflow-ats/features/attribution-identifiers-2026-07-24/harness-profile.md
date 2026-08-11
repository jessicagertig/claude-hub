# Harness profile — Fable-trimmed lifecycle (Jessica's rulings, 2026-07-24)

This run uses the Feature Development Harness (`~/claude-hub/features/LIFECYCLE.md` + inflow-ats overrides) with the following deviations, approved by Jessica for Fable-driven runs. The harness's stock convergence counts were tuned for Opus; Fable keeps the structure and cuts iterations. **Savings come from fewer rounds — never from fewer agents or cheaper models** (Jessica: "cut it on iterations rather than agent count").

## No human gate (Jessica, 2026-07-24)

The stock Phase 1 human gate (user approves review angles) is REMOVED for this run — Jessica: "go ahead... I don't expect you to [human-gate]." The orchestrator proceeds through all phases autonomously. Escalations (ESCALATE verdicts, round caps, spec contradictions requiring an owner ruling) still stop the run and go to Jessica.

## Round-count trims

| Phase | Stock | This run |
|---|---|---|
| 2 — Spec review | Up to 5 rounds, two consecutive clean passes | One round; a second round only if round 1 produces HIGH+ |
| 3/4 — Plan + plan review | Plan, then exactly 2 review passes | One plan pass (must include the SPEC §9 structural manifest), one review pass |
| 6 — Impl review | Two consecutive clean rounds, 50-round cap | Exit on the FIRST clean round; loop on HIGH+ exactly as stock; cap unchanged |

**Convergence rule (Jessica, 2026-07-24, applies to every review loop including Phase 8 layers):** two clean passes are never required. A round with zero HIGH+ and no unaddressed MEDs is terminal. A round ending with only a couple of LOW items may also be terminal at the orchestrator's judgment — LOWs alone do not force another round.
| 7 — Hardening | Stock | Stock |
| 8 — QA | 5 layers, 15-30 agents each, two clean rounds per layer | See below |

## Phase 8 layers

- **Layer 1 (diff-to-spec):** ~11 Fable agents, slices defined by the spec's own structure, NOT an arbitrary count: one per identifier chain (8 — capture rule → payload → permit → both `magic_create` branches → SSO ride → `from_omniauth` → org copy), one for the collection-point removal, one for tests-vs-spec, and one running the REVERSE direction — everything in the diff the spec never asked for. The reverse-direction agent is first-class; the historical Layer 1 miss (unspecced 46-line method) was a reverse-direction failure at high agent count.
- **Layer 4 (regression suites):** full, stock.
- **Layer 5 (browser):** ONE pass — seed the cookies (`_ga`, `_ga_*`, `_fbp`, `_fbc`, `_gcl_aw`, `__adroll_fpc`, `li_fat_id`), land with the URL params (`gclid`, `fbclid`, `li_fat_id`, `adct`, `utm_*`), sign up through both paths, verify the user and organization rows.
- **Layers 2-3:** skipped for this feature.

## MED rule (replaces stock "MEDs don't block")

- Reviewers: MED means "should be fixed." An observation that doesn't warrant a fix is a note/LOW — it must never be filed as MED.
- Orchestrator: address MEDs with judgment — fix the ones whose fix is minimal-scope and clearly right; any MED deliberately left unfixed is listed with reasoning in the round artifact. Nothing is silently absorbed; there is no fix-all convergence requirement.

## Test priorities (Jessica, 2026-07-24)

1. **Cypress tests — top priority.** Jessica wrote them. They must pass (`registration.cy.js` runs pre-commit) and are read-only per repo rules.
2. **Customer/public API specs — important.** Jessica wrote them. (Not touched by this feature.)
3. **All other RSpec — strongly deprioritized.** Keep them green and correct; extend minimally per SPEC §10 (mirroring the `ec9f87232` additions). "Missing RSpec coverage" is never a HIGH or MED finding on its own. BROKEN specs and WRONG specs remain real findings — deprioritized does not mean tolerated when incorrect; ghost tests remain BLOCKER.
