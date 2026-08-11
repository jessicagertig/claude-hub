# reinventing-the-wheel (always-on impl) — Round 2

- Checkbox reuses shared `FormCheckbox`; tooltip reuses shared `Tooltip`; info block copies the established `CustomQuestionModal` `Styled.Info` pattern; Statement block copies the established `RunPlatoReviewAllModal` `Styled.Statement`. No new bespoke component invented. ✓
- Recipient resolution reuses the `job.organization_users.actives` scope + the `JobApplicationMailer#hiring_team_new_job_application` map shape, rather than hand-rolling a query. ✓
- Strong-param `require(...).require(:rescore_requested)` reuses the bulk controller's proven pattern. ✓
- Interactor gate reuses the bulk interactor's exact condition string. ✓
- No duplicate helper/util created where one exists.

## Findings
No issues found.
