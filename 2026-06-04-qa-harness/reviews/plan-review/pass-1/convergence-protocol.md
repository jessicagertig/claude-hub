# Convergence Protocol — Pass 1

## Fact Check

- **Claim:** "5-round cap with 2-consecutive-clean-pass convergence" matches existing lifecycle.
  - Verified: LIFECYCLE.md Phase 2 (spec review) uses "up to 5 rounds" with "two consecutive clean passes" (line 55). Phase 6 (impl review) uses the same pattern (line 97). Correct.

- **Claim:** "Default team size is 3 agents; this is configurable via `qa_team_size` in `qa-config.yml`."
  - Verified: Spec says "Default team size is 3 agents; this is configurable via `qa_team_size` in `qa-config.yml`" (SPEC.md). Plan's `QAConfig.qa_team_size: int = 3`. Consistent.

- **Claim:** "Agents execute sequentially within a round."
  - Verified: Spec says "Agents execute sequentially within a round, not in parallel." LIFECYCLE.md Phase 8 says "Individual QA agents do NOT start or stop the server. Agents execute sequentially." Consistent.

- **Claim:** "if two agents disagree on a finding, it stays alive for the next round."
  - Verified: Spec says "if two agents found the same bug, the finding with the most detailed evidence wins. If agents disagree on whether a prior finding is valid (one confirms, one invalidates), the finding stays alive." Consistent.

- **Claim:** "Only HIGH and BLOCKER findings affect convergence."
  - Verified: Spec says "Only HIGH and BLOCKER findings affect convergence." Consistent.

- **Claim:** Plan's section 11 says "Disagreement semantics for convergence" -- "only unanimous invalidation counts as a change."
  - Verified: This is a deferred open question from the spec review (MED #1). The existing qa-prompt.md at `~/claude-hub/features/qa-prompt.md` (Step 6) says: "A disagreed-on finding (one agent confirms, another invalidates) is NOT a change -- it stays alive but does not reset the counter. Only unanimous invalidation counts as a change." So the prompt already resolves this.

## Completeness

Spec requirements covered by this angle:
1. Severity scale (BLOCKER, HIGH, MED, LOW) -- plan section 8, qa-prompt.md Step 4
2. Convergence criteria (two consecutive clean passes) -- plan section 8 Step 6
3. Round mechanics (seed plan, dispatch, execute, consolidate, evaluate) -- plan section 8 Steps 1-6
4. Round cap (5 rounds) -- plan section 8 Step 7
5. Deduplication by reproduction steps -- plan section 8 Step 5
6. Disagreement handling -- plan section 11 + qa-prompt.md Step 6
7. FAILURE-REPORT.md for sending issues back -- plan section 8 Step 7
8. QA-COMPLETE.md gate file -- plan section 8 Step 8
9. QA-ESCALATION.md for round cap -- plan section 8 Step 9

All spec requirements for convergence addressed.

## Findings

No BLOCKER, HIGH, or MED findings.

## Amendments Applied

None needed.
