# Inflow ATS — Feature Spec Writing

You are writing a feature spec for inflow-ats (Rails API + React frontend). The spec will be reviewed adversarially in Phase 2, then drive planning and implementation. Write it to survive that review.

## Ground rules

- Read the live codebase (path in `REPO-PATH` in the working directory). Read-only — do not write code, create branches, push, or perform branch operations.
- Follow `~/claude-hub/inflow-ats/CLAUDE.md` safety rules.
- Do not leave any agent-generated files in the repo tree. All output goes in the working directory.

## Inputs

1. The task description provided when this session was launched — this is the feature request.
2. The live codebase at the path from `REPO-PATH`.
3. `~/claude-hub/inflow-ats/CLAUDE.md`
4. `<REPO>/cursor_rules/core_critical_rules.md` and the relevant area files in `<REPO>/cursor_rules/` for whatever this feature touches (backend, frontend, cypress).

## Process

### Step 1: Establish the working directory

Read `REPO-PATH` in the working directory. If it doesn't exist, write it — you know your worktree path. The file is a single line: the absolute path to the repo or worktree (e.g., `/Users/jessica/wrk/wrk-corp/inflow-ats.ai-subscriptions/`).

### Step 2: Understand the feature request

Read the task description. Identify what's being asked for, why, and any constraints or scope boundaries Jessica specified.

### Step 3: Analyze the codebase

Study the relevant parts of the codebase before writing anything. Read broadly before narrowing:

- Models, associations, validations, callbacks, scopes
- Controllers, routes, before_actions
- Services, interactors, background jobs
- Serializers and API response shapes
- Pundit policies and permission checks
- React components, hooks, React Query queries/mutations
- Existing tests (RSpec, Cypress) that cover the affected areas

Take your time here. The spec's quality depends on how well you understand the existing code.

### Step 4: Read the project rules

Read `~/claude-hub/inflow-ats/CLAUDE.md` and the relevant `cursor_rules/` files for the areas this feature touches. These contain conventions the spec must respect.

### Step 5: Write SPEC.md

Write `SPEC.md` in the working directory. Cover:

- **Summary:** What this feature does and why, in plain language.
- **Stack scope:** Which parts of the stack it touches (backend, frontend, both) and why.
- **Data model changes:** New or modified tables, columns, indexes, constraints. Include column types, nullability, defaults. If no data model changes, say so explicitly.
- **API changes:** New or modified endpoints, HTTP methods, request params, response shapes. If no API changes, say so explicitly.
- **Frontend changes:** New or modified components, hooks, queries, mutations, routes. Describe the user-facing behavior, not just the technical pieces.
- **Authorization requirements:** Which policies need creation or modification, what permissions gate what actions, how this interacts with existing org/role boundaries.
- **Constraints and requirements:** Edge cases, validation rules, error states, performance considerations, backward compatibility requirements.
- **Existing patterns to follow:** Name specific files and patterns in the codebase that the implementation should model after. This is where your codebase analysis from Step 3 pays off — cite concrete examples, not abstract advice.

The spec must be specific enough that a planning agent can read it cold and produce an implementation plan without re-discovering things you already found. If you reference a model, name it. If you reference a pattern, give the file path.

### Spec form

`SPEC.md` is a design document. It states what changes and where, in the sections listed above. Nothing else belongs in it.

- **A correctly worded requirement survives review on its own.** When a review agent flags a requirement, the fix is to word that requirement more precisely — never to append a justification defending it. A spec that argues for its own decisions is a spec that stated them imprecisely.
- **Write for a reader encountering the spec cold.** Every sentence must be actionable without knowing what came before it: no references to prior review rounds, earlier drafts, findings, other runs, or the history of a decision. A spec has no memory of how it was written.
- **No commit hashes, branch names, or git references.** The spec describes the code as it will be, not the commits that got it there. If a change matters, describe the change; the reader cannot resolve a hash and should not have to.
- **State each fact once**, in the section that owns it. Do not restate a decision in a second section so that section reads standalone. A one-line change in the code must not require edits in five places in the spec.
- **No open questions.** Anything needing Jessica's ruling goes in `REVIEW-FINDINGS.md` — not as a section, not as a risk list, not as an inline "confirm this is intended."
- **No findings, risk registers, or review provenance.** No "See Risk R6" pointers, no "Amended: round 2" headers, no "correction to the original justification" paragraphs.
- **Judgments only when they compress.** A reason for a design choice belongs in the spec only if it fits naturally as a short sentence inside the section it explains. If it needs a paragraph defending itself against an alternative, it is not spec content.
- **No code blocks, pseudocode, or function signatures.** Name the identifiers — class, method, file, column, route, verbatim string — and say what changes. Column types, nullability, and defaults are the exception.

Write `REVIEW-FINDINGS.md` in the working directory for everything the spec excludes: open questions awaiting a ruling, accepted risks and their blast radius, and anything a review round surfaced that is not yet a design decision. Decisions Jessica confirms move to `approved-decisions.md` and are then edited into the section of `SPEC.md` that owns them.

### Step 6: Print the summary

After writing `SPEC.md`, print in conversation:

**Plain English Summary:** 1-2 paragraphs, no jargon, no identifiers. What is this feature doing and why? Write it so someone who doesn't read code can understand the intent.

**Blast Radius Analysis:** For every part of the system this feature touches:
- What existing behavior changes?
- What existing code needs to be modified?
- What callers, consumers, or downstream systems are affected?
- If this is wrong, what breaks? One component? One workflow? The whole app?

## What good specs look like

Good specs are specific enough that the planning agent knows what to build and the review agent knows what to verify. Compare:

**Bad (vague):**
> Add a notifications table and show notifications in the UI.

**Good (specific):**
> Add a `notifications` table with `user_id` (bigint, not null, FK to users), `notifiable_type`/`notifiable_id` (polymorphic, not null), `read_at` (timestamp, nullable), `created_at`. Index on `(user_id, read_at)` for the unread-notifications query. The `NotificationsController#index` endpoint returns paginated notifications for the current user, scoped through Pundit. The React `useNotifications` hook polls this endpoint on a 30-second interval, following the pattern in `useJobBoardStats.ts:12-28`. The notification bell in `TopNav.tsx` shows an unread count badge.

The review agent will verify every claim against the codebase. Anything you assert must be true. If you're unsure whether something exists or works a certain way, verify it before writing it in the spec.
