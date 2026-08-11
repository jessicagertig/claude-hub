# Angle 4 — API surface: route, controller, serializer, authorization — Round 2

All files in this angle are byte-identical to the round-1-reviewed state (verified: `git diff e7b8cef0a HEAD` empty for the controller, serializer, routes hunk, and their specs). Merge did not touch them.

## Re-verified at HEAD

- **Route:** `resource :ai_job_criteria, only: [:show, :create], controller: 'ai_job_criteria'` at routes.rb:266, inside the `resources :jobs do` block (:224), after `bulk_channel_messages` per plan D-6.
- **Controller:** `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found')` + block in both actions; authorize AFTER find with explicit queries (`:show?` / `:update_ai_settings?`); Flipper `AI_APPLICANT_SUMMARY` gate on POST only; blank-description 422 with the exact spec message BEFORE the model call; POST renders the same serializer payload (idempotent no-op while in-flight via the model guards); no begin blocks, no bangs, zero params methods; no job-status conditions anywhere (regenerate-any-state honored).
- **Serializer:** four attributes exactly (`criteria`, `extracted_at`, `status`, `zero_criteria_failure`); all computed via Job model methods (`latest_succeeded_ai_job_criteria`, `latest_ai_job_criteria`, `zero_criteria_extraction_failure?`); safe navigation, no fabricated `|| false`; no criteria fields added to `Api::V1::JobSerializer` (grep clean).
- **Authorization:** no new policy methods (job_policy.rb / ai_job_application_summary_policy.rb untouched in the diff).
- **Specs:** all six payload states, create-enqueue args `[row.id, current_organization_user.id]`, blank-description/Flipper 422s with no row, in-flight no-ops, draft AND published, authz split — passing in this round's suite run.

## Findings

No issues found.
