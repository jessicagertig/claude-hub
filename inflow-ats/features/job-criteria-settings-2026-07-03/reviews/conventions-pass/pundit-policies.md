# Conventions pass: pundit_policies.md

Diff reviewed: `git diff develop...HEAD -- app/controllers/api/v1/ai_job_criteria_controller.rb app/policies` at 68e5e6a4e in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings

No issues found.

Evidence checked:

- **Authorize-after-find**: `app/controllers/api/v1/ai_job_criteria_controller.rb:6` (`authorize job, :show?`) and `:13` (`authorize job, :update_ai_settings?`) both sit inside the `exists(current_organization.jobs.where(id: params[:job_id]), ...)` block, immediately after the job is found — matches the rule's "authorize AFTER finding/building resource" pattern (pundit_policies.md lines 32-38, 66-75). In `create`, authorization runs before the Flipper gate, description guard, and `extract_job_criteria_immediately` call.
- **Explicit policy queries**: both calls name the policy method explicitly (`:show?`, `:update_ai_settings?`). Authorizing the related `job` from a job-nested controller matches the documented pattern at pundit_policies.md lines 52-63.
- **No new policy methods**: `git diff develop...HEAD -- app/policies` is empty and no branch commits touch `app/policies/job_policy.rb`. Both referenced methods pre-exist on develop: `JobPolicy#show?` at app/policies/job_policy.rb:12 and `JobPolicy#update_ai_settings?` at app/policies/job_policy.rb:24.
