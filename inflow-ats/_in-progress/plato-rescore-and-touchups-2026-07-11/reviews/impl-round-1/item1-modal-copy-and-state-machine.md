# item1-modal-copy-and-state-machine — Round 1

Reviewed committed file `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` (commit f9ec4a80d) against SPEC 1.1–1.4 pinned text and the pinned sources (`RunPlatoReviewAllModal.tsx`, `CustomQuestionModal/index.js`, `FormCheckbox/index.tsx`).

## Verified
- Credit math: `candidatesToScoreCount = rescore ? candidatesCount : processableCount` (:53), `shortfall = Math.max(0, candidatesToScoreCount - available)` (:54) — rescore-aware, matches SPEC 1.2.
- 5 states present in precedence order 1→2→3→4 (:127-161):
  - State 1 no-selection (`candidatesCount === 0`) kept VERBATIM — byte-identical to pre-commit `instructions` first branch (confirmed against `f9ec4a80d~1`), incl. bold `<span>`/`<b>`.
  - State 2 (`!rescore && processableCount === 0`): "0 of the {candidatesCount} candidates selected…" numeric `0`, no credit sentence.
  - State 3 (`!rescore`): "Up to " prefix gated on `!isProcessableCountExact`, then `creditCopy`.
  - State 4 (checked): leading "The" preserved (owner-ruled divergence).
- `creditCopy` (:108-124) matches SPEC shortfall/normal variants verbatim; `shortfall > 0` is the exact SPEC condition (per-stage `creditCopy` only renders when `candidatesToScoreCount > 0`, so the all-stages extra `&& candidatesToScoreCount > 0` guard is correctly unnecessary — not a deviation).
- Checkbox (:199-208): `name="rescore"`, exact label/description strings, `checked={rescore}`, toggling `onChange`, `disabled={candidatesCount === 0}` (visible-not-checkable in no-selection). `Styled.RescoreCheckbox` = `styled.div` with only `${t.mt(4)}`, label `BulkGenerateAiSummariesConfirmModal_RescoreCheckbox`.
- Submit disabled (:171): `isLoading || candidatesCount === 0 || (!rescore && processableCount === 0)` — enables states 3/4, disables 1/2. `loading={isLoading}` present (pairing intact, known-failure #11).
- Overestimate info block (:191-198) renders only when `!isProcessableCountExact && !rescore`; Tooltip + `Styled.Info` (Icon `alert-circle` + span); short message and Tooltip label verbatim. `Styled.Info` styles are a verbatim copy of `CustomQuestionModal` `Styled.Info` (only `label:` renamed to `BulkGenerateAiSummariesConfirmModal_Info`).
- Statement block (:209-216, styles :286-305): copy verbatim; `Icon name="mail"`; styles match `RunPlatoReviewAllModal` `Styled.Statement`; label `BulkGenerateAiSummariesConfirmModal_Statement`; uses `${t.text.sm}` standalone (no `font-size:` wrap — known-failure #1 clear).
- `rescoreRequested: rescore` (:77) replaces the pre-commit literal `false`.
- Deleted: old 4-branch `instructions`, `shortfallText`, `Styled.Caveat`, `Styled.Callout` (all confirmed present pre-commit, absent post-commit).

## Findings
No issues found.
