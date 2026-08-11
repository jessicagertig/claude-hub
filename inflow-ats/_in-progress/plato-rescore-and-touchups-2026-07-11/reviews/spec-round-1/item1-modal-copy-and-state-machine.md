# item1-modal-copy-and-state-machine — Round 1

Trace: SPEC 1.1-1.4 → BulkGenerateAiSummariesConfirmModal.tsx (current) → RunPlatoReviewAllModal.tsx (pinned source, :35-151) → CustomQuestionModal/index.js:192-199,254-273 (pinned source) → FormCheckbox.tsx (contract)

## Source-accuracy checks (all confirmed against worktree)
- `rescoreRequested: false` at `BulkGenerateAiSummariesConfirmModal.tsx:74` — CONFIRMED (grep).
- Deletable blocks all present in current file: 4-branch `instructions` const (:112-150), `shortfallText` fragment (:105-110), `Styled.Caveat` (:236-248), `Styled.Callout` (:250-270). CONFIRMED.
- Pinned source `RunPlatoReviewAllModal.tsx`: `RescoreCheckbox` usage :135-143 and style :178-184; `Statement` usage :145-151 and style :186-206; Body credit copy :117-133. SPEC 1.1 cite ":135-143", SPEC 1.4 cite ":145-151 / :186-206" — CONFIRMED accurate.
- Pinned source `CustomQuestionModal/index.js`: info block (Tooltip+Styled.Info+`Icon name="alert-circle"`+span) at :192-199; `Styled.Info` styles at :254-273 (`t.text.xs`,`t.mt(-1)`,`t.mb(5)`, gray[400] dark/gray[600] light, flex, align-items center, line-height 1.3, svg `h(6) w(4) mr(1)` min-width 16px, hover cursor text). SPEC 1.3 cite ":192-199" and ":254+" — CONFIRMED accurate; the style list in SPEC 1.3 matches verbatim.
- `FormCheckbox` contract: `name`, `label`, `checked`, `onChange:(name,value)=>void`, `disabled?`, `description?`. SPEC 1.1 props (`name="rescore"`, label, description, `checked={rescore}`, toggling onChange) are all valid against the contract. The analog's `onChange={() => setRescore(c => !c)}` ignores the (name,value) args and toggles — SPEC 1.1 "onChange that toggles the state" matches.

## State-machine logic (verified sound at spec level)
- `candidatesToScoreCount = rescore ? candidatesCount : processableCount`, `shortfall = Math.max(0, candidatesToScoreCount - available)` (SPEC 1.2). Rescore-aware; replaces the current `shortfall = Math.max(0, processableCount - available)` (:51). Correct.
- 5 states in precedence order 1→2→3→4 are mutually exclusive and total: state1 `candidatesCount===0` (highest), state2 `!rescore && processableCount===0`, state3 `!rescore && processableCount>0`, state4 `rescore`. The `rescore && candidatesCount===0` corner cannot occur (state1 wins; checkbox disabled in state1 so rescore cannot be set). No gap.
- Submit disabled = `isLoading || state1 || state2`. Verified equivalent to the analog's `isLoading || candidatesToScoreCount===0` in every state (when !rescore, candidatesToScoreCount=processableCount; when rescore, =candidatesCount). Consistent.
- Overestimate info block renders only `!isProcessableCountExact && !rescore` (SPEC 1.3) — drops when checked (count becomes exact) or when exact. Correct.

## Findings
- F1 [LOW] SPEC 1.2 restructures the body copy but does not pin the body-copy WRAPPER styled component. The current file renders copy in `Styled.Instructions` (styled.p: `t.mb(5)` + bold-`span` styling, :208-219); the pinned analog uses `Styled.Body` (styled.p: `t.mt(2)`, gray[300]/gray[600], line-height 1.5, :168-176). SPEC pins the RescoreCheckbox/_Info/_Statement emotion labels but not the body wrapper, so an implementer could keep `Styled.Instructions` (different margins/color; bold span affects only the state-1 verbatim copy which contains a `<span>`). Cosmetic and decision-adjacent (visual fidelity vs the "mirror the analog" methodology). NOT amended — surfaced for Jessica. Recommend the SPEC state whether the body renders in the retained `Styled.Instructions` or an analog-matching `Styled.Body`.

## Amendments Applied
- None in this angle (F1 is LOW, decision-adjacent, escalated not amended).

## Rejected as false positives (guardrails)
- Leading "The" on the per-stage checked sentence (state 4) diverging from all-stages (1.5) — owner-ruled (guardrail 2), not a defect.
- Per-stage overestimate info block absent from the all-stages analog — owner-ruled (SPEC 1.3), not a structural mismatch.
