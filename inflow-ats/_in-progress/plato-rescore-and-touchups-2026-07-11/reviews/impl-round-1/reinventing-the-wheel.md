# reinventing-the-wheel (always-on impl) — Round 1

- Checkbox uses the existing `FormCheckbox` component (not a hand-rolled input). ✓
- Overestimate info block reuses `Tooltip` + the `CustomQuestionModal` `Styled.Info` pattern. ✓
- Statement block reuses the `RunPlatoReviewAllModal` `Styled.Statement` pattern. ✓
- Mailer recipient resolution reuses the `job_application_mailer.rb` `.actives`/`.map`/`any?` pattern. ✓
- Strong-param requiredness reuses the bulk controller's `require(...).require(:rescore_requested)` pattern (leans on Rails `require` treating `false` as present) rather than inventing custom presence validation. ✓
- Gate reuses the bulk interactor's exact condition. ✓
- Boolean typecast handled by the existing `:boolean` virtual attribute, not re-parsed in the controller. ✓

No bespoke reimplementation of an existing capability.

## Findings
No issues found.
