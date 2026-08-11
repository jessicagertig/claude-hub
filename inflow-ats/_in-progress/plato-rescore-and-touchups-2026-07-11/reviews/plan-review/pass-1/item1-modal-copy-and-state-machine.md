# item1-modal-copy-and-state-machine — Pass 1

Scope: Task A1 (`BulkGenerateAiSummariesConfirmModal.tsx`, SPEC 1.1–1.4).

## Fact Check

| Claim (plan) | Verify | Result |
|---|---|---|
| `Icon` line 7, `FormContainer` line 8 already imported (A1.1) | Read modal | TRUE — lines 7, 8 |
| `const [errors, setErrors] = React.useState([]);` present (A1.2 anchor) | line 46 | TRUE |
| `const shortfall = Math.max(0, processableCount - available);` at line 51 + comment above (A1.3) | lines 50-51 | TRUE |
| `rescoreRequested: false,` at line 74 (A1.4) | line 74 | TRUE |
| `shortfallText` fragment at lines 105-110 (A1.5) | lines 105-110 | TRUE |
| four-branch `instructions` const lines 112-150 (A1.5) | lines 112-150 | TRUE |
| submit `disabled={isLoading || processableCount === 0}` at line 160 (A1.7) | line 160 | TRUE |
| `return (...)` at lines 177-198 (A1.8) | lines 177-198 | TRUE |
| `Styled.Caveat` lines 236-248, `Styled.Callout` lines 250-270 (A1.9) | lines 236-270 | TRUE |
| `Styled.Instructions` + `Styled.ButtonContainer` kept | lines 208-234 | TRUE |
| `Styled.Info` pinned verbatim from `CustomQuestionModal` `:254-273` | Read CustomQuestionModal | TRUE — body identical, label renamed to `BulkGenerateAiSummariesConfirmModal_Info` |
| info-block usage pinned from `CustomQuestionModal:192-199` (`Tooltip`>`Styled.Info`>`Icon name="alert-circle"`+span) | lines 192-199 | TRUE |
| `Styled.RescoreCheckbox` pinned from `RunPlatoReviewAllModal:178-184` (`${t.mt(4)}`) | lines 178-184 | TRUE — label renamed |
| `Styled.Statement` pinned from `RunPlatoReviewAllModal:186-206` | lines 186-206 | TRUE — body identical, label renamed |
| `FormCheckbox` contract (`name`,`label`,`description`,`checked`,`onChange`,`disabled?`) | Read FormCheckbox `:5-45` | TRUE — Props match; `disabled` short-circuits `handleClick` |
| Tooltip import path `@ats/src/components/shared/Tooltip` | used by CustomQuestionModal analog | TRUE |

## Completeness (SPEC 1.1–1.4)

- 1.1 checkbox: A1.1 import, A1.2 state, A1.8 JSX (`name="rescore"`, exact label/description, `checked`, toggling `onChange`, `disabled={candidatesCount === 0}`), A1.9 style, A1.4 `rescoreRequested: rescore`. COVERED.
- 1.2 copy restructure: A1.3 `candidatesToScoreCount`/`shortfall`, A1.5 delete old, A1.6 5-state `bodyCopy` in precedence 1→2→3→4, A1.7 submit-disabled `isLoading || candidatesCount===0 || (!rescore && processableCount===0)`. COVERED. State strings verified verbatim vs SPEC 1.2 (numeric `0` in state 2; "Up to " only when `!isProcessableCountExact && !rescore`; leading "The" kept in state 4; shortfall vs normal credit variants). `creditCopy` uses `shortfall > 0` — correct: in states 3/4 `candidatesToScoreCount > 0`, and `shortfall > 0` mathematically implies it, so the analog's extra `&& candidatesToScoreCount > 0` is not needed and SPEC pins `shortfall > 0`.
- 1.3 overestimate info block: renders only `!isProcessableCountExact && !rescore`, verbatim short message + Tooltip label. COVERED.
- 1.4 Statement block: A1.8 JSX + A1.9 style, string verbatim vs SPEC 1.4. COVERED.
- Old `Styled.Caveat`, `Styled.Callout`, `shortfallText`, 4-branch `instructions` all deleted (A1.5/A1.9). COVERED.
- Return restructure moves info/checkbox/statement to direct children of `CenterModal` with empty `<FormContainer .../>` at end — matches the analog's structure (`RunPlatoReviewAllModal` lines 116-154), which compiles with an empty FormContainer. COVERED.

## Findings
- No issues found.

## Amendments Applied
- None.
