# Angle 6: Mailer Bug Fixes and Template Renames -- Round 4

## Fresh adversarial focus areas

1. **`admin_recipients` implementation.** `organization.organization_users.select(&:is_admin).map(&:user).uniq`. The `is_admin` method on `OrganizationUser` is a boolean column that returns true for `org_admin`, `org_owner`, and `god_admin` roles. Members (`org_user`) and interviewers (`org_interviewer`) have `is_admin == false`. The spec tests confirm this. Correct.

2. **Mailer spec uses `create_credit_test_organization_user` helper.** The helper creates a User and an OrganizationUser with the specified role. The spec creates owner, admin, member, and interviewer org users. The owner is set up separately via `credit_test_owner_organization_user` (which finds the org's owner from setup). Correct.

3. **`BulkJobApplicationAiSummaryResultMailer` template names.** `'user-bulk-ai-summary-complete'` and `'user-bulk-ai-summary-failed'`. These follow the existing template naming convention (`user-` prefix, kebab-case). Correct.

4. **`BulkJobApplicationAiSummaryResultMailer` uses `User.find` (not `find_by`).** If the user_id or job_id doesn't exist, it raises `ActiveRecord::RecordNotFound`. This is intentional -- the mailer should not silently swallow missing records. The caller (`notify_failure`/`notify_complete`) guards with `return unless user` before calling the mailer (but uses `find_by` to get the user, not the mailer's `find`). Wait -- `notify_failure` does `user = User.find_by(id: payload['user_id'])` and `return unless user`, then calls the mailer which does `User.find(user_id)`. The same user_id is passed. Since `find_by` already confirmed the user exists, the `find` in the mailer should not raise. And in `notify_complete`, the user is already resolved. Correct.

## Findings

**No findings.**
