# item1-modal-copy-and-state-machine — Round 2

Independent re-verification of `BulkGenerateAiSummariesConfirmModal.tsx` (committed f9ec4a80d) against SPEC 1.1–1.4 pins.

- Imports: `FormCheckbox` (`@ats/src/components/forms/FormCheckbox`), `Tooltip` (`@ats/src/components/shared/Tooltip`) added; `Icon`/`FormContainer` already present. ✓ (SPEC 1.1/1.3)
- State: `const [rescore, setRescore] = React.useState(false);` added after `errors`. ✓
- Credit math: `candidatesToScoreCount = rescore ? candidatesCount : processableCount`; `shortfall = Math.max(0, candidatesToScoreCount - available)`. Old `processableCount`-based shortfall replaced. ✓ (SPEC 1.2)
- Mutation flag: `rescoreRequested: rescore` replaces literal `false` (line 77). trackEvent name/payload untouched (SPEC 1.8). ✓
- 5-state precedence 1→2→3→4 exact:
  - State 1 (`candidatesCount === 0`): no-selection copy byte-identical to prior, bold `<span>`. ✓
  - State 2 (`!rescore && processableCount === 0`): "0 of the {candidatesCount} candidates selected from this hiring stage don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." Numeric `0`, no credit sentence. ✓
  - State 3 (`!rescore`): `{isProcessableCountExact ? "" : "Up to "}` + "{processableCount} of the {candidatesCount} candidates selected from this hiring stage don't have a Plato review yet. {creditCopy}". ✓
  - State 4 (`else` = rescore): "The {candidatesCount} candidates selected from this hiring stage will be reviewed, including candidates that already have a review. {creditCopy}" — leading "The" owner-ruled divergence preserved. ✓
- `creditCopy` fragment: "Each successful review uses one AI credit" + shortfall variant (`shortfall > 0`) / normal variant (`candidatesToScoreCount`, `available`) — matches SPEC 1.2 pin verbatim. ✓
- Submit disabled: `isLoading || candidatesCount === 0 || (!rescore && processableCount === 0)` (= states 1 & 2 disabled, 3 & 4 enabled). `loading={isLoading}` retained (known-failure #11 pairing intact). ✓
- Overestimate info block renders only `!isProcessableCountExact && !rescore`, beneath body; `Icon name="alert-circle"` + short message "This count may be an overestimate." + Tooltip label verbatim. ✓ (SPEC 1.3)
- Checkbox: `name="rescore"`, exact label/description, `checked={rescore}`, toggling `onChange`, `disabled={candidatesCount === 0}` (visible-but-not-checkable in no-selection). ✓ (SPEC 1.1)
- Statement block replaces Callout: `Icon name="mail"` + verbatim string; `FormContainer` at end is empty. ✓ (SPEC 1.4)
- Deletions confirmed: `shortfallText`, four-branch `instructions`, `Styled.Caveat`, `Styled.Callout` all gone. ✓
- Emotion labels: `_RescoreCheckbox` (only `${t.mt(4)}`), `_Info` (verbatim from `CustomQuestionModal` `Styled.Info`), `_Statement` (verbatim from `RunPlatoReviewAllModal` `Styled.Statement`). ✓
- Theme utilities used standalone (`${[t.text.xs, ...]}`, `${t.text.sm}`) — never inside `font-size:` (known-failure #1). ✓

Note (spec-faithful, not a finding): the info block condition `!isProcessableCountExact && !rescore` does not exclude State 2; if an inexact Select-All yields `processableCount === 0`, "This count may be an overestimate" renders beneath the "0 of the..." copy. This is exactly what SPEC 1.3 pins ("only when isProcessableCountExact === false && !rescore"), so per the priority rule the pin wins.

## Findings
No issues found.
