# Plan Review — QA Verification Harness

## Pass 1 Summary

| Angle | BLOCKER | HIGH | MED | Outcome |
|-------|---------|------|-----|---------|
| server-lifecycle | 0 | 0 | 2 | Clean |
| seed-data-design | 0 | 0 | 1 | Clean |
| convergence-protocol | 0 | 0 | 0 | Clean |
| playwright-mcp-integration | 0 | 0 | 0 | Clean |
| pipeline-scalability | 0 | 0 | 1 | Clean |
| lifecycle-integration | 0 | 2 | 0 | 2 amendments applied |
| claude-md-compliance | 0 | 0 | 0 | Clean |

Two HIGH findings, both in lifecycle-integration:
1. Plan said to "Add Phase 8 section" to LIFECYCLE.md, but it already exists
2. Plan put `prompts/qa-prompt.md` inside the package, but the prompt already exists at `~/claude-hub/features/qa-prompt.md`

Both amended: 6 locations in plan.md updated to reference existing files instead of creating new ones.

## Pass 2 Summary

| Angle | BLOCKER | HIGH | MED | Outcome |
|-------|---------|------|-----|---------|
| server-lifecycle | 0 | 0 | 0 | Clean, amendments verified |
| seed-data-design | 0 | 0 | 0 | Clean |
| convergence-protocol | 0 | 0 | 0 | Clean |
| playwright-mcp-integration | 0 | 0 | 0 | Clean |
| pipeline-scalability | 0 | 0 | 0 | Clean |
| lifecycle-integration | 0 | 0 | 0 | Clean, all 6 amendment locations verified |
| claude-md-compliance | 0 | 0 | 0 | Clean, all known failure patterns checked |

No new findings. All Pass 1 amendments verified correct and consistent.

## Verdict: APPROVED

0 BLOCKER, 0 HIGH findings after amendments. The plan is correct, complete, and safe.

---

## Reviewed Plan

The reviewed plan is the file at `/Users/jessica/claude-hub/2026-06-04-qa-harness/plan.md` with the following amendments applied during this review:

### Amendments applied

1. **Section 3 (Package Structure):** Removed `prompts/` directory from the tree. Added note that the Phase 8 orchestrator prompt already exists at `~/claude-hub/features/qa-prompt.md`.

2. **Section 4 (Files to Create):** Changed "Config and prompts" to "Config". Removed `prompts/qa-prompt.md` from the file table. Added note that the prompt already exists. Changed LIFECYCLE.md entry from "Add Phase 8 section after Phase 7" to "Verify existing Phase 8 section is consistent with the spec."

3. **Section 8 (Phase 8 Orchestrator Prompt):** Updated header from `prompts/qa-prompt.md` to "already exists at `~/claude-hub/features/qa-prompt.md`". Updated preamble to instruct the implementation agent to verify the existing prompt, not create a new one. Changed "Prompt length estimate" subsection to "Prompt verification note" with actual line count (260 lines).

4. **Section 10 (Build Sequence):** Changed Phase 6 from creating files to verifying existing ones.

5. **Section 12 (Estimated Scope):** Updated to "14 new files + 2 verifications" and "~1,480 LOC" (removed prompt and lifecycle addition counts).

### Key verification results

- All file paths, class names, method names, and line numbers in the plan are accurate against the reference codebase
- The help pipeline analog patterns are correctly identified and the plan's adaptations are justified
- The existing `~/claude-hub/features/qa-prompt.md` (260 lines) covers all 9 steps described in plan section 8
- The existing `~/claude-hub/features/LIFECYCLE.md` Phase 8 section (lines 115-128) is complete and consistent with the spec
- All global CLAUDE.md hard rules are respected (no DATABASE_URL, no .env modification, Cypress cleanup via HTTP only, no database drops)
- All hub CLAUDE.md rules are respected (no files written into source repos, subdirectory created for new work)
- All hub Known Failure Patterns are addressed (stale references, discarded information, precondition checks, shared-resource conflicts, pipeline-specific names)
