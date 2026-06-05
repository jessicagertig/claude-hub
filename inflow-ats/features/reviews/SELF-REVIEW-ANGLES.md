# Self-Review Angles -- Jessica's Feature Harness vs Nick's Approach

Generated: 2026-06-03
Sources reviewed: 10 Jessica harness files, 8 Nick source files, Nick's process description from Slack

---

## Angle 1: Orchestration Model -- Who Drives, Who Stops

**What to compare:**
- Jessica: `LIFECYCLE.md` (orchestrating agent concept, sub-agent dispatch, phase gates)
- Jessica: `SETUP-INSTRUCTIONS.md` (manual `claude --append-system-prompt-file` invocations)
- Nick: `convox/v3/features/CLAUDE.md` (phases, manual `cd` + `claude` invocations)
- Nick: Slack process description ("I have my agents write specs and iteratively adversarial review specs with workflow agents")
- Nick: `R1-ITERATIVE-REVIEW-PROMPT.md` (single-session, self-contained prompt)

**What a divergence looks like:**

Jessica's harness has two contradictory orchestration models living side by side. `LIFECYCLE.md` describes an "orchestrating agent" that spawns sub-agents and drives the entire flow autonomously, checking gate conditions between phases. `SETUP-INSTRUCTIONS.md` describes a completely different model: the human runs each phase manually via separate `claude` invocations.

Nick does not use an orchestrating agent. He runs each phase as a separate Claude session, manually, from the right directory. His Slack description confirms this: "I generally try to just go to the correct directory for the applicable claude.md trees to load... so like cd /convox/v2/patches && claude." His `v3/features/CLAUDE.md` has no orchestrator concept -- just phase descriptions and manual launch commands.

The divergence is that Jessica's `LIFECYCLE.md` introduces an abstraction (a persistent orchestrating agent) that Nick's process does not have and that `SETUP-INSTRUCTIONS.md` contradicts. An agent reading both files gets conflicting instructions about whether it should autonomously chain phases or stop and wait for human invocation.

---

## Angle 2: Spec vs Plan Emphasis

**What to compare:**
- Jessica: `spec-writing-prompt.md`, `spec-review-prompt.md` (dedicated spec phase)
- Jessica: `_base-template.md` (planning prompt, called "Phase 3")
- Jessica: `plan-review-prompt.md` (2-pass plan review)
- Nick: Slack process description ("I've found plans to be less helpful than spec")
- Nick: `R1-ITERATIVE-REVIEW-PROMPT.md` (iterative review on the plan/spec, not a separate plan artifact)
- Nick: `convox/v3/features/CLAUDE.md` ("Planning Phase" produces a plan, "Review Phase" is one step)

**What a divergence looks like:**

Nick explicitly says "I've found plans to be less helpful than spec." His iterative adversarial review (the heavy multi-round process) runs on the spec/plan as a combined artifact -- `MASTER-COMBINED-PLAN.md` is both spec and plan. He does not run separate iterative adversarial review on the spec AND then again on the plan.

Jessica's harness runs the full iterative adversarial review loop (up to 5 rounds, two-consecutive-pass criterion) on the spec in Phase 2, then writes a separate plan in Phase 3, then reviews the plan in Phase 4 (2 fixed passes), then implements in Phase 5, then runs ANOTHER full iterative adversarial review loop on the implementation in Phase 6. That is three review gates with two being iterative.

The divergence is structural weight distribution. Nick puts the heavy review on the spec (because that is where the design decisions live), treats the plan as a mechanical translation (2 fixed passes, no iterative loop), and puts the second heavy review on the implementation. Jessica duplicates this structure but adds the spec as a separate artifact from the plan, creating an extra phase boundary that Nick's process does not have. The spec-writing phase (`spec-writing-prompt.md`) and the planning phase (`_base-template.md`) could produce overlapping or contradictory content because they run in separate sessions with no shared state beyond files on disk.

Nick's comment about plans being less helpful than specs suggests the right response is to invest more in the spec and less in a separate plan artifact, not to have both as heavyweight phases.

---

## Angle 3: Review Angle Grain Size and Structure

**What to compare:**
- Jessica: `generate-review-angles-prompt.md` (dynamic angle generation per feature)
- Jessica: `spec-review-prompt.md` (references `REVIEW-ANGLES.md` for angles)
- Jessica: `impl-review-prompt.md` (references `REVIEW-ANGLES.md` for impl angles)
- Nick: `R1-ITERATIVE-REVIEW-PROMPT.md` (8 hardcoded adversarial angles, A1-A8)
- Nick: `adversarial-review-agent.md` (6 hardcoded phases)
- Nick: Review rounds at `.../reviews/round-1/` (6-7 angle files per round: state-machine-review, source-accuracy-review, concurrency-review, etc.)

**What a divergence looks like:**

Nick's review angles are bespoke, hand-written, and domain-specific. His R1 iterative review prompt defines 8 angles (A1-A8) with extreme specificity: exact file:line ranges to check, exact gate-combination matrices to enumerate, exact failure modes to verify. His `adversarial-review-agent.md` template has 6 fixed phases (understand the change, known failure patterns, backward compat, code scrutiny, production scenarios, testing gaps). In practice, his actual review rounds use feature-specific angle names like "state-machine-review", "graphql-contract-review", "concurrency-review" -- each one written for that specific feature's concerns.

Jessica's harness generates angles dynamically via `generate-review-angles-prompt.md`. The agent reads the spec, identifies subsystems, finds a full-stack analog, and produces `REVIEW-ANGLES.md`. The examples given are generic ("state-machine-review", "graphql-contract-review", "authorization-review"). This is a reasonable idea but the prompt does not show how to make angles as specific as Nick's -- Nick's A4 "Template correctness under all gate combinations" has an explicit 4-cell matrix; his A5 has specific test assertion checks. The `generate-review-angles-prompt.md` tells the agent to find "thematic concerns" but does not push for that level of specificity.

The divergence is that Nick's angles are surgical and verifiable (each angle has concrete pass/fail criteria baked in), while Jessica's angles risk being generic lenses that produce generic findings. The `generate-review-angles-prompt.md` stops at "identify the themes that matter" without requiring the agent to define what a pass and a fail look like for each angle.

---

## Angle 4: Agent Autonomy on Launch -- What Does the Agent Know When It Starts

**What to compare:**
- Jessica: `_base-template.md` (template with placeholder sections: Open PR Branches, High-Conflict Files, Standing Technical Directives -- all empty)
- Jessica: `impl-prompt.md` (same empty placeholder sections)
- Jessica: `SETUP-INSTRUCTIONS.md` (setup is create dir, copy spec, write REPO-PATH)
- Nick: `convox/CLAUDE.md` (repository map, high-conflict files listed, known failure patterns with real incidents, cross-system dependency guide)
- Nick: `convox/v3/CLAUDE.md` (architecture section, provider rules, terraform safety, completion checklist)
- Nick: `R1-ITERATIVE-REVIEW-PROMPT.md` (explicit inputs list with full file paths, scope definition, prior round references)

**What a divergence looks like:**

Nick's agents inherit a deep context tree. When an agent starts in `convox/v3/features/`, it inherits rules from the project root, `convox/CLAUDE.md` (repo map, known failure patterns, backward compat rules, code style rules, automated safety checks, completion checklist), and `convox/v3/CLAUDE.md` (architecture, provider rules, TF safety, kubectl rules, high-conflict files). The agent knows the terrain before it reads the first line of the feature spec.

Jessica's agents start with much less. The `_base-template.md` and `impl-prompt.md` have empty placeholder sections for "Open PR Branches", "High-Conflict Files", and "Standing Technical Directives" -- marked with HTML comments like `<!-- Update this table before each planning session -->` and `<!-- Populate as we identify frequently-changing files -->`. The `CLAUDE.md` at `~/claude-hub/inflow-ats/` is thin: it names the stack, points to the source repo's CLAUDE.md and cursor_rules, and lists hard rules inherited from the global config. But it has no equivalent of Nick's "Known Failure Patterns" section (real incidents that teach agents what to fear), no repo map, no high-conflict files, no cross-system dependency guide.

The divergence is that Nick's agents arrive pre-loaded with institutional knowledge, while Jessica's agents arrive with a pointer to the source repo and empty scaffolding. The feature prompts tell agents to "read cursor_rules/" and "read CLAUDE.md", but the CLAUDE.md they read is thin on operational wisdom. The placeholder sections in the templates suggest the intent is there but the content has not been filled in.

---

## Angle 5: Artifact Structure and Naming

**What to compare:**
- Jessica: `LIFECYCLE.md` (artifact trail section), all prompt files (output file names)
- Nick: `convox/v3/features/CLAUDE.md` (directory naming, status tracking)
- Nick: `.../reviews/` directory structure (round-1/ through round-6/, impl-round-1/, angle-slug filenames)
- Nick: Project root CLAUDE.md (naming conventions section)

**What a divergence looks like:**

The artifact structures are broadly aligned. Both use round directories (`spec-round-N/`, `impl-round-N/` for Jessica; `round-N/`, `impl-round-1/` for Nick). Both use angle-slug filenames within rounds. Both have terminal verdict files.

Two differences stand out:

1. Nick's archive shows the review rounds live alongside the feature artifacts in the same directory tree (`.../reviews/round-1/`, `.../reviews/impl-round-1/`). Jessica's harness puts reviews under a `reviews/` subdirectory in the feature working directory, which matches. But Nick's R1 prompt writes a `ROUND-LOG.md` as an append-only log alongside the per-angle files. Jessica's harness has no equivalent of a consolidated round log -- only per-angle files and a `verdict.md` per round. The round log is useful for quick scanning across rounds without opening each directory.

2. Jessica's naming convention for working directories (`YYYY-MM-DD-feature-name/`) matches the project root conventions. Nick uses `NN-kebab-slug/` for features in the queue and dated directories for work items. This is a reasonable adaptation, not a divergence.

The divergence is minor but the missing consolidated round log could matter for multi-round reviews where you want to see the trajectory at a glance.

---

## Angle 6: Intervention and Escalation Patterns

**What to compare:**
- Jessica: `LIFECYCLE.md` (gate conditions, escalation points)
- Jessica: `spec-review-prompt.md` (escalation conditions section)
- Jessica: `impl-review-prompt.md` (escalation conditions section)
- Nick: `convox/CLAUDE.md` ("Failure Handling During Testing -- STOP, VERIFY, PRESENT, WAIT")
- Nick: `R1-ITERATIVE-REVIEW-PROMPT.md` (escalation conditions section)

**What a divergence looks like:**

Nick's escalation protocol is visceral and battle-tested. His "STOP, VERIFY, PRESENT, WAIT" section in `convox/CLAUDE.md` runs almost 100 lines. It was written after real incidents where agents "documented and continued" past failures, producing useless 12-section test reports built on a broken foundation. It includes a `BLOCKING-FAILURE.md` template with exact fields. It bans specific phrases ("proceeding anyway", "documenting and continuing", "noted, continuing"). It distinguishes interactive sessions (present in chat) from overnight sessions (file is the communication channel).

Jessica's escalation points are present but thinner. `LIFECYCLE.md` says "If ESCALATE: stop and present to Jessica" at multiple gates. The review prompts list escalation conditions (redesign needed, prior amendment incorrect, repo drift, permission denial). But there is no equivalent of the "STOP, VERIFY, PRESENT, WAIT" discipline -- no explicit instructions to verify the failure is real before escalating, no `BLOCKING-FAILURE.md` template, no banned phrases, no distinction between interactive and autonomous sessions.

The divergence is not that Jessica's harness lacks escalation points (it has them at every gate), but that it lacks the operational discipline around how to escalate. Nick's protocol exists because agents are bad at distinguishing real failures from agent errors, and the protocol forces verification before escalation. Without that discipline, Jessica's agents might escalate on false positives or, worse, might silently continue past real failures because the prompt only says "stop and present" without defining what counts as a failure worth presenting.

---

## Angle 7: Iterative Review Mechanics -- Rounds, Convergence, Failure Reports

**What to compare:**
- Jessica: `spec-review-prompt.md` (iterative loop, 5-round cap, two consecutive passes)
- Jessica: `impl-review-prompt.md` (iterative loop, 5-round cap, two consecutive passes, FAILURE-REPORT.md)
- Nick: `R1-ITERATIVE-REVIEW-PROMPT.md` (iterative loop, 5-round cap, two consecutive passes, ROUND-LOG.md)
- Nick: `.../reviews/round-1/ through round-6/` (actual rounds from a real review)

**What a divergence looks like:**

The core mechanics are well-matched: both use two-consecutive-pass convergence, both cap at 5 rounds, both have escalation at the cap. Two mechanical differences:

1. Nick's spec review and impl review are separate sessions but share the SAME convergence criterion and angle set. His R1 prompt reviews a combined spec+plan artifact. Jessica's harness runs the spec review with its own angles and convergence loop, then later runs the impl review with potentially different angles from the same `REVIEW-ANGLES.md`. The `generate-review-angles-prompt.md` produces one file that both review agents consume, which is good -- but the spec review prompt says "address every angle listed in the 'Spec review angles' section" while the impl review prompt says "address every angle listed in the 'Impl review angles' section." This implies `REVIEW-ANGLES.md` should have two separate angle lists, but the `generate-review-angles-prompt.md` does not mention splitting angles into spec vs impl categories. The agent has to figure this out.

2. Nick's actual review archive shows 6 rounds of spec review and 1 round of impl review for the monitoring-toggle-redesign feature. That is more rounds than the 5-round cap. Looking more carefully, the `round-1/` through `round-6/` directories are spec review rounds, and `impl-round-1/` is the first impl round. This suggests Nick sometimes exceeds the cap or the cap is enforced differently in practice than in the prompt.

The divergence on the angle-splitting ambiguity is a real gap that could confuse agents. The divergence on round count may just be that the monitoring-toggle-redesign predates the 5-round cap rule.

---

## Angle 8: Pattern Matching Approach -- Full-Stack Analog and Conventions

**What to compare:**
- Jessica: `generate-review-angles-prompt.md` (Step 2: "Find the full-stack analog", priority rule)
- Jessica: `_base-template.md` (Step 3: "Study existing patterns", pattern precedents)
- Jessica: `spec-writing-prompt.md` (Step 3: "Analyze the codebase", "Existing patterns to follow")
- Nick: Slack process description ("adversarial review lane specifically at 'reinventing the wheel or not using codebase existing patterns'")
- Nick: `convox/CLAUDE.md` ("Backward Compatibility" section, API and SDK Safety section)
- Nick: `adversarial-review-agent.md` (Phase 2: known failure pattern scan)

**What a divergence looks like:**

Both approaches emphasize pattern matching, but they operationalize it differently.

Jessica's harness has a formal "full-stack analog" concept: the `generate-review-angles-prompt.md` instructs the agent to find an end-to-end flow that matches the shape of work, trace every layer of it, and use it as the primary blueprint. The `_base-template.md` requires finding "at least two existing examples" as pattern precedents. The `generate-review-angles-prompt.md` adds a priority rule: "Where the full-stack analog deviates from convention, the analog wins." This is explicit and well-structured.

Nick's approach to pattern matching is less formalized but more deeply embedded. His `convox/CLAUDE.md` has hundreds of lines of known failure patterns, API safety rules, backward compatibility requirements, and code style rules. These are not "find an analog" instructions -- they are accumulated institutional knowledge that prevents pattern violations. His "reinventing the wheel" review lane is one of several adversarial angles, not a separate pre-review phase.

The divergence is that Jessica's harness formalizes the analog-finding process (good) but puts the burden on the agent to discover patterns at runtime. Nick's approach front-loads pattern knowledge into the CLAUDE.md tree so agents inherit it automatically. Jessica's `CLAUDE.md` does not yet have the accumulated "here is what we always get wrong" knowledge that makes Nick's approach work. The formal analog process is a reasonable substitute for institutional knowledge that does not yet exist, but it should be understood as a bootstrapping mechanism, not the steady-state design.

---

## Angle 9: CLAUDE.md Tree Structure and Content Weight

**What to compare:**
- Jessica: `~/claude-hub/inflow-ats/CLAUDE.md` (thin: stack description, pointers, hard rules, empty pipeline-specific section)
- Jessica: `~/claude-hub/inflow-ats/features/` (prompt files carry all the methodology)
- Nick: `~/Projects/claude-outputs/convox/CLAUDE.md` (heavy: git rules, code style, backward compat, known failures, safety checks, completion checklist -- 382 lines)
- Nick: `~/Projects/claude-outputs/convox/v3/CLAUDE.md` (heavy: architecture, TF safety, kubectl rules, high-conflict files, completion checklist -- 102 lines)
- Nick: `~/Projects/claude-outputs/convox/v3/features/CLAUDE.md` (methodology only: phases, status tracking -- 40 lines)

**What a divergence looks like:**

Nick's CLAUDE.md tree has a clear content gradient: shared CLAUDE.md files are heavy with safety rules, known failure patterns, and institutional knowledge. Workflow-tier files (like `v3/features/CLAUDE.md`) are thin and contain only methodology. The project root CLAUDE.md explicitly defines a tier system with rules about what goes where.

Jessica's tree is inverted. The `~/claude-hub/inflow-ats/CLAUDE.md` is thin (48 lines, mostly pointers to the source repo). The feature prompt files carry all the operational weight -- review procedures, convergence criteria, failure report formats. The source repo has its own CLAUDE.md and `cursor_rules/`, but those are not the scratchpad's CLAUDE.md files.

This is not wrong -- the inflow-ats source repo's CLAUDE.md and cursor_rules/ are the institutional knowledge base, and the scratchpad CLAUDE.md correctly points agents there. But there is a gap: Nick's `convox/CLAUDE.md` contains operational lessons learned from failures (the TF State Fingertrap, the CF Stack Deadlock, the Lint Verification Gap). Jessica's `~/claude-hub/inflow-ats/CLAUDE.md` has a "Pipeline-specific rules" section that says "(Add inflow-ats-only rules here that aren't already in the source repo's CLAUDE.md and aren't global. Empty for now -- we'll fill as we build workflows.)"

The hardening prompt (`hardening-prompt.md`) is designed to fill this gap -- it extracts lessons from failure reports and writes rules to the CLAUDE.md. But until features have actually been run through the harness, the CLAUDE.md will remain thin. The divergence is that Nick's CLAUDE.md files represent years of accumulated operational wisdom, while Jessica's represent an empty vessel waiting to be filled. The harness correctly includes the mechanism to fill it, but the gap at launch is real.

---

## Angle 10: The Spec-Writing Phase -- Existence and Scope

**What to compare:**
- Jessica: `spec-writing-prompt.md` (Phase 0 in LIFECYCLE.md)
- Nick: No equivalent standalone spec-writing prompt

**What a divergence looks like:**

Jessica's harness has an explicit spec-writing phase (Phase 0) with a dedicated prompt. The agent reads the codebase, reads project rules, and writes `SPEC.md` with a defined structure: summary, stack scope, data model changes, API changes, frontend changes, authorization requirements, constraints, existing patterns.

Nick does not have a separate spec-writing prompt in his templates. His Slack description says "I have my agents write specs and iteratively adversarial review specs" but the mechanism for spec-writing is not templated -- it appears to be part of the planning session or a preceding ad-hoc session. His R1 prompt references `MASTER-COMBINED-PLAN.md` which is a combined spec+plan artifact, not a standalone spec reviewed separately from the plan.

This is an intentional adaptation by Jessica's harness, not an omission. But it creates the question: does the spec-writing prompt produce a spec that is specific enough to survive adversarial review? The prompt says "Write it so someone who doesn't read code can understand the intent" for the summary, and requires specificity for the technical sections. Nick's specs (as seen through his review rounds) contain file:line citations, exact struct field definitions, migration tables with row-by-row mappings, gate-combination matrices. Jessica's `spec-writing-prompt.md` asks for "specific enough that a planning agent can read it cold" but does not push for the level of precision that Nick's adversarial review rounds demand.

The divergence is that the spec-writing prompt sets the floor too low for what the downstream adversarial review will require. If the spec is written at the level the prompt asks for (model names, file paths, pattern examples), it may not survive review angles that demand gate-combination matrices and migration row mappings. The prompt should either push for higher precision or the review angles prompt should calibrate to the precision the spec-writing prompt actually produces.

---

## Angle 11: Human Gate Placement and Count

**What to compare:**
- Jessica: `LIFECYCLE.md` (Phase 1 gate: "Stop here and present the angles to Jessica. She reviews and approves before you continue. This is the one human gate in the flow.")
- Nick: Slack process description (multiple implicit human gates: Nick launches each session manually, reviews specs via plain-english summary, decides when to proceed)
- Nick: `convox/CLAUDE.md` ("Failure Handling" section: "Present to Nick and wait for instructions. Nick decides what happens next.")

**What a divergence looks like:**

Jessica's `LIFECYCLE.md` explicitly calls Phase 1 (review angles approval) "the one human gate in the flow." Every other gate is an automated file-existence check ("SPEC.md exists", "plan.md exists", "SPEC-REVIEW-COMPLETE.md exists and says READY FOR PLANNING").

Nick has no single explicit human gate because every phase IS a human gate -- he manually launches each session. He reviews the plain-english summary + blast radius before proceeding. He reads failure reports and decides whether to re-test, investigate, skip, or block. Every phase transition involves Nick making a decision.

The divergence is that Jessica's harness has automated away most of the inter-phase decisions, leaving only one explicit human checkpoint. If the orchestrating agent model from `LIFECYCLE.md` is used (rather than the manual model from `SETUP-INSTRUCTIONS.md`), the flow could run from Phase 0 through Phase 7 with human intervention only at Phase 1. That is a much higher level of autonomy than Nick's process. Whether this is a good adaptation or a risk depends on trust: Nick has years of operational context that lets him catch problems agents miss. Jessica is bootstrapping that context, which argues for more human gates, not fewer, during the early runs.

---

## Angle 12: Hardening Loop -- Learning from Failures

**What to compare:**
- Jessica: `hardening-prompt.md` (Phase 7: extract lessons from failure reports, write rules to CLAUDE.md)
- Nick: Slack process description ("have other agents pick it apart for issues then immediately have those agents write FAILURE reports then get my action agents to update all claude.md files")
- Nick: `convox/CLAUDE.md` ("Known Failure Patterns" section -- real incidents with root cause, mitigation, prevention)

**What a divergence looks like:**

Both approaches include a hardening step. Nick describes it as: review -> failure reports -> update CLAUDE.md. Jessica's `hardening-prompt.md` formalizes this as Phase 7 with a specific process (extract lessons, check existing coverage, write rules, document what was done).

The key difference is WHERE the hardened rules go. Nick's rules go into the main CLAUDE.md tree that every agent inherits automatically by virtue of working in the right directory. Jessica's `hardening-prompt.md` writes rules to `~/claude-hub/inflow-ats/CLAUDE.md`. But the feature prompt files tell agents to read the source repo's CLAUDE.md and cursor_rules/, not just the scratchpad CLAUDE.md. Unless the hardened rules also flow back to the source repo (or the prompts explicitly tell agents to read both CLAUDE.md files), the lessons may not reach future agents.

The `impl-prompt.md` says "Follow ~/claude-hub/inflow-ats/CLAUDE.md safety rules and all cursor_rules/ in the inflow-ats repo." The spec-review prompt says the same. So agents ARE told to read the scratchpad CLAUDE.md. But the scratchpad CLAUDE.md currently says "Pipeline-specific rules: (Empty for now)." Once hardening starts filling it, the rules should propagate. The gap is that the hardening prompt does not consider whether a rule belongs in the source repo's CLAUDE.md instead of (or in addition to) the scratchpad CLAUDE.md.

---

## Summary of Divergence Severity

| Angle | Severity | Core Issue |
|-------|----------|------------|
| 1. Orchestration Model | HIGH | Two contradictory models (`LIFECYCLE.md` vs `SETUP-INSTRUCTIONS.md`); Nick uses manual launches |
| 2. Spec vs Plan Emphasis | MEDIUM | Extra phase boundary; Nick treats spec+plan as one artifact, says plans less helpful |
| 3. Review Angle Grain Size | HIGH | Jessica's angles risk being generic; Nick's are surgical with explicit pass/fail criteria |
| 4. Agent Autonomy on Launch | HIGH | Empty placeholder sections; no institutional knowledge yet in CLAUDE.md |
| 5. Artifact Structure | LOW | Broadly aligned; missing consolidated round log is minor |
| 6. Intervention/Escalation | MEDIUM | Escalation points exist but lack verification discipline and banned-phrase rigor |
| 7. Iterative Review Mechanics | MEDIUM | Spec vs impl angle split is ambiguous in generate-review-angles prompt |
| 8. Pattern Matching | MEDIUM | Formal analog concept is good; but institutional knowledge base is empty |
| 9. CLAUDE.md Tree Structure | MEDIUM | Intentionally thin (waiting for hardening), but gap at launch is real |
| 10. Spec-Writing Precision | MEDIUM | Floor set by spec-writing prompt may be too low for downstream review demands |
| 11. Human Gate Placement | HIGH | "One human gate" is much less oversight than Nick's process; risky during bootstrap |
| 12. Hardening Loop | LOW | Mechanism exists; minor gap on which CLAUDE.md receives the rules |
