# Kind Dispatch — Round 1

## Findings

No issues found.

Verified:
- `all_stages` controller sets `kind: 'all_stages'` (:41)
- Interactor passes `kind` to payload with default `'single_hiring_stage'` when absent (:90)
- Job `notify_complete` branches on `kind` for both link construction (:127-132) and mailer dispatch (:141-163)
- Job `notify_failure` branches on `kind` for mailer dispatch (:185-197)
- Both branches chain `.deliver_later` on mailer calls
- Existing `create` caller passes no `kind`, default applies correctly
- `hiringStageLink` in broadcast uses job-level URL for `all_stages`, stage-specific for `single_hiring_stage`
