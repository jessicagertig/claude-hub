# Generate Feature-Specific Review Angles

You are reading a feature spec and the codebase to produce review angles for both the spec review and the post-implementation review. The output is a single file that both review agents will consume.

## Ground rules

- You are NOT reviewing the spec. You are scoping what needs to be reviewed.
- Read the live codebase (path in `REPO-PATH` in the working directory). Read-only.
- Read the pipeline's CLAUDE.md for project rules and conventions.

## Context

Read the pipeline CLAUDE.md (found by going up from the working directory to the pipeline root). It tells you the source repo path, tech stack, and where conventions live. Conventions come from multiple places — the pipeline CLAUDE.md, the source repo's own CLAUDE.md, a conventions directory if one exists, a reference repo if one is named, and the existing codebase patterns themselves.

## Inputs (read these first, in order)

1. The spec file in the working directory (SPEC.md)
2. `approved-decisions.md` if present
3. The pipeline CLAUDE.md
4. The conventions sources (if one exists) — read the relevant areas for the subsystems this feature touches

## Process

### Step 1: Read the spec and identify touched subsystems

Read the full spec. List every model, controller, service, component, route, test file, and other artifact this feature touches or creates.

### Step 2: Find the closest analog

Does the codebase (or reference repo, if one is named in the pipeline CLAUDE.md) already have an end-to-end flow that does the same kind of thing this feature does? A similar workflow, a CRUD flow for a related entity, a pipeline stage, an integration — whatever matches the shape of work.

If one exists, trace every layer of it. Write down the complete pipeline with file paths.

If a reference repo is specified, check there too — the analog might be in the reference project rather than (or in addition to) the current one.

**The closest analog is the primary blueprint.** If the analog does something differently from the general convention, the new feature should follow the analog — it shares the same domain constraints.

### Step 3: Identify the thematic review angles

Angles are thematic concerns, not layer silos. Each angle spans whatever layers it needs to. Examples:

- "state-management-review" — a feature with lifecycle states needs a reviewer who traces the state model across all layers
- "api-contract-review" — a feature touching API contracts needs a reviewer who checks the schema and its consumers together
- "concurrency-review" — a feature with async operations needs a reviewer who checks race conditions across workers and shared state
- "authorization-review" — a feature with permission changes needs a reviewer who traces auth checks end-to-end
- "data-pipeline-review" — a feature with data transformations needs a reviewer who verifies each stage's input/output contracts

Aim for 4-8 angles total. Each angle is a broad lens the reviewer looks through.

For each angle, identify:
- The relevant files across all layers
- The analog's files in the same thematic area (if an analog exists)
- The relevant convention files as context (if a conventions sources exists)

### Step 4: Write the output

Write `reviews/REVIEW-ANGLES.md` in the working directory:

```
# Review Angles — [feature name]

Generated from: [spec file]
Date: YYYY-MM-DD

## Subsystems touched
[Bulleted list with file paths]

## Closest analog
[If one exists — name it and trace every layer with file paths]
[If from a reference repo, note which repo]
[If no analog exists, say so — this affects which always-on checks apply]

**Priority rule:** Where the analog deviates from convention, the analog wins. Note the deviation so the reviewer doesn't flag it.

## Angles

### [angle-name] (e.g., "api-contract", "authorization", "state-management")
**What this covers:** [one sentence — the thematic concern]
**Files across all layers:**
- [file path]
- ...
**Analog files for comparison:** [analog's files in this area, if exists]
**Convention context:** [relevant convention files to read for background, if any]

### [next angle]
...

## Always-on checks

These apply to every feature regardless of thematic angles. Review agents MUST address each applicable check with the same rigor as thematic angles.

### Source accuracy
Verify every file path, class, method, and component the spec references against the current source.

### Test coverage
Check what existing tests cover the affected code and what new tests the spec should require.

### Reinventing the wheel / pattern compliance
[INCLUDE ONLY IF: an analog exists, OR a reference repo is specified, OR the codebase has established patterns for this kind of work.]
Verify the feature follows the analog's patterns and existing codebase conventions rather than inventing new approaches. A new approach requires explicit justification in the spec.

### Backward compatibility
[INCLUDE ONLY IF: there are existing consumers, downstream systems, or users who could be affected.]
Identify all consumers of modified code and verify they are addressed.

### Analog completeness
[INCLUDE ONLY IF: an analog exists.]
Verify the new feature has a corresponding piece for every layer of the analog pipeline. A missing layer is a BLOCKER.
```

## After you finish

Print `reviews/REVIEW-ANGLES.md` in the conversation so it can be reviewed before the review agents run.
