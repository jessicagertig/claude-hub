# Inflow ATS — Generate Feature-Specific Review Angles

You are reading a feature spec and the inflow-ats codebase to produce review angles for both the spec review and the post-implementation review. The output is a single file that both review agents will consume.

## Ground rules

- You are NOT reviewing the spec. You are scoping what needs to be reviewed.
- Read the live codebase (path in `REPO-PATH` in the working directory). Read-only.
- Follow `~/claude-hub/inflow-ats/CLAUDE.md` safety rules.

## Inputs (read these first, in order)

1. The spec file in the working directory (SPEC.md or design-spec.md)
2. `approved-decisions.md` if present
3. `~/claude-hub/inflow-ats/CLAUDE.md`
4. `<REPO>/cursor_rules/core_critical_rules.md` (where `<REPO>` is the path in `REPO-PATH`)

## Process

### Step 1: Read the spec and identify touched subsystems

Read the full spec. List every model, controller, service, serializer, policy, route, job, React component, hook, query, context, migration, and test file this feature touches or creates.

### Step 2: Find the full-stack analog

Does the codebase already have an end-to-end flow that does the same kind of thing this feature does? A subscription flow, a CRUD workflow for a similar entity, an approval pipeline, an import/export flow, an invitation flow — whatever matches the shape of work.

If one exists, trace every layer of it — frontend component, mutation hook, API endpoint, controller action, service/interactor, serializer, policy, background job, mailer, model callbacks. Write down the complete pipeline with file paths.

There may be only one analog. That's fine — one complete pipeline is still the pattern to follow.

**The full-stack analog is the primary blueprint.** If the analog does something differently from the general convention, the new feature should follow the analog — the analog shares the same domain constraints.

### Step 3: Identify the thematic review angles

Angles are thematic concerns, not layer silos. Each angle spans whatever layers it needs to. A "backend contract" angle covers models, controllers, serializers, and the frontend that consumes them — because a contract mismatch can only be found by looking across layers.

Look at the feature and identify the themes that matter. Examples from real reviews:

- "state-machine-review" — a feature with lifecycle states needs a reviewer who traces the state model across the model, controller, worker, and storage layers
- "graphql-contract-review" — a feature touching the API contract needs a reviewer who checks the schema, the resolver, and the frontend consumer together
- "concurrency-review" — a feature with async operations needs a reviewer who checks race conditions across workers, controllers, and shared state
- "authorization-review" — a feature with permission changes needs a reviewer who traces policy checks from the route through the controller to the serializer
- "source-accuracy-review" — verifies file paths, identifiers, and claims in the spec against the actual codebase
- "test-coverage-review" — checks what's tested, what's not, and whether tests actually exercise the failure modes they claim to

Aim for 4-8 angles total. Each angle is a broad lens the reviewer looks through, not a specific check. The reviewer is smart enough to find issues — they just need to know which theme to focus on and which files are in scope.

For each angle, identify:
- The relevant files across all layers (not just one layer)
- The analog's files in the same thematic area (if an analog exists) — the reviewer compares the feature against the analog
- The relevant `cursor_rules/` files as convention context (not the scope of the review — just conventions the reviewer should know about)

### Step 4: Write the output

Write `reviews/REVIEW-ANGLES.md` in the working directory:

```
# Review Angles — [feature name]

Generated from: [spec file]
Date: YYYY-MM-DD

## Subsystems touched
[Bulleted list with file paths]

## Full-stack analog
[If one exists — name it and trace every layer with file paths]
- Frontend: [component] → [hook/mutation]
- API: [route] → [controller#action]
- Backend: [service/interactor] → [model callbacks] → [background job]
- Auth: [policy]
- Serialization: [serializer]
- Tests: [spec files, Cypress files]

[If no full-stack analog exists, say so]

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Note the deviation so the reviewer doesn't flag it.

## Angles

### [angle-name] (e.g., "backend-contract", "authorization", "state-management")
**What this covers:** [one sentence — the thematic concern]
**Files across all layers:**
- [file path]
- ...
**Analog files for comparison:** [analog's files in this area, if exists]
**Convention context:** [relevant cursor_rules/ files to read for background]

### [next angle]
...

## Always-on checks

These apply to every feature regardless of angles:

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source.

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require.

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed.

### Full-stack analog completeness
[If analog exists] The review agent verifies the new feature has a corresponding piece for every layer of the analog pipeline. A missing layer is a BLOCKER.
```

## After you finish

Print `reviews/REVIEW-ANGLES.md` in the conversation so it can be reviewed before the review agents run.
