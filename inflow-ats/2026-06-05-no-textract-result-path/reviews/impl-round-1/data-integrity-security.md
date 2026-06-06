# data-integrity-security — Impl Round 1

## Findings

### Data integrity
- Change 1: `update_columns` skips callbacks. This is intentional — we only need to set the FK, not trigger `after_commit` callbacks (which would fire `destroy_previous_textract_results` prematurely). Correct.
- Change 2: `summary.destroy` uses standard Rails destroy, which triggers callbacks. The `after_commit :destroy_previous_textract_results, on: :update` callback only fires on `:update`, not `:destroy`. No unintended side effects.
- Change 2: `find_by(status: :textract_processing, stale: false)` — correct query. Only finds the specific waiting summary, not other summaries.

### Authorization
- Change 2: `OrganizationUser.find_by(id: summary.requested_by_organization_user_id)` — looks up the user who requested the summary. This is an internal job context (no HTTP request, no user input). No authorization check needed — the job already has access to the data. Correct.

### Injection
- No user input in any of the 3 changes. All queries use ActiveRecord query interface with bound parameters. No injection risk.

No issues found.
