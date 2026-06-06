# Claude Hub — Launcher and Workspace

This is the launcher hub for all Claude Code sessions across Jessica's projects. It is **not** a code repository. Source code lives elsewhere (each pipeline subdir's `CLAUDE.md` points to its source repo). This hub holds:

- **Feature development harness** (`features/`) — generic prompt files for the spec → review → plan → implement → review → harden lifecycle. Any pipeline can use these; pipelines with specific needs override individual prompts at `<pipeline>/features/`. See the "Feature Development Harness" section below.
- **Agent prompt templates** (`_templates/`) loaded via `--append-system-prompt-file` at session launch
- **Skills** (`_skills/`) — domain knowledge files. The actively-used `investigating-before-answering` skill lives at `~/.claude/skills/` (global). Skills checked in here are hub-local.
- **Per-pipeline scratchpad subdirs** — design docs, investigation notes, plans, PR drafts, anything that doesn't belong inside the source repos
- **In-progress working artifacts** (`_in-progress/`) — durable file storage for hub-level and cross-pipeline working artifacts during a session (brainstorm-session scratch, draft skills that apply across pipelines, hub-structural experiments). Pipeline-specific working artifacts live in the corresponding pipeline's own `_in-progress/`, not here. See the "`_in-progress/` directory convention" section below.

## Pipelines

| Pipeline | Source repo | Status |
|---|---|---|
| `inflow-ats/` | `/Users/jessica/wrk/wrk-corp/inflow-ats` | **Focus** — Rails monorepo, rich `cursor_rules/` |
| `thought-leadership-automation/` | `/Users/jessica/wrk/thought-leadership-automation` | **Focus** |
| `wrk-marketing/` | `/Users/jessica/wrk/wrk-corp/wrk-marketing` | Active — frequent small updates |
| `rage-review-cli/` | `/Users/jessica/wrk/review-cli` | Reference + feature work — heavy to run |
| `polymer-help-pipeline/` | `/Users/jessica/polymer-help-pipeline` | Active |
| `polymer-instantly-pipeline/` | `/Users/jessica/polymer-instantly-pipeline` | Active |
| `polymer-prospecting-pipeline/` | `/Users/jessica/polymer-prospecting-pipeline` | Active |

## CLAUDE.md tier rules

Each tier has exactly ONE mandate. Concepts live in exactly ONE tier.

| Tier | Mandate |
|---|---|
| Global (`~/.claude/CLAUDE.md`) | MCP tools, cross-project session patterns, hard rules (db safety, etc.) |
| Hub root (this file) | Hub structure, naming conventions, universal scratchpad rules |
| Pipeline (`<pipeline>/CLAUDE.md`) | Source repo location, pipeline-specific rules and conventions |
| Workflow subdir (`<pipeline>/<workflow>/CLAUDE.md`) | Methodology ONLY for that workflow |

Do NOT repeat upstream rules in downstream files.

## Universal rules

1. **Never write files into source repos from a hub session.** Outputs go in the pipeline scratchpad subdir, not into the source code.
2. **Always create a subdirectory for new work** (`<pipeline>/<workflow>/<dated-slug>/`) — never dump files at a pipeline root.
3. **The source repo's own `CLAUDE.md` and `cursor_rules/` are authoritative for code conventions.** The hub does not duplicate them.

## Naming

- Workflow subdirs: lowercase hyphenated (`features/`, `investigations/`, `pr-reviews/`)
- Dated work items: `YYYY-MM-DD-kebab-slug/`
- Instructions/playbooks (UPPERCASE): `INSTRUCTIONS.md`, `PLAYBOOK.md`
- Work outputs (kebab-case): `plan.md`, `pr-description.md`, `investigation.md`
- Agent prompt templates: `<name>-agent.md` in `_templates/`

## `_in-progress/` directory convention

Working artifacts that need durable file storage during a session — draft skills, design notes, partial plans, in-flight investigations, anything that may or may not graduate to a permanent location — live in `_in-progress/` directories at two levels:

- **Hub-level** (`~/claude-hub/_in-progress/<artifact-name>/`) for cross-pipeline and hub-level work — a brainstorming session for a new global skill, a template design that applies across pipelines, a hub-structural experiment.
- **Pipeline-level** (`~/claude-hub/<pipeline>/_in-progress/<artifact-name>/`) for work specific to one pipeline — a draft agent for inflow-ats, an investigation that only applies to thought-leadership-automation, a feature design specific to polymer-help-pipeline.

Do not cross-level: pipeline-specific artifacts do not live in the hub-root `_in-progress/`; hub-level artifacts do not live in any pipeline's `_in-progress/`.

The user retains complete control over `_in-progress/` contents at either level. Graduating an artifact to its permanent location is a deliberate move — for example moving a finalized skill from `~/claude-hub/_in-progress/<skill-name>/` to `~/.claude/skills/` or `~/claude-hub/_skills/`. Deleting an entire `_in-progress/` subdirectory at either level is safe and affects nothing outside that subdirectory.

## Feature Development Harness

Generic prompt files for the full feature lifecycle live at `~/claude-hub/features/`. Read `~/claude-hub/features/LIFECYCLE.md` for the orchestrated flow (Phases 0-7). Read `~/claude-hub/features/MANUAL-REFERENCE.md` to run individual phases manually.

**Override mechanism:** For each phase, the orchestrating agent looks for the prompt file at `~/claude-hub/<pipeline>/features/<prompt-file>` first, then falls back to `~/claude-hub/features/<prompt-file>`. A pipeline can override one prompt, all of them, or none.

**Pipeline CLAUDE.md requirements for the harness:** Each pipeline's CLAUDE.md should declare:
- **Source repo** — the path to the source code
- **Stack** — the tech stack (language, framework, etc.)
- **Conventions sources** (optional) — where coding conventions live. A pipeline can have multiple: a conventions directory in the source repo (e.g., `cursor_rules/`), a reference repo to copy patterns from, the source repo's own CLAUDE.md, and the existing codebase itself (find analogs). List whatever applies. If nothing is declared, the harness works with the codebase and CLAUDE.md files as the conventions sources.

## Known Failure Patterns

Rules derived from actual review failures. Each cites the failure that motivated it.

### Stale references after amendments

When a spec or document is amended (renaming a concept, changing a design decision, switching from parallel to sequential, etc.), **search the entire document for every other reference to the old concept and update them all in the same amendment.** Do not amend only the primary location.

_Motivated by: QA harness spec review Rounds 2-3. Round 1 renamed `test_frr` to `script_runner` but left 3 stale `test_frr` references elsewhere. Round 2 changed agents from parallel to sequential but left a stale "in parallel" clause. Each stale reference became a HIGH finding in the next round._

### Do not discard information callers need

When a helper function has access to data its callers will need (status codes, error details, metadata), **return that data.** Do not silently discard it and force callers to hardcode a substitute. If a function talks to an external system (HTTP, database, file system), its return type must include the response metadata, not just the parsed body.

_Motivated by: QA harness impl review Round 1. `_request` returned only the parsed response body, discarding `response.status_code`. `_execute_step` had no choice but to hardcode `"status_code": 200` for every request regardless of actual outcome, producing misleading output._

### Verify preconditions before network calls

Before making HTTP calls to a service, **verify the service is alive** (health check, process-alive check, or equivalent). Do not let requests fail with opaque connection errors or timeouts when a clear precondition check would produce an actionable error message.

_Motivated by: QA harness spec review Round 1. Seed/cleanup commands made HTTP calls without verifying the server was running, leading to opaque timeout failures._

### Account for shared-resource conflicts in multi-agent designs

When multiple agents or processes share a resource (database, browser session, file system, port), **explicitly state whether they run in parallel or sequentially and why.** If parallel, document the isolation mechanism. If sequential, enforce it in the orchestrator -- do not leave it to convention.

_Motivated by: QA harness spec review Rounds 1-2. Round 1: parallel agents sharing one Playwright browser session would race. Round 2: parallel agents sharing one database would destroy each other's seed data during cleanup. Both required switching to sequential execution with orchestrator-owned lifecycle._

### Do not embed pipeline-specific names in generic infrastructure

When building infrastructure intended to work across pipelines, **use pipeline-agnostic names for concepts, commands, and config keys.** If a concept originates from one pipeline's terminology, rename it before putting it in the generic layer.

_Motivated by: QA harness spec review Round 1. `test_frr` (a Rails-specific Foreman concept) was used as the name for a generic "run a test script" capability, with an incorrect definition. Renamed to `script_runner`._

### Hard rules cannot be rationalized away by plans

When a spec or global CLAUDE.md states a hard rule (e.g., "RAILS_ENV=test always"), **the implementation must enforce it defensively even if another mechanism also provides it.** A plan that says "the config command includes it inline, so we don't need to enforce it in code" does not override a hard rule. Defense in depth is the point -- the harness enforces the invariant regardless of what the config author does.

_Motivated by: QA harness impl review (redo) Round 1, HIGH-1. The plan explicitly rationalized omitting `env["RAILS_ENV"] = "test"` because the config's server command includes it inline. The spec's hard rule says "RAILS_ENV=test always." The analog enforces it defensively. A config author could omit it from the command string and the harness would silently start a dev server._

### Verify the execution lifecycle matches before copying an analog pattern

When adapting code from an analog, **check whether the new code has the same process lifecycle** (long-lived vs. fire-and-forget, parent-stays-alive vs. parent-exits). Patterns that are correct for a long-lived context manager (atexit handlers, subprocess.PIPE for output capture) can be fatal for a CLI that spawns children and exits. Specifically: atexit handlers fire on parent exit and kill children; PIPE stdout causes SIGPIPE death in children when the parent's read-end closes.

_Motivated by: QA harness impl review (redo) Rounds 3-4. HIGH-4: atexit handler copied from the analog (a long-lived context manager) killed server subprocesses immediately when the CLI process exited after printing "READY." HIGH-5: subprocess.PIPE from the same analog caused child processes to die via SIGPIPE when the parent exited. Both were correct in the analog's lifecycle but fatal in the CLI's fire-and-forget lifecycle._

### Check whether target artifacts already exist before proposing creation

Before a plan says "create file X" or "add section Y to document Z," **verify that X does not already exist and that Z does not already contain Y.** If the artifact exists, the plan should say "verify" or "update if needed," not "create" or "add." An implementation agent following "create" instructions will produce duplicates or overwrite existing content.

_Motivated by: QA harness plan review Pass 1. HIGH-1: plan said "Add Phase 8 section to LIFECYCLE.md" but LIFECYCLE.md already had Phase 8 (lines 115-128). HIGH-2: plan put `prompts/qa-prompt.md` inside the qa-harness package, but the prompt already existed at `~/claude-hub/features/qa-prompt.md` and was outside the lifecycle's search path. Both required amendments._

### Fix agent code is unreviewed scope

When a fix agent adds substantial new code to resolve a review finding (new methods, new code paths, modified validations), **that code has been through zero adversarial review.** The diff-to-spec review must trace every line of fix agent code back to the spec. Code that doesn't trace back is HIGH — "it works correctly" is not a downgrade reason. Report the FULL extent of the change, not just one surface symptom.

_Motivated by: inflow-ats AI credits feature, Phase 8 Layer 1. A fix agent added 46 lines of new payment interactor code (apply_one_off_from_invoice) and relaxed model validations in the Stripe payment area — all without spec coverage. The diff-to-spec review had 20+ agents reading the full diff. Every one of them should have flagged a brand new unspecced method in the payment interactor. None did. The finding was classified MED and only mentioned the validation line, not the 46 lines of new logic behind it._

### Spec-implementation mismatch is never MED

If the spec says X and the implementation does Y, **that is HIGH or BLOCKER — even if Y is "functionally equivalent."** The user decides whether the deviation is acceptable, not the reviewer. "Close enough" is not spec-compliant. Reviewers must not rationalize deviations by arguing functional equivalence.

_Motivated by: inflow-ats AI credits feature. M6: spec said "use invoice metadata" for top-up granting, implementation made two extra Stripe API calls via checkout session lookup instead. Classified MED as "functionally equivalent." M8: spec explicitly reviewed handle_charge_refunded and said "no change," fix agent deleted it entirely. Classified MED as "cleanup." Both were spec-implementation mismatches that should have been HIGH/BLOCKER and surfaced to the user._

### Fix agents must not delete pre-existing code the spec reviewed

When the spec explicitly reviews a piece of existing code and decides "no change," **that decision is part of the spec.** A fix agent that deletes that code has destroyed approved work. Before classifying a deletion as cleanup or "removing out-of-spec code," check whether the code existed on the branch before the fix agent's changes and whether the spec reviewed it.

_Motivated by: inflow-ats AI credits feature. The spec (Note #33) explicitly reviewed handle_charge_refunded and decided "no change." The fix agent, told to strip out-of-spec code, deleted it. The reviewer classified this as MED ("refund handling outside Phase 1 scope") despite the spec explicitly including it in scope._
