# Hardening Report

Rules added to `/Users/jessica/claude-hub/CLAUDE.md` under a new "Known Failure Patterns" section, based on actual failures from the QA Verification Harness spec and implementation reviews.

## Rules added

### 1. Stale references after amendments

**Rule:** When amending a spec or document, search the entire document for every other reference to the old concept and update them all in the same amendment.

**Failures:** Spec Round 2 found 3 stale `test_frr` references and a stale "Phase 7" reference, both left behind by Round 1 amendments. Spec Round 3 found a stale "in parallel" reference contradicting the sequential model introduced in Round 2. This pattern repeated across two consecutive rounds -- amendments that fix one location but leave stale references elsewhere.

**Frequency:** 3 occurrences across 2 rounds. Clear pattern.

### 2. Do not discard information callers need

**Rule:** When a helper function has access to data its callers need (status codes, error details, metadata), return that data. Do not force callers to hardcode substitutes.

**Failure:** Impl Round 1: `_request` returned only the parsed response body, discarding `response.status_code`. `_execute_step` hardcoded `"status_code": 200` for every request. QA agents consuming this output would get misleading evidence about what actually happened.

**Frequency:** 1 occurrence, but the pattern (helper function silently drops metadata that the caller then fakes) generalizes broadly.

### 3. Verify preconditions before network calls

**Rule:** Before making HTTP calls to a service, verify the service is alive. Opaque connection timeouts are not acceptable when a precondition check would produce an actionable error.

**Failure:** Spec Round 1: seed/cleanup commands made HTTP calls without checking whether the server was running.

**Frequency:** 1 occurrence, but a universal infrastructure pattern.

### 4. Account for shared-resource conflicts in multi-agent designs

**Rule:** When multiple agents share a resource, explicitly state whether they run in parallel or sequentially and document the isolation mechanism.

**Failures:** Spec Round 1: parallel agents sharing one Playwright browser session would race. Spec Round 2: parallel agents sharing one database would destroy each other's data during cleanup. Both required switching to sequential execution.

**Frequency:** 2 occurrences across 2 rounds. Clear pattern.

### 5. Do not embed pipeline-specific names in generic infrastructure

**Rule:** Use pipeline-agnostic names when building cross-pipeline infrastructure. Rename pipeline-specific terminology before putting it in the generic layer.

**Failure:** Spec Round 1: `test_frr` (a Rails/Foreman concept) was used as the generic name for "run a test script," with an incorrect definition.

**Frequency:** 1 occurrence, but the pattern (leaking pipeline-specific concepts into shared infra) generalizes.

## Findings NOT added (one-offs or already covered)

- **Missing seed endpoints from catalog** -- specific to this feature's data requirements, not a generalizable pattern.
- **Unspecified team size default** -- borderline; decided this is covered by the shared-resource conflicts rule (team size only mattered because of its interaction with parallelism and resource sharing). A standalone "specify all operational defaults" rule would be too vague.
- **`stop_from_state_file` sends SIGTERM without waiting** -- MED severity, process lifecycle detail. Not elevated to a rule.
- **`validate_plan` does not check params** -- MED severity, acceptable for v1 per plan risk notes.
- **No MED threshold in convergence protocol** -- LOW, by design.
