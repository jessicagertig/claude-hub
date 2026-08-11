# Feature Spec Writing

You are writing a feature spec. The spec will be reviewed adversarially in Phase 2, then drive planning and implementation. Write it to survive that review.

## Ground rules

- Read the live codebase (path in `REPO-PATH` in the working directory). Read-only — do not write code, create branches, push, or perform branch operations.
- Read the pipeline's CLAUDE.md for project-specific safety rules and conventions.
- Do not leave any agent-generated files in the repo tree. All output goes in the working directory.

## Context

Read the pipeline's CLAUDE.md (found by going up from the working directory to the pipeline root — e.g., `~/claude-hub/<pipeline>/CLAUDE.md`). It tells you:
- The source repo path (also in `REPO-PATH`)
- The tech stack
- Where conventions live — conventions come from MULTIPLE places, not just one
- Any pipeline-specific rules

Conventions sources (check all that apply):
- **The pipeline CLAUDE.md itself** — pipeline-level rules and known failure patterns
- **The source repo's own CLAUDE.md** — if the repo has its own CLAUDE.md, it carries conventions too
- **A conventions directory** (e.g., `cursor_rules/`) — if one exists in the source repo, read the relevant area files
- **A reference repo** — if the pipeline CLAUDE.md names a different project whose patterns to follow, study that repo's relevant code as a primary blueprint
- **The existing codebase** — find analogs for whatever you're building. Existing patterns in the code are conventions whether or not they're documented

## Process

### Step 1: Establish the working directory

Read `REPO-PATH` in the working directory. If it doesn't exist, write it — the file is a single line: the absolute path to the repo or worktree.

### Step 2: Understand the feature request

Read the task description. Identify what's being asked for, why, and any constraints or scope boundaries.

### Step 3: Analyze the codebase

Study the relevant parts of the codebase before writing anything. Read broadly before narrowing. Look at:
- Data models, schemas, associations, validations
- Controllers, routes, API endpoints, handlers
- Services, business logic, background jobs
- Serialization and API response shapes
- Authorization and permission checks
- Frontend components, state management, data fetching
- Existing tests that cover the affected areas

If a reference repo is specified, study the same areas there and note the patterns to follow.

Take your time here. The spec's quality depends on how well you understand the existing code.

### Step 4: Read the project rules

Read the pipeline CLAUDE.md and all conventions sources it references. These contain conventions the spec must respect.

### Step 5: Write SPEC.md

Write `SPEC.md` in the working directory. Cover:

- **Summary:** What this feature does and why, in plain language.
- **Stack scope:** Which parts of the stack it touches and why.
- **Data model changes:** New or modified tables, columns, schemas. Include types, nullability, defaults. If none, say so explicitly.
- **API changes:** New or modified endpoints, methods, params, response shapes. If none, say so explicitly.
- **Frontend changes:** New or modified components, state, data fetching, routes. Describe the user-facing behavior, not just the technical pieces.
- **Authorization requirements:** What permissions gate what actions, how this interacts with existing boundaries.
- **Constraints and requirements:** Edge cases, validation rules, error states, performance considerations, backward compatibility.
- **Existing patterns to follow:** Name specific files and patterns in the codebase (or reference repo) that the implementation should model after. Cite concrete examples with file paths, not abstract advice.

The spec must be specific enough that a planning agent can read it cold and produce an implementation plan without re-discovering things you already found.

### Spec form

`SPEC.md` is a design document. It states what changes and where, in the sections listed above. Nothing else belongs in it.

- **A correctly worded requirement survives review on its own.** When a review agent flags a requirement, the fix is to word that requirement more precisely — never to append a justification defending it. A spec that argues for its own decisions is a spec that stated them imprecisely.
- **Write for a reader encountering the spec cold.** Every sentence must be actionable without knowing what came before it: no references to prior review rounds, earlier drafts, findings, other runs, or the history of a decision. A spec has no memory of how it was written.
- **No commit hashes, branch names, or git references.** The spec describes the code as it will be, not the commits that got it there. If a change matters, describe the change; the reader cannot resolve a hash and should not have to.
- **State each fact once**, in the section that owns it. Do not restate a decision in a second section so that section reads standalone. A one-line change in the code must not require edits in five places in the spec.
- **No open questions.** Anything needing the owner's ruling goes in `REVIEW-FINDINGS.md` — not as a section, not as a risk list, not as an inline "confirm this is intended."
- **No findings, risk registers, or review provenance.** No "See Risk R6" pointers, no "Amended: round 2" headers, no "correction to the original justification" paragraphs.
- **Judgments only when they compress.** A reason for a design choice belongs in the spec only if it fits naturally as a short sentence inside the section it explains. If it needs a paragraph defending itself against an alternative, it is not spec content.
- **No code blocks, pseudocode, or function signatures.** Name the identifiers — class, method, file, column, route, verbatim string — and say what changes. Column types, nullability, and defaults are the exception.

Write `REVIEW-FINDINGS.md` in the working directory for everything the spec excludes: open questions awaiting a ruling, accepted risks and their blast radius, and anything a review round surfaced that is not yet a design decision. Decisions the owner confirms move to `approved-decisions.md` and are then edited into the section of `SPEC.md` that owns them.

### Step 6: Print the summary

After writing `SPEC.md`, print in conversation:

**Plain English Summary:** 1-2 paragraphs, no jargon, no identifiers. What is this feature doing and why? Write it so someone who doesn't read code can understand the intent.

**Blast Radius Analysis:** For every part of the system this feature touches:
- What existing behavior changes?
- What existing code needs to be modified?
- What callers, consumers, or downstream systems are affected?
- If this is wrong, what breaks? One component? One workflow? The whole app?

## What good specs look like

Good specs are specific enough that the planning agent knows what to build and the review agent knows what to verify. Be concrete — name files, cite patterns, give types. The review agent will verify every claim against the codebase.
