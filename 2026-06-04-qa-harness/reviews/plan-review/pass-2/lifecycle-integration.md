# Lifecycle Integration — Pass 2

## Pass 1 Corrections Verification

1. **F1 amendment (LIFECYCLE.md):** Plan section 4 now says "Verify existing Phase 8 section is consistent with the spec (Phase 8 already exists in LIFECYCLE.md)" instead of "Add Phase 8 section after Phase 7." Verified correct.

2. **F2 amendment (qa-prompt.md):** Package structure no longer includes `prompts/` directory (section 3). Section 4 "Config" table has note about existing qa-prompt.md. Section 8 header now says "already exists at `~/claude-hub/features/qa-prompt.md`." Section 10 Build Sequence Phase 6 now says "Verify" instead of create. Section 12 counts updated to "14 new files + 2 verifications." All amendments applied correctly.

3. **Consistency check:** Do the amendments introduce any inconsistencies? Searched for remaining references to `prompts/qa-prompt.md` or "add Phase 8" in the plan. Section 8 still describes what the prompt "must cover" -- this is now framed as verification criteria for the existing prompt, not creation instructions. The preamble says "The implementation agent should verify the existing prompt is consistent with the spec and the plan below." Consistent.

## Fresh Scrutiny

- **Existing qa-prompt.md content verification:** I compared the existing `~/claude-hub/features/qa-prompt.md` against the plan's section 8 "What the prompt must cover." All 9 steps are present in the existing prompt:
  - Preamble: present (lines 1-5)
  - Step 1 (seed planning): present (lines 17-33)
  - Step 2 (server start): present (lines 35-43)
  - Step 3 (round dispatch): present (lines 45-55)
  - Step 4 (agent instructions): present (lines 58-155)
  - Step 5 (consolidation): present (lines 157-193)
  - Step 6 (convergence): present (lines 195-205)
  - Step 7 (failure loop): present (lines 207-215)
  - Step 8 (completion): present (lines 217-227)
  - Step 9 (escalation): present (lines 229-237)
  The existing prompt is complete and consistent with the plan.

- **LIFECYCLE.md Phase 8 content verification:** I compared the existing Phase 8 in LIFECYCLE.md (lines 115-128) against the spec. It covers:
  - QA orchestrator role: yes
  - Server lifecycle: yes ("starts the test server via `qa-harness start`")
  - Seed planning: yes ("dispatches a seed planner")
  - Round mechanics: yes ("up to 5 rounds of QA agents")
  - Team size: yes ("`qa_team_size` (default 3)")
  - Sequential execution: yes ("Agents execute sequentially")
  - Failure loop: yes ("loops back to Phase 5 (implementation), skipping Phase 6")
  - Gate file: yes ("`reviews/QA-COMPLETE.md`")
  - Escalation: yes ("`reviews/QA-ESCALATION.md`")
  - Config reference: yes ("`~/claude-hub/<pipeline>/qa-config.yml`")
  The existing LIFECYCLE.md Phase 8 is complete and consistent with the spec.

- **Artifact trail consistency:** LIFECYCLE.md's full artifact trail (lines 133-152) includes `seed-plans/`, `qa-round-1/`, `qa-round-2/`, and `QA-COMPLETE.md` under `reviews/`. This matches the spec's artifact trail exactly.

## Completeness Sweep

All spec requirements for lifecycle integration are addressed. The existing files (LIFECYCLE.md and qa-prompt.md) are already correct and complete. The plan now correctly directs the implementation agent to verify rather than create.

## Findings

No BLOCKER, HIGH, or MED findings.

## Amendments Applied

None needed.
