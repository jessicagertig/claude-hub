# Lifecycle Integration — Pass 1

## Fact Check

- **Claim:** Plan says "Phase 8 (QA Verification) is added after Phase 7 (hardening)."
  - Verified: LIFECYCLE.md already has Phase 8 (lines 115-128). It says "Proceed to Phase 8" in the Phase 7 gate (line 113). Consistent.

- **Claim:** Plan says to "Add Phase 8 section after Phase 7" to LIFECYCLE.md.
  - **ISSUE:** LIFECYCLE.md already HAS Phase 8 defined (lines 115-128). The plan says "Edit `~/claude-hub/features/LIFECYCLE.md` -- add Phase 8 section" as if it doesn't exist yet. This is factually wrong -- LIFECYCLE.md already has Phase 8 with the full description, gate conditions, and config requirements. The plan needs to say "verify Phase 8 section in LIFECYCLE.md" or "update if needed" rather than "add."

- **Claim:** Plan says the prompt file goes in `prompts/qa-prompt.md` inside the qa-harness package.
  - **ISSUE:** The prompt file already exists at `~/claude-hub/features/qa-prompt.md` (260 lines). This is the standard location per the lifecycle override mechanism: "For each phase, the orchestrating agent looks for the prompt file at `~/claude-hub/<pipeline>/features/<prompt-file>` first, then falls back to `~/claude-hub/features/<prompt-file>`." The plan proposes putting it in `~/claude-hub/qa-harness/prompts/qa-prompt.md` which is NOT in the lifecycle's search path. The orchestrator would never find it there.

- **Claim:** "QA-COMPLETE.md is the Phase 8 gate file."
  - Verified: LIFECYCLE.md Phase 8 (line 127): "Gate: `reviews/QA-COMPLETE.md` exists and says APPROVED." Spec also says this. Consistent.

- **Claim:** "QA failure reports loop back to Phase 5 (impl) directly, skipping Phase 6 (impl review) on re-entry."
  - Verified: Spec says "Orchestrator goes back to Phase 5 (implementation), skipping Phase 6 (impl review) on re-entry." LIFECYCLE.md Phase 8 says the same. qa-prompt.md Step 7 says "Skip Phase 6 (impl review) on re-entry." Consistent across all three sources.

- **Claim:** "QA-ESCALATION.md" for round cap escalation.
  - Verified: LIFECYCLE.md says "If the 5-round cap is hit without convergence, `reviews/QA-ESCALATION.md` is written instead." qa-prompt.md Step 9 matches. Consistent.

## Completeness

Spec requirements covered by this angle:
1. Phase 8 position in lifecycle (after Phase 7) -- already in LIFECYCLE.md
2. Gate file (QA-COMPLETE.md) -- in LIFECYCLE.md and qa-prompt.md
3. Escalation file (QA-ESCALATION.md) -- in LIFECYCLE.md and qa-prompt.md
4. Failure loop back to Phase 5, skip Phase 6 -- in spec, LIFECYCLE.md, and qa-prompt.md
5. Orchestrator prompt file -- qa-prompt.md already exists at features/qa-prompt.md
6. Artifact trail -- in spec, LIFECYCLE.md, and qa-prompt.md

All spec requirements addressed, but the plan has two factual errors about the current state of files.

## Findings

- F1 [HIGH] Plan section 4 "Files to Create" lists "Edit `~/claude-hub/features/LIFECYCLE.md` -- Add Phase 8 section after Phase 7" (line 104). But LIFECYCLE.md already has Phase 8 defined (lines 115-128) with the full description, gate, config requirements, and artifact trail. The implementation agent would attempt to add a duplicate Phase 8 section. The plan should say "Verify Phase 8 section in LIFECYCLE.md is consistent with the spec" instead of "Add Phase 8 section."

- F2 [HIGH] Plan section 3 defines `prompts/qa-prompt.md` inside the `~/claude-hub/qa-harness/` package directory. But the Phase 8 orchestrator prompt already exists at `~/claude-hub/features/qa-prompt.md` (260 lines, fully written), which is the standard location per the lifecycle's prompt file resolution mechanism (`~/claude-hub/features/<prompt-file>` fallback). The plan's proposed location (`~/claude-hub/qa-harness/prompts/qa-prompt.md`) is outside the lifecycle search path and would never be found by the orchestrator. The plan should either (a) remove the `prompts/` directory from the package structure and reference the existing file, or (b) if the prompt needs changes, edit the existing file at `~/claude-hub/features/qa-prompt.md`.

## Amendments Applied

- plan.md: Section 3 package structure -- removing `prompts/` directory and `qa-prompt.md` since the prompt file already exists at `~/claude-hub/features/qa-prompt.md`
- plan.md: Section 4 "Files to Create" -- removing `prompts/qa-prompt.md` from the file list and changing LIFECYCLE.md entry from "Add Phase 8 section" to "Verify Phase 8 section"
- plan.md: Section 10 Build Sequence Phase 6 -- updating to reflect that qa-prompt.md already exists and LIFECYCLE.md already has Phase 8
- plan.md: Section 12 Estimated Scope -- updating counts to remove prompt file
