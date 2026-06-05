# lifecycle-integration -- Round 1

## Findings

- F1 [HIGH] Phase ordering: spec says Phase 8 is after Phase 7, but LIFECYCLE.md says Phase 7 (hardening) reads all failure reports and extracts lessons. If QA is Phase 8 (after hardening), then hardening cannot incorporate QA findings. The spec's summary says "After implementation passes adversarial code review (Phase 6)" -- this suggests QA should happen after Phase 6, before Phase 7 (hardening). The spec's blast radius section says "Phase 8 is added after Phase 7" but the body text says it comes after Phase 6. These are contradictory.

  Looking at the lifecycle flow: Phase 6 reviews the implementation, Phase 7 does hardening. QA should happen between Phase 6 and Phase 7, so that QA findings can feed into hardening. This means QA should be Phase 7, and the current Phase 7 (hardening) should become Phase 8.

  **Fix:** The spec should clearly state that QA is Phase 7 and hardening moves to Phase 8. OR: QA is Phase 8 and hardening stays at Phase 7 but is acknowledged to not benefit from QA findings. Either is valid -- the spec just needs to be internally consistent.

  Taking the least disruptive approach: keep QA as Phase 8 (after hardening), but acknowledge that hardening does not incorporate QA findings. The hardening phase extracts lessons from code review failure reports; QA failure reports go back to Phase 5 (impl) directly, which is how the spec already describes the loop.

  **Fix applied:** Clarify that Phase 8 is after Phase 7, and the QA-to-impl loop bypasses hardening.

- F2 [HIGH] Re-entry from QA to impl and the Phase 6 question. The spec says: "Orchestrator goes back to Phase 5 (implementation)" and "After the fix, QA resumes (not restarts -- the round counter continues)." But what about Phase 6 (impl review)? After the impl agent fixes QA-reported issues, does the fix go through Phase 6 (code review) again before returning to QA? The spec is silent on this.

  Options:
  (a) Skip Phase 6 on re-entry (QA already validated the behavior, code review is redundant)
  (b) Run Phase 6 again (ensures the fix doesn't introduce new code-quality issues)

  The spec should explicitly state which approach is used.

  **Fix:** State that QA-driven fixes skip Phase 6 on re-entry. QA already validates behavior; the fix is typically small and targeted. Running full code review on a QA fix would add significant overhead.

- F3 [MED] Missing orchestrator prompt file. Every phase in the lifecycle has a prompt file (e.g., `spec-review-prompt.md`, `impl-prompt.md`). Phase 8 would need a `qa-prompt.md` (or similar). The spec does not mention this file. The orchestrator prompt contains the convergence loop logic, team dispatch logic, and the QA agent instructions. Without it, the lifecycle integration is incomplete.

- F4 [MED] Gate file naming. The lifecycle uses `SPEC-REVIEW-COMPLETE.md` and `IMPL-REVIEW-COMPLETE.md`. The spec proposes `QA-COMPLETE.md`. The naming is consistent (it is a *-COMPLETE.md pattern) but the spec should be explicit that this is the Phase 8 gate file.

## Amendments Applied

- Spec: clarified Phase 8 position (after Phase 7) and that QA-to-impl loop skips Phase 6.
- Spec: clarified QA-COMPLETE.md as the Phase 8 gate file.
