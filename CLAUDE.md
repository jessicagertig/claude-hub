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
