# Sub-Project Outline (non-authoritative reference)

## Nick's actual process (source of truth: Nick's Slack description)

1. Agents write specs
2. Iterative adversarial review of specs (until two consecutive clean passes)
3. Write a plan
4. Review plan TWICE (fixed count — 2 passes, no more)
5. Implement
6. Full iterative adversarial review of implementation (until consecutive convergence of no issues)
7. Failure reports → agents update CLAUDE.md files to prevent repeats

Additional: Nick never reads the spec. Requires plain English rendition + blast radius analysis. Has an adversarial lane for "reinventing the wheel / not using existing codebase patterns."

## Prompts to write (in lifecycle order)

1. **Plan prompt** — DONE (first draft at `~/claude-hub/inflow-ats/features/_base-template.md`)
2. **Spec adversarial review prompt** — iterative, 8 adversarial angles (adapted from Nick's `R1-ITERATIVE-REVIEW-PROMPT.md`), two-consecutive-clean-passes termination, must include plain English summary + blast radius analysis for Jessica
3. **Plan review prompt** — 2 fixed passes, adapted from Nick's `plan-review-agent.md`
4. **Implementation prompt** — the working prompt that guides the coding agent; context, rules, workflow steps, output artifacts
5. **Post-implementation review prompt** — iterative adversarial review of the built code; code quality, spec-to-implementation completeness, "not reinventing the wheel" angle; two-consecutive-clean-passes termination
6. **Failure report → CLAUDE.md hardening prompt** — agents write failure reports, then update CLAUDE.md files; Nick does this ad-hoc but we formalize it
7. **QC/QA workflow** — staged testing, independent verification by a different agent, binary verdict
8. **Makefile launcher** — make targets that create working directories, set context, launch Claude with the right prompt
9. **Lifecycle cheat sheet** — human-readable map of the entire end-to-end workflow; every phase with the corresponding make command

## Designed concurrently within each prompt

- Artifact conventions — what files that phase produces, naming, where they go
- CLAUDE.md files — rules, safety invariants, known failure patterns relevant to that workflow
- INSTRUCTIONS.md files — reusable reference docs consumed by that phase's agents
