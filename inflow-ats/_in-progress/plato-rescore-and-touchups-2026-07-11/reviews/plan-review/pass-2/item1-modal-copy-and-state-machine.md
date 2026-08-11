# item1-modal-copy-and-state-machine — Pass 2

## Pass 1 corrections for this angle
- None (no Pass 1 findings in this angle's scope).

## Fresh sweep
- Re-verified the 5-state precedence (A1.6) is total and non-overlapping: state 1 (`candidatesCount===0`) → 2 (`!rescore && processableCount===0`) → 3 (`!rescore`) → 4 (else = rescore). Every input falls into exactly one branch. Matches SPEC 1.2 order.
- Submit-disabled (A1.7) exactly enables states 3 & 4 and disables 1 & 2. `loading={isLoading}` retained with `disabled` including `isLoading` — pairing intact.
- Deleting `shortfallText` + `instructions` + `Styled.Caveat` + `Styled.Callout` leaves no dangling reference: the return JSX (A1.8) is fully replaced and references only `bodyCopy`, `Styled.Instructions`, `Styled.Info`, `Styled.RescoreCheckbox`, `Styled.Statement`, `FormContainer`. Clean.
- Empty `<FormContainer errors={errors} buttons={modalButtons} onSubmit={handleOnConfirm} />` still surfaces validation errors and buttons — identical to the analog's usage, which compiles. `handleOnConfirm` validation path (`available`, `setErrors`) is untouched.
- D1 decision (keep `Styled.Instructions` wrapper vs analog `Styled.Body`) preserves state 1 byte-identically and its bold `<span>`; SPEC leaves the wrapper unpinned — pin-faithful.
- Emotion labels renamed to the pinned `BulkGenerateAiSummariesConfirmModal_*` names; theme utilities used standalone (no `font-size: ${t.text.x}` misuse — known-failure #1).

## Findings
- No issues found.

## Amendments Applied
- None.
