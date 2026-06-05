# inflow-ats — Pipeline Scratchpad

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Stack:** Ruby 3.1+ / Rails 6.1+ / PostgreSQL / Pundit / Sidekiq · TypeScript 4+ / React 18+ / React Query / Emotion
**Status:** Focus pipeline.
**Conventions sources:**
- This file (`~/claude-hub/inflow-ats/CLAUDE.md`) — pipeline-level rules and known failure patterns
- The source repo's `CLAUDE.md` — core development rules, critical "AI keeps getting these wrong" rules
- `cursor_rules/` directory in the source repo — 45 rules files organized by area (backend, frontend, cypress). Read `core_critical_rules.md` plus the area-specific `_base.md` for each area you touch. Do NOT read all 45 upfront.
- Existing codebase patterns — the codebase itself is a conventions source. Find analogs for whatever you're building.

## What lives in the source repo (authoritative — do not duplicate here)

- `CLAUDE.md` (~500 lines) — core development rules, critical "AI keeps getting these wrong" rules
- `cursor_rules/` — full conventions per area (backend, frontend, cypress, etc.)
- `.claude/agents/` — existing agent definitions (under review; Jessica plans to evaluate which to keep)
- `.claude/commands/cci.md` — existing slash command

The source repo is authoritative for code conventions. **Sessions launched into this scratchpad must read the source repo's `CLAUDE.md` and the relevant `cursor_rules/` area files.** The agent prompts in `_templates/` enforce this.

## What lives here (in this scratchpad)

Cross-session artifacts that should NOT be written into the source repo:

- `features/<YYYY-MM-DD-slug>/` — multi-session feature design, plans, in-progress notes
- `investigations/<YYYY-MM-DD-slug>/` — bug traces, flaky test diagnosis, perf investigations
- `pr-reviews/<PR-number>/` — adversarial PR reviews and notes
- (other workflow subdirs as we add them)

## In-progress working artifacts

Pipeline-specific working artifacts that need durable file storage during a session — draft agents specific to inflow-ats, in-flight investigation notes, feature design drafts that may or may not graduate to a permanent location — live in `~/claude-hub/inflow-ats/_in-progress/<artifact-name>/`, with each work item getting its own per-item subdirectory.

These artifacts do NOT live in the hub-root `~/claude-hub/_in-progress/`. That location is reserved for hub-level and cross-pipeline working artifacts (see the hub root `CLAUDE.md` for the full convention).

The user retains complete control over `_in-progress/` contents: graduate artifacts to their permanent location by moving them, or delete entire `_in-progress/` subdirectories without affecting anything outside.

## Hard rules inherited from global `~/.claude/CLAUDE.md`

These apply to every inflow-ats session and override anything else:

- **Database safety hard rules** — no DROP DATABASE, no `rails db:reset`/`db:setup`/`db:schema:load`, no direct `psql` writes or reads, no setting `DATABASE_URL`, no editing `.env`. Read/write the DB only via running app, `rails console`, or `rails runner`.
- **Pre-commit tests are non-negotiable** — never `--no-verify`, never rewrite tests to pass. Commit via `nvm use && git commit ...` outside the sandbox.
- **Never work directly on `master`** — always a branch.

## Feature Development Harness

This pipeline has pipeline-specific prompt overrides at `~/claude-hub/inflow-ats/features/`. These override the generic prompts at `~/claude-hub/features/` for inflow-ats work (they add `cursor_rules/` integration and Rails/React-specific guidance). Read `~/claude-hub/features/LIFECYCLE.md` for the orchestrated flow — it will find the inflow-ats overrides automatically.

## Pipeline-specific rules

(Add inflow-ats-only rules here that aren't already in the source repo's CLAUDE.md and aren't global.)

## Known Failure Patterns

Rules extracted from adversarial review findings. Each cites its motivating failure.

### 1. Emotion theme utilities are complete CSS declarations, not raw values

`t.text.sm`, `t.text.xs`, etc. are `css` template literals that already include the `font-size:` property declaration. Use them standalone, not inside a `font-size:` property.

```tsx
// WRONG -- produces "font-size: font-size: 0.875rem;" (invalid CSS)
font-size: ${t.text.sm};

// CORRECT -- standalone usage
${t.text.sm};
```

*Motivated by: email-subjects-phase-1 impl-round-2 frontend-contract F1 -- `ChannelMessageTemplateSelectionModal.tsx` line 207 produced invalid CSS.*

### 2. Parallel-field features: trace every pipeline end-to-end before implementing

When adding a new field that parallels an existing field through multiple pipelines (e.g., `subject` paralleling `body`), enumerate every code path the original field flows through BEFORE writing code. For each path, verify the new field is threaded through: controller permit, controller sanitize, interactor/job processing, model validation, mailer consumption, serializer exposure, anonymization, and frontend form/validation/mutation/display. A missed path means the field silently drops and the fallback fires without the user knowing.

*Motivated by: email-subjects-phase-1 review structure -- the spec and impl reviews verified subject flowed through all 7 channel_message creation paths and 4 distinct pipelines (single-send, bulk, automation, apply-response). The implementation got this right, but only because the spec and plan explicitly enumerated every path. Without that enumeration, paths get missed.*

### 3. Specs and plans must include test requirements

Every spec and implementation plan must state which existing tests need updating and what new test coverage is required. "No tests" is acceptable only when explicitly documented with reasoning (e.g., test infrastructure unavailable), never by omission.

*Motivated by: email-subjects-phase-1 spec-round-1 always-on-checks F2 -- the spec had no test plan section. No tests were created during implementation. The absence was caught by review but should have been caught at spec time.*

### 4. ActionMailer calls require `.deliver_now` or `.deliver_later`

Calling `SomeMailer.some_method(...)` without `.deliver_now` or `.deliver_later` returns a lazy `ActionMailer::MessageDelivery` object. The mailer method body never executes. The email is silently never sent. Every mailer invocation in a job, controller, or service MUST chain a delivery method. When writing specs for code that calls a mailer, stub the mailer class method to return an `instance_double(ActionMailer::MessageDelivery)` and verify that `.deliver_now` (or `.deliver_later`) is called on it -- do not stub the mailer class alone, as that masks missing delivery calls.

*Motivated by: weekly-engagement-digest impl-round-2 BLOCKER -- `WeeklyDigestJob` called `WeeklyDigestMailer.weekly_digest(...)` without `.deliver_now`. The email was silently never sent. The job spec masked this by stubbing `WeeklyDigestMailer` at the class level without verifying delivery. A previous review round flagged this as MED and dismissed it, proving the pattern needs an explicit rule.*

### 5. Full-stack feature specs must list all modified files, not just new files

When specifying a feature that touches existing files (controllers, serializers, TypeScript interfaces, UI components), the spec must explicitly list every modified file and what changes. New files are obvious; modifications to existing files are where things get missed. If a feature adds a new preference/field/column, trace it through every layer that already handles the analogous existing fields and list each one.

*Motivated by: weekly-engagement-digest spec-round-1 -- spec listed new files but omitted `MeController` (needs `settings_params` permit change) and `UserSettings` TypeScript interface (needs new field). Both are existing files that require modification for the feature to work. The review caught them, but the implementing agent would have missed them without the spec listing them.*
